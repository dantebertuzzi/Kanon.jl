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

"Misconfigured environment: two domains claim the same name, or a layer registered something invalid."
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

"""
Apelido de idioma para o nome de um atributo ou de um formatador: `preciso` para
`precise`, `maiusculo` para `upper`.

Não é palavra-chave — o nome canônico continua valendo ao lado dele — e não é nome de
tipo: não aponta para um registro, porque atributo e formatador são métodos do tipo, e
só a análise, que conhece o tipo, sabe se o nome canônico existe ali (D-076).
"""
struct NameAlias
    alias::Symbol
    canonical::Symbol
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

Construction state of an [`Environment`](@ref). It is mutable; the `Environment` is not.
Only the builder has `register_*!`, and it exists only while the environment is being
built, so an environment already in use cannot be mutated.

`domain` is the layer currently being applied. The constructor keeps it up to date so
that a conflict message can name both culprits without the layer having to identify
itself.
"""
mutable struct EnvironmentBuilder
    locale::Union{Nothing,Symbol}
    domain::Symbol
    types::Vector{TypeEntry}
    typealiases::Vector{TypeAlias}
    attributealiases::Vector{NameAlias}
    formatteraliases::Vector{NameAlias}
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
    terms::Vector{Pair{Symbol,String}}
end

EnvironmentBuilder(locale::Union{Nothing,Symbol} = nothing) =
    EnvironmentBuilder(locale, :kanon, TypeEntry[], TypeAlias[], NameAlias[], NameAlias[],
                       KeywordAlias[],
                       BlockStyle[], String[], nothing, :none, nothing, :none,
                       nothing, :none, ".", "", "yyyy-mm-dd", Pair{Symbol,String}[],
                       Pair{Symbol,String}[])

"""
    register_type!(b, T::Type; aliases = (,))

Gives the Julia type `T` a name in the language. The canonical name comes from
`kanon_typename(T)`; `aliases` gives per-language names (`aliases = (pt = :dinheiro,)`),
and only the one for the active language enters the environment.

What the type **does** (format, validate, decode, compare) does not go through here: it
is methods of the generic functions in `types.jl`, defined in the layer's module (D-019).
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

Gives an **already registered** type a name in the active language. This is how
`dinheiro` becomes an alias of `money`: the core registers its own types and, being
neutral, has no aliases to give, and `register_type!` only accepts aliases from whoever
registers the type (D-025).
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
    register_attribute_alias!(b, lang, alias, canonical)

Gives the attribute `canonical` a name in language `lang`: `quando pontos é preciso` in a
`pt` template asks the same as `when pontos is precise`. Applied only when `lang` is the
active language.

It is **additive**: the canonical name keeps working, and no template changes meaning. An
attribute is not a keyword, so D-003 does not apply, just as a type name coexists with
its alias.

The **language layer** registers it, not the layer that defines the attribute: `preciso`
is a Portuguese word, and `KanonScience` has no language (the glossary form of D-056). A
canonical name may have more than one alias, and does when the adjective agrees in gender
with the field (`a estimativa é precisa`, `o ponto é preciso`). The **first** one
registered is the one the engine writes back in messages.

The alias **cannot** be a keyword of the language: `verdadeiro` is already `true`, and
the parser would read it as a keyword before the environment is consulted (D-076).
"""
function register_attribute_alias!(b::EnvironmentBuilder, lang::Symbol, alias::Symbol,
                                   canonical::Symbol)
    lang === b.locale || return b
    register_name_alias!(b, b.attributealiases, "atributo", alias, canonical)
end

"""
    register_formatter_alias!(b, lang, alias, canonical)

Gives the formatter `canonical` a name in language `lang`: `{nome:maiusculo}` in a `pt`
template is `{nome:upper}`. Applied only when `lang` is the active language, additive, and
registered by the language layer: the same rules as
[`register_attribute_alias!`](@ref).

Not to be confused with a formatter **of a language**, such as `extenso`: that is
behaviour, exists through dispatch and is declared by `kanon_format_locale` (D-026). An
alias is only a name, and formats nothing the canonical formatter does not (D-076).
"""
function register_formatter_alias!(b::EnvironmentBuilder, lang::Symbol, alias::Symbol,
                                   canonical::Symbol)
    lang === b.locale || return b
    register_name_alias!(b, b.formatteraliases, "formatador", alias, canonical)
end

function register_name_alias!(b::EnvironmentBuilder, into::Vector{NameAlias},
                              what::AbstractString, alias::Symbol, canonical::Symbol)
    alias === canonical &&
        enverr("`$(b.domain)` dá ao $what `$canonical` um apelido igual ao próprio nome.")
    prev = findfirst(e -> e.alias === alias, into)
    if prev !== nothing
        old = into[prev]
        old.canonical === canonical && return b
        enverr("o apelido de $what `$alias` é registrado por `$(old.domain)` (para " *
               "`$(old.canonical)`) e por `$(b.domain)` (para `$canonical`).")
    end
    push!(into, NameAlias(alias, canonical, b.domain))
    return b
end

"""
    register_list_joiner!(b, lang, f)

