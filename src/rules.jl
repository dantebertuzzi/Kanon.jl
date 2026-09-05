# As regras em execução: quais blocos existem, quantas vezes, e com que número.
#
# A invariante anti-XSLT (D-015) governa este arquivo inteiro:
#
#   **Regras só removem ou repetem blocos. Nunca inserem, nunca substituem, nunca
#   reordenam.**
#
# É por isso que o resultado cabe numa lista de instâncias na ordem do plano do texto:
# não há para onde um bloco ir, só quantas vezes ele aparece. Ler o plano do texto
# continua sendo um limite superior confiável do documento gerado — que é exatamente o
# que faltou ao XSLT.
#
# O plano é computado em `bind`, e não no render, por um motivo: uma remissão a bloco
# que as regras removeram é erro **destes dados**, e erro de dados se reporta em `check`.
# `render` não emite diagnóstico (`ast.md` §8).

"""
    Budget

Limites **contados**, nunca de tempo de parede (D-010): um limite de tempo tornaria não
determinístico *se* o motor erra — a mesma entrada erraria numa máquina carregada e
passaria numa ociosa, e a suíte golden ficaria instável justamente em CI, que é onde a
máquina lenta aparece.

Mora neste arquivo porque a primeira contagem acontece aqui: as repetições que as regras
produzem são contadas antes de qualquer texto sair.
"""
struct Budget
    nodes::Int
    bytes::Int
    depth::Int
    iterations::Int
end

Budget(; nodes = 1_000_000, bytes = 64 * 1024 * 1024, depth = 64, iterations = 100_000) =
    Budget(nodes, bytes, depth, iterations)

"""
    BlockInstance

Uma ocorrência de um bloco na saída. `subject` é o valor do sujeito — o elemento
corrente, quando o bloco se repete — e `number` é o número que ela consumiu, vazio se o
bloco não é numerado.
"""
struct BlockInstance
    pos::Int32
    subject::Any
    number::Vector{Int32}
end

"""
    Plan

O que as regras decidiram, dados estes dados: as instâncias na ordem da saída, e o
número de cada bloco para efeito de remissão.

`numbers[pos]` fica vazio para bloco removido ou não numerado. Bloco repetido não é
remetível (`K2034`, verificado sem dados), então o número de remissão nunca é ambíguo.
"""
struct Plan
    instances::Vector{BlockInstance}
    numbers::Vector{Vector{Int32}}
    present::Vector{Bool}
end

Plan(n::Integer) = Plan(BlockInstance[], [Int32[] for _ in 1:n], trues(n))

# --- avaliação de expressão --------------------------------------------------

"""
    RuleScope

O que uma expressão de regra enxerga. `iterating` é o caminho que o bloco repete e
`element` o item corrente: dentro de `cada one for each witnesses`, `witnesses` denota
**uma** testemunha, tanto no texto quanto no `when` do próprio bloco (§8.3).
"""
struct RuleScope
    bound_values::Vector{Any}
    fields::Vector{FieldDecl}
    iterating::Union{Nothing,Path}
    element::Any
    ctx::FormatContext
end

"O valor de um caminho, com a substituição do elemento corrente quando ele se aplica."
function scope_value(sc::RuleScope, p::Path)
    segs = p.segments
    if sc.iterating !== nothing && length(sc.iterating.segments) == 1 &&
       sc.iterating.segments[1] === segs[1]
        return descend_value(sc.element, segs, 2)
    end
    i = findfirst(f -> f.name === segs[1], sc.fields)
    i === nothing && return nothing
    v = sc.bound_values[i]
    v === nothing ? nothing : descend_value(v, segs, 2)
end

"""
Avalia uma condição. Devolve `Bool`.

Não há veracidade implícita: um caminho isolado só chega aqui se `analyze` tiver
verificado que o tipo dele é `boolean` (§8.1), e por isso este avaliador pode confiar no
que recebe.
"""
function eval_rule(sc::RuleScope, e::RuleExpr)
    e isa LitExpr && return e.lit.value === true
    e isa NotExpr && return !eval_rule(sc, e.operand)
    e isa PathExpr && return scope_value(sc, e.path) === true
    e isa AttrExpr && return eval_attr(sc, e)

    if e isa BinExpr
        e.op === :and && return eval_rule(sc, e.lhs) && eval_rule(sc, e.rhs)
        e.op === :or && return eval_rule(sc, e.lhs) || eval_rule(sc, e.rhs)
        return eval_comparison(sc, e)
    end
    return false
end

function eval_attr(sc::RuleScope, e::AttrExpr)
    v = scope_value(sc, e.subject)
    r = if e.attr === :present
        v !== nothing
    elseif e.attr === :absent
        v === nothing
    else
        # um atributo de tipo sobre valor ausente é falso, e não um erro: `absent` é o
        # que se escreve para perguntar pela ausência
        v === nothing ? false : kanon_attribute(v, Val(e.attr))
    end
    e.negated ? !r : r
