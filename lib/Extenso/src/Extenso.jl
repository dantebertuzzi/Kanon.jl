"""
    Extenso

A camada de idioma português do [`Kanon`](https://github.com/dantebertuzzi/Kanon.jl):
flexão por marca, números e valores por extenso, datas, junção de listas, separadores e
as palavras-chave em português.

Publicável sozinho: as funções de extenso — `inteiro_extenso`, `ordinal_extenso`,
`dinheiro_extenso`, `data_extenso` — servem a qualquer programa Julia que gere texto
formal em português, com ou sem Kanon.

Nada de direito nem de qualquer outro domínio entra aqui. Tipos como `pessoa` e
`imovel`, e o estilo de bloco `§`, são de `KanonLegal`.

O invariante que a camada não pode quebrar é o D-013: **só a palavra que carrega a marca
muda**. Não há aqui nenhuma travessia da prosa do autor.
"""
module Extenso

using Dates
using Kanon
using Kanon: Money, NumberValue, FormatContext, EnvironmentBuilder

include("numeros.jl")
include("flexao.jl")

export inteiro_extenso, ordinal_extenso, dinheiro_extenso, data_extenso, data_corrente
export genero, numero, flexionar

# --- formatadores ------------------------------------------------------------
#
# Métodos de `Kanon.format`, definidos por despacho: carregar este módulo basta para
# eles existirem, e nenhum registro adicional é preciso (api-extensao.md §2.1).

"O gênero que um formatador por extenso usa quando o contexto não diz outro."
const GENERO_PADRAO = :m

Kanon.format(v::NumberValue, ::Val{:extenso}, ctx) = extenso_de_numero(v)
Kanon.format(v::NumberValue, ::Val{:ordinal}, ctx) = ordinal_extenso(Integer(v))
Kanon.format(v::NumberValue, ::Val{:ordinal_f}, ctx) = ordinal_extenso(Integer(v); genero = :f)

"""
Por extenso, um número não inteiro se escreve pela parte inteira e pela decimal, como em
`três inteiros e catorze centésimos`. Enquanto isso não for preciso, o formatador recusa
o não-inteiro em vez de arredondar em silêncio.
"""
function extenso_de_numero(v)
    isinteger(v) || throw(ArgumentError(
        "por extenso só de número inteiro: `$v` tem parte decimal. " *
        "Para dinheiro, use o tipo `money`, que escreve os centavos."))
    inteiro_extenso(Integer(v))
end

Kanon.format(v::Money, ::Val{:extenso}, ctx) = dinheiro_extenso(v.amount, v.currency)
Kanon.format(v::Date, ::Val{:extenso}, ctx) = data_extenso(v)
Kanon.format(v::Date, ::Val{:corrente}, ctx) = data_corrente(v)
Kanon.format(v::Date, ::Val{:mes}, ctx) = MESES[Dates.month(v)]

"""
Estes formatadores são **do português**, e só existem em ambiente que declare
`locale = :pt`.

A declaração é necessária porque método em Julia é global: sem ela, carregar este pacote
faria `{preco:extenso}` valer num ambiente neutro, e um relatório em inglês sairia com
`mil e duzentos reais` (D-026).
"""
Kanon.kanon_format_locale(::Type{T}, ::Val{:extenso}) where {T<:NumberValue} = :pt
Kanon.kanon_format_locale(::Type{T}, ::Val{:ordinal}) where {T<:NumberValue} = :pt
Kanon.kanon_format_locale(::Type{T}, ::Val{:ordinal_f}) where {T<:NumberValue} = :pt
Kanon.kanon_format_locale(::Type{Money}, ::Val{:extenso}) = :pt
Kanon.kanon_format_locale(::Type{Date}, ::Val{:extenso}) = :pt
Kanon.kanon_format_locale(::Type{Date}, ::Val{:corrente}) = :pt
Kanon.kanon_format_locale(::Type{Date}, ::Val{:mes}) = :pt

# --- a camada ----------------------------------------------------------------

"""
Junta os elementos de uma lista como o português junta: vírgula entre todos, `e` antes
do último. Substitui a convenção do núcleo, que é `", "` — e a substituição é gancho de
ambiente, e não método sobre `AbstractVector`, para que carregar este módulo não mude a
saída de um ambiente que não o declarou (D-025).
"""
function juntar(partes, ctx)
    n = length(partes)
    n == 0 && return ""
    n == 1 && return String(first(partes))
    join(partes[1:(end - 1)], ", ") * " e " * partes[end]
end

"""
As palavras-chave em português (`especificacao.md` §9), como vetor de pares e não como
`NamedTuple`: `for`, `and`, `is`, `true` e `false` são reservadas em Julia.

`one for each` são três palavras na gramática, e viram três aqui — `um para cada`.
"""
const PALAVRAS = [
    :data => "dados", :text => "texto", :rules => "regras",
    :when => "quando", :one => "um", Symbol("for") => "para", :each => "cada",
    :and => "e", :or => "ou", :not => "não",
    :is => "é", :present => "presente", :absent => "ausente",
    :today => "hoje",
    Symbol("true") => "verdadeiro", Symbol("false") => "falso", :null => "nulo",
]

"Os nomes dos tipos do núcleo em português."
const TIPOS = (:texto => :text, :numero => :number, :dinheiro => :money,
               :data => :date, :booleano => :boolean, :lista => :list)

"""
    Kanon.configure_locale!(b, ::Val{:pt})

Tudo que é **nome** e é local ao ambiente. O que é comportamento — formatar, flexionar —
já existe por despacho, sem passar por aqui.
"""
function Kanon.configure_locale!(b::EnvironmentBuilder, ::Val{:pt})
    register_aliases!(b, :pt, PALAVRAS)

    for (apelido, canonico) in TIPOS
        register_type_alias!(b, apelido, canonico)
    end

    register_inflection!(b, :pt; marks = formas_de_marca(),
                         apply = (palavra, marca, sujeito, ctx) ->
                                 flexionar(palavra, marca, sujeito))
    register_repair_hook!(b, :pt, recapitalizar)
    register_list_joiner!(b, :pt, juntar)

    # `0,42` e `1.200` — do idioma, não do tipo (§3.3)
    register_separators!(b; decimal = ",", group = ".")
    register_date_pattern!(b, "dd/mm/yyyy")

    for (codigo, simbolo) in (:BRL => "R\$", :EUR => "€", :USD => "US\$")
        register_currency!(b, codigo, simbolo)
    end
    return b
end

end # module
