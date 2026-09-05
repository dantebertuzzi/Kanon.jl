# A árvore sintática.
#
# Quatro invariantes governam este arquivo (docs/ast.md). Cada uma tem teste.
#
#   I1  Todo nó é imutável. `struct`, nunca `mutable struct`.
#   I2  Nenhum resultado de análise mora no nó. Número de cláusula, tipo resolvido,
#       nulabilidade e estilo de bloco vivem em tabelas laterais produzidas por
#       `analyze`, endereçadas por `NodeId`.
#   I3  Nenhum nó depende da ordem de visita.
#   I4  Nada de `Dict` cuja iteração alcance o texto de saída.
#
# A tentação, ao implementar a F5, será guardar o número calculado dentro do `Block`.
# Funciona, é mais curto, e mata a v2 (D-011).

"Índice denso de nó. Denso para que as tabelas laterais sejam `Vector`, não `Dict` (I4)."
const NodeId = Int32

"""
    Span

Posição de um trecho no arquivo. Colunas são contadas em **caracteres**, 1-based —
é o que o redator vê no editor, não o que o byte diz.
"""
struct Span
    file::Int32
    line::Int32
    col::Int32
    endline::Int32
    endcol::Int32
end

Span(file::Integer, line::Integer, col::Integer) = Span(file, line, col, line, col)

"Junta dois trechos no menor que cobre os dois."
merge_span(a::Span, b::Span) = Span(a.file, a.line, a.col, b.endline, b.endcol)

abstract type Node end

id(n::Node) = n.id
span(n::Node) = n.span

# --- caminhos e literais -----------------------------------------------------

"""
    Path

Um caminho de campo: `price`, `seller.name`, `seller.spouse.name`.
"""
struct Path
    segments::Vector{Symbol}
    span::Span
end

Base.string(p::Path) = join(String.(p.segments), '.')
Base.show(io::IO, p::Path) = print(io, string(p))

"""
    Literal

Valor escrito no arquivo. `kind` é `:number`, `:text`, `:boolean`, `:date`, `:null` ou
`:constant` (hoje só `today`).
"""
struct Literal
    kind::Symbol
    value::Any
    span::Span
end

# --- plano de dados ----------------------------------------------------------

@enum CardKind SCALAR EXACT ATLEAST RANGE ANY

"""
    Cardinality

`SCALAR` sem colchetes; `EXACT` para `[2]`; `ATLEAST` para `[1..]`; `RANGE` para
`[2..5]`; `ANY` para `[]` e `[..5]` (que é `RANGE` com `lo == 0`).
"""
struct Cardinality
    kind::CardKind
    lo::Int32
    hi::Int32
end

Cardinality() = Cardinality(SCALAR, 0, 0)
islist(c::Cardinality) = c.kind !== SCALAR

@enum Presence REQUIRED OPTIONAL DEFAULTED

"""
    FieldDecl

Uma linha do plano de dados. `presence` é o que decide a nulabilidade, e portanto o que
sustenta o teorema da lacuna: só `OPTIONAL` pode ser nulo.
"""
struct FieldDecl <: Node
    id::NodeId
    name::Symbol
    type::Symbol
    card::Cardinality
    presence::Presence
    default::Union{Nothing,Literal}
    span::Span
end

"A ordem dos campos é semântica: governa a ordem dos erros e do checklist."
struct DataPlane
    fields::Vector{FieldDecl}
end

DataPlane() = DataPlane(FieldDecl[])

# --- plano do texto ----------------------------------------------------------

"""
    TextLit

Prosa literal. Os escapes (`{{`, `}}`, `[[`, `]]`, `((`, `))`, `\\:` e `\\\\` na coluna 0)
já estão resolvidos aqui: o renderizador nunca vê a forma escapada.
"""
struct TextLit <: Node
    id::NodeId
    value::String
    span::Span
end

"`{caminho}` ou `{caminho:formatador}`. `formatter === nothing` significa o padrão do tipo."
struct Interp <: Node
    id::NodeId
    path::Path
    formatter::Union{Nothing,Symbol}
    span::Span
end

"`{::nome}` — remissão a bloco numerado."
struct BlockRef <: Node
    id::NodeId
    target::Symbol
    span::Span
end

"""
    FlexPoint

Candidato a ponto de flexão: uma marca curta colada ao fim de uma palavra
(`portador(a)`). O núcleo **não sabe** quais marcas existem — quem registra é a camada
de idioma, e `parse` não consulta o ambiente. Portanto o léxico só reconhece a forma;
`analyze` decide se a marca está registrada e, se não estiver, trata o nó como prosa
literal `word * mark`.
"""
struct FlexPoint <: Node
    id::NodeId
    word::String
    mark::String
    span::Span
end

"`[ ... ]` — grupo opcional. Aninhável, mas nunca atravessa fronteira de parágrafo."
struct Group <: Node
    id::NodeId
    children::Vector{Node}
    span::Span
