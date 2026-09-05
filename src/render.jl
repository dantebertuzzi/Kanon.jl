# `render` — o passo que produz o documento.
#
#   Bound  ── erro de CONTRATO (com dados)
#     render
#   texto  ── só pode falhar por ORÇAMENTO (§11)
#
# Quatro restrições normativas (`docs/ast.md` §8), e nenhuma é negociável:
#
#   `render` é PURO: (Template, Analysis, dados, env) → String. Sem I/O, sem relógio,
#   sem aleatoriedade, sem estado global. `today` é injetado.
#
#   `render` NÃO EMITE DIAGNÓSTICO. Se `analyze` e `check` passaram, a única falha
#   possível é o orçamento de recursos.
#
#   Nada de execução de código do modelo, nada de acesso a campo não declarado (§11).
#
#   Determinismo: mesma entrada, mesma saída byte a byte.
#
# A parte difícil deste arquivo é a elisão, e ela está isolada em `elide.jl`.

"""
    PreviewMarker

O que ocupa o lugar de um valor garantido que ainda não veio, **só no rascunho**.

Existe como sentinela de render, e não como dado, porque não há como fabricar um valor
de um tipo arbitrário: um `«preco»` não é um `money`, e tentar injetá-lo como dado faria
o rascunho falhar exatamente onde ele precisa funcionar. O marcador vive no texto.
"""
struct PreviewMarker
    path::String
end

mutable struct RenderCtx
    bound::Bound
    fctx::FormatContext
    budget::Budget
    nodes::Int
    file::String
    # o sujeito do bloco corrente, quando o cabeçalho declara `<- caminho`
    subject::Any
    # rascunho: valor garantido que falta vira marcador visível, em vez de erro
    preview::Bool
end

function RenderCtx(b::Bound, budget::Budget, preview::Bool)
    RenderCtx(b, FormatContext(b.model.env, b.today), budget, 0,
              isempty(b.model.template.sources) ? "<string>" : b.model.template.sources[1],
              nothing, preview)
end

model(ctx::RenderCtx) = ctx.bound.model
analysis(ctx::RenderCtx) = ctx.bound.model.analysis
template(ctx::RenderCtx) = ctx.bound.model.template

function overbudget(ctx::RenderCtx, code::AbstractString, msg::AbstractString, hint::AbstractString)
    d = Diagnostic(code, :resource, Span(1, 0, 0), ctx.file, msg; hint)
    throw(KanonResourceError(DiagnosticSet([d])))
end

function spend!(ctx::RenderCtx, n::Int = 1)
    ctx.nodes += n
    ctx.nodes <= ctx.budget.nodes && return nothing
    overbudget(ctx, "K4001",
        "o documento visitou mais de $(ctx.budget.nodes) nós e o render foi interrompido.",
        "O limite é uma contagem, não um tempo: a mesma entrada erra em toda máquina. " *
        "Aumente o orçamento com `render(...; budget = Budget(nodes = ...))`.")
end

# --- o valor de um caminho ---------------------------------------------------

"""
Segue um caminho a partir dos dados validados. Só campos declarados são alcançáveis
(§11.4): a descida usa `kanon_getfield`, que lê o que o esquema promete, e não
`getproperty` sobre um objeto arbitrário.

Devolve `nothing` para valor ausente — o que só acontece em caminho nulável, e caminho
nulável só chega aqui dentro de um grupo (teorema da lacuna).
"""
function path_value(ctx::RenderCtx, n::Interp)
    rp = analysis(ctx).paths[id(n)]
    rp === nothing && return nothing
    if rp.kind === :constant
        return ctx.fctx.today === nothing ? placeholder(ctx, rp, n) : ctx.fctx.today
    end

    segs = n.path.segments
    v = if rp.kind === :subject_field
        ctx.subject === nothing ? nothing : descend_value(ctx.subject, segs, 1)
    else
        w = value(ctx.bound, segs[1])
        w === nothing ? nothing : descend_value(w, segs, 2)
    end
    v === nothing ? placeholder(ctx, rp, n) : v
end

