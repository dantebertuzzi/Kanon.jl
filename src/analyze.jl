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
    # o caminho que o bloco corrente itera, quando uma regra `one for each` o repete
    iterating::Union{Nothing,Path}
    # os caminhos que o `when` do bloco corrente afirma presentes (D-020, 2ª revisão)
    guaranteed::Vector{Vector{Symbol}}
    # campos cujo tipo declarado não existe: caminhos que passem por eles não geram
    # erro em cascata, porque o erro já foi dito na declaração
    poisoned::Vector{Symbol}
end

function AnalysisCtx(env::Environment, tmpl::Template)
    AnalysisCtx(env, tmpl, Analysis(tmpl.nnodes),
                isempty(tmpl.sources) ? "<string>" : tmpl.sources[1],
                nothing, nothing, nothing, Vector{Symbol}[], Symbol[])
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
        # a opcionalidade deste segmento não conta se a regra do bloco afirma que o
        # caminho até aqui está presente
        nullable |= spec.optional && !guaranteed_prefix(ctx, segs, i)
    end
    ResolvedPath(kind, typename, nullable, card, decl), nothing
end

# --- as duas resoluções ------------------------------------------------------

"""
Dentro de um bloco que `one for each` repete, o caminho iterado denota o **elemento
corrente**, não a coleção (§8.3). É por isso que `: cada <- witnesses` com
`cada one for each witnesses` faz `{witnesses}` valer uma testemunha e
`{witnesses.name}` valer o nome dela.

Sem isto, `{witnesses}` renderizaria a lista inteira em cada iteração — e em silêncio,
que é a pior forma de estar errado.
"""
iterated_head(ctx::AnalysisCtx, head::Symbol) =
    ctx.iterating !== nothing && length(ctx.iterating.segments) == 1 &&
    ctx.iterating.segments[1] === head

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

    # a iteração entrega um elemento, e um elemento nunca é a lista nem é nulo; e um
    # caminho que a regra do bloco afirma presente também não é (D-020)
    iterado = iterated_head(ctx, head)
    card = iterado ? Cardinality() : decl.card
    nulo = iterado ? false : decl.presence === OPTIONAL
    nulo &= !guaranteed_prefix(ctx, segs, 1)

    length(segs) == 1 &&
        return ResolvedPath(:field, decl.type, nulo, card, decl.id), nothing

    descend(ctx, segs, 2, decl.type, card, nulo, :field, decl.id)
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

"O prefixo `segs[1:i]` é um dos caminhos que a regra do bloco afirma presentes?"
guaranteed_prefix(ctx::AnalysisCtx, segs::Vector{Symbol}, i::Int) =
    any(g -> g == segs[1:i], ctx.guaranteed)

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

    fmts = kanon_formats(T, ctx.env)
    n.formatter in fmts && return nothing

    # O formatador pode existir, e ser de outro idioma: dizer "não existe" mandaria o
    # redator procurar um erro de digitação onde falta uma camada.
    idioma = format_locale_of(T, n.formatter)
    if idioma !== nothing
        err!(ctx, "K2020", n.span,
             "`$(n.formatter)` é um formatador do idioma `$idioma`, e este ambiente " *
             (ctx.env.locale === nothing ? "não tem idioma." :
                                           "está em `$(ctx.env.locale)`.");
             hint = "Construa o ambiente com `locale = :$idioma`.", path = string(n.path))
        return nothing
    end

    tail = isempty(fmts) ?
        "`$effective` não tem formatador nomeado; escreva `{$(string(n.path))}`." :
        "Formatadores de `$effective`: $(join(fmts, ", "))."
    err!(ctx, "K2020", n.span,
         "`$(n.formatter)` não existe para o tipo `$effective`.";
         hint = did_you_mean(n.formatter, fmts, tail), path = string(n.path))
    return nothing
end

# --- grupos opcionais e o teorema da lacuna ----------------------------------

"""
As interpolações **diretas** de um grupo (§4.4): as que estão lexicalmente dentro dele e
fora de qualquer grupo aninhado nele. Remissões `{::x}` não contam — nunca são nulas.

São elas, e só elas, que decidem a elisão: um grupo aninhado elide por conta própria e
não afeta o de fora.
"""
direct_interps(g::Group) = Interp[n for n in g.children if n isa Interp]

