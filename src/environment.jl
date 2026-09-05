# O ambiente: vocabulário local a uma configuração de camadas.
#
# A divisão que governa este arquivo (`docs/api-extensao.md` §5):
#
#   COMPORTAMENTO é método de função genérica — global, aditivo, definido pelo módulo
#   da camada, sem passar por aqui. Formatar, validar, decodificar, comparar.
#
#   NOME é registro no ambiente — local, ordenado, e conflitante entre domínios. Nome
#   de tipo, apelido de idioma, marcador de bloco, marca de flexão.
#
# O conflito de nome é detectado na CONSTRUÇÃO, com os dois domínios na mensagem, e não
# no render. Dois ambientes com domínios diferentes coexistem no mesmo processo porque
# o que é global é aditivo e o que é conflitante é local.

"Modelo mal configurado: dois domínios disputam um nome, ou uma camada registrou algo inválido."
struct KanonEnvironmentError <: KanonError
    message::String
end

Base.showerror(io::IO, e::KanonEnvironmentError) =
    print(io, "ambiente mal configurado: ", e.message)

enverr(msg::AbstractString) = throw(KanonEnvironmentError(String(msg)))

# --- entradas ----------------------------------------------------------------

"Vínculo entre um nome da linguagem e o tipo Julia que o implementa."
struct TypeEntry
    name::Symbol
    juliatype::Type
    domain::Symbol
end

"Apelido de idioma para um nome de tipo. Nome de tipo não é palavra-chave (§2.2)."
struct TypeAlias
    alias::Symbol
    canonical::Symbol
    domain::Symbol
end

"""
    BlockStyle

`unit` é a **unidade** do marcador, não a forma do nível 1: registrar `"§§"` tornaria
impossível derivar `§§§`. `layout` e `separator` dizem onde o rótulo entra no texto.

`number` e `ref` recebem o vetor de contadores (`[3]`, `[3,1]`), o que deixa a camada
renderizar `3.1` ou `Parágrafo Primeiro da Cláusula Terceira` sem mudança no núcleo.
"""
struct BlockStyle
    name::Symbol
    unit::Char
    layout::Symbol            # :prefix | :heading
    separator::String
    number::Function          # (path, ctx) -> AbstractString
    ref::Function             # (path, ctx) -> AbstractString
    domain::Symbol
end

"Uma forma escrita que substitui a palavra-chave canônica no idioma ativo."
struct KeywordAlias
    form::String
    canonical::Symbol
    domain::Symbol
end

# --- o construtor mutável ----------------------------------------------------

"""
    EnvironmentBuilder

Estado de construção de um [`Environment`](@ref). É mutável; o `Environment` não é. Só
o builder tem `register_*!`, e ele existe apenas durante a construção — não há como
mutar um ambiente já em uso.

`domain` é a camada que está sendo aplicada agora. O construtor o mantém atualizado
para que a mensagem de conflito possa nomear os dois culpados sem que a camada precise
se identificar.
"""
mutable struct EnvironmentBuilder
    locale::Union{Nothing,Symbol}
    domain::Symbol
    types::Vector{TypeEntry}
    typealiases::Vector{TypeAlias}
    keywords::Vector{KeywordAlias}
    styles::Vector{BlockStyle}
    marks::Vector{String}
    inflect::Union{Nothing,Function}
    inflect_domain::Symbol
    repair::Union{Nothing,Function}
    repair_domain::Symbol
    joiner::Union{Nothing,Function}
    joiner_domain::Symbol
    decimal_separator::String
    group_separator::String
    date_pattern::String
    currency::Vector{Pair{Symbol,String}}
end

EnvironmentBuilder(locale::Union{Nothing,Symbol} = nothing) =
    EnvironmentBuilder(locale, :kanon, TypeEntry[], TypeAlias[], KeywordAlias[],
                       BlockStyle[], String[], nothing, :none, nothing, :none,
                       nothing, :none, ".", "", "yyyy-mm-dd", Pair{Symbol,String}[])