How the language joins the elements of a list. `f` receives the **already formatted
parts** and returns the whole text: `["a","b","c"]` ⟶ `"a, b e c"`.

The core joins with `", "`, its only typographic convention, stated as such in §3.3 and
explicitly replaceable. The replacement is a **hook in the environment**, not a method on
`AbstractVector`: a method would be global and additive, so loading the layer would change
the output of the bare core and break the neutrality that F6 checks (D-025).
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

The written forms of the keywords in language `lang`. Accepts a `NamedTuple`
(`(data = "dados", when = "quando")`) or any iterable of pairs
(`[:data => "dados", Symbol("for") => "para"]`); the second form exists because `for`,
`and` and other keywords of the language are reserved in Julia and cannot be
`NamedTuple` keys.

Applied only when `lang` is the active language.

The corresponding English form **stops** being a keyword: a file that declares `pt`
writes `dados`, not `data`. Mixing them is an error (D-003).
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

A domain's block style. `unit` is the marker unit; two domains registering the same unit
is an error here.
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

The language's inflection marks and the function that applies them. `apply` receives
`(word, mark, subject, ctx)` and returns the **whole word** already inflected, which is
what allows `portador(a)` → `portadoras` without the core knowing how to pluralise
(D-013).
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

Seam repair hook, called after elision with `(text, seams, ctx)`. Repair is local to the
seam, never global (D-014).
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

A currency's symbol. `money:symbol` uses what is declared here; the core embeds no
national convention (§3.3).
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
    register_term!(b, lang, key, word)

Uma palavra que a **camada de idioma** empresta a quem não tem idioma nenhum.

Existe pelo lugar em que o `KanonScience` se encontrou: o estilo `@` numera `Theorem 1`,
e num roteiro de aula em português o rótulo tinha de ser `Teorema 1`. As três saídas
óbvias quebram uma declaração cada — pôr português dentro de uma camada que se anuncia
sem idioma, pôr um estilo de domínio dentro do `Extenso`, que não conhece domínio nenhum,
ou pôr qualquer das duas coisas no núcleo, que não tem nem uma nem outra (invariante 3).

O glossário é a quarta: o **domínio** declara a chave e a palavra inglesa de que se
contenta; o **idioma** registra a tradução, que para ele é só uma palavra da própria
língua; e o núcleo transporta o par sem entender nenhum dos dois lados. É a forma da
D-041 — a camada obtém do contexto o que é do idioma — aplicada ao rótulo em vez de ao
separador.

Uma chave sem tradução no idioma ativo não é erro: quem consulta passa o padrão, e o
domínio continua escrevendo em inglês onde ninguém traduziu (D-056).
"""
function register_term!(b::EnvironmentBuilder, lang::Symbol, key::Symbol,
                        word::AbstractString)
    lang === b.locale || return b
    i = findfirst(p -> first(p) === key, b.terms)
    i === nothing ? push!(b.terms, key => String(word)) : (b.terms[i] = key => String(word))
    return b
end

"""
    register_separators!(b; decimal, group)

The language's decimal and thousands separators. The core prints `0.42` and `1200`; the
language layer is what makes them `0,42` and `1.200` (§3.3).
"""
function register_separators!(b::EnvironmentBuilder; decimal = nothing, group = nothing)
    decimal === nothing || (b.decimal_separator = String(decimal))
    group === nothing || (b.group_separator = String(group))
    return b
end

"Date pattern for `date:numeric`. The factory default is ISO."
function register_date_pattern!(b::EnvironmentBuilder, pattern::AbstractString)
    b.date_pattern = String(pattern)
    return b
end

# --- o ambiente congelado ----------------------------------------------------

"""
    Environment(; locale = nothing, domains = [])

The frozen vocabulary of one configuration of layers. Immutable: there is no
`register_*!` on an `Environment`.

Built in a deterministic, visible order: core, language layer, then each domain in the
order of the vector. A name conflict is an error **here**, with both domains in the
message.

