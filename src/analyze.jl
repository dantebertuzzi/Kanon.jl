# `analyze` — o passo que tem o ambiente e não tem os dados.
#
#   Template  ── erro de SINTAXE     (sem dados, sem ambiente)
#     analyze(env)
#   Analysis  ── erro de REFERÊNCIA  (sem dados, COM ambiente)
#     check(dados)
#   Bound     ── erro de CONTRATO    (com dados)
#
# Duas restrições normativas (`docs/ast.md` §8): `analyze` é **puro em relação ao
# `Template`** — não muta a árvore, devolve tabelas laterais — e acumula todos os erros
# em vez de parar no primeiro (§10.3).
#
# Esta fase (F2.2) resolve caminhos e formatadores. A exigência de grupo para caminho
# nulável é a F2.3; a semântica das regras, a F2.5.

"""
    AnalysisCtx

Estado da análise. Mutável pelo mesmo motivo que o `ParseCtx`: o que muda é a lista de
diagnósticos e as tabelas, nunca a árvore.
"""
mutable struct AnalysisCtx
    env::Environment
    tmpl::Template
    out::Analysis
    file::String
    # o escopo do bloco em curso; `nothing` fora de bloco e em bloco sem sujeito
    subject::Union{Nothing,ResolvedPath}
    subject_path::Union{Nothing,Path}
    # campos cujo tipo declarado não existe: caminhos que passem por eles não geram
    # erro em cascata, porque o erro já foi dito na declaração
    poisoned::Vector{Symbol}
end

function AnalysisCtx(env::Environment, tmpl::Template)
    AnalysisCtx(env, tmpl, Analysis(tmpl.nnodes),
                isempty(tmpl.sources) ? "<string>" : tmpl.sources[1],
                nothing, nothing, Symbol[])
end

function err!(ctx::AnalysisCtx, code::AbstractString, sp::Span, msg::AbstractString;
              hint = nothing, path = nothing, severity::Symbol = :error)
    push!(ctx.out.diagnostics,
          Diagnostic(code, :reference, sp, ctx.file, msg; hint, path, severity))
    return nothing
end

# --- sugestão de nome --------------------------------------------------------

"""
Distância de edição **com transposição** (Damerau, alinhamento ótimo). Existe só para a
sugestão da mensagem de erro (§10.4), e conta transposição porque `nmae` por `name` é o
erro de digitação mais comum — com Levenshtein puro ele custa 2 e a sugestão não sai.
"""
function edit_distance(a::AbstractString, b::AbstractString)
    x, y = collect(a), collect(b)
    m, n = length(x), length(y)
    m == 0 && return n
    n == 0 && return m
    d = zeros(Int, m + 1, n + 1)
    d[:, 1] = 0:m
    d[1, :] = 0:n
    for i in 1:m, j in 1:n
        cost = x[i] == y[j] ? 0 : 1
        d[i + 1, j + 1] = min(d[i, j + 1] + 1, d[i + 1, j] + 1, d[i, j] + cost)
        if i > 1 && j > 1 && x[i] == y[j - 1] && x[i - 1] == y[j]
            d[i + 1, j + 1] = min(d[i + 1, j + 1], d[i - 1, j - 1] + cost)
        end
    end
    d[m + 1, n + 1]
end

"""
O candidato mais próximo de `name`, ou `nothing`. O limiar cresce com o tamanho da
palavra: um erro de digitação em `nmae` é um caractere; em `benificiario`, dois.
"""
function nearest(name::Symbol, candidates)
    isempty(candidates) && return nothing
    s = String(name)
    limit = max(1, length(s) ÷ 3)
    best, bestd = nothing, typemax(Int)
    for c in candidates
        d = edit_distance(s, String(c))
        if d < bestd || (d == bestd && best !== nothing && String(c) < String(best))
            best, bestd = c, d
        end
    end
    bestd <= limit ? best : nothing
end

