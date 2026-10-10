# O protocolo de tipo.
#
# Um tipo Kanon é um conjunto de métodos de funções genéricas do núcleo, definidos
# sobre um tipo Julia (`docs/api-extensao.md` §2). Não há tabela de despacho mantida à
# mão, não há registro mutável de formatadores, não há `eval`.
#
# Obrigação 5-A: se este arquivo algum dia ganhar um `Dict` de formatadores, a
# implementação está lutando contra a linguagem. Pare e reveja.

"""
    FieldSpec

A field of a composite type. `optional` is what extends the gap theorem into composites:
if `person.spouse` is optional, `{seller.spouse.name}` is nullable and needs a group
(`docs/especificacao.md` §3.1 and §14).
"""
struct FieldSpec
    name::Symbol
    type::Symbol
    optional::Bool
    card::Cardinality
end

FieldSpec(name::Symbol, type::Symbol; optional::Bool = false,
          card::Cardinality = Cardinality()) = FieldSpec(name, type, optional, card)

# --- falhas do protocolo -----------------------------------------------------
#
# São exceções, não diagnósticos: acontecem fora de um arquivo de modelo, e portanto
# não têm linha nem coluna. `check` (F2.6) e `analyze` (F2.2) as capturam e as
# convertem em diagnóstico quando há uma posição a que atribuí-las.

"""
    KanonProtocolError

A failure of the **type protocol**: the type cannot do what was asked of it.

These are exceptions rather than diagnostics because they happen outside a template file,
so they have no line or column. `analyze` and `check` catch them and turn them into
diagnostics when there is a position to attribute them to.
"""
abstract type KanonProtocolError <: Exception end

"The Julia type does not implement `kanon_typename`, so it is not a Kanon type."
struct UnregisteredType <: KanonProtocolError
    type::Type
end

"The type has no such formatter. The message lists the ones it has."
struct UnknownFormatter <: KanonProtocolError
    type::Type
    name::Symbol
end

"The type has no such attribute. The message lists the ones it has."
struct UnknownAttribute <: KanonProtocolError
    type::Type
    name::Symbol
end

"A value from external input that the type cannot decode (§3.4: there is no implicit coercion)."
struct UndecodableValue <: KanonProtocolError
    type::Type
    raw::Any
    reason::String
end

"""
Valor que o tipo aceitou e que um formatador dele **não consegue escrever**.

É o outro lado do [`UndecodableValue`](@ref), e existe porque os dois erram em momentos
diferentes: um valor que não entra é recusado pelo `check`, com os dados na mão, e nunca
chega ao documento. Este só aparece no render, e vem de duas origens — um valor que a
camada **calcula** (a incerteza relativa de uma medição de valor zero é uma divisão por
zero) e um que o `check` não tinha como recusar sem os formatadores do modelo na mão.

Dizer "não foi possível **ler**" nesse caso seria falso: o valor foi lido, e é escrever
que não dá.
"""
struct UnwritableValue <: KanonProtocolError
    type::Type
    value::Any
    reason::String
end

"The type does not declare how to compare itself with that value (§8.1)."
struct IncomparableValues <: KanonProtocolError
    type::Type
    other::Any
end

Base.showerror(io::IO, e::UnregisteredType) =
    print(io, "o tipo Julia `", e.type, "` não é um tipo Kanon: falta um método ",
              "`kanon_typename(::Type{", e.type, "})`.")

function Base.showerror(io::IO, e::UnknownFormatter)
    print(io, "`", kanon_typename_or_julia(e.type), "` não tem o formatador `", e.name, "`.")
    fs = kanon_formats(e.type)
    isempty(fs) ? print(io, " Esse tipo não tem formatador nomeado.") :
                  print(io, " Disponíveis: ", join(fs, ", "), ".")
end