`Environment()` with no arguments is the bare core, the environment of the neutrality
test.
"""
struct Environment
    locale::Union{Nothing,Symbol}
    domains::Vector{Symbol}
    types::Vector{TypeEntry}
    typealiases::Vector{TypeAlias}
    attributealiases::Vector{NameAlias}    # na ordem de registro: o primeiro é o escrito
    formatteraliases::Vector{NameAlias}
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
    terms::Vector{Pair{Symbol,String}}
end

"""
    configure!(b::EnvironmentBuilder)

The core's registration: its types and factory defaults. Defined in `core_types.jl`.
"""
function configure! end

"""
    configure_locale!(b, ::Val{lang})

Extension point for a language layer. `Extenso.jl` defines
`Kanon.configure_locale!(b, ::Val{:pt})`; loading the module is enough for the language
to exist.
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
        registro = isdefined(m, :configure!) ? getfield(m, :configure!) : nothing
        # O `configure!` do próprio módulo, e não o do núcleo que ele importou com `using
        # Kanon`: uma camada de idioma não tem vocabulário de domínio, e chamar o do núcleo
        # registrava os seis tipos de novo, com um conflito que acusava a camada (D-068).
        registro === nothing || registro === configure! || registro(b)
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

    keywords = build_keywords(b)
    for a in b.attributealiases
        k = keyword(keywords, String(a.alias))
        k === nothing ||
            enverr("o apelido de atributo `$(a.alias)` (para `$(a.canonical)`, por " *
                   "`$(a.domain)`) é a palavra-chave `$k` deste idioma, e uma regra que o " *
                   "escrevesse o leria como palavra-chave.")
    end

    Environment(b.locale, domains, types, aliases,
                copy(b.attributealiases), copy(b.formatteraliases),
                keywords, sort(b.styles; by = s -> s.name), copy(b.marks),
                b.inflect, b.repair, b.joiner, b.decimal_separator, b.group_separator,
                b.date_pattern, sort(b.currency; by = first),
                sort(b.terms; by = first))
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

"The Julia type registered under `name`, resolving language aliases. `nothing` if there is none."
function typefor(env::Environment, name::Symbol)
    i = findfirst(e -> e.name === name, env.types)
    i === nothing || return env.types[i].juliatype
    j = findfirst(a -> a.alias === name, env.typealiases)
    j === nothing && return nothing
    k = findfirst(e -> e.name === env.typealiases[j].canonical, env.types)
    k === nothing ? nothing : env.types[k].juliatype
end

"""
    canonical_typename(env, name) -> Symbol

O nome canônico de um tipo, resolvendo apelido de idioma: `booleano` ⟶ `boolean`. Um
nome que o ambiente não conhece volta como veio.

Existe porque **o nome que o modelo escreve não é o nome que o núcleo compara**. Um
`FieldDecl` e um `ResolvedPath` guardam o nome tal como o autor o digitou — é o que a
mensagem de erro tem de dizer de volta a ele —, e comparar esse nome com `:boolean`
faz o mesmo modelo valer em inglês e não valer em português. Onde a lógica decide algo
pelo tipo, ela decide pelo canônico; onde ela fala com o autor, fala pelo escrito.
"""
function canonical_typename(env::Environment, name::Symbol)
    findfirst(e -> e.name === name, env.types) === nothing || return name
    j = findfirst(a -> a.alias === name, env.typealiases)
    j === nothing ? name : env.typealiases[j].canonical
end

"""
    written_typename(env, canonical) -> Symbol

O inverso de [`canonical_typename`](@ref): o nome que **este** ambiente escreve para um
tipo canônico. `:text` num ambiente `pt` é `:texto`.

Serve às mensagens que precisam sugerir um tipo que o autor não escreveu. Sugerir
`text[]` a quem escreve em português seria a D-027 ao contrário — o motor falando a
língua dele com quem escolheu outra.
"""
function written_typename(env::Environment, canonical::Symbol)
    i = findfirst(a -> a.canonical === canonical, env.typealiases)
    i === nothing ? canonical : env.typealiases[i].alias
end

"""
Every type name that can be **declared** in this environment, sorted, for error messages
and editor completion. Collection behaviour and its aliases are left out: it exists, but
is written through cardinality (D-071).
"""
typenames(env::Environment) =
    sort!(vcat([e.name for e in env.types if e.name !== COLLECTION_TYPENAME],
               [a.alias for a in env.typealiases if a.canonical !== COLLECTION_TYPENAME]))