end

"O valor de um operando de comparação: caminho, ou literal."
function operand_value(sc::RuleScope, e::RuleExpr)
    e isa PathExpr && return scope_value(sc, e.path)
    e isa LitExpr || return nothing
    e.lit.kind === :constant && return sc.ctx.today      # hoje só `today`
    return e.lit.value
end

"""
Comparar usa `kanon_compare`, que `analyze` já verificou existir para o par de tipos
(§8.1). A ordem dos operandos não importa: o motor tenta os dois sentidos, como a
validação fez.
"""
function eval_comparison(sc::RuleScope, e::BinExpr)
    a = operand_value(sc, e.lhs)
    b = operand_value(sc, e.rhs)
    # ausência não se compara: a pergunta pela ausência é `is absent`
    (a === nothing || b === nothing) && return false

    c = try
        kanon_compare(a, b)
    catch err
        err isa KanonProtocolError || rethrow()
        try
            -kanon_compare(b, a)
        catch
            return false
        end
    end

    e.op === :eq && return c == 0
    e.op === :ne && return c != 0
    e.op === :lt && return c < 0
    e.op === :le && return c <= 0
    e.op === :gt && return c > 0
    e.op === :ge && return c >= 0
    return false
end

# --- o plano -----------------------------------------------------------------

"""
Monta o plano: percorre os blocos na ordem do arquivo — que é a ordem da saída, porque
regras não reordenam — e decide, para cada um, quantas instâncias existem e que número
cada uma consome.

**Bloco removido não consome número; bloco repetido consome um por iteração** (§6.2). É
o que faz a numeração depender dos dados, e por isso ela mora aqui e não na `Analysis`.
"""
function build_plan(m::Model, values::Vector{Any}, ctx::FormatContext, budget)
    tmpl = m.template
    a = m.analysis
    blocos = tmpl.text.blocks
    plan = Plan(length(blocos))
    contadores = Pair{Char,Vector{Int32}}[]
    iteracoes = 0

    for (pos, b) in enumerate(blocos)
        k_for = isempty(a.block_foreach) ? Int32(0) : a.block_foreach[pos]
        k_when = isempty(a.block_rule) ? Int32(0) : a.block_rule[pos]
        regra_for = k_for == 0 ? nothing : tmpl.rules.rules[k_for]
        regra_when = k_when == 0 ? nothing : tmpl.rules.rules[k_when]

        elementos = instances_of(m, values, ctx, b, regra_for)
        criadas = 0

        for elemento in elementos
            iteracoes += 1
            iteracoes > budget.iterations && overbudget_iterations(m, budget)

            sc = RuleScope(values, tmpl.data.fields,
                           regra_for === nothing ? nothing : regra_for.foreach,
                           elemento, ctx)
            regra_when === nothing || eval_rule(sc, regra_when.when) || continue

            sujeito = block_subject_value(m, values, b, regra_for, elemento)
            numero = level(b) == 0 ? Int32[] :
                     advance_counter!(contadores, b.unit, level(b))
            push!(plan.instances, BlockInstance(Int32(pos), sujeito, numero))
            criadas += 1
            criadas == 1 && (plan.numbers[pos] = numero)
        end

        plan.present[pos] = criadas > 0
    end
    plan
end

"""
Os elementos sobre os quais o bloco se repete. Um bloco sem `one for each` tem uma
iteração só, com `nothing` no lugar do elemento.
"""
function instances_of(m::Model, values::Vector{Any}, ctx::FormatContext, b::Block,
                      regra::Union{Nothing,Rule})
    regra === nothing && return Any[nothing]
    sc = RuleScope(values, m.template.data.fields, nothing, nothing, ctx)
    v = scope_value(sc, regra.foreach)
    v === nothing && return Any[]           # coleção ausente: nenhuma iteração
    collect(Any, v)
end

"O sujeito de uma instância: o elemento, quando o bloco itera sobre o próprio sujeito."
function block_subject_value(m::Model, values::Vector{Any}, b::Block,
                             regra::Union{Nothing,Rule}, elemento)
    b.subject === nothing && return nothing
    regra !== nothing && b.subject.segments == regra.foreach.segments && return elemento
    segs = b.subject.segments
    i = findfirst(f -> f.name === segs[1], m.template.data.fields)
    i === nothing && return nothing
    v = values[i]
    v === nothing ? nothing : descend_value(v, segs, 2)
end

function overbudget_iterations(m::Model, budget)
    d = Diagnostic("K4004", :resource, Span(1, 0, 0),
                   isempty(m.template.sources) ? "<string>" : m.template.sources[1],
                   "as regras produziram mais de $(budget.iterations) repetições de bloco.";
                   hint = "O limite é uma contagem, não um tempo. Aumente o orçamento " *
                          "com `render(...; budget = Budget(iterations = ...))`.")
    throw(KanonResourceError(DiagnosticSet([d])))
end