"""
Todo o texto literal de dentro de um grupo, incluindo o dos grupos aninhados.

Pontos de flexão ficam de fora: os parênteses de `portador(a)` são notação da
linguagem, não pontuação do redator, e desaparecem na flexão.
"""
function group_text(g::Group)
    io = IOBuffer()
    collect_text!(io, g.children)
    String(take!(io))
end

function collect_text!(io::IO, nodes)
    for n in nodes
        n isa TextLit && print(io, n.value)
        n isa Group && collect_text!(io, n.children)
    end
end

"""
Conta a pontuação que a elisão deixaria órfã.

Um parêntese literal escrito `((` conta como qualquer outro, de propósito: o problema
não é de onde o caractere veio, e sim que o par dele ficou do lado de fora do grupo —
elidir o grupo deixa o outro lado sozinho no texto.

Aspas retas são contadas pela paridade, porque não têm lado. Apóstrofo não é contado:
`d\'água` e `l\'état` fariam disso um gerador de falso positivo. Aspas curvas ficam para
a camada de saída, que é quem as introduz.
"""
function unbalanced(text::AbstractString)
    depth = 0
    lowest = 0
    quotes = 0
    for c in text
        if c == '('
            depth += 1
        elseif c == ')'
            depth -= 1
            lowest = min(lowest, depth)
        elseif c == '"'
            quotes += 1
        end
    end
    (parens = depth != 0 || lowest < 0, quotes = isodd(quotes))
end

"""
As três verificações que a §4.4 exige de um grupo, mais a extensão de D-021.

A pergunta que todas respondem é a mesma: **este grupo pode elidir?** Um grupo que não
pode não é opcional coisa nenhuma — é ruído que faz o redator acreditar ter tornado o
texto dispensável quando não tornou.
"""
function check_group!(ctx::AnalysisCtx, g::Group)
    diretas = direct_interps(g)

    if isempty(diretas)
        err!(ctx, "K2010", g.span,
             "este grupo opcional não tem nenhuma interpolação direta, e por isso nunca elide.";
             hint = "Um grupo elide quando um valor seu falta. Sem valor dentro, " *
                    "escreva o texto sem os colchetes.")
    else
        resolvidas = [rp for rp in (ctx.out.paths[id(n)] for n in diretas) if rp !== nothing]
        # Nenhuma resolveu: o erro já foi dito no caminho, não se diz de novo aqui.
        if !isempty(resolvidas) && !any(rp -> rp.nullable, resolvidas)
            nomes = join(sort!(unique!(["`" * string(n.path) * "`" for n in diretas])), ", ")
            plural = length(diretas) > 1
            # A garantia pode vir do contrato ou da regra do próprio bloco, e mandar
            # corrigir o plano de dados quando o culpado é o `when` seria mandar mexer
            # no lugar errado.
            pela_regra = any(n -> guaranteed_present(ctx, n.path), diretas)
            if pela_regra
                err!(ctx, "K2011", g.span,
                     "este grupo opcional nunca elide: a regra deste bloco já garante " *
                     (plural ? "$nomes." : "$nomes.");
                     hint = "O bloco só existe quando o valor está presente, então o " *
                            "grupo é redundante — escreva o texto sem os colchetes.")
            else
                err!(ctx, "K2011", g.span,
                     "este grupo opcional nunca elide: $nomes " *
                     (plural ? "são valores que o contrato sempre garante." :
                               "é um valor que o contrato sempre garante.");
                     hint = "Marque o campo como opcional no plano de dados, ou escreva o " *
                            "texto sem os colchetes.")
            end
        end
    end

    p, q = unbalanced(group_text(g))
    p && err!(ctx, "K2013", g.span,
              "os parênteses dentro deste grupo opcional não fecham dentro dele.";
              hint = "Elidir o grupo deixaria o parêntese do par sozinho no texto. " *
                     "Ponha o par inteiro dentro do grupo, ou o inteiro fora.")
    q && err!(ctx, "K2014", g.span,
              "as aspas dentro deste grupo opcional não fecham dentro dele.";
              hint = "Elidir o grupo deixaria a outra aspa sozinha no texto. " *
                     "Ponha o par inteiro dentro do grupo, ou o inteiro fora.")
    return nothing
end

