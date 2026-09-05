# O esqueleto de um modelo (F9).
#
# O roadmap pede um editor de três colunas — o modelo, a regra ao lado de cada bloco, e
# a pré-visualização sempre visível — e diz que ele **não é extra**: sem ele a linguagem
# fica, na prática, pior que um motor convencional (risco 16.2).
#
# O editor é uma aplicação, e não uma biblioteca. O que a biblioteca deve entregar é o
# que ele consome: **a estrutura do modelo, já resolvida**, para que a interface não
# precise reimplementar a análise (D-029). É o mesmo que um servidor de linguagem
# consumiria.
#
# Tudo aqui sai da `Analysis`, que já tem o trabalho feito. Não há segunda travessia com
# regras próprias — se houvesse, a coluna do meio poderia discordar do motor, e uma
# ferramenta que mente sobre o que vai sair é pior que nenhuma.

"""
    FieldUse

Um campo usado por um bloco: onde, com que formatador, e se ele pode faltar.

`guarded` é o que a coluna do meio precisa mostrar em vermelho quando falta: um campo
nulável **tem** de estar dentro de um grupo, e o editor pode dizer isso enquanto o
redator digita.
"""
struct FieldUse
    path::String
    typename::Symbol
    formatter::Symbol
    nullable::Bool
    guarded::Bool
    line::Int32
end

"""
    BlockOutline

Um bloco, como uma ferramenta precisa vê-lo: o que ele é, o que o governa, e o que ele
usa.

`rule` e `foreach` são o texto da regra que prende o bloco — a **coluna do meio** do
editor —, e `number` é o número que ele consome quando nada é removido.
"""
struct BlockOutline
    name::Symbol
    line::Int32
    level::Int
    number::Vector{Int32}
    label::Union{Nothing,String}
    subject::Union{Nothing,String}
    rule::Union{Nothing,String}
    foreach::Union{Nothing,String}
    rule_line::Int32
    fields::Vector{FieldUse}
    paragraphs::Int
end

"O bloco pode sumir ou repetir? É o que a interface sinaliza ao lado dele."
conditional(b::BlockOutline) = b.rule !== nothing
repeated(b::BlockOutline) = b.foreach !== nothing

"""
    outline(model) -> Vector{BlockOutline}

O esqueleto do modelo, na ordem do arquivo — que é a ordem da saída, porque regras só
removem e repetem (D-015).
"""
function outline(m::Model)
    t = m.template
    a = m.analysis
    out = BlockOutline[]

    for (pos, b) in enumerate(t.text.blocks)
        k_when = isempty(a.block_rule) ? Int32(0) : a.block_rule[pos]
        k_for = isempty(a.block_foreach) ? Int32(0) : a.block_foreach[pos]
        regra = k_when == 0 ? nothing : t.rules.rules[k_when]
        rep = k_for == 0 ? nothing : t.rules.rules[k_for]
        numero = isempty(a.numbering) ? Int32[] : a.numbering[pos]

        estilo = stylefor(m.env, b.unit)
        rotulo = (isempty(numero) || estilo === nothing) ? nothing :
                 String(estilo.number(numero, FormatContext(m.env, nothing)))

        push!(out, BlockOutline(
            b.name, b.span.line, length(numero), numero, rotulo,
            b.subject === nothing ? nothing : string(b.subject),
            regra === nothing ? nothing : rule_text(regra.when),
            rep === nothing ? nothing : string(rep.foreach),
            regra === nothing ? (rep === nothing ? Int32(0) : rep.span.line) : regra.span.line,
            field_uses(m, b), length(b.children)))
    end
    out
end

"Os campos que um bloco usa, na ordem em que aparecem no texto."
function field_uses(m::Model, b::Block)
    out = FieldUse[]
    for p in b.children
        collect_uses!(out, m, p.children)
    end
    out
end