"""
No rascunho, um valor **garantido** que falta vira marcador; um valor nulável que falta
continua elidindo o grupo, porque é isso que ele faz num documento de verdade.
"""
function placeholder(ctx::RenderCtx, rp::ResolvedPath, n::Interp)
    (ctx.preview && !rp.nullable) ? PreviewMarker(string(n.path)) : nothing
end

function descend_value(v, segs::Vector{Symbol}, from::Int)
    for i in from:length(segs)
        v === nothing && return nothing
        v = kanon_getfield(v, Val(segs[i]))
    end
    return v
end

"""
O texto de uma interpolação. O formatador efetivo já foi resolvido por `analyze`, e uma
lista é formatada **como lista** — é o que faz `{witnesses:count}` valer.
"""
function interp_text(ctx::RenderCtx, n::Interp, v)
    v isa PreviewMarker && return string(Char(0x00AB), v.path, Char(0x00BB))
    f = analysis(ctx).formatter[id(n)]
    format(v, Val(f), ctx.fctx)
end

# --- travessia ---------------------------------------------------------------

"""
Emite os nós de um parágrafo num buffer, registrando uma **emenda** na posição de cada
grupo elidido.

A emenda é a posição no texto resultante, e é toda a informação que o reparo recebe: ele
nunca varre o parágrafo (D-014).
"""
function emit_nodes!(ctx::RenderCtx, out::Vector{Char}, seams::Vector{Int}, nodes)
    for n in nodes
        spend!(ctx)
        if n isa TextLit
            append!(out, n.value)
        elseif n isa Interp
            v = path_value(ctx, n)
            v === nothing || append!(out, interp_text(ctx, n, v))
        elseif n isa FlexPoint
            # O núcleo não sabe flexionar. Marca não registrada volta a ser prosa
            # literal, que é o que ela era antes de a camada de idioma existir.
            append!(out, hasmark(model(ctx).env, n.mark) ? inflect_text(ctx, n) :
                         n.word * n.mark)
        elseif n isa BlockRef
            append!(out, blockref_text(ctx, n))
        elseif n isa Group
            if elides(ctx, n)
                push!(seams, length(out) + 1)
            else
                emit_nodes!(ctx, out, seams, n.children)
            end
        end
    end
    return nothing
end

"""
O grupo elide se, e somente se, **alguma de suas interpolações diretas** resolve para
nulo (§4.4). Grupos aninhados elidem por conta própria e não afetam o de fora — é a
regra que os casos 11 e 12 fixam.
"""
function elides(ctx::RenderCtx, g::Group)
    for n in g.children
        n isa Interp || continue
        path_value(ctx, n) === nothing && return true
    end
    return false
end

"O gancho de flexão da camada de idioma. O núcleo entrega `(palavra, marca, sujeito)` e recebe a palavra inteira (D-013)."
function inflect_text(ctx::RenderCtx, n::FlexPoint)
    f = model(ctx).env.inflect
    f === nothing && return n.word * n.mark
    String(f(n.word, n.mark, ctx.subject, ctx.fctx))
end

"O texto de remissão do estilo do bloco apontado (§6.3)."
function blockref_text(ctx::RenderCtx, n::BlockRef)
    pos = findfirst(b -> b.name === n.target, template(ctx).text.blocks)
    pos === nothing && return ""      # `analyze` já recusou; não se chega aqui
    b = template(ctx).text.blocks[pos]
    estilo = stylefor(model(ctx).env, b.unit)
    estilo === nothing && return ""
    # o número é o do plano: se uma regra removeu blocos antes deste, ele renumerou —
    # e `check` já recusou a remissão a bloco que as regras tiraram (K3040)
    String(estilo.ref(ctx.bound.plan.numbers[pos], ctx.fctx))
end

# --- blocos e parágrafos -----------------------------------------------------