"""
Por que este caminho é nulável, em uma oração — porque mandar o redator procurar sozinho
é o que transforma um erro correto numa mensagem inútil. `{seller.spouse.name}` não é
nulável por causa de `seller`, que é obrigatório; é por causa de `spouse`, que é
opcional dentro de `person`, e é isso que a mensagem tem de dizer.

Refaz a descida em vez de guardar a origem no `ResolvedPath`: o custo é uma travessia
de caminho no momento do erro, e a forma do `ResolvedPath` é normativa (`ast.md` §7).
"""
function nullability_reason(ctx::AnalysisCtx, p::Path, rp::ResolvedPath)
    segs = p.segments
    typename = :?
    start = 2

    if rp.kind === :subject_field
        subj = ctx.subject
        subj === nothing && return "o valor é opcional"
        subj.nullable &&
            return "vem de `$(string(ctx.subject_path))`, o sujeito deste bloco, que pode faltar"
        T = typefor(ctx.env, subj.typename)
        T === nothing && return "o valor é opcional"
        spec = findspec(kanon_schema(T), segs[1])
        spec === nothing && return "o valor é opcional"
        spec.optional && return "`$(segs[1])` é opcional em `$(subj.typename)`"
        typename = spec.type
    else
        decl = fielddecl(ctx.tmpl, segs[1])
        decl === nothing && return "o valor é opcional"
        decl.presence === OPTIONAL && return "o contrato declara `$(segs[1])` opcional"
        typename = decl.type
    end

    for i in start:length(segs)
        T = typefor(ctx.env, typename)
        T === nothing && break
        spec = findspec(kanon_schema(T), segs[i])
        spec === nothing && break
        spec.optional && return "`$(segs[i])` é opcional em `$typename`"
        typename = spec.type
    end
    return "o valor é opcional"
end

function findspec(schema, name::Symbol)
    i = findfirst(f -> f.name === name, schema)
    i === nothing ? nothing : schema[i]
end

"""
O teorema da lacuna, no ponto em que ele deixa de ser enunciado e vira verificação:
toda interpolação de caminho nulável tem de estar dentro de pelo menos um grupo.

Sem isto, `{seller.spouse.name}` com cônjuge ausente renderizaria vazio, e nenhum
princípio teria sido formalmente violado — que é exatamente como a lacuna silenciosa
voltaria.
"""
function check_guarded!(ctx::AnalysisCtx, n::Interp, rp::ResolvedPath, depth::Int)
    ctx.out.guarded[id(n)] = depth > 0
    (rp.nullable && depth == 0) || return nothing

    err!(ctx, "K2012", n.span,
         "`$(string(n.path))` pode faltar, porque $(nullability_reason(ctx, n.path, rp)), " *
         "e está fora de qualquer grupo opcional.";
         hint = "Envolva o trecho que depende dele em colchetes: " *
                "`[..., $(string(n.path)) ...]`. Assim o trecho inteiro sai quando o " *
                "valor falta, em vez de deixar um buraco.",
         path = string(n.path))
    return nothing
end

# --- blocos, estilos e níveis ------------------------------------------------

"A posição de um bloco em `text.blocks`, ou `nothing`. É por ela que as tabelas por bloco são indexadas."
function blockpos(ctx::AnalysisCtx, name::Symbol)
    findfirst(b -> b.name === name, ctx.tmpl.text.blocks)
end

blocknames(ctx::AnalysisCtx) = [b.name for b in ctx.tmpl.text.blocks]

"O nível de um bloco: a unidade repetida *n*+1 vezes é o nível *n*; `:` sozinho é 0, o não numerado."
level(b::Block) = Int(b.repeat) - 1

