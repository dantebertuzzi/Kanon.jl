# Que nó está sob o cursor.
#
# É geometria sobre `Span`, e nada além disso: nenhuma regra da linguagem mora aqui. A
# pergunta "o que está nesta posição" é do editor, e a resposta sai da árvore que o motor
# já construiu — se esta busca precisasse decidir alguma coisa sobre a linguagem, estaria
# no arquivo errado (D-029).

"A posição `(l, c)` está dentro do trecho? `endcol` é **inclusiva**: aponta o último caractere."
function contains(sp::Kanon.Span, l::Integer, c::Integer)
    (l > sp.line || (l == sp.line && c >= sp.col)) &&
        (l < sp.endline || (l == sp.endline && c <= sp.endcol))
end

"""
    Hit

O que a busca achou: o nó mais interno na posição, e o bloco que o contém — porque quase
toda resposta precisa dos dois. `block` é `nothing` quando a posição está no plano de
dados ou no das regras.
"""
struct Hit
    node::Any
    block::Union{Nothing,Kanon.Block}
    field::Union{Nothing,Kanon.FieldDecl}
    rule::Union{Nothing,Kanon.Rule}
end

Hit(node) = Hit(node, nothing, nothing, nothing)

"""
    at(model, linha, coluna) -> Hit | nothing

O nó mais interno que cobre a posição, procurado nos três planos.

O arquivo importa: um modelo composto tem nós de vários arquivos, e a posição vale só
dentro de um deles. Sem essa checagem, a linha 9 do fragmento responderia por uma consulta
na linha 9 do hospedeiro.
"""
function at(m::Kanon.Model, arquivo::Integer, l::Integer, c::Integer)
    t = m.template

    for f in t.data.fields
        f.span.file == arquivo && contains(f.span, l, c) &&
            return Hit(f, nothing, f, nothing)
    end

    for b in t.text.blocks
        b.span.file == arquivo && contains(b.span, l, c) || continue
        for p in b.children
            contains(p.span, l, c) || continue
            n = innermost(p.children, l, c)
            n === nothing || return Hit(n, b, nothing, nothing)
        end
        return Hit(b, b, nothing, nothing)          # o cabeçalho, ou uma linha em branco
    end

    for r in t.rules.rules
        r.span.file == arquivo && contains(r.span, l, c) || continue
        e = r.when === nothing ? nothing : innermost_expr(r.when, l, c)
        return Hit(e === nothing ? r : e, nothing, nothing, r)
    end

    return nothing
end

"O nó mais interno de uma lista de filhos de parágrafo. Grupos aninham; o resto não."
function innermost(nodes, l::Integer, c::Integer)
    for n in nodes
        contains(n.span, l, c) || continue
        if n isa Kanon.Group
            inner = innermost(n.children, l, c)
            return inner === nothing ? n : inner
        end
        return n
    end
    return nothing
end

function innermost_expr(e, l::Integer, c::Integer)
    contains(e.span, l, c) || return nothing
    if e isa Kanon.NotExpr
        inner = innermost_expr(e.operand, l, c)
        return inner === nothing ? e : inner
    elseif e isa Kanon.BinExpr
        for sub in (e.lhs, e.rhs)
            inner = innermost_expr(sub, l, c)
            inner === nothing || return inner
        end
    end
    return e
end

"O índice do arquivo do documento na tabela de fontes do modelo composto. `0` se não está lá."
function file_index(m::Kanon.Model, nome::AbstractString)
    i = findfirst(==(nome), m.template.sources)
    i === nothing ? 0 : Int(i)
end

"A posição do bloco em `text.blocks` — a chave das tabelas por bloco da `Analysis`."
blockpos(m::Kanon.Model, b::Kanon.Block) =
    something(findfirst(x -> x.name === b.name, m.template.text.blocks), 0)

"A declaração de campo de um `NodeId`, ou `nothing`."
function decl_of(m::Kanon.Model, node_id)
    i = findfirst(f -> Kanon.id(f) == node_id, m.template.data.fields)
    i === nothing ? nothing : m.template.data.fields[i]
end

"O bloco de nome `nome`, ou `nothing`."
function block_named(m::Kanon.Model, nome::Symbol)
    i = findfirst(b -> b.name === nome, m.template.text.blocks)
    i === nothing ? nothing : m.template.text.blocks[i]
end