end

struct Paragraph <: Node
    id::NodeId
    children::Vector{Node}
    span::Span
end

"""
    Block

`unit` e `repeat` guardam o marcador **como escrito** (`:` com 2 repetições, `§` com 3).
Estilo e nível resolvidos moram na `Analysis`, não aqui: resolvê-los exige o ambiente,
e nó não guarda resultado de análise (I2).
"""
struct Block <: Node
    id::NodeId
    name::Symbol
    unit::Char
    repeat::Int8
    subject::Union{Nothing,Path}
    children::Vector{Paragraph}
    span::Span
end

"""
    IncludePoint

Onde um fragmento entra no plano do texto. `before` é o índice do bloco diante do qual
ele é inserido — `length(blocks) + 1` quando a inclusão está no fim.

O caminho fica **como escrito**: `parse` não lê arquivo, e resolver o caminho é do
carregador, que tem a raiz e as regras de segurança (D-005).
"""
struct IncludePoint
    path::String
    before::Int32
    span::Span
end

"""
A ordem dos blocos é a ordem da saída — invariante anti-XSLT (D-015).

`includes` só existe entre o parse e a composição: depois que `load_template` resolve os
fragmentos, o plano tem apenas blocos, e quem analisa e renderiza não sabe que houve
inclusão nenhuma.
"""
struct TextPlane
    blocks::Vector{Block}
    includes::Vector{IncludePoint}
end

TextPlane() = TextPlane(Block[], IncludePoint[])
TextPlane(blocks::Vector{Block}) = TextPlane(blocks, IncludePoint[])

# --- plano das regras --------------------------------------------------------

"""
Expressão do plano das regras. Não descende de `Node`, mas carrega `id` e `span` pelo
mesmo motivo: `analyze` endereça o caminho resolvido de cada expressão por `NodeId`, e
o contador de identificadores é o mesmo da árvore.
"""
abstract type RuleExpr end

id(e::RuleExpr) = e.id
span(e::RuleExpr) = e.span

struct PathExpr <: RuleExpr
    id::NodeId
    path::Path
    span::Span
end

struct LitExpr <: RuleExpr
    id::NodeId
    lit::Literal
    span::Span
end

struct NotExpr <: RuleExpr
    id::NodeId
    operand::RuleExpr
    span::Span
end

"`op` ∈ `:and :or :eq :ne :lt :le :gt :ge`."
struct BinExpr <: RuleExpr
    id::NodeId
    op::Symbol
    lhs::RuleExpr
    rhs::RuleExpr
    span::Span
end

"`property is rural`, `seller is not minor`."
struct AttrExpr <: RuleExpr
    id::NodeId
    subject::Path
    attr::Symbol
    negated::Bool
    span::Span
end

"""
    Rule

Uma linha do plano das regras. Um bloco admite no máximo um `when` e no máximo um
`one for each` (D-002); a checagem é da F2, porque exige a tabela de blocos.
"""
struct Rule <: Node
    id::NodeId
    block::Symbol
    when::Union{Nothing,RuleExpr}
    foreach::Union{Nothing,Path}
    span::Span
end

struct RulesPlane
    rules::Vector{Rule}
end

RulesPlane() = RulesPlane(Rule[])

# --- o modelo ----------------------------------------------------------------

struct LangVersion
    major::Int16
    minor::Int16
end

Base.show(io::IO, v::LangVersion) = print(io, v.major, '.', v.minor)

"""
    Template

O modelo analisado sintaticamente. **Não conhece `Environment`**: o mesmo `Template`
pode ser analisado em dois ambientes diferentes e produzir duas `Analysis`, que é
exatamente o que o teste de neutralidade precisa fazer.
"""
struct Template
    version::LangVersion
    language::Union{Nothing,Symbol}
    sources::Vector{String}
    data::DataPlane
    text::TextPlane
    rules::RulesPlane
    nnodes::Int32
end

"""
    source_of(tmpl, span) -> String

O arquivo em que o trecho está. `Span` guarda um **índice** na tabela de fontes, e não um
nome, porque um modelo composto tem várias fontes e repetir o nome em cada nó custaria
mais do que o modelo inteiro.

Existe porque resolver o índice não é opcional: um diagnóstico sobre um bloco vindo de
fragmento que nomeie o hospedeiro aponta uma linha que muitas vezes nem existe lá, e
quem seguir o ponteiro não acha nada.
"""
function source_of(t::Template, sp::Span)
    i = Int(sp.file)
    1 <= i <= length(t.sources) ? t.sources[i] :
        (isempty(t.sources) ? "<string>" : t.sources[1])
end

function Base.show(io::IO, t::Template)
    print(io, "Template(kanon ", t.version)
    t.language === nothing || print(io, ' ', t.language)
    print(io, ", ", length(t.data.fields), " campos, ",
          length(t.text.blocks), " blocos, ", length(t.rules.rules), " regras)")
end