"""
Valida os marcadores e a sequência de níveis, e monta o índice de blocos.

A sequência é verificação estática pura — nível 2 sem nível 1 antes é erro **sem
dados** — e por isso mora aqui, e não na F5 com os contadores.
"""
function index_blocks!(ctx::AnalysisCtx)
    aberto = Pair{Char,Int}[]      # nível do último bloco visto, por estilo
    contadores = Pair{Char,Vector{Int32}}[]   # contadores por estilo, um por nível

    resize!(ctx.out.numbering, length(ctx.tmpl.text.blocks))
    for i in eachindex(ctx.out.numbering)
        ctx.out.numbering[i] = Int32[]
    end

    for (pos, b) in enumerate(ctx.tmpl.text.blocks)
        push!(ctx.out.block_index, b.name => id(b))

        estilo = stylefor(ctx.env, b.unit)
        if estilo === nothing
            marcadores = sort!([string(s.unit) for s in ctx.env.styles])
            err!(ctx, "K2030", b.span,
                 "o marcador `$(b.unit)` não tem estilo registrado neste ambiente.";
                 hint = isempty(marcadores) ?
                     "Nenhum estilo de bloco está registrado." :
                     "Marcadores deste ambiente: $(join(marcadores, ", ")). " *
                     "Carregue a camada que registra `$(b.unit)`.")
            continue
        end

        n = level(b)
        if n == 0 && b.unit != NUMBERING_FREE_UNIT
            err!(ctx, "K2032", b.span,
                 "`$(b.unit)` sozinho não é um cabeçalho: o estilo `$(estilo.name)` só " *
                 "tem formas numeradas.";
                 hint = "O nível 1 é a unidade repetida duas vezes: `$(b.unit)$(b.unit)`.")
            continue
        end
        n == 0 && continue          # não numerado: fora da sequência de níveis

        ctx.out.numbering[pos] = advance_counter!(contadores, b.unit, n)

        i = findfirst(p -> first(p) == b.unit, aberto)
        anterior = i === nothing ? 0 : last(aberto[i])
        if n > anterior + 1
            err!(ctx, "K2031", b.span,
                 "este bloco é de nível $n, e nenhum bloco de nível $(n - 1) o precede " *
                 "no estilo `$(estilo.name)`.";
                 hint = "Um nível só existe dentro do anterior. Insira um bloco " *
                        "`$(repeat(b.unit, n))` antes deste, ou escreva este como " *
                        "`$(repeat(b.unit, anterior + 2))`.")
        end
        i === nothing ? push!(aberto, b.unit => n) : (aberto[i] = b.unit => n)
    end

    sort!(ctx.out.block_index; by = first)
end

"""
Avança o contador do estilo: um bloco de nível *n* incrementa o contador de nível *n* e
zera os de nível maior (§6.2). Cada estilo tem sua própria família de contadores.

Esta é a numeração **estática**, com todos os blocos presentes. Quando a F5 aplicar as
regras, blocos removidos deixarão de consumir número e blocos repetidos consumirão um
por iteração — e a numeração final passará a ser do render, que tem os dados. Enquanto
não há regras aplicadas, a estática é a final.
"""
function advance_counter!(contadores::Vector{Pair{Char,Vector{Int32}}}, unit::Char, n::Int)
    i = findfirst(p -> first(p) == unit, contadores)
    if i === nothing
        push!(contadores, unit => Int32[])
        i = length(contadores)
    end
    c = last(contadores[i])
    # `resize!` para cima não inicializa memória em Julia: os níveis novos entram em
    # zero explicitamente, senão o contador começa em lixo.
    while length(c) < n
        push!(c, Int32(0))
    end
    resize!(c, n)               # zera os níveis abaixo deste (§6.2)
    c[n] += Int32(1)
    copy(c)
end

# --- regras: a que bloco cada uma se prende ----------------------------------

"""
Prende cada regra ao seu bloco e preenche `block_rule` e `block_foreach`.

Roda **antes** do plano do texto porque a validação das remissões precisa saber quais
blocos uma regra repete ou pode remover (§6.3).

D-002 é verificada aqui, e não com a semântica das expressões, porque é aqui que o
conflito aparece: duas regras da mesma espécie disputam a mesma casa da tabela, e
guardar uma delas em silêncio seria escolher por conta própria qual das duas o redator
quis dizer.
"""
function bind_rules!(ctx::AnalysisCtx)
    nb = length(ctx.tmpl.text.blocks)
    resize!(ctx.out.block_rule, nb); fill!(ctx.out.block_rule, Int32(0))
    resize!(ctx.out.block_foreach, nb); fill!(ctx.out.block_foreach, Int32(0))

    for (k, r) in enumerate(ctx.tmpl.rules.rules)
        pos = blockpos(ctx, r.block)
        if pos === nothing
            nomes = blocknames(ctx)
            err!(ctx, "K2036", r.span,
                 "a regra nomeia o bloco `$(r.block)`, que o plano do texto não tem.";
                 hint = did_you_mean(r.block, nomes,
                     isempty(nomes) ? "O modelo não tem bloco nenhum." :
                                      "Blocos deste modelo: $(join(sort(nomes), ", "))."))
            continue
        end

        r.when === nothing || bind_one!(ctx, ctx.out.block_rule, pos, k, r, "when")
        r.foreach === nothing || bind_one!(ctx, ctx.out.block_foreach, pos, k, r, "one for each")
    end
end