"""
    resolve_name(aliases, available, written) -> Union{Nothing,Symbol}

O nome canônico que `written` denota entre os nomes `available` de um tipo: ele mesmo, se o
tipo o tem; o canônico de um apelido, se o tipo tem esse canônico; `nothing`, se nenhum.

A resolução é **por tipo**, e o nome canônico ganha do apelido. É o que deixa uma camada
nacional ter um atributo chamado, por acaso, como o apelido de outro: `rural` do
`KanonLegal` é `rural` onde o tipo o tem, e o ambiente nunca precisa saber (D-076).
"""
function resolve_name(aliases::Vector{NameAlias}, available, written::Symbol)
    written in available && return written
    for a in aliases
        a.alias === written && a.canonical in available && return a.canonical
    end
    return nothing
end

"O atributo canônico que `written` denota em `T`, ou `nothing` (D-076)."
attribute_name(env::Environment, T::Type, written::Symbol) =
    resolve_name(env.attributealiases, kanon_attributes(T), written)

"O formatador canônico, visível neste ambiente, que `written` denota em `T` (D-076)."
formatter_name(env::Environment, T::Type, written::Symbol) =
    resolve_name(env.formatteraliases, kanon_formats(T, env), written)

"""
    written_name(aliases, canonical) -> Symbol

O nome que o ambiente escreve para um canônico: o primeiro apelido registrado, ou o
próprio canônico. É o `written_typename` dos atributos e dos formatadores — a mensagem que
lista o que existe cita a língua do modelo (D-051).
"""
function written_name(aliases::Vector{NameAlias}, canonical::Symbol)
    i = findfirst(a -> a.canonical === canonical, aliases)
    i === nothing ? canonical : aliases[i].alias
end

"""
Atributos como este ambiente os escreve, ordenados (I4). Os quatro que são palavras-chave —
`present`, `absent`, `true` e `false` — saem pela tabela do idioma; os demais, pelo apelido.
"""
written_attributes(env::Environment, names) =
    sort!([n in KEYWORD_ATTRIBUTES ? Symbol(written(env.keywords, n)) :
                                     written_name(env.attributealiases, n) for n in names])

const KEYWORD_ATTRIBUTES = (:absent, :present, Symbol("true"), Symbol("false"))

"Os formatadores de `T` visíveis neste ambiente, como ele os escreve, ordenados (I4)."
written_formatters(env::Environment, T::Type) =
    sort!([written_name(env.formatteraliases, f) for f in kanon_formats(T, env)])

"Block style for the marker unit, or `nothing`."
function stylefor(env::Environment, unit::Char)
    i = findfirst(s -> s.unit == unit, env.styles)
    i === nothing ? nothing : env.styles[i]
end

"Is the inflection mark registered? If not, `analyze` treats the candidate as prose."
hasmark(env::Environment, mark::AbstractString) = String(mark) in env.marks

"""
    kanon_formats(T, env) -> Tuple{Vararg{Symbol}}

The formatters of `T` **visible in this environment**: the language-independent ones plus
those of the active language. This is the list validation uses and error messages show.

`kanon_formats(T)` on its own still lists everything that exists in the process; that is
the protocol, and it knows no environment. The filtering happens here (D-026).
"""
kanon_formats(::Type{T}, env::Environment) where {T} =
    Tuple(f for f in kanon_formats(T) if format_visible(T, f, env))

"O formatador vale neste ambiente? Vale se não tem idioma, ou se é o idioma ativo."
function format_visible(T::Type, name::Symbol, env::Environment)
    l = kanon_format_locale(T, Val(name))
    l === nothing || l === env.locale
end

"O idioma em que um formatador existe, para a mensagem de quem o pediu sem a camada."
format_locale_of(T::Type, name::Symbol) = kanon_format_locale(T, Val(name))

"Currency symbol, or the code itself when the environment declares no symbol (§3.3)."
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

What a formatter may consult. Deliberately small: the environment and `today`.

`today` is **injected**, never read from the clock, which makes determinism something
that can be checked (§2.2). A template that uses `today`, rendered without it, is a
contract error.
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

"""
    term(ctx, key, default) -> String

A palavra que o idioma ativo dá a `key`, ou `default` quando ele não dá nenhuma.

É o lado da leitura de [`register_term!`](@ref), e o `default` é obrigatório de
propósito: quem pergunta tem de saber escrever a própria resposta, e um domínio que
dependesse da existência da tradução deixaria de funcionar em ambiente neutro — que é
onde o teste de neutralidade o observa.
"""
function term(env::Environment, key::Symbol, default::AbstractString)
    i = findfirst(p -> first(p) === key, env.terms)
    i === nothing ? String(default) : last(env.terms[i])
end

term(ctx::FormatContext, key::Symbol, default::AbstractString) =
    term(ctx.env, key, default)