"Acrescenta `Você quis dizer 'x'?` à sugestão, quando há um candidato próximo."
function did_you_mean(name::Symbol, candidates, tail::AbstractString)
    s = nearest(name, candidates)
    s === nothing ? tail : "Você quis dizer `$s`? " * tail
end

# --- consulta ao contrato ----------------------------------------------------

"A declaração de um campo de primeiro nível, ou `nothing`."
function fielddecl(tmpl::Template, name::Symbol)
    i = findfirst(f -> f.name === name, tmpl.data.fields)
    i === nothing ? nothing : tmpl.data.fields[i]
end

fieldnames_of(tmpl::Template) = [f.name for f in tmpl.data.fields]

"""
    Failure

Por que uma tentativa de resolução falhou. `depth` é quantos segmentos ela conseguiu
resolver: entre duas falhas, a que foi mais fundo é a que explica melhor o erro.
"""
struct Failure
    code::String
    message::String
    hint::Union{Nothing,String}
    depth::Int
end

"Falha já reportada em outro lugar — não gera mensagem nova (evita cascata)."
const SILENT = Failure("", "", nothing, -1)

# --- descida por tipo composto -----------------------------------------------

"""
Desce os segmentos restantes de um caminho a partir de um tipo. É aqui que a
nulabilidade atravessa o tipo composto: `spouse` opcional em `person` torna
`{seller.spouse.name}` nulável, e portanto exige grupo.
"""
function descend(ctx::AnalysisCtx, segs::Vector{Symbol}, from::Int,
                 typename::Symbol, card::Cardinality, nullable::Bool,
                 kind::Symbol, decl::NodeId)
    for i in from:length(segs)
        seg = segs[i]
        owner = segs[i - 1]

        if islist(card)
            return nothing, Failure("K2008",
                "`$owner` é uma lista, e a versão 1 não tem como escolher um item dela.",
                "Repita o bloco com `one for each $owner` e escreva `{$seg}` dentro dele.",
                i - 1)
        end

        T = typefor(ctx.env, typename)
        if T === nothing
            return nothing, Failure("K2005",
                "`$owner` é do tipo `$typename`, que este ambiente não conhece.",
                "Carregue a camada que define `$typename`.", i - 1)
        end

        schema = kanon_schema(T)
        if isempty(schema)
            return nothing, Failure("K2004",
                "`$owner` é um valor de `$typename`, que não tem campos; `$seg` não existe nele.",
                "Escreva `{$(join(segs[1:(i - 1)], '.'))}` para usar o valor inteiro.",
                i - 1)
        end

        j = findfirst(f -> f.name === seg, schema)
        if j === nothing
            names = [f.name for f in schema]
            return nothing, Failure("K2003",
                "`$typename` não tem o campo `$seg`.",
                did_you_mean(seg, names, "Campos de `$typename`: $(join(sort(names), ", "))."),
                i - 1)
        end

        spec = schema[j]
        typename = spec.type
        card = spec.card
        nullable |= spec.optional
    end
    ResolvedPath(kind, typename, nullable, card, decl), nothing
end

# --- as duas resoluções ------------------------------------------------------

"Resolve contra os campos de primeiro nível do contrato."
function resolve_in_contract(ctx::AnalysisCtx, p::Path)
    segs = p.segments
    head = segs[1]
    decl = fielddecl(ctx.tmpl, head)

    if decl === nothing
        names = fieldnames_of(ctx.tmpl)
        return nothing, Failure("K2001",
            "o contrato não declara `$head`.",
            did_you_mean(head, names,
                isempty(names) ? "O modelo não tem plano de dados." :
                                 "Campos do contrato: $(join(sort(names), ", "))."),
            0)
    end

    head in ctx.poisoned && return nothing, SILENT

    length(segs) == 1 &&
        return ResolvedPath(:field, decl.type, decl.presence === OPTIONAL, decl.card, decl.id), nothing

    descend(ctx, segs, 2, decl.type, decl.card, decl.presence === OPTIONAL, :field, decl.id)