function bind_one!(ctx::AnalysisCtx, tabela::Vector{Int32}, pos::Int, k::Int,
                   r::Rule, especie::AbstractString)
    if tabela[pos] != 0
        anterior = ctx.tmpl.rules.rules[tabela[pos]]
        err!(ctx, "K2037", r.span,
             "o bloco `$(r.block)` já tem uma regra `$especie`, na linha $(anterior.span.line).";
             hint = especie == "when" ?
                 "Um bloco admite um `when` só. Junte as duas condições numa expressão " *
                 "com `and` ou `or` — combinação implícita é a pergunta que o leitor não " *
                 "deveria ter de fazer." :
                 "Um bloco se repete sobre uma coleção só.")
        return nothing
    end
    tabela[pos] = Int32(k)
    return nothing
end

# --- remissões ---------------------------------------------------------------

"""
`{::nome}` — a remissão (§6.3). Três verificações, e a terceira é aviso de propósito.

Remissão a bloco que uma regra pode remover é **aviso**, não erro: o autor pode saber
que as duas condições coincidem — que o bloco que remete e o remetido saem juntos — e o
motor não tem como provar que ele está errado. Mas ele precisa ser avisado, porque o
caso em que não coincidem produz uma remissão a um bloco que não está no documento.
"""
function check_blockref!(ctx::AnalysisCtx, n::BlockRef)
    pos = blockpos(ctx, n.target)
    if pos === nothing
        nomes = blocknames(ctx)
        err!(ctx, "K2033", n.span,
             "a remissão aponta o bloco `$(n.target)`, que o plano do texto não tem.";
             hint = did_you_mean(n.target, nomes,
                 isempty(nomes) ? "O modelo não tem bloco nenhum." :
                                  "Blocos deste modelo: $(join(sort(nomes), ", "))."))
        return nothing
    end

    alvo = ctx.tmpl.text.blocks[pos]
    if level(alvo) == 0
        err!(ctx, "K2038", n.span,
             "o bloco `$(n.target)` não é numerado, e uma remissão rende um número.";
             hint = "Numere o bloco escrevendo `$(alvo.unit)$(alvo.unit) $(n.target)`, " *
                    "ou repita o texto em vez de remeter.")
        return nothing
    end

    if !isempty(ctx.out.block_foreach) && ctx.out.block_foreach[pos] != 0
        regra = ctx.tmpl.rules.rules[ctx.out.block_foreach[pos]]
        err!(ctx, "K2034", n.span,
             "o bloco `$(n.target)` se repete (`one for each`, linha $(regra.span.line)), " *
             "e não há como nomear uma das cópias.";
             hint = "Remeta a um bloco que ocorre uma vez só.")
        return nothing
    end

    if !isempty(ctx.out.block_rule) && ctx.out.block_rule[pos] != 0
        regra = ctx.tmpl.rules.rules[ctx.out.block_rule[pos]]
        err!(ctx, "K2035", n.span,
             "o bloco `$(n.target)` pode ser removido por uma regra (linha $(regra.span.line)), " *
             "e então esta remissão apontaria para o que não está no documento.";
             hint = "Se as duas condições coincidem de propósito, não há o que corrigir. " *
                    "Senão, prenda este trecho à mesma condição.",
             severity = :warning)
    end
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

"""
A regra `when` do bloco garante que este caminho está presente?

Deliberadamente conservadora: reconhece uma conjunção de termos em que algum afirme a
presença do caminho, e nada além disso. Um `or` não garante, e uma condição que implique
a presença por caminho indireto também não — dizer que garante quando não garante
reabriria a lacuna que a F2.3 fechou, e o custo de não reconhecer é apenas um par de
colchetes a mais.
"""
function guaranteed_present(ctx::AnalysisCtx, p::Path)
    any(g -> g == p.segments, ctx.guaranteed)
end

"""
Os caminhos que a regra `when` do bloco afirma presentes.

Deliberadamente conservadora: só uma conjunção de termos que afirmem presença. Um `or`
não garante nada, e uma condição que implique a presença por caminho indireto também
não — dizer que garante quando não garante reabriria a lacuna que a F2.3 fechou, e o
custo de não reconhecer é um par de colchetes que o redator sempre pode escrever.
"""
function present_paths(ctx::AnalysisCtx, pos::Int)
    out = Vector{Symbol}[]
    isempty(ctx.out.block_rule) && return out
    k = ctx.out.block_rule[pos]
    k == 0 && return out
    collect_present!(out, ctx.tmpl.rules.rules[k].when)
    out
end

