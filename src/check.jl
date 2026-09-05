# `check` — o passo que tem os dados.
#
#   Analysis  ── erro de REFERÊNCIA  (sem dados)
#     check(dados)
#   Bound     ── erro de CONTRATO    (com dados)
#     render
#
# É aqui que "o que não satisfaz o contrato não renderiza" deixa de ser uma frase. Não
# há modo leniente, nem opção, nem flag: `render` sobre dados que não passaram por aqui
# lança.
#
# Um conceito de ausência só (§2.3): chave ausente, `null`, `nothing` e `missing` são o
# mesmo nulo. Texto em branco é o buraco por onde a lacuna voltaria, e por isso é erro
# no campo garantido e nulo declarado no opcional (D-008).

"Marca a diferença entre 'a chave não veio' e 'a chave veio com nulo' — que a linguagem não faz."
struct AbsentKey end

"""
Teto de profundidade ao descer num valor composto. Existe porque nada impede que os
dados tenham um ciclo (`a.spouse === b`, `b.spouse === a`), e uma validação recursiva
sem teto nunca terminaria.
"""
const MAX_COMPOSITE_DEPTH = 32

"""
    Bound

Dados validados e decodificados, prontos para o render. `values` é indexado pela posição
do campo em `template.data.fields` — a ordem do arquivo, que é a ordem do checklist e a
dos erros.

O render não redecodifica nada: o que chega nele já passou por aqui.
"""
struct Bound
    model::Model
    values::Vector{Any}
    today::Union{Nothing,Date}
    plan::Plan
    diagnostics::Vector{Diagnostic}
end

haserrors(b::Bound) = any(d -> d.severity === :error, b.diagnostics)
diagnostics(b::Bound) = DiagnosticSet(b.diagnostics)

"O valor validado de um campo, pelo nome. `nothing` para campo opcional ausente."
function value(b::Bound, name::Symbol)
    i = findfirst(f -> f.name === name, b.model.template.data.fields)
    i === nothing ? nothing : b.values[i]
end

function Base.show(io::IO, b::Bound)
    n = count(!isnothing, b.values)
    print(io, "Bound(", n, "/", length(b.values), " campos com valor, ",
          length(b.diagnostics), " diagnósticos)")
end

# --- acesso genérico à entrada ----------------------------------------------

"""
Lê um campo da entrada externa, seja ela `Dict` de string, `Dict` de símbolo,
`NamedTuple` ou `struct`.

Aceitar as quatro formas não é conveniência: é o que permite que o mesmo modelo receba
um JSON decodificado, uma linha de tabela e um objeto Julia sem um adaptador por
formato.
"""
function input_field(data, name::Symbol)
    if data isa AbstractDict
        haskey(data, name) && return data[name]
        s = String(name)
        haskey(data, s) && return data[s]
        return AbsentKey()
    end
    hasproperty(data, name) && return getproperty(data, name)
    return AbsentKey()
end

"Os nomes que a entrada traz, ordenados — para o aviso de campo a mais."
function input_keys(data)
    ks = data isa AbstractDict ? [Symbol(k) for k in keys(data)] :
                                 collect(propertynames(data))
    sort!(ks)
end

"Chave ausente, `null`, `nothing` e `missing` são o mesmo nulo (§2.3)."
isnull(v) = v isa AbsentKey || v === nothing || v === missing

"Texto que só tem espaço em branco — o buraco que D-008 fecha."
isblank(v) = v isa AbstractString && all(isspace, v)

# --- o contexto da checagem --------------------------------------------------

mutable struct CheckCtx
    model::Model
    fctx::FormatContext
    file::String
    diags::Vector{Diagnostic}
end

function cerr!(ctx::CheckCtx, code::AbstractString, sp::Span, msg::AbstractString;
               hint = nothing, path = nothing, severity::Symbol = :error)
    push!(ctx.diags, Diagnostic(code, :contract, sp, ctx.file, msg; hint, path, severity))
    return nothing