function Base.showerror(io::IO, e::UnknownAttribute)
    print(io, "`", kanon_typename_or_julia(e.type), "` não tem o atributo `", e.name, "`.")
    as = kanon_attributes(e.type)
    isempty(as) ? print(io, " Esse tipo não tem atributo.") :
                  print(io, " Disponíveis: ", join(as, ", "), ".")
end

Base.showerror(io::IO, e::UndecodableValue) =
    print(io, "não foi possível ler `", repr(e.raw), "` como `",
              kanon_typename_or_julia(e.type), "`: ", e.reason)

Base.showerror(io::IO, e::UnwritableValue) =
    print(io, "não foi possível escrever `", repr(e.value), "` como `",
              kanon_typename_or_julia(e.type), "`: ", e.reason)

Base.showerror(io::IO, e::IncomparableValues) =
    print(io, "`", kanon_typename_or_julia(e.type), "` não se compara com `",
              repr(e.other), "`.")

"Nome Kanon do tipo, ou o nome Julia quando ele não é um tipo Kanon. Só para mensagens."
function kanon_typename_or_julia(T::Type)
    try
        return kanon_typename(T)
    catch e
        e isa UnregisteredType || rethrow()
        return T
    end
end

# --- as oito funções genéricas -----------------------------------------------

"""
    kanon_typename(::Type{T}) -> Symbol

The type's name in the language. Required: it is what makes a Julia type a Kanon type.
"""
kanon_typename(::Type{T}) where {T} = throw(UnregisteredType(T))

"""
    kanon_schema(::Type{T}) -> Tuple{Vararg{FieldSpec}}

The fields of a composite type, in declaration order. `()` for a scalar, the default.
"""
kanon_schema(::Type) = ()

"""
    kanon_validate(v, ctx) -> Nothing | Vector{Diagnostic}

Checks on the value beyond its Julia type. The default checks nothing.
"""
kanon_validate(v, ctx) = nothing

"""
    format(v, ::Val{name}, ctx) -> AbstractString

A formatter. `Val{:default}` is required for every type; the others are optional and
listed by [`kanon_formats`](@ref).
"""
format(v, ::Val{name}, ctx) where {name} = throw(UnknownFormatter(typeof(v), name))

"""
    kanon_formats(::Type{T}) -> Tuple{Vararg{Symbol}}

The named formatters of `T`, sorted, **without** `:default`, which cannot be written in an
interpolation: the default is just `{price}`.

The default implementation inspects the method table of [`format`](@ref) for signatures
`Tuple{typeof(format), T′, Val{S}, Any}` with `T <: T′` and `S::Symbol`. This is what keeps
the promise of `docs/api-extensao.md` §2.1: a formatter added by plain dispatch, through no
facade, exists for template validation and for error messages with no extra
registration.

This inspects the **method table**, not user data: it runs no template code and is
deterministic because the result is sorted.

A layer may override this method to document its formatters, or to cover formatters
defined generically (`format(v::T, ::Val{N}, ctx) where {N}`), which inspection cannot
enumerate.
"""
function kanon_formats(::Type{T}) where {T}
    out = Symbol[]
    for m in methods(format)
        sig = Base.unwrap_unionall(m.sig)
        sig isa DataType || continue
        params = sig.parameters
        length(params) == 4 || continue

        marker = params[3]
        (marker isa DataType && marker <: Val) || continue
        length(marker.parameters) == 1 || continue
        name = marker.parameters[1]
        # Um formatador genérico deixa aqui uma `TypeVar`, não um `Symbol`: não é
        # enumerável, e a camada que o define é quem sobrescreve `kanon_formats`.
        name isa Symbol || continue
        name === :default && continue

        target = params[2]
        target isa Type || continue
        T <: target || continue

        push!(out, name)
    end
    Tuple(unique!(sort!(out)))
end

"""
    kanon_format_locale(::Type{T}, ::Val{name}) -> Symbol | Nothing

The language a formatter belongs to, or `nothing` if it applies in any environment. The
default is `nothing`; a language layer declares its own.

It exists because Julia methods are **global and additive**: without this declaration,
loading `Extenso` in the process would make `{preco:extenso}` valid in a neutral
environment, and an English report would come out with `mil e duzentos reais`. Behaviour
is still dispatch; what the environment decides is **visibility** (D-026).
"""
kanon_format_locale(::Type, ::Val) = nothing