function collect_present!(out::Vector{Vector{Symbol}}, e::Union{Nothing,RuleExpr})
    e === nothing && return out
    if e isa AttrExpr
        afirma = (e.attr === :present && !e.negated) || (e.attr === :absent && e.negated)
        afirma && push!(out, e.subject.segments)
    elseif e isa NotExpr && e.operand isa AttrExpr
        o = e.operand
        o.attr === :absent && !o.negated && push!(out, o.subject.segments)
    elseif e isa BinExpr && e.op === :and
        collect_present!(out, e.lhs)
        collect_present!(out, e.rhs)
    end
    out
end

"Resolve o sujeito do cabeçalho e o guarda em `paths[bloco]` — nó nenhum o carrega (I2)."
function analyze_subject!(ctx::AnalysisCtx, b::Block, pos::Int)
    ctx.subject = nothing
    ctx.subject_path = nothing
    ctx.iterating = nothing

    ctx.guaranteed = present_paths(ctx, pos)

    k = isempty(ctx.out.block_foreach) ? Int32(0) : ctx.out.block_foreach[pos]
    k == 0 || (ctx.iterating = ctx.tmpl.rules.rules[k].foreach)

    b.subject === nothing && return nothing

    rp, f = resolve_in_contract(ctx, b.subject)
    # D-020, refinada: um bloco que só existe quando o sujeito está presente tem o
    # sujeito presente por construção, e não precisa espalhar nulabilidade pelo texto.
    if rp !== nothing && rp.nullable && guaranteed_present(ctx, b.subject)
        rp = ResolvedPath(rp.kind, rp.typename, false, rp.card, rp.decl)
    end
    if rp === nothing
        if f !== SILENT && f !== nothing
            code = f.code == "K2001" ? "K2006" : f.code
            err!(ctx, code, b.subject.span, f.message; hint = f.hint,
                 path = string(b.subject))
        end
        return nothing
    end

    # Um sujeito escalar é legítimo no bloco iterado: o redator refere o elemento
    # inteiro, e não campos dele.
    T = typefor(ctx.env, rp.typename)
    if ctx.iterating === nothing && T !== nothing && isempty(kanon_schema(T))
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

function analyze_nodes!(ctx::AnalysisCtx, nodes, depth::Int = 0)
    for n in nodes
        if n isa Interp
            rp = resolve!(ctx, n.path, n.span)
            rp === nothing && continue
            ctx.out.paths[id(n)] = rp
            resolve_formatter!(ctx, n, rp)
            check_guarded!(ctx, n, rp, depth)
        elseif n isa BlockRef
            check_blockref!(ctx, n)
        elseif n isa Group
            # Os filhos primeiro: decidir se o grupo pode elidir exige saber a
            # nulabilidade das interpolações que ele contém.
            analyze_nodes!(ctx, n.children, depth + 1)
            check_group!(ctx, n)
        end
    end
end

function analyze_text!(ctx::AnalysisCtx)
    for (pos, b) in enumerate(ctx.tmpl.text.blocks)
        analyze_subject!(ctx, b, pos)
        for p in b.children
            analyze_nodes!(ctx, p.children)
        end
    end
    ctx.subject = nothing
    ctx.subject_path = nothing
    ctx.iterating = nothing
end

# --- semântica das regras ----------------------------------------------------

"""
O método padrão de `kanon_compare` — o que recusa. Serve para distinguir "este tipo
declara comparação com aquele" de "caiu no recuso genérico": `hasmethod` sozinho é
sempre verdadeiro, porque o padrão casa com tudo.

Calculado na chamada, e não numa constante, porque uma camada carregada depois muda a
resposta — e é exatamente isso que tem de acontecer.
"""
compare_fallback() = which(kanon_compare, Tuple{Any,Any})

"O tipo declara como comparar um valor seu com um de `R`? (§8.1)"
can_compare(L::Type, R::Type) = which(kanon_compare, Tuple{L,R}) !== compare_fallback()

"Tipo Kanon e tipo Julia de um literal escrito no plano das regras."
function literal_types(lit::Literal)
    lit.kind === :constant && return (:date, Date)      # `today`
    lit.kind === :null && return (:null, Nothing)
    (lit.kind, typeof(lit.value))
end

"O nome de tipo efetivo de um caminho: `list` quando a cardinalidade é de lista."
effective_typename(rp::ResolvedPath) = islist(rp.card) ? :list : rp.typename