"""
Renderiza um bloco: os parágrafos, já elididos e reparados, mais o rótulo de numeração
quando o bloco é numerado.

`layout = :prefix` prefixa o primeiro parágrafo com o rótulo e o separador;
`:heading` põe o rótulo num parágrafo próprio (§6.4).
"""
function render_block(ctx::RenderCtx, b::Block, inst::BlockInstance)
    ctx.subject = inst.subject
    paras = String[]
    for p in b.children
        spend!(ctx)
        s = render_paragraph(ctx, p)
        s === nothing || push!(paras, s)
    end
    ctx.subject = nothing

    rotulo = block_label(ctx, b, inst)
    rotulo === nothing && return paras
    estilo = stylefor(model(ctx).env, b.unit)
    if estilo.layout === :heading
        pushfirst!(paras, rotulo)
    elseif isempty(paras)
        push!(paras, rotulo)
    else
        paras[1] = rotulo * estilo.separator * paras[1]
    end
    return paras
end

"""
O rótulo desta instância. O número vem do **plano**, e não da `Analysis`: bloco removido
por regra não consome número e bloco repetido consome um por iteração, então a numeração
final depende dos dados (§6.2).
"""
function block_label(ctx::RenderCtx, b::Block, inst::BlockInstance)
    isempty(inst.number) && return nothing
    estilo = stylefor(model(ctx).env, b.unit)
    estilo === nothing ? nothing : String(estilo.number(inst.number, ctx.fctx))
end

"""
Um parágrafo: emitir, reparar as emendas, limpar. Devolve `nothing` quando o parágrafo
ficou vazio — e é assim que o caso 13 remove o parágrafo e uma das linhas em branco que
o cercavam.
"""
function render_paragraph(ctx::RenderCtx, p::Paragraph)
    out = Char[]
    seams = Int[]
    emit_nodes!(ctx, out, seams, p.children)

    s, finais = isempty(seams) ? (String(out), seams) : repair(out, seams)
    s = apply_repair_hook(ctx, s, finais)
    check_bytes!(ctx, s)
    all(isspace, s) ? nothing : s
end

"O gancho da camada de idioma, depois do reparo do núcleo (§5.4). O núcleo nunca mexe em caixa."
function apply_repair_hook(ctx::RenderCtx, s::AbstractString, seams::Vector{Int})
    h = model(ctx).env.repair
    (h === nothing || isempty(seams)) && return String(s)
    String(h(s, seams, ctx.fctx))
end

function check_bytes!(ctx::RenderCtx, s::AbstractString)
    ncodeunits(s) <= ctx.budget.bytes && return nothing
    overbudget(ctx, "K4002",
        "o documento passou de $(ctx.budget.bytes) bytes e o render foi interrompido.",
        "Aumente o orçamento com `render(...; budget = Budget(bytes = ...))`.")
end

# --- a API -------------------------------------------------------------------

"""
    render(bound; budget = Budget()) -> String

Renderiza dados já validados. Puro: sem I/O, sem relógio, sem aleatoriedade.
"""
function render(b::Bound; budget::Budget = Budget(), preview::Bool = false)
    preview || haserrors(b) && throw(KanonContractError(diagnostics(b)))
    ctx = RenderCtx(b, budget, preview)

    paras = String[]
    for inst in b.plan.instances
        append!(paras, render_block(ctx, template(ctx).text.blocks[inst.pos], inst))
    end

    s = join(paras, "\n\n")
    check_bytes!(ctx, s)
    return s
end

"""
    render(model, dados; today = nothing, budget = Budget()) -> String

Valida e renderiza. Lança `KanonContractError` se os dados não satisfazem o contrato —
**não existe render sem validação**, nem como opção (§14).
"""
function render(m::Model, data; today::Union{Nothing,Date} = nothing,
                budget::Budget = Budget())
    render(bind(m, data; today, budget); budget)
end

"""
    preview(model, dados; today = nothing) -> String

O rascunho: o documento com «marcadores» no lugar do que ainda não veio. **Não é um modo
leniente** — é um comando à parte, a saída é sempre visivelmente marcada, e `render`
continua recusando exatamente os mesmos dados.

A necessidade real por trás do pedido de "modo leniente" é ver o texto enquanto os dados
estão sendo reunidos. Atendê-la aqui é o que permite que o motor nunca relaxe em lugar
nenhum.
"""
function preview(m::Model, data; today::Union{Nothing,Date} = nothing,
                 budget::Budget = Budget())
    render(bind(m, data; today, budget); budget, preview = true)
end
