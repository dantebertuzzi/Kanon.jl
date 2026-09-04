# Utilidades da suíte.
#
# Os testes afirmam sobre o CÓDIGO do diagnóstico, não sobre a redação da mensagem.
# É o que permite melhorar as mensagens — que são o produto — sem quebrar a suíte.

using Kanon
using Dates
using Kanon: CODE_TITLES, sorted, Cursor, canonical_keywords

"Códigos emitidos ao analisar `src`, ordenados. Vazio se não houve erro."
function codes(src::AbstractString; name = "t.kanon")
    try
        parse_string(src; name)
        return String[]
    catch e
        e isa KanonSyntaxError || rethrow()
        return [d.code for d in sorted(e.diagnostics)]
    end
end

"O conjunto de diagnósticos lançado por `src`."
function diags(src::AbstractString; name = "t.kanon")
    try
        parse_string(src; name)
        return DiagnosticSet()
    catch e
        e isa KanonSyntaxError || rethrow()
        return sorted(e.diagnostics)
    end
end

"Analisa e devolve o modelo, falhando o teste com a mensagem formatada se houver erro."
function ok(src::AbstractString; name = "t.kanon")
    try
        return parse_string(src; name)
    catch e
        e isa KanonSyntaxError || rethrow()
        error("esperava um modelo válido, e vieram problemas:\n" * format_diagnostics(e.diagnostics))
    end
end

"Envolve um plano de texto mínimo em volta de um corpo, para testar planos isolados."
withtext(body) = "kanon 1\n\ntext\n\n: b\n" * body * "\n"

"Todos os nós de um modelo, em ordem de travessia."
function allnodes(t::Template)
    out = Kanon.Node[]
    for f in t.data.fields
        push!(out, f)
    end
    for b in t.text.blocks
        push!(out, b)
        for p in b.children
            push!(out, p)
            walknodes!(out, p.children)
        end
    end
    for r in t.rules.rules
        push!(out, r)
    end
    return out
end

function walknodes!(out, ns)
    for n in ns
        push!(out, n)
        n isa Group && walknodes!(out, n.children)
    end
end

"Os nós de texto do primeiro bloco, achatados."
function nodes1(t::Template)
    out = Kanon.Node[]
    for p in t.text.blocks[1].children
        append!(out, p.children)
    end
    out
end

"""
Toda interpolação do primeiro bloco, **inclusive as de dentro de grupos**. `nodes1` só
achata os filhos diretos do parágrafo, e uma interpolação protegida por colchetes não
aparece lá.
"""
function all_interps(t::Template)
    out = Interp[]
    for p in t.text.blocks[1].children
        collect_interps!(out, p.children)
    end
    out
end

function collect_interps!(out, ns)
    for n in ns
        n isa Interp && push!(out, n)
        n isa Group && collect_interps!(out, n.children)
    end
end

"Dump canônico da árvore. Serve de comparação estrutural e de documentação do formato."
function dump_tree(t::Template)
    io = IOBuffer()
    println(io, "kanon ", t.version, " ", t.language === nothing ? "-" : t.language)
    for f in t.data.fields
        println(io, "field ", f.name, " ", f.type, " ", f.presence, " ", f.card.kind,
                " ", f.card.lo, " ", f.card.hi, " ",
                f.default === nothing ? "-" : "$(f.default.kind)=$(f.default.value)")
    end
    for b in t.text.blocks
        println(io, "block ", b.name, " ", b.unit, b.repeat, " ",
                b.subject === nothing ? "-" : string(b.subject))
        for p in b.children
            println(io, "  para @", p.span.line)
            dump_nodes(io, p.children, 4)
        end
    end
    for r in t.rules.rules
        println(io, "rule ", r.block, " when=", r.when === nothing ? "-" : dump_expr(r.when),
                " foreach=", r.foreach === nothing ? "-" : string(r.foreach))
    end
    String(take!(io))
end

function dump_nodes(io, ns, ind)
    for n in ns
        pad = " "^ind
        if n isa TextLit
            println(io, pad, "text ", repr(n.value))
        elseif n isa Interp
            println(io, pad, "interp ", n.path, " ", n.formatter === nothing ? "-" : n.formatter,
                    " @", n.span.line, ":", n.span.col)
        elseif n isa BlockRef
            println(io, pad, "ref ", n.target)
        elseif n isa FlexPoint
            println(io, pad, "flex ", repr(n.word), " ", repr(n.mark))
        elseif n isa Group
            println(io, pad, "group")
            dump_nodes(io, n.children, ind + 2)
        end
    end
end

function dump_expr(e)
    e isa PathExpr && return string(e.path)
    e isa LitExpr  && return "$(e.lit.kind):$(e.lit.value)"
    e isa NotExpr  && return "not(" * dump_expr(e.operand) * ")"
    e isa BinExpr  && return "$(e.op)(" * dump_expr(e.lhs) * "," * dump_expr(e.rhs) * ")"
    e isa AttrExpr && return "is($(e.subject),$(e.attr)$(e.negated ? ",not" : ""))"
    return "?"
end