"""
Verifica uma expressão de regra e devolve o nome do tipo do seu valor, `:boolean` para
as que já são condições, ou `:?` quando o erro já foi dito e encadear outro só faria
ruído.

Não há veracidade implícita (§8.1): um caminho isolado só é condição se o tipo dele for
`boolean`. `when notes` é erro, e a mensagem diz o que escrever no lugar.
"""
function check_expr!(ctx::AnalysisCtx, e::RuleExpr)
    if e isa PathExpr
        rp = resolve!(ctx, e.path, e.span)
        rp === nothing && return :?
        ctx.out.paths[id(e)] = rp
        return effective_typename(rp)

    elseif e isa LitExpr
        return first(literal_types(e.lit))

    elseif e isa NotExpr
        require_boolean!(ctx, e.operand, check_expr!(ctx, e.operand))
        return :boolean

    elseif e isa AttrExpr
        rp = resolve!(ctx, e.subject, e.span)
        rp === nothing && return :?
        ctx.out.paths[id(e)] = rp
        check_attribute!(ctx, e, rp)
        return :boolean

    elseif e isa BinExpr
        if e.op === :and || e.op === :or
            require_boolean!(ctx, e.lhs, check_expr!(ctx, e.lhs))
            require_boolean!(ctx, e.rhs, check_expr!(ctx, e.rhs))
        else
            check_comparison!(ctx, e)
        end
        return :boolean
    end
    return :?
end

"""
Uma condição tem de ser verdadeira ou falsa. Este é o ponto em que a linguagem recusa a
veracidade implícita — a conveniência que faria `when notes` significar "quando houver
notas" em um leitor e "quando notas for verdadeiro" em outro.
"""
function require_boolean!(ctx::AnalysisCtx, e::RuleExpr, tn::Symbol)
    (tn === :boolean || tn === :?) && return nothing
    hint = tn === :null ?
        "Para testar ausência, escreva `is absent`." :
        "Escreva `is present`, `is absent`, uma comparação, ou um atributo do tipo — " *
        "a linguagem não tem veracidade implícita."
    err!(ctx, "K2040", span(e),
         "esta condição é do tipo `$tn`, e uma condição precisa ser verdadeira ou falsa.";
         hint)
    return nothing
end

"`present` e `absent` valem para todo campo; os demais atributos vêm do tipo."
function check_attribute!(ctx::AnalysisCtx, e::AttrExpr, rp::ResolvedPath)
    if e.attr in UNIVERSAL_ATTRIBUTES
        # Um campo que o contrato garante torna `is present` uma tautologia, e a regra
        # que depende dela, decoração. Aviso, não erro: pode ser um modelo em edição.
        rp.nullable && return nothing
        sempre = (e.attr === :present) != e.negated
        err!(ctx, "K2047", e.span,
             "`$(string(e.subject))` é um valor que o contrato sempre garante, " *
             "e por isso esta condição é sempre $(sempre ? "verdadeira" : "falsa").";
             hint = sempre ? "A regra não remove o bloco nunca; ela pode sair." :
                             "A regra remove o bloco sempre; ou o bloco, ou a regra, sobra.",
             severity = :warning, path = string(e.subject))
        return nothing
    end

    tn = effective_typename(rp)
    T = typefor(ctx.env, tn)
    T === nothing && return nothing
    attrs = kanon_attributes(T)
    e.attr in attrs && return nothing

    todos = sort!(collect(Symbol, (attrs..., UNIVERSAL_ATTRIBUTES...)))
    err!(ctx, "K2041", e.span,
         "`$tn` não tem o atributo `$(e.attr)`.";
         hint = did_you_mean(e.attr, todos, "Atributos de `$tn`: $(join(todos, ", "))."),
         path = string(e.subject))
    return nothing
end

"""
Comparar exige que o tipo diga como (§8.1): `price > 0` vale porque `money` compara com
número, e `name > 3` não vale porque `text` não compara com número.

Sem essa exigência, comparar seria uma promessa que o núcleo não tem como cumprir — e a
falha apareceria no render, com dados, que é tarde demais.
"""
function check_comparison!(ctx::AnalysisCtx, e::BinExpr)
    lt = check_expr!(ctx, e.lhs)
    rt = check_expr!(ctx, e.rhs)
    (lt === :? || rt === :?) && return nothing

    if lt === :null || rt === :null
        outro = lt === :null ? string_of(e.rhs) : string_of(e.lhs)
        err!(ctx, "K2044", e.span,
             "não se compara um valor com `null`.";
             hint = "Ausência não é um valor: escreva `$outro is absent` ou " *
                    "`$outro is present`.")
        return nothing
    end

    L, R = typefor(ctx.env, lt), typefor(ctx.env, rt)
    (L === nothing || R === nothing) && return nothing
    (can_compare(L, R) || can_compare(R, L)) && return nothing

    err!(ctx, "K2043", e.span,
         "`$lt` e `$rt` não se comparam.";
         hint = "O tipo é quem declara com o que se compara. `$lt` não declara " *
                "comparação com `$rt`.")
    return nothing