"""
    register_type!(b, T::Type; aliases = (,))

Dá ao tipo Julia `T` um nome na linguagem. O nome canônico vem de `kanon_typename(T)`;
`aliases` dá apelidos por idioma (`aliases = (pt = :dinheiro,)`), e só o do idioma
ativo entra no ambiente.

O que o tipo **faz** — formatar, validar, decodificar, comparar — não passa por aqui:
são métodos das funções genéricas de `types.jl`, definidos no módulo da camada (D-019).
"""
function register_type!(b::EnvironmentBuilder, T::Type; aliases = NamedTuple())
    name = kanon_typename(T)

    prev = findfirst(e -> e.name === name, b.types)
    if prev !== nothing
        old = b.types[prev]
        old.juliatype === T && old.domain === b.domain && return b
        enverr("o tipo `$name` é registrado por `$(old.domain)` (como `$(old.juliatype)`) " *
               "e por `$(b.domain)` (como `$T`).")
    end
    push!(b.types, TypeEntry(name, T, b.domain))

    for (lang, alias) in pairs(aliases)
        lang === b.locale || continue
        a = Symbol(alias)
        prev = findfirst(e -> e.alias === a, b.typealiases)
        if prev !== nothing
            old = b.typealiases[prev]
            enverr("o apelido de tipo `$a` é registrado por `$(old.domain)` (para " *
                   "`$(old.canonical)`) e por `$(b.domain)` (para `$name`).")
        end
        push!(b.typealiases, TypeAlias(a, name, b.domain))
    end
    return b
end

"""
    register_type_alias!(b, alias, canonical)

Dá a um tipo **já registrado** um nome no idioma ativo. É como `dinheiro` vira apelido
de `money`: os seis tipos do núcleo são registrados pelo próprio núcleo, que é neutro e
não tem apelido nenhum a dar, e `register_type!` só aceita apelidos de quem registra o
tipo (D-025).
"""
function register_type_alias!(b::EnvironmentBuilder, alias::Symbol, canonical::Symbol)
    prev = findfirst(e -> e.alias === alias, b.typealiases)
    if prev !== nothing
        old = b.typealiases[prev]
        old.canonical === canonical && return b
        enverr("o apelido de tipo `$alias` é registrado por `$(old.domain)` (para " *
               "`$(old.canonical)`) e por `$(b.domain)` (para `$canonical`).")
    end
    push!(b.typealiases, TypeAlias(alias, canonical, b.domain))
    return b
end

"""
    register_list_joiner!(b, lang, f)

Como o idioma junta os elementos de uma lista. `f` recebe as **partes já formatadas** e
devolve o texto inteiro: `["a","b","c"]` ⟶ `"a, b e c"`.

O núcleo junta por `", "` — a única convenção tipográfica dele, declarada como tal na
§3.3 e explicitamente substituível. A substituição é **gancho no ambiente**, e não um
método sobre `AbstractVector`: um método seria global e aditivo, e carregar a camada
mudaria a saída do núcleo puro, quebrando a neutralidade que a F6 verifica (D-025).
"""
function register_list_joiner!(b::EnvironmentBuilder, lang::Symbol, f::Function)
    lang === b.locale || return b
    b.joiner === nothing ||
        enverr("`$(b.joiner_domain)` e `$(b.domain)` registram junção de lista para `$lang`.")
    b.joiner = f
    b.joiner_domain = b.domain
    return b
end

