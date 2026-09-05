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

Um campo de tipo composto. `optional` é o que estende o teorema da lacuna para dentro
dos compostos: se `person.spouse` é opcional, `{seller.spouse.name}` é nulável e exige
grupo (`docs/especificacao.md` §3.1 e §14).
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

Falha do **protocolo de tipo**: o tipo não sabe fazer o que lhe foi pedido.

São exceções e não diagnósticos porque acontecem fora de um arquivo de modelo, e portanto
não têm linha nem coluna. `analyze` e `check` as capturam e as convertem em diagnóstico
quando há uma posição a que atribuí-las.
"""
abstract type KanonProtocolError <: Exception end

"O tipo Julia não implementa `kanon_typename` — não é um tipo Kanon."
struct UnregisteredType <: KanonProtocolError
    type::Type
end

"O tipo não tem o formatador pedido. A mensagem lista os que ele tem."
struct UnknownFormatter <: KanonProtocolError
    type::Type
    name::Symbol
end

"O tipo não tem o atributo pedido. A mensagem lista os que ele tem."
struct UnknownAttribute <: KanonProtocolError
    type::Type
    name::Symbol
end

"Valor da entrada externa que o tipo não sabe decodificar (§3.4: não há coerção implícita)."
struct UndecodableValue <: KanonProtocolError
    type::Type
    raw::Any
    reason::String
end

"O tipo não declara como se comparar com aquele valor (§8.1)."
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

Nome do tipo na linguagem. Obrigatória: é ela que faz de um tipo Julia um tipo Kanon.
"""
kanon_typename(::Type{T}) where {T} = throw(UnregisteredType(T))

"""
    kanon_schema(::Type{T}) -> Tuple{Vararg{FieldSpec}}

Campos do tipo composto, em ordem de declaração. `()` para escalar — o padrão.
"""
kanon_schema(::Type) = ()

"""
    kanon_validate(v, ctx) -> Nothing | Vector{Diagnostic}

Verificação do valor além do tipo Julia. O padrão não verifica nada.
"""
kanon_validate(v, ctx) = nothing

"""
    format(v, ::Val{name}, ctx) -> AbstractString

Formatador. `Val{:default}` é obrigatório em todo tipo; os demais são opcionais e
enumeráveis por [`kanon_formats`](@ref).
"""
format(v, ::Val{name}, ctx) where {name} = throw(UnknownFormatter(typeof(v), name))

"""
    kanon_formats(::Type{T}) -> Tuple{Vararg{Symbol}}

Formatadores nomeados de `T`, ordenados, **sem** `:default` — que não é um nome
escrevível na interpolação: quem quer o padrão escreve `{price}`.

A implementação padrão introspecta a tabela de métodos de [`format`](@ref) procurando
assinaturas `Tuple{typeof(format), T′, Val{S}, Any}` com `T <: T′` e `S::Symbol`. É o
que faz a promessa da §2.1 de `docs/api-extensao.md` valer: um formatador acrescentado
por despacho direto, sem passar por nenhuma fachada, passa a existir para a validação
do modelo e para a mensagem de erro sem registro adicional.

Isso é introspecção de **tabela de métodos**, não de dados do usuário: não executa
código do modelo e é determinística por causa da ordenação.

Uma camada pode sobrescrever este método para documentar, ou para cobrir formatadores
definidos genericamente (`format(v::T, ::Val{N}, ctx) where {N}`), que a introspecção
não tem como enumerar.
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

O idioma a que um formatador pertence, ou `nothing` se ele vale em qualquer ambiente.
O padrão é `nothing`; uma camada de idioma declara os seus.

Existe porque método em Julia é **global e aditivo**: sem esta declaração, bastaria
carregar `Extenso` no processo para que `{preco:extenso}` passasse a valer num ambiente
neutro e um relatório em inglês saísse com `mil e duzentos reais`. O comportamento
continua sendo despacho — o que o ambiente decide é a **visibilidade** (D-026).
"""
kanon_format_locale(::Type, ::Val) = nothing

"""
    kanon_attribute(v, ::Val{name}) -> Bool

Predicado nomeado, usado no plano das regras (`when property is rural`).
"""
kanon_attribute(v, ::Val{name}) where {name} = throw(UnknownAttribute(typeof(v), name))

"""
    kanon_attributes(::Type{T}) -> Tuple{Vararg{Symbol}}

Atributos de `T`, ordenados — para validar a regra sem dados e para a mensagem de erro.

`present` e `absent` não aparecem aqui: valem para todo campo e são do motor, não do
tipo (ver [`UNIVERSAL_ATTRIBUTES`](@ref)).
"""
kanon_attributes(::Type) = ()

"""
    UNIVERSAL_ATTRIBUTES

Atributos que todo campo tem, independentemente do tipo. São do motor: decorrem da
presença do valor, e nenhum tipo os implementa.
"""
const UNIVERSAL_ATTRIBUTES = (:absent, :present)

"""
    kanon_getfield(v, ::Val{name})

Lê um campo declarado por [`kanon_schema`](@ref). O padrão é `getproperty(v, name)`, que
serve quando o nome do campo no esquema é o nome da propriedade Julia; um tipo cujo
esquema não espelha a `struct` define métodos seus.

Existe porque o esquema é a **interface** do tipo e a `struct` é a implementação dele:
sem separar as duas, `kanon_schema` viraria uma promessa sobre nomes de campos Julia, e
renomear um campo interno quebraria os modelos do acervo (D-023).
"""
kanon_getfield(v, ::Val{name}) where {name} = getproperty(v, name)

"""
    kanon_decode(::Type{T}, raw, ctx) -> T

Converte um valor da entrada externa (JSON, planilha, `DataFrame`) para o tipo. É o
único ponto de conversão: não há coerção implícita em lugar nenhum (§3.4).

O padrão aceita o que já é do tipo e recusa o resto — falhando alto, com o nome do tipo
na mensagem.
"""
function kanon_decode(::Type{T}, raw, ctx) where {T}
    raw isa T && return raw
    throw(UndecodableValue(T, raw, "esperava um valor de `$(kanon_typename_or_julia(T))`."))
end

"""
    kanon_compare(a::T, b) -> Int

Ordem para o plano das regras (`price > 0`). Devolve `-1`, `0` ou `1`. O padrão recusa:
comparar exige que o tipo declare como.
"""
kanon_compare(a::T, b) where {T} = throw(IncomparableValues(T, b))