end

env(ctx::CheckCtx) = ctx.model.env

# --- validação de um valor ---------------------------------------------------

"""
Desce num valor composto exigindo o que o esquema promete: um campo que o esquema **não**
marca como opcional não pode chegar nulo.

Sem esta descida, o teorema da lacuna teria um furo do tamanho de um tipo composto:
`{seller.name}` é não-nulável porque `person` declara `name` obrigatório, e nada
verificaria que o `person` recebido cumpre a declaração.
"""
function check_composite!(ctx::CheckCtx, v, tn::Symbol, sp::Span, path::AbstractString,
                          depth::Int)
    if depth > MAX_COMPOSITE_DEPTH
        cerr!(ctx, "K3030", sp,
              "`$path` aninha mais de $MAX_COMPOSITE_DEPTH níveis; provavelmente há um ciclo nos dados.";
              hint = "Um valor não pode conter a si mesmo.", path)
        return nothing
    end

    T = typefor(env(ctx), tn)
    T === nothing && return nothing
    schema = kanon_schema(T)
    isempty(schema) && return nothing

    for spec in schema
        sub = try
            kanon_getfield(v, Val(spec.name))
        catch
            cerr!(ctx, "K3012", sp,
                  "`$tn` promete o campo `$(spec.name)`, e o valor de `$path` não o tem.";
                  hint = "O esquema do tipo e o valor entregue têm de casar; " *
                         "veja `kanon_schema` e `kanon_getfield` de `$T`.",
                  path = "$path.$(spec.name)")
            continue
        end

        sp2 = sp
        p2 = "$path.$(spec.name)"

        if isnull(sub) || isblank(sub)
            spec.optional && continue
            cerr!(ctx, "K3001", sp2,
                  "`$tn` declara `$(spec.name)` obrigatório, e o valor de `$path` " *
                  (isblank(sub) ? "o traz em branco." : "não o traz.");
                  hint = "Um campo que o esquema garante não pode faltar: é dele que " *
                         "`{$p2}` depende para não abrir buraco no texto.",
                  path = p2)
            continue
        end

        islist(spec.card) ?
            check_list!(ctx, sub, spec.type, spec.card, sp2, p2, depth + 1) :
            check_composite!(ctx, sub, spec.type, sp2, p2, depth + 1)
    end
    return nothing
end

function check_list!(ctx::CheckCtx, v, tn::Symbol, card::Cardinality, sp::Span,
                     path::AbstractString, depth::Int)
    v isa AbstractVector || return nothing
    for x in v
        isnull(x) || check_composite!(ctx, x, tn, sp, path, depth)
    end
end

"Cardinalidade em palavras, para a mensagem."
function card_text(c::Cardinality)
    c.kind === EXACT && return "exatamente $(c.lo)"
    c.kind === ATLEAST && return "pelo menos $(c.lo)"
    c.kind === RANGE && return c.lo == 0 ? "no máximo $(c.hi)" : "de $(c.lo) a $(c.hi)"
    return "qualquer número de"
end

function card_ok(c::Cardinality, n::Integer)
    c.kind === EXACT && return n == c.lo
    c.kind === ATLEAST && return n >= c.lo
    c.kind === RANGE && return c.lo <= n <= c.hi
    return true
end

"Decodifica um valor pelo tipo declarado, virando o erro do protocolo em diagnóstico."
function decode_value(ctx::CheckCtx, T::Type, raw, f::FieldDecl, path::AbstractString)
    try
        return kanon_decode(T, raw, ctx.fctx), true
    catch e
        e isa KanonProtocolError || rethrow()
        cerr!(ctx, "K3010", f.span,
              "`$(f.name)` é do tipo `$(f.type)`, e " * decode_reason(e);
              hint = "Não há conversão implícita: o valor entra como o tipo declarado, " *
                     "ou não entra (§3.4).",
              path)
        return nothing, false
    end