"""
    register_aliases!(b, lang, forms)

Formas escritas das palavras-chave no idioma `lang`. Aceita um `NamedTuple`
(`(data = "dados", when = "quando")`) ou qualquer iterável de pares
(`[:data => "dados", Symbol("for") => "para"]`) — a segunda forma existe porque
`for`, `and` e outras palavras-chave da linguagem são reservadas em Julia e não cabem
num `NamedTuple`.

Aplicado só quando `lang` é o idioma ativo.

A forma inglesa correspondente **deixa** de ser palavra-chave: um arquivo que declara
`pt` escreve `dados`, não `data`. Misturar é erro (D-003).
"""
function register_aliases!(b::EnvironmentBuilder, lang::Symbol, forms)
    lang === b.locale || return b
    for (canon, form) in (forms isa NamedTuple ? pairs(forms) : forms)
        canon in CANONICAL_KEYWORD_SYMBOLS ||
            enverr("`$(b.domain)` dá um apelido a `$canon`, que não é palavra-chave da " *
                   "linguagem. As palavras-chave são: $(join(CANONICAL_KEYWORDS, ", ")).")
        s = String(form)
        prev = findfirst(e -> e.form == s, b.keywords)
        if prev !== nothing
            old = b.keywords[prev]
            old.canonical === canon && continue
            enverr("a forma `$s` é apelido de `$(old.canonical)` por `$(old.domain)` e " *
                   "de `$canon` por `$(b.domain)`.")
        end
        push!(b.keywords, KeywordAlias(s, canon, b.domain))
    end
    return b
end

"""
    register_block_style!(b, name; unit, layout, separator, number, ref)

Estilo de bloco de um domínio. `unit` é a unidade do marcador; dois domínios que
registrem a mesma unidade é erro aqui.
"""
function register_block_style!(b::EnvironmentBuilder, name::Symbol; unit::Char,
                               layout::Symbol = :prefix, separator::AbstractString = " ",
                               number::Function, ref::Function)
    is_marker_unit(unit) ||
        enverr("`$unit` não é uma unidade de marcador de bloco. As unidades da versão 1 " *
               "são: $(join(sort(collect(MARKER_UNITS)), ' ')).")
    layout in (:prefix, :heading) ||
        enverr("o estilo `$name` pede o arranjo `$layout`; os arranjos são `:prefix` e `:heading`.")

    prev = findfirst(s -> s.unit == unit, b.styles)
    if prev !== nothing
        old = b.styles[prev]
        enverr("o marcador `$unit` é registrado por `$(old.domain)` (estilo `$(old.name)`) " *
               "e por `$(b.domain)` (estilo `$name`).")
    end
    prev = findfirst(s -> s.name === name, b.styles)
    prev === nothing ||
        enverr("o estilo de bloco `$name` é registrado por `$(b.styles[prev].domain)` e por `$(b.domain)`.")

    push!(b.styles, BlockStyle(name, unit, layout, String(separator), number, ref, b.domain))
    return b
end

"""
    register_inflection!(b, lang; marks, apply)

Marcas de flexão do idioma e a função que as aplica. `apply` recebe
`(palavra, marca, sujeito, ctx)` e devolve a **palavra inteira** já flexionada — é o que
permite `portador(a)` → `portadoras` sem que o núcleo saiba pluralizar (D-013).
"""
function register_inflection!(b::EnvironmentBuilder, lang::Symbol; marks, apply::Function)
    lang === b.locale || return b
    b.inflect === nothing ||
        enverr("`$(b.inflect_domain)` e `$(b.domain)` registram flexão para `$lang`; " *
               "só uma camada de idioma pode fazê-lo.")
    for m in marks
        s = String(m)
        isempty(s) && enverr("`$(b.domain)` registra uma marca de flexão vazia.")
        s in b.marks || push!(b.marks, s)
    end
    sort!(b.marks)
    b.inflect = apply
    b.inflect_domain = b.domain
    return b
end

"""
    register_repair_hook!(b, lang, hook)

Gancho de reparo de emenda, chamado depois da elisão com `(texto, emendas, ctx)`. O
reparo é local à emenda, nunca global (D-014).
"""
function register_repair_hook!(b::EnvironmentBuilder, lang::Symbol, hook::Function)
    lang === b.locale || return b
    b.repair === nothing ||
        enverr("`$(b.repair_domain)` e `$(b.domain)` registram gancho de reparo para `$lang`.")
    b.repair = hook
    b.repair_domain = b.domain
    return b
end