function collect_uses!(out, m::Model, nodes)
    for n in nodes
        if n isa Interp
            rp = m.analysis.paths[id(n)]
            rp === nothing && continue
            push!(out, FieldUse(string(n.path), rp.typename,
                                m.analysis.formatter[id(n)], rp.nullable,
                                m.analysis.guarded[id(n)], n.span.line))
        elseif n isa Group
            collect_uses!(out, m, n.children)
        end
    end
end

"""
O texto de uma condição, reconstruído da árvore.

Reconstruído, e não copiado do arquivo: o editor precisa mostrar a condição **como o
motor a entendeu**, com a precedência explícita. `a and b or c` aparece como
`(a and b) or c`, que é o que ele vai fazer — e é a pergunta que o leitor não deveria
ter de fazer.
"""
function rule_text(e::Union{Nothing,RuleExpr})
    e === nothing && return nothing
    e isa PathExpr && return string(e.path)
    e isa LitExpr && return literal_text(e.lit)
    e isa NotExpr && return "not " * parenthesize(e.operand)
    if e isa AttrExpr
        return string(e.subject) * " is " * (e.negated ? "not " : "") * String(e.attr)
    end
    if e isa BinExpr
        op = get(RULE_OPS, e.op, String(e.op))
        return parenthesize(e.lhs) * " " * op * " " * parenthesize(e.rhs)
    end
    return "?"
end

const RULE_OPS = Dict(:and => "and", :or => "or", :eq => "==", :ne => "!=",
                      :lt => "<", :le => "<=", :gt => ">", :ge => ">=")

"Parênteses só onde a precedência os exige — mostrar `((a))` seria ruído."
parenthesize(e::RuleExpr) =
    e isa BinExpr && (e.op === :and || e.op === :or) ? "(" * rule_text(e) * ")" :
    rule_text(e)

function literal_text(l::Literal)
    l.kind === :text && return "\"" * l.value * "\""
    l.kind === :constant && return String(l.value)
    l.kind === :null && return "null"
    string(l.value)
end

# --- apresentação ------------------------------------------------------------

"""
    format_outline(io, model)

O esqueleto em texto, alinhado: o bloco à esquerda, a regra à direita.

São as duas primeiras colunas do editor, no terminal — e é o que responde à pergunta que
o roadmap chama de risco 16.2: *o que sai deste modelo, e sob que condição?*
"""
function format_outline(io::IO, m::Model)
    blocos = outline(m)
    if isempty(blocos)
        println(io, "o modelo não tem bloco nenhum.")
        return nothing
    end

    largura = maximum(length(rotulo_bloco(b)) for b in blocos)
    for b in blocos
        print(io, rpad(rotulo_bloco(b), largura + 2))
        marca = repeated(b) ? "* " : (conditional(b) ? "? " : "  ")
        print(io, marca)
        cond = condicao_texto(b)
        println(io, cond === nothing ? "sempre" : cond)

        for f in b.fields
            aviso = (f.nullable && !f.guarded) ? "  <- pode faltar, e não está em grupo" : ""
            println(io, " " ^ (largura + 4), "{", f.path, "} : ", f.typename,
                    f.nullable ? " opcional" : "", aviso)
        end
    end
    println(io)
    println(io, "  ? bloco condicional   * bloco repetido")
    return nothing
end

function rotulo_bloco(b::BlockOutline)
    prefixo = b.label === nothing ? "" : b.label * " "
    sujeito = b.subject === nothing ? "" : " <- " * b.subject
    string(prefixo, b.name, sujeito, "  (linha ", b.line, ")")
end

function condicao_texto(b::BlockOutline)
    partes = String[]
    b.foreach === nothing || push!(partes, "um por " * b.foreach)
    b.rule === nothing || push!(partes, "quando " * b.rule)
    isempty(partes) ? nothing : join(partes, ", ")
end

function format_outline(m::Model)
    io = IOBuffer()
    format_outline(io, m)
    String(take!(io))
end
