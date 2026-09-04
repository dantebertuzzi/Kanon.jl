# As tabelas laterais da análise.
#
# Invariante I2, a que a F5 vai tentar quebrar: **nenhum resultado de análise mora no
# nó**. Tipo resolvido, nulabilidade, formatador efetivo, número de cláusula — tudo vive
# aqui, indexado por `NodeId`, e o nó continua sendo só o que o redator escreveu.
#
# As tabelas são `Vector`, não `Dict`, porque `NodeId` é denso (I4).

"""
    ResolvedPath

O que um caminho escrito no modelo quer dizer, depois de consultado o ambiente.

`nullable` é o campo que o teorema da lacuna usa: ele é verdadeiro se **qualquer**
segmento do caminho for opcional — a opcionalidade atravessa o tipo composto, senão o
teorema valeria só no primeiro nível, que é o mesmo que não valer.
"""
struct ResolvedPath
    kind::Symbol                 # :field | :subject_field | :constant
    typename::Symbol
    nullable::Bool
    card::Cardinality
    decl::NodeId                 # a declaração de origem, para a mensagem de erro; 0 se constante
end

"Valor neutro de `formatter` para os nós que não são interpolação."
const NO_FORMATTER = Symbol("")

"""
    Analysis

O resultado de `analyze`: tabelas laterais endereçadas por `NodeId`, mais os
diagnósticos acumulados.

Preenchimento por fase, para que a leitura do arquivo não engane: `paths` e `formatter`
são da F2.2; `guarded` é da F2.3; `block_index`, `block_rule` e `block_foreach` são da
F2.4; `numbering` é da F5.
"""
struct Analysis
    # por nó
    paths::Vector{Union{Nothing,ResolvedPath}}
    formatter::Vector{Symbol}
    guarded::Vector{Bool}

    # por bloco, indexadas pela POSIÇÃO em `template.text.blocks` — a ordem do arquivo,
    # que é também a ordem da saída (D-015)
    numbering::Vector{Vector{Int32}}
    block_rule::Vector{Int32}       # índice da regra `when` que prende o bloco; 0 se nenhuma
    block_foreach::Vector{Int32}    # idem para `one for each`

    # globais
    block_index::Vector{Pair{Symbol,NodeId}}
    diagnostics::Vector{Diagnostic}
end

function Analysis(n::Integer)
    Analysis(Union{Nothing,ResolvedPath}[nothing for _ in 1:n],
             fill(NO_FORMATTER, n),
             falses(n),
             Vector{Int32}[],
             Int32[],
             Int32[],
             Pair{Symbol,NodeId}[],
             Diagnostic[])
end

"O caminho resolvido de um nó, ou `nothing` se o nó não tem caminho ou não resolveu."
resolved(a::Analysis, n::Node) = a.paths[id(n)]
resolved(a::Analysis, e::RuleExpr) = a.paths[id(e)]

"O formatador efetivo de uma interpolação: `:default` quando o modelo não nomeia nenhum."
formatter(a::Analysis, n::Interp) = a.formatter[id(n)]

haserrors(a::Analysis) = any(d -> d.severity === :error, a.diagnostics)

diagnostics(a::Analysis) = DiagnosticSet(a.diagnostics)

function Base.show(io::IO, a::Analysis)
    n = count(!isnothing, a.paths)
    print(io, "Analysis(", n, " caminhos resolvidos, ",
          length(a.block_index), " blocos, ", length(a.diagnostics), " diagnósticos)")
end

"""
    Model

Um modelo carregado: a árvore, a análise e o ambiente em que ela foi feita.

`Template` é a árvore sintática pura, que não conhece ambiente nenhum; `Model` é o
modelo pronto para uso. A separação é o que permite analisar a mesma árvore em dois
ambientes — o que o teste de neutralidade faz.
"""
struct Model
    env::Environment
    template::Template
    analysis::Analysis
end

function Base.show(io::IO, m::Model)
    print(io, "Model(", length(m.template.data.fields), " campos, ",
          length(m.template.text.blocks), " blocos, ", m.env, ")")
end