"""
    register_currency!(b, code, symbol)

Símbolo de uma moeda. `money:symbol` usa o que está declarado aqui — o núcleo não
embute nenhuma convenção nacional (§3.3).
"""
function register_currency!(b::EnvironmentBuilder, code::Symbol, symbol::AbstractString)
    prev = findfirst(p -> first(p) === code, b.currency)
    if prev !== nothing && last(b.currency[prev]) != String(symbol)
        enverr("a moeda `$code` tem o símbolo `$(last(b.currency[prev]))` e `$(b.domain)` " *
               "quer `$symbol`.")
    end
    prev === nothing && push!(b.currency, code => String(symbol))
    return b
end

"""
    register_separators!(b; decimal, group)

Separador decimal e de milhar do idioma. O núcleo emite `0.42` e `1200`; a camada de
idioma é quem faz `0,42` e `1.200` (§3.3).
"""
function register_separators!(b::EnvironmentBuilder; decimal = nothing, group = nothing)
    decimal === nothing || (b.decimal_separator = String(decimal))
    group === nothing || (b.group_separator = String(group))
    return b
end

"Padrão de data de `date:numeric`. Valor de fábrica ISO."
function register_date_pattern!(b::EnvironmentBuilder, pattern::AbstractString)
    b.date_pattern = String(pattern)
    return b
end

# --- o ambiente congelado ----------------------------------------------------

"""
    Environment(; locale = nothing, domains = [])

O vocabulário congelado de uma configuração de camadas. Imutável: não há `register_*!`
sobre um `Environment`.

Construção, em ordem determinística e visível: núcleo, camada de idioma, cada domínio
na ordem do vetor. Conflito de nome é erro **aqui**, com os dois domínios na mensagem.

`Environment()` sem argumentos é o núcleo puro — o ambiente do teste de neutralidade.
"""
struct Environment
    locale::Union{Nothing,Symbol}
    domains::Vector{Symbol}
    types::Vector{TypeEntry}
    typealiases::Vector{TypeAlias}
    keywords::KeywordTable
    styles::Vector{BlockStyle}
    marks::Vector{String}
    inflect::Union{Nothing,Function}
    repair::Union{Nothing,Function}
    joiner::Union{Nothing,Function}
    decimal_separator::String
    group_separator::String
    date_pattern::String
    currency::Vector{Pair{Symbol,String}}
end

"""
    configure!(b::EnvironmentBuilder)

Registro do núcleo: os seis tipos e os valores de fábrica. Definido em `core_types.jl`.
"""
function configure! end

"""
    configure_locale!(b, ::Val{lang})

Ponto de extensão da camada de idioma. `Extenso.jl` define
`Kanon.configure_locale!(b, ::Val{:pt})`; carregar o módulo basta para o idioma existir.
"""
configure_locale!(b::EnvironmentBuilder, ::Val{L}) where {L} =
    enverr("o idioma `$L` não tem camada carregada. Carregue o pacote que define " *
           "`Kanon.configure_locale!(b, ::Val{:$L})`, ou construa o ambiente sem `locale`.")

function Environment(; locale::Union{Nothing,Symbol} = nothing, domains = Module[])
    b = EnvironmentBuilder(locale)

    b.domain = :kanon
    configure!(b)

    if locale !== nothing
        b.domain = locale
        configure_locale!(b, Val(locale))
    end

    names = Symbol[]
    for m in domains
        m isa Module || enverr("`$m` não é um módulo; um domínio é um módulo Julia (§5).")
        d = nameof(m)
        d in names && enverr("o domínio `$d` aparece duas vezes na lista.")
        push!(names, d)
        b.domain = d
        isdefined(m, :configure!) && getfield(m, :configure!)(b)
    end

    return freeze(b, names)
end