end

"Resolve contra os campos do sujeito do bloco (§4.2)."
function resolve_in_subject(ctx::AnalysisCtx, p::Path)
    subj = ctx.subject
    subj === nothing && return nothing, SILENT

    T = typefor(ctx.env, subj.typename)
    T === nothing && return nothing, SILENT

    schema = kanon_schema(T)
    isempty(schema) && return nothing, SILENT

    head = p.segments[1]
    i = findfirst(f -> f.name === head, schema)
    if i === nothing
        names = [f.name for f in schema]
        return nothing, Failure("K2003",
            "`$(subj.typename)` não tem o campo `$head`.",
            did_you_mean(head, names, "Campos de `$(subj.typename)`: $(join(sort(names), ", "))."),
            0)
    end

    spec = schema[i]
    # A nulabilidade do próprio sujeito atravessa: um bloco preso a um campo opcional
    # torna nulável tudo que se lê dentro dele.
    nullable = subj.nullable || spec.optional

    length(p.segments) == 1 &&
        return ResolvedPath(:subject_field, spec.type, nullable, spec.card, subj.decl), nothing

    descend(ctx, p.segments, 2, spec.type, spec.card, nullable, :subject_field, subj.decl)
end

"""
Resolve um caminho no escopo corrente e devolve o `ResolvedPath`, emitindo o
diagnóstico quando não resolve.

A ordem da §4.2 não é uma precedência: as duas resoluções são tentadas **sempre**, e
resolver nas duas é erro de ambiguidade. Precedência silenciosa aqui seria a categoria
de defeito que a linguagem existe para impedir — o redator leria `{name}` como o campo
do sujeito enquanto o motor lê o do contrato.
"""
function resolve!(ctx::AnalysisCtx, p::Path, sp::Span)
    segs = p.segments

    if length(segs) == 1 && segs[1] === :today
        if fielddecl(ctx.tmpl, :today) !== nothing
            err!(ctx, "K2002", sp,
                 "`today` é o nome da constante de data e também o de um campo do contrato.";
                 hint = "Renomeie o campo: `today` é reservado.", path = "today")
            return nothing
        end
        return ResolvedPath(:constant, :date, false, Cardinality(), NodeId(0))
    end

    rs, fs = resolve_in_subject(ctx, p)
    rc, fc = resolve_in_contract(ctx, p)

    if rs !== nothing && rc !== nothing
        err!(ctx, "K2002", sp,
             "`$(segs[1])` é campo de `$(ctx.subject.typename)`, o sujeito deste bloco, " *
             "e também campo do contrato.";
             hint = "Escreva `$(ctx.subject_path).$(string(p))` para o do sujeito, ou " *
                    "renomeie um dos dois.",
             path = string(p))
        return nothing
    end

    rs === nothing || return rs
    rc === nothing || return rc

    # Nenhuma resolveu. Quando as duas falharam já no primeiro segmento, o redator
    # precisa saber que procuramos nos DOIS escopos — dizer só um manda corrigir no
    # lugar errado.
    if ctx.subject !== nothing && fs !== nothing && fc !== nothing &&
       fs !== SILENT && fc !== SILENT && fs.depth == 0 && fc.depth == 0
        report_neither!(ctx, p, sp)
        return nothing
    end

    # Senão, reporta a falha que foi mais fundo, que é a que explica melhor.
    f = pick_failure(fs, fc)
    f === SILENT || f === nothing ||
        err!(ctx, f.code, sp, f.message; hint = f.hint, path = string(p))
    return nothing
end

"O caminho não existe em nenhum dos dois escopos do §4.2."
function report_neither!(ctx::AnalysisCtx, p::Path, sp::Span)
    head = p.segments[1]
    subj = ctx.subject
    T = typefor(ctx.env, subj.typename)
    from_subject = T === nothing ? Symbol[] : sort!([spec.name for spec in kanon_schema(T)])
    from_contract = sort!(fieldnames_of(ctx.tmpl))
    err!(ctx, "K2001", sp,
         "nem `$(subj.typename)`, que é o sujeito deste bloco, nem o contrato declaram `$head`.";
         hint = did_you_mean(head, vcat(from_subject, from_contract),
             "Campos de `$(subj.typename)`: $(join(from_subject, ", ")). " *
             "Campos do contrato: $(join(from_contract, ", "))."),
         path = string(p))