end

decode_reason(e::UndecodableValue) =
    "o valor recebido não serve — " * lowercasefirst(e.reason)
decode_reason(e::KanonProtocolError) = sprint(showerror, e)

lowercasefirst(s::AbstractString) = isempty(s) ? s : lowercase(s[1]) * s[2:end]

# --- um campo do contrato ----------------------------------------------------

function check_field!(ctx::CheckCtx, f::FieldDecl, raw)
    path = String(f.name)
    T = typefor(env(ctx), f.type)
    T === nothing && return nothing        # tipo desconhecido: já foi dito por `analyze`

    # --- ausência, e a normalização do branco (D-008) ---
    if isnull(raw)
        f.presence === REQUIRED && return missing_required!(ctx, f)
        f.presence === DEFAULTED && return default_value(ctx, f, T)
        return nothing
    end

    if isblank(raw)
        if f.presence === OPTIONAL
            cerr!(ctx, "K3004", f.span,
                  "`$(f.name)` veio em branco, e foi lido como ausente.";
                  hint = "Texto em branco não é um valor: sem esta normalização, o " *
                         "grupo que protege `{$(f.name)}` não elidiria e o documento " *
                         "sairia com um espaço no lugar do valor.",
                  path, severity = :warning)
            return nothing
        end
        cerr!(ctx, "K3003", f.span,
              "`$(f.name)` veio em branco, e o contrato o garante.";
              hint = "Informe um valor, ou declare o campo opcional — em branco ele " *
                     "abriria no texto o buraco que o modelo existe para impedir.",
              path)
        return nothing
    end

    # --- cardinalidade ---
    if islist(f.card)
        if !(raw isa AbstractVector)
            cerr!(ctx, "K3002", f.span,
                  "`$(f.name)` é uma coleção, e veio um valor único.";
                  hint = "Informe uma lista, mesmo que de um elemento só.", path)
            return nothing
        end
        n = length(raw)
        if !card_ok(f.card, n)
            cerr!(ctx, "K3002", f.span,
                  "`$(f.name)` admite $(card_text(f.card)) valores, e vieram $n.";
                  hint = "Ajuste os dados, ou a cardinalidade declarada no modelo.", path)
            return nothing
        end
        return decode_list!(ctx, f, T, raw, path)
    end

    if raw isa AbstractVector
        cerr!(ctx, "K3002", f.span,
              "`$(f.name)` é um valor único, e veio uma lista de $(length(raw)).";
              hint = "Declare `$(f.name) : $(f.type)[]` no modelo, ou informe um valor só.",
              path)
        return nothing
    end

    v, ok = decode_value(ctx, T, raw, f, path)
    ok || return nothing
    validate_value!(ctx, v, f, path)
    check_composite!(ctx, v, f.type, f.span, path, 1)
    return v
end

function decode_list!(ctx::CheckCtx, f::FieldDecl, T::Type, raw, path::AbstractString)
    out = Any[]
    for (i, x) in enumerate(raw)
        p = "$path[$i]"
        if isnull(x) || isblank(x)
            cerr!(ctx, "K3001", f.span,
                  "o $(i)º valor de `$(f.name)` " * (isblank(x) ? "veio em branco." : "está ausente.");
                  hint = "Uma coleção não tem buracos: `[]` é vazia, e nula é o campo " *
                         "inteiro, nunca um item.",
                  path = p)
            continue
        end
        v, ok = decode_value(ctx, T, x, f, p)
        ok || continue
        validate_value!(ctx, v, f, p)
        check_composite!(ctx, v, f.type, f.span, p, 1)
        push!(out, v)
    end
    return out
end

function missing_required!(ctx::CheckCtx, f::FieldDecl)
    cerr!(ctx, "K3001", f.span,
          "`$(f.name)` é exigido pelo modelo (linha $(f.span.line)) e não foi informado.";
          hint = "Informe o valor, ou declare o campo opcional e envolva em `[...]` " *
                 "o trecho que depende dele.",
          path = String(f.name))
    return nothing