"""
    kanon_attribute(v, ::Val{name}) -> Bool

A named predicate, used in the rules plane (`when property is rural`).
"""
kanon_attribute(v, ::Val{name}) where {name} = throw(UnknownAttribute(typeof(v), name))

"""
    kanon_attributes(::Type{T}) -> Tuple{Vararg{Symbol}}

The attributes of `T`, sorted, to validate rules without data and for error messages.

`present` and `absent` are not listed here: they apply to every field and belong to the
engine, not to the type (see [`UNIVERSAL_ATTRIBUTES`](@ref)).
"""
kanon_attributes(::Type) = ()

"""
    UNIVERSAL_ATTRIBUTES

Attributes every field has, whatever its type. They belong to the engine: they follow from
whether the value is present, and no type implements them.
"""
const UNIVERSAL_ATTRIBUTES = (:absent, :present)

"""
    kanon_getfield(v, ::Val{name})

Reads a field declared by [`kanon_schema`](@ref). The default is `getproperty(v, name)`,
which works when the field's name in the schema is the Julia property name; a type whose
schema does not mirror its `struct` defines its own methods.

It exists because the schema is the type's **interface** and the `struct` is its
implementation: without separating them, `kanon_schema` would become a promise about
Julia field names, and renaming an internal field would break existing templates (D-023).
"""
kanon_getfield(v, ::Val{name}) where {name} = getproperty(v, name)

"""
    kanon_json_schema(::Type{T}) -> Nothing | JSON shape

The JSON shape [`kanon_decode`](@ref) accepts for `T`, as JSON Schema: what the contract
(`contract`) publishes under the type's `\$defs`. The default is `nothing`, and the
contract then derives the shape from [`kanon_schema`](@ref).

The two descriptions are different things, which is why this function exists (D-079).
`kanon_schema` is the **read interface**: the fields a template reaches with
`{pessoa.nome}`. Input may require more than that (`pessoa` needs `genero`, which decides
`portador(a)` and which no template writes), and a contract derived only from the schema
forbade (`additionalProperties: false`) the key the decoder requires. The JSON data of
five real templates, which the engine renders byte for byte, was rejected by their own
contract in a JSON Schema validator.

The shape is written with vectors of pairs, which keep their order, so the contract can
be compared with `diff` (D-009):

```julia
Kanon.kanon_json_schema(::Type{Pessoa}) = [
    "type" => "object",
    "properties" => [
        "nome"   => ["type" => "string", "title" => "Nome completo"],
        "genero" => ["type" => "string", "enum" => ["f", "m"], "title" => "Gênero"],
    ],
    "required" => ["nome", "genero"],
    "additionalProperties" => false,
]
```

A reference to another type (`"\$ref" => "#/\$defs/pessoa"`) is included in the contract
along with it.
"""
kanon_json_schema(::Type) = nothing

"""
    kanon_decode(::Type{T}, raw, ctx) -> T

Converts a value from external input (JSON, a spreadsheet, a `DataFrame`) to the type.
It is the only conversion point: there is no implicit coercion anywhere (§3.4).

The default accepts what is already of the type and rejects everything else, failing
loudly with the type's name in the message.
"""
function kanon_decode(::Type{T}, raw, ctx) where {T}
    raw isa T && return raw
    throw(UndecodableValue(T, raw, "esperava um valor de `$(kanon_typename_or_julia(T))`."))
end

"""
    kanon_compare(a::T, b) -> Int

Ordering for the rules plane (`price > 0`). Returns `-1`, `0` or `1`. The default
refuses: comparison requires the type to declare how.
"""
kanon_compare(a::T, b) where {T} = throw(IncomparableValues(T, b))