end

function pick_failure(a::Union{Nothing,Failure}, b::Union{Nothing,Failure})
    a === nothing && return b
    b === nothing && return a
    a === SILENT && return b === SILENT ? SILENT : b
    b === SILENT && return a
    a.depth >= b.depth ? a : b
end

# --- formatador --------------------------------------------------------------

"""
Resolve o formatador de uma interpolação. Sem dados: é a §3.5.

Um caminho de cardinalidade de lista é formatado **como lista**, e não como o tipo do
elemento — é o que faz `{witnesses:count}` valer e `{witnesses:upper}` não.
"""
function resolve_formatter!(ctx::AnalysisCtx, n::Interp, rp::ResolvedPath)
    ctx.out.formatter[id(n)] = n.formatter === nothing ? :default : n.formatter
    n.formatter === nothing && return nothing

    effective = islist(rp.card) ? :list : rp.typename
    T = typefor(ctx.env, effective)
    if T === nothing
        err!(ctx, "K2005", n.span,
             "`$(string(n.path))` é do tipo `$effective`, que este ambiente não conhece.";
             hint = "Carregue a camada que define `$effective`.", path = string(n.path))
        return nothing
    end

    fmts = kanon_formats(T)
    n.formatter in fmts && return nothing

    tail = isempty(fmts) ?
        "`$effective` não tem formatador nomeado; escreva `{$(string(n.path))}`." :
        "Formatadores de `$effective`: $(join(fmts, ", "))."
    err!(ctx, "K2020", n.span,
         "`$(n.formatter)` não existe para o tipo `$effective`.";
         hint = did_you_mean(n.formatter, fmts, tail), path = string(n.path))
    return nothing
end

# --- travessia ---------------------------------------------------------------

"""
Valida os tipos declarados no plano de dados. Roda antes de qualquer caminho para que um
tipo inexistente seja dito **uma vez**, na declaração, e não a cada interpolação que o
use.
"""
function analyze_data!(ctx::AnalysisCtx)
    for f in ctx.tmpl.data.fields
        typefor(ctx.env, f.type) === nothing || continue
        push!(ctx.poisoned, f.name)
        names = typenames(ctx.env)
        err!(ctx, "K2005", f.span,
             "`$(f.name)` é declarado do tipo `$(f.type)`, que este ambiente não conhece.";
             hint = did_you_mean(f.type, names, "Tipos disponíveis: $(join(names, ", "))."),
             path = String(f.name))
    end
end

"Resolve o sujeito do cabeçalho e o guarda em `paths[bloco]` — nó nenhum o carrega (I2)."
function analyze_subject!(ctx::AnalysisCtx, b::Block)
    ctx.subject = nothing
    ctx.subject_path = nothing
    b.subject === nothing && return nothing

    rp, f = resolve_in_contract(ctx, b.subject)
    if rp === nothing
        if f !== SILENT && f !== nothing
            code = f.code == "K2001" ? "K2006" : f.code
            err!(ctx, code, b.subject.span, f.message; hint = f.hint,
                 path = string(b.subject))
        end
        return nothing
    end

    T = typefor(ctx.env, rp.typename)
    if T !== nothing && isempty(kanon_schema(T))
        err!(ctx, "K2007", b.subject.span,
             "o bloco `$(b.name)` toma `$(string(b.subject))` por sujeito, e " *
             "`$(rp.typename)` não tem campos.";
             hint = "Só um valor com campos serve de sujeito; escreva " *
                    "`{$(string(b.subject))}` no texto do bloco.",
             path = string(b.subject))
        return nothing
    end

    ctx.out.paths[id(b)] = rp
    ctx.subject = rp
    ctx.subject_path = b.subject
    return nothing