end

"O texto de um operando, para a mensagem. Vazio quando não é um caminho."
string_of(e::RuleExpr) = e isa PathExpr ? string(e.path) : "o valor"

"""
`bloco one for each C` exige que `C` seja lista e que o cabeçalho declare `<- C` — o
mesmo caminho (§8.3).

A redundância é deliberada, e verificá-la é o que a torna útil: o plano do texto precisa
ser legível sozinho, e `<- seller` é o que diz ao leitor de `{name}` o que `name` é.
"""
function check_foreach!(ctx::AnalysisCtx, r::Rule, pos::Int)
    rp = resolve!(ctx, r.foreach, r.span)
    rp === nothing && return nothing
    ctx.out.paths[id(r)] = rp

    if !islist(rp.card)
        err!(ctx, "K2045", r.span,
             "`$(string(r.foreach))` é um valor único, do tipo `$(rp.typename)`, e " *
             "`one for each` repete sobre uma coleção.";
             hint = "Declare o campo com cardinalidade — `$(string(r.foreach)) : " *
                    "$(rp.typename)[]` — ou remova a regra.",
             path = string(r.foreach))
        return nothing
    end

    b = ctx.tmpl.text.blocks[pos]
    if b.subject === nothing
        err!(ctx, "K2046", b.span,
             "o bloco `$(b.name)` se repete sobre `$(string(r.foreach))`, e o cabeçalho " *
             "dele não declara o sujeito.";
             hint = "Escreva `$(repeat(b.unit, b.repeat)) $(b.name) <- " *
                    "$(string(r.foreach))`: o plano do texto precisa ser legível sozinho.")
    elseif b.subject.segments != r.foreach.segments
        err!(ctx, "K2046", b.span,
             "o bloco `$(b.name)` declara o sujeito `$(string(b.subject))` e a regra o " *
             "repete sobre `$(string(r.foreach))`.";
             hint = "Os dois caminhos têm de ser o mesmo.")
    end
    return nothing
end

"""
Resolve os caminhos do plano das regras. Regra não tem sujeito: ela nomeia o bloco de
fora, e seus caminhos são do contrato.

A **semântica** — tipagem dos operadores, atributos, veracidade implícita, `one for
each` sobre lista — é a F2.5. Aqui só se resolve o que os caminhos apontam.
"""
function analyze_rule_paths!(ctx::AnalysisCtx)
    ctx.subject = nothing
    ctx.subject_path = nothing
    ctx.guaranteed = Vector{Symbol}[]

    for r in ctx.tmpl.rules.rules
        pos = blockpos(ctx, r.block)

        # `one for each` sempre vê a coleção: é ela que ele repete.
        ctx.iterating = nothing
        r.foreach === nothing || pos === nothing || check_foreach!(ctx, r, pos)

        # O `when` de um bloco repetido é avaliado POR ITERAÇÃO, e o caminho denota o
        # elemento corrente (§8.3): `grantor when seller is not minor` lê-se "um bloco
        # por vendedor, exceto os menores".
        ctx.iterating = nothing
        if pos !== nothing && !isempty(ctx.out.block_foreach) && ctx.out.block_foreach[pos] != 0
            ctx.iterating = ctx.tmpl.rules.rules[ctx.out.block_foreach[pos]].foreach
        end
        r.when === nothing || require_boolean!(ctx, r.when, check_expr!(ctx, r.when))
    end
    ctx.iterating = nothing
end

"""
    analyze(env, tmpl) -> Analysis

Resolve o modelo contra o ambiente. Não muta o `Template` e não lança: devolve a
`Analysis` com os diagnósticos acumulados. Quem lança é [`load_template`](@ref).
"""
function analyze(env::Environment, tmpl::Template)
    ctx = AnalysisCtx(env, tmpl)
    analyze_data!(ctx)
    index_blocks!(ctx)
    bind_rules!(ctx)          # antes do texto: as remissões consultam as tabelas
    analyze_text!(ctx)
    analyze_rule_paths!(ctx)
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
