# As tabelas laterais da análise.
#
# Invariante I2, a que a F5 vai tentar quebrar: **nenhum resultado de análise mora no
# nó**. Tipo resolvido, nulabilidade, formatador efetivo, número de cláusula — tudo vive
# aqui, indexado por `NodeId`, e o nó continua sendo só o que o redator escreveu.
#
# As tabelas são `Vector`, não `Dict`, porque `NodeId` é denso (I4).

"""
    ResolvedPath

What a path written in the template means, once the environment has been consulted.

`nullable` is the field the gap theorem relies on: it is true if **any** segment of the
path is optional. Optionality propagates through composite types; otherwise the theorem
would hold only at the first level.
"""
struct ResolvedPath
    kind::Symbol                 # :field | :element | :subject_field | :constant
    typename::Symbol
    nullable::Bool
    card::Cardinality
    decl::NodeId                 # a declaração de origem, para a mensagem de erro; 0 se constante
end

"Valor neutro de `formatter` e `attribute` para os nós que não são do seu tipo."
const NO_FORMATTER = Symbol("")

"""
    Analysis

The result of `analyze`: side tables indexed by `NodeId`, plus the accumulated
diagnostics.

Filled in by phase: `paths` and `formatter` come from F2.2; `attribute`, which holds the
canonical name of an `is` written with a language alias, from D-076; `guarded` from F2.3;
`block_index`, `block_rule` and `block_foreach` from F2.4; `numbering` from F5.
"""
struct Analysis
    # por nó
    paths::Vector{Union{Nothing,ResolvedPath}}
    formatter::Vector{Symbol}
    attribute::Vector{Symbol}
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

"""
O atributo canônico de uma condição `is`: `precise` quando o modelo escreveu `preciso`. O
nó guarda o que o autor escreveu, e o render pergunta por aqui (I2, D-076).
"""
attribute(a::Analysis, e::AttrExpr) = a.attribute[id(e)]

haserrors(a::Analysis) = any(d -> d.severity === :error, a.diagnostics)

diagnostics(a::Analysis) = DiagnosticSet(a.diagnostics)

function Base.show(io::IO, a::Analysis)
    n = count(!isnothing, a.paths)
    print(io, "Analysis(", n, " caminhos resolvidos, ",
          length(a.block_index), " blocos, ", length(a.diagnostics), " diagnósticos)")
end

"""
    Model

A loaded template: the syntax tree, its analysis, and the environment it was analysed in.

`Template` is the bare syntax tree and knows no environment; `Model` is the template
ready to use. Keeping them apart is what allows the same tree to be analysed in two
environments, which the neutrality test does.
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