"""
Congela o builder. A ordenação não é estética: é o que torna determinística toda lista
que chega a uma mensagem de erro (I4).
"""
function freeze(b::EnvironmentBuilder, domains::Vector{Symbol})
    types = sort(b.types; by = e -> e.name)
    aliases = sort(b.typealiases; by = e -> e.alias)

    for a in aliases
        findfirst(e -> e.name === a.canonical, types) === nothing &&
            enverr("o apelido `$(a.alias)` aponta para o tipo `$(a.canonical)`, que não " *
                   "está registrado.")
        findfirst(e -> e.name === a.alias, types) === nothing ||
            enverr("`$(a.alias)` é ao mesmo tempo nome de tipo e apelido de `$(a.canonical)`.")
    end

    Environment(b.locale, domains, types, aliases,
                build_keywords(b), sort(b.styles; by = s -> s.name), copy(b.marks),
                b.inflect, b.repair, b.joiner, b.decimal_separator, b.group_separator,
                b.date_pattern, sort(b.currency; by = first))
end

"""
Monta a tabela de palavras-chave do idioma ativo. A forma inglesa de uma palavra
apelidada é **removida**: o arquivo declara um idioma e escreve nele, sem mistura
(D-003).
"""
function build_keywords(b::EnvironmentBuilder)
    b.locale === nothing && return canonical_keywords()
    forms = Dict{String,Symbol}()
    translated = Set{Symbol}(a.canonical for a in b.keywords)
    for w in CANONICAL_KEYWORDS
        Symbol(w) in translated || (forms[w] = Symbol(w))
    end
    for a in b.keywords
        forms[a.form] = a.canonical
    end
    KeywordTable(b.locale, forms)
end

# --- consulta ----------------------------------------------------------------

"O tipo Julia registrado sob `name`, resolvendo apelido de idioma. `nothing` se não há."
function typefor(env::Environment, name::Symbol)
    i = findfirst(e -> e.name === name, env.types)
    i === nothing || return env.types[i].juliatype
    j = findfirst(a -> a.alias === name, env.typealiases)
    j === nothing && return nothing
    k = findfirst(e -> e.name === env.typealiases[j].canonical, env.types)
    k === nothing ? nothing : env.types[k].juliatype
end

"Todo nome de tipo escrevível neste ambiente, ordenado — para a mensagem de erro."
typenames(env::Environment) =
    sort!(vcat([e.name for e in env.types], [a.alias for a in env.typealiases]))

"Estilo de bloco da unidade de marcador, ou `nothing`."
function stylefor(env::Environment, unit::Char)
    i = findfirst(s -> s.unit == unit, env.styles)
    i === nothing ? nothing : env.styles[i]
end

"A marca de flexão está registrada? Se não, `analyze` trata o candidato como prosa."
hasmark(env::Environment, mark::AbstractString) = String(mark) in env.marks

"Símbolo da moeda, ou o próprio código quando o ambiente não declara símbolo (§3.3)."
function currency_symbol(env::Environment, code::Symbol)
    i = findfirst(p -> first(p) === code, env.currency)
    i === nothing ? String(code) : last(env.currency[i])
end

function Base.show(io::IO, env::Environment)
    print(io, "Environment(", env.locale === nothing ? "neutro" : env.locale)
    isempty(env.domains) || print(io, ", ", join(env.domains, " + "))
    print(io, ", ", length(env.types), " tipos)")
end

# --- contexto de formatação --------------------------------------------------

"""
    FormatContext

O que um formatador pode consultar. Deliberadamente pequeno: ambiente e `today`.

`today` é **injetado**, nunca lido do relógio — é o que torna o determinismo
verificável em vez de aspiracional (§2.2). Um modelo que usa `today` e um `render` que
não o recebeu produz erro de contrato.
"""
struct FormatContext
    env::Environment
    today::Union{Nothing,Date}
end

FormatContext(env::Environment; today::Union{Nothing,Date} = nothing) =
    FormatContext(env, today)

decimal_separator(ctx::FormatContext) = ctx.env.decimal_separator
group_separator(ctx::FormatContext) = ctx.env.group_separator
currency_symbol(ctx::FormatContext, code::Symbol) = currency_symbol(ctx.env, code)