end

"O valor padrão de um campo `= lit`. `today` é injetado, nunca lido do relógio (§2.2)."
function default_value(ctx::CheckCtx, f::FieldDecl, T::Type)
    lit = f.default
    lit === nothing && return nothing
    if lit.kind === :constant           # hoje só `today`
        ctx.fctx.today === nothing && return missing_today!(ctx, f.span, String(f.name))
        return ctx.fctx.today
    end
    return lit.value
end

function missing_today!(ctx::CheckCtx, sp::Span, path)
    cerr!(ctx, "K3005", sp,
          "o modelo usa `today`, e a data de hoje não foi informada.";
          hint = "`today` é injetado, nunca lido do relógio: passe `today = Date(...)`. " *
                 "É o que torna o determinismo verificável em vez de aspiracional.",
          path)
    return nothing
end

"Chama a validação do próprio tipo, que é quem sabe o que é um valor bem-formado."
function validate_value!(ctx::CheckCtx, v, f::FieldDecl, path::AbstractString)
    ds = try
        kanon_validate(v, ctx.fctx)
    catch e
        e isa KanonProtocolError || rethrow()
        cerr!(ctx, "K3011", f.span, "`$(f.name)`: " * sprint(showerror, e); path)
        return nothing
    end
    ds === nothing && return nothing
    for d in ds
        push!(ctx.diags, d)
    end
    return nothing
end

# --- a checagem inteira ------------------------------------------------------

"""
Onde o texto interpola `today`, se interpola. Só o texto: o `= today` de um campo emite
o próprio erro, na linha da declaração, e contar os dois aqui diria duas vezes a mesma
coisa.
"""
function today_in_text(m::Model)
    for b in m.template.text.blocks, p in b.children
        n = find_today(m, p.children)
        n === nothing || return n
    end
    return nothing
end

function find_today(m::Model, nodes)
    for n in nodes
        if n isa Interp
            rp = m.analysis.paths[id(n)]
            rp === nothing || rp.kind === :constant && return n
        elseif n isa Group
            r = find_today(m, n.children)
            r === nothing || return r
        end
    end
    return nothing
end

"""
Avisa sobre campo que a entrada traz e o contrato não declara.

**Aviso, e não erro** (D-022): um campo a mais nunca esconde um erro sozinho — se o nome
foi digitado errado, o campo declarado aparece como ausente e o erro sai por lá. Recusar
tornaria impossível alimentar vários modelos com a mesma fonte, que é o caso normal de
uma tabela.
"""
function check_extras!(ctx::CheckCtx, data)
    declarados = [f.name for f in ctx.model.template.data.fields]
    for k in input_keys(data)
        k in declarados && continue
        # sem linha: o problema está nos dados, não em nenhum ponto do arquivo
        cerr!(ctx, "K3021", Span(1, 0, 0),
              "os dados trazem `$k`, que o contrato não declara.";
              hint = did_you_mean(k, declarados,
                  "O campo é ignorado: só o que o modelo declara chega ao documento."),
              path = String(k), severity = :warning)
    end
    return nothing
end

"""
    rows(tabela)

As linhas de uma tabela como dados. Precisa de `Tables.jl` carregado — o núcleo não
depende dele, e a extensão só existe quando ele existe.
"""
function rows end

"""
    render_each(modelo, tabela; today, budget) -> Vector{String}

Um documento por linha da tabela. Precisa de `Tables.jl` carregado.
"""
function render_each end

"""
    read_json(caminho) -> Dict{String,Any}

Lê dados de um arquivo JSON. Precisa de `JSON3.jl` carregado.
"""
function read_json end

"""
    parse_json(texto) -> Dict{String,Any}

Como [`read_json`](@ref), a partir do texto. Precisa de `JSON3.jl` carregado.
"""
function parse_json end