end

function analyze_nodes!(ctx::AnalysisCtx, nodes)
    for n in nodes
        if n isa Interp
            rp = resolve!(ctx, n.path, n.span)
            rp === nothing && continue
            ctx.out.paths[id(n)] = rp
            resolve_formatter!(ctx, n, rp)
        elseif n isa Group
            analyze_nodes!(ctx, n.children)
        end
    end
end

function analyze_text!(ctx::AnalysisCtx)
    for b in ctx.tmpl.text.blocks
        push!(ctx.out.block_index, b.name => id(b))
        analyze_subject!(ctx, b)
        for p in b.children
            analyze_nodes!(ctx, p.children)
        end
    end
    ctx.subject = nothing
    ctx.subject_path = nothing
    sort!(ctx.out.block_index; by = first)
end

"""
Resolve os caminhos do plano das regras. Regra não tem sujeito: ela nomeia o bloco de
fora, e seus caminhos são do contrato.

A **semântica** — tipagem dos operadores, atributos, veracidade implícita, `one for
each` sobre lista — é a F2.5. Aqui só se resolve o que os caminhos apontam.
"""
function analyze_rules!(ctx::AnalysisCtx)
    ctx.subject = nothing
    ctx.subject_path = nothing
    for r in ctx.tmpl.rules.rules
        r.when === nothing || analyze_expr!(ctx, r.when)
        if r.foreach !== nothing
            rp = resolve!(ctx, r.foreach, r.span)
            rp === nothing || (ctx.out.paths[id(r)] = rp)
        end
    end
end

function analyze_expr!(ctx::AnalysisCtx, e::RuleExpr)
    if e isa PathExpr
        rp = resolve!(ctx, e.path, e.span)
        rp === nothing || (ctx.out.paths[id(e)] = rp)
    elseif e isa AttrExpr
        rp = resolve!(ctx, e.subject, e.span)
        rp === nothing || (ctx.out.paths[id(e)] = rp)
    elseif e isa NotExpr
        analyze_expr!(ctx, e.operand)
    elseif e isa BinExpr
        analyze_expr!(ctx, e.lhs)
        analyze_expr!(ctx, e.rhs)
    end
    return nothing
end

"""
    analyze(env, tmpl) -> Analysis

Resolve o modelo contra o ambiente. Não muta o `Template` e não lança: devolve a
`Analysis` com os diagnósticos acumulados. Quem lança é [`load_template`](@ref).
"""
function analyze(env::Environment, tmpl::Template)
    ctx = AnalysisCtx(env, tmpl)
    analyze_data!(ctx)
    analyze_text!(ctx)
    analyze_rules!(ctx)
    sort!(ctx.out.diagnostics; by = sortkey)
    return ctx.out
end

# --- API de alto nível -------------------------------------------------------

"""
    load_string(env, text; name = "<string>") -> Model

Lê, analisa e devolve o modelo pronto. Lança `KanonSyntaxError` se o arquivo é
malformado e `KanonReferenceError` se algum caminho, tipo ou formatador não resolve.

Um erro de sintaxe suprime a análise: não há árvore para validar (§10.3).
"""
function load_string(env::Environment, text::AbstractString; name::AbstractString = "<string>")
    tmpl = parse_string(text; name, keywords = env.keywords)
    a = analyze(env, tmpl)
    haserrors(a) && throw(KanonReferenceError(diagnostics(a)))
    Model(env, tmpl, a)
end

"""
    load_template(env, path) -> Model

Como [`load_string`](@ref), lendo do disco.
"""
function load_template(env::Environment, path::AbstractString)
    tmpl = parse_file(path; keywords = env.keywords)
    a = analyze(env, tmpl)
    haserrors(a) && throw(KanonReferenceError(diagnostics(a)))
    Model(env, tmpl, a)
end