"Acrescenta o número da linha ao diagnóstico, para a ingestão dizer qual falhou."
with_row(d::Diagnostic, i::Integer) =
    Diagnostic(d.code, d.severity, d.category, d.file, d.line, d.col, d.endline, d.endcol,
               d.path, "linha $i da tabela: " * d.message, d.hint)

"""
    bind(model, data; today = nothing) -> Bound

Valida os dados contra o contrato e decodifica o que passar. Não lança: devolve o
`Bound` com os diagnósticos acumulados, para que o chamador decida.
"""
function bind(m::Model, data; today::Union{Nothing,Date} = nothing,
              budget::Budget = Budget())
    ctx = CheckCtx(m, FormatContext(m.env, today),
                   isempty(m.template.sources) ? "<string>" : m.template.sources[1],
                   Diagnostic[])

    campos = m.template.data.fields
    valores = Vector{Any}(nothing, length(campos))
    for (i, f) in enumerate(campos)
        valores[i] = check_field!(ctx, f, input_field(data, f.name))
    end

    check_extras!(ctx, data)
    if today === nothing
        n = today_in_text(m)
        n === nothing || missing_today!(ctx, n.span, "today")
    end

    # O plano é montado sempre, inclusive com dados incompletos: é dele que o rascunho
    # depende, e uma condição sobre campo ausente tem resposta definida e conservadora —
    # `is present` é falso, comparação é falsa.
    plano = build_plan(m, valores, ctx.fctx, budget)

    # A remissão quebrada só se reporta quando não há outro erro: com um campo faltando,
    # o bloco pode ter sumido por causa do campo, e o K3040 seria cascata.
    haserrors(DiagnosticSet(ctx.diags)) || check_dangling_refs!(ctx, plano)

    sort!(ctx.diags; by = sortkey)
    Bound(m, valores, today, plano, ctx.diags)
end

"""
Uma remissão a bloco que as regras **de fato** removeram, para estes dados.

`analyze` já avisou que isso podia acontecer (`K2035`), e o aviso existe porque o autor
pode saber que as duas condições coincidem. Quando elas não coincidem, o documento sairia
com uma remissão a um bloco que não está nele — e isso é erro de dados, reportado aqui,
onde há dados para reportá-lo. O render não emite diagnóstico.
"""
function check_dangling_refs!(ctx::CheckCtx, plano::Plan)
    isempty(plano.instances) && return nothing
    m = ctx.model
    for (pos, b) in enumerate(m.template.text.blocks)
        plano.present[pos] || continue
        for p in b.children
            scan_refs!(ctx, plano, p.children)
        end
    end
end

function scan_refs!(ctx::CheckCtx, plano::Plan, nodes)
    for n in nodes
        if n isa BlockRef
            alvo = findfirst(b -> b.name === n.target, ctx.model.template.text.blocks)
            alvo === nothing && continue
            plano.present[alvo] && continue
            cerr!(ctx, "K3040", n.span,
                  "a remissão aponta o bloco `$(n.target)`, que as regras removeram " *
                  "para estes dados.";
                  hint = "O modelo avisou que isso podia acontecer. Prenda este trecho " *
                         "à mesma condição do bloco remetido, ou informe os dados que " *
                         "mantêm os dois.",
                  path = String(n.target))
        elseif n isa Group
            scan_refs!(ctx, plano, n.children)
        end
    end
end

"""
    check(model, data; today = nothing) -> DiagnosticSet

Os dados satisfazem o contrato? Conjunto vazio quer dizer que sim.

Não lança, de propósito: `check` é a pergunta, e quem responde "não" merece a lista
inteira do que falta, e não o primeiro problema.
"""
check(m::Model, data; today::Union{Nothing,Date} = nothing,
      budget::Budget = Budget()) =
    diagnostics(bind(m, data; today, budget))
