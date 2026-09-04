# Os seis tipos do núcleo.
#
# Nenhum deles conhece idioma (`docs/especificacao.md` §3.3). `money:symbol` usa o
# símbolo declarado no ambiente, não uma convenção nacional embutida; separador decimal
# e de milhar vêm do contexto. Por extenso, ordinal, mês por nome e junção de lista com
# conjunção são da camada de idioma — o núcleo não os tem.
#
# Regra que este arquivo não pode violar: nenhum literal de string não-ASCII. É o que o
# teste de neutralidade da F6 verifica mecanicamente.

# --- text --------------------------------------------------------------------

kanon_typename(::Type{<:AbstractString}) = :text

format(v::AbstractString, ::Val{:default}, ctx) = String(v)
format(v::AbstractString, ::Val{:upper}, ctx) = uppercase(v)
format(v::AbstractString, ::Val{:lower}, ctx) = lowercase(v)
format(v::AbstractString, ::Val{:title}, ctx) = titlecase(v)

kanon_compare(a::AbstractString, b::AbstractString) = cmp(a, b)

function kanon_decode(::Type{AbstractString}, raw, ctx)
    raw isa AbstractString && return raw
    throw(UndecodableValue(AbstractString, raw,
        "esperava texto; escreva o valor entre aspas na entrada."))
end

# --- number ------------------------------------------------------------------

"""
    NumberValue

O que conta como `number`. `Bool` fica de fora de propósito: em Julia ele é `Integer`,
e em Kanon `boolean` é tipo à parte — sem isso, `{flag:fixed2}` seria válido.
"""
const NumberValue = Union{AbstractFloat,Rational,Signed,Unsigned}

kanon_typename(::Type{<:NumberValue}) = :number

"""
Insere o separador de milhar da direita para a esquerda. `sep` vazio (o valor de
fábrica do núcleo) devolve os dígitos intactos.
"""
function group_digits(digits::AbstractString, sep::AbstractString)
    isempty(sep) && return digits
    n = length(digits)
    n <= 3 && return digits
    io = IOBuffer()
    head = n % 3
    head == 0 && (head = 3)
    print(io, digits[1:head])
    i = head
    while i < n
        print(io, sep, digits[(i + 1):(i + 3)])
        i += 3
    end
    String(take!(io))
end

"""
Parte inteira e parte fracionária de `v` com `digits` casas, arredondando meio para
longe do zero — a convenção de documento, e determinística.

Passa por `Rational{BigInt}`, e não por `BigFloat`, porque a precisão do `BigFloat` é
estado global (`setprecision`) e o determinismo não pode depender dela.
"""
function scaled_digits(v::Real, digits::Integer)
    scale = big(10)^digits
    n = round(BigInt, Rational{BigInt}(v) * scale, RoundNearestTiesAway)
    neg = n < 0
    n = abs(n)
    int, frac = divrem(n, scale)
    (neg, string(int), digits == 0 ? "" : lpad(string(frac), digits, '0'))
end

"Monta o texto de um número já separado em sinal, inteiro e fração, com os separadores do contexto."
function assemble_number(neg::Bool, int::AbstractString, frac::AbstractString, ctx)
    io = IOBuffer()
    neg && print(io, '-')
    print(io, group_digits(int, group_separator(ctx)))
    isempty(frac) || print(io, decimal_separator(ctx), frac)
    String(take!(io))
end

"Número com um número fixo de casas decimais."
function fixed_number(v::Real, digits::Integer, ctx)
    neg, int, frac = scaled_digits(v, digits)
    assemble_number(neg, int, frac, ctx)
end

"""
A forma natural do número: sem casas quando é inteiro, e com o mínimo necessário quando
não é. `MAX_DECIMALS` é o teto para um racional que não termina — uma convenção do
núcleo, declarada aqui, e não uma propriedade do valor.
"""
const MAX_DECIMALS = 6

function plain_number(v::Real, ctx)
    if v isa Integer || (v isa Rational && isone(denominator(v)))
        neg, int, _ = scaled_digits(v, 0)
        return assemble_number(neg, int, "", ctx)
    end
    if v isa AbstractFloat
        isfinite(v) || throw(UndecodableValue(typeof(v), v, "nao e um numero finito."))
        isinteger(v) && return assemble_number(v < 0, string(abs(BigInt(v))), "", ctx)
    end
    neg, int, frac = scaled_digits(v, MAX_DECIMALS)
    frac = rstrip(frac, '0')
    assemble_number(neg, int, frac, ctx)
end

format(v::NumberValue, ::Val{:default}, ctx) = plain_number(v, ctx)
format(v::NumberValue, ::Val{:integer}, ctx) = fixed_number(v, 0, ctx)
format(v::NumberValue, ::Val{:fixed2}, ctx) = fixed_number(v, 2, ctx)

kanon_attributes(::Type{<:NumberValue}) = (:negative, :positive, :zero)
kanon_attribute(v::NumberValue, ::Val{:zero}) = iszero(v)
kanon_attribute(v::NumberValue, ::Val{:negative}) = v < 0
kanon_attribute(v::NumberValue, ::Val{:positive}) = v > 0

kanon_compare(a::NumberValue, b::NumberValue) = cmp(a, b)

function kanon_decode(::Type{NumberValue}, raw, ctx)
    raw isa NumberValue && return raw
    raw isa Bool && throw(UndecodableValue(NumberValue, raw,
        "verdadeiro e falso nao sao numeros; declare o campo como `boolean`."))
    throw(UndecodableValue(NumberValue, raw, "esperava um numero."))
end

# --- money -------------------------------------------------------------------

"""
    Money(amount, currency)

Valor monetário: quantia exata e código de moeda. A quantia é `Rational{Int128}`, e não
ponto flutuante, porque um documento que diz `R\$ 1.234,57` não pode depender do
arredondamento binário.

O núcleo emite duas casas decimais. É convenção declarada, não propriedade da moeda.
"""
struct Money
    amount::Rational{Int128}
    currency::Symbol
end

Money(amount::Real, currency::Symbol) = Money(Rational{Int128}(amount), currency)
Money(amount::Real, currency::AbstractString) = Money(amount, Symbol(currency))

"Quantia escrita como decimal. Passa por `Rational`, nunca por ponto flutuante."
Money(amount::AbstractString, currency) = Money(parse_decimal(amount), Symbol(currency))

Base.:(==)(a::Money, b::Money) = a.amount == b.amount && a.currency === b.currency
Base.hash(m::Money, h::UInt) = hash(m.currency, hash(m.amount, h))
Base.show(io::IO, m::Money) = print(io, "Money(", m.amount, ", :", m.currency, ")")

kanon_typename(::Type{Money}) = :money

"Casas decimais que o núcleo emite para dinheiro."
const MONEY_DECIMALS = 2

format(v::Money, ::Val{:plain}, ctx) = fixed_number(v.amount, MONEY_DECIMALS, ctx)
format(v::Money, ::Val{:code}, ctx) =
    string(v.currency, ' ', fixed_number(v.amount, MONEY_DECIMALS, ctx))
format(v::Money, ::Val{:symbol}, ctx) =
    string(currency_symbol(ctx, v.currency), ' ', fixed_number(v.amount, MONEY_DECIMALS, ctx))

"O padrão é o símbolo — que cai no código da moeda quando o ambiente não declara nenhum."
format(v::Money, ::Val{:default}, ctx) = format(v, Val(:symbol), ctx)

kanon_attributes(::Type{Money}) = (:negative, :positive, :zero)
kanon_attribute(v::Money, ::Val{:zero}) = iszero(v.amount)
kanon_attribute(v::Money, ::Val{:negative}) = v.amount < 0
kanon_attribute(v::Money, ::Val{:positive}) = v.amount > 0

function kanon_compare(a::Money, b::Money)
    a.currency === b.currency || throw(IncomparableValues(Money, b))
    cmp(a.amount, b.amount)
end
kanon_compare(a::Money, b::NumberValue) = cmp(a.amount, b)

"""
Dinheiro não se decodifica de um número solto: faltaria a moeda, e adivinhá-la seria a
coerção implícita que a §3.4 proíbe. Aceita `Money`, ou um par quantia + moeda.
"""
function kanon_decode(::Type{Money}, raw, ctx)
    raw isa Money && return raw
    if raw isa AbstractDict
        haskey(raw, "amount") && haskey(raw, "currency") &&
            return Money(decode_amount(raw["amount"]), Symbol(raw["currency"]))
        throw(UndecodableValue(Money, raw, "faltam as chaves `amount` e `currency`."))
    end
    if raw isa NamedTuple && haskey(raw, :amount) && haskey(raw, :currency)
        return Money(decode_amount(raw.amount), Symbol(raw.currency))
    end
    raw isa NumberValue && throw(UndecodableValue(Money, raw,
        "falta a moeda; escreva `{\"amount\": $raw, \"currency\": \"...\"}`."))
    throw(UndecodableValue(Money, raw, "esperava uma quantia com moeda."))
end

function decode_amount(x)
    x isa NumberValue && return Rational{Int128}(x)
    x isa AbstractString && return parse_decimal(x)
    throw(UndecodableValue(Money, x, "a quantia nao e um numero."))
end

"Lê uma quantia decimal exata, sem passar por ponto flutuante."
function parse_decimal(s::AbstractString)
    m = match(r"^([+-]?)([0-9]+)(?:\.([0-9]+))?$", strip(s))
    m === nothing && throw(UndecodableValue(Money, s, "a quantia nao e um numero decimal."))
    sign = m.captures[1] == "-" ? -1 : 1
    int = parse(Int128, m.captures[2])
    frac = m.captures[3]
    frac === nothing && return Rational{Int128}(sign * int)
    Rational{Int128}(sign) * (int + parse(Int128, frac) // Int128(10)^length(frac))
end

# --- date --------------------------------------------------------------------

kanon_typename(::Type{Date}) = :date

format(v::Date, ::Val{:default}, ctx) = format(v, Val(:iso), ctx)
format(v::Date, ::Val{:iso}, ctx) = Dates.format(v, dateformat"yyyy-mm-dd")
format(v::Date, ::Val{:numeric}, ctx) = Dates.format(v, DateFormat(ctx.env.date_pattern))

kanon_compare(a::Date, b::Date) = cmp(a, b)

function kanon_decode(::Type{Date}, raw, ctx)
    raw isa Date && return raw
    raw isa DateTime && throw(UndecodableValue(Date, raw,
        "e um instante, nao uma data; corte a hora na origem."))
    if raw isa AbstractString
        m = match(r"^([0-9]{4})-([0-9]{2})-([0-9]{2})$", strip(raw))
        m === nothing && throw(UndecodableValue(Date, raw,
            "a data se escreve `aaaa-mm-dd` na entrada."))
        try
            return Date(parse(Int, m.captures[1]), parse(Int, m.captures[2]),
                        parse(Int, m.captures[3]))
        catch
            throw(UndecodableValue(Date, raw, "nao e uma data do calendario."))
        end
    end
    throw(UndecodableValue(Date, raw, "esperava uma data."))
end

# --- boolean -----------------------------------------------------------------

kanon_typename(::Type{Bool}) = :boolean

# Sem formatador nomeado: interpolar um booleano direto no texto e' quase sempre erro de
# modelagem — o que se quer e' uma regra `when`. O padrao existe porque todo tipo deve
# ter um.
format(v::Bool, ::Val{:default}, ctx) = v ? "true" : "false"

kanon_attributes(::Type{Bool}) = (:false, :true)
kanon_attribute(v::Bool, ::Val{Symbol("true")}) = v
kanon_attribute(v::Bool, ::Val{Symbol("false")}) = !v

kanon_compare(a::Bool, b::Bool) = cmp(a, b)

function kanon_decode(::Type{Bool}, raw, ctx)
    raw isa Bool && return raw
    throw(UndecodableValue(Bool, raw, "esperava verdadeiro ou falso."))
end

# --- list --------------------------------------------------------------------

kanon_typename(::Type{<:AbstractVector}) = :list

"""
A única convenção tipográfica do núcleo: `", "` entre os elementos. Está declarada como
tal na §3.3 e a camada de idioma a substitui — junção com conjunção (`a, b e c`) é da
camada, não daqui.
"""
const LIST_SEPARATOR = ", "

format(v::AbstractVector, ::Val{:default}, ctx) =
    join((format(x, Val(:default), ctx) for x in v), LIST_SEPARATOR)
format(v::AbstractVector, ::Val{:count}, ctx) = plain_number(length(v), ctx)

kanon_attributes(::Type{<:AbstractVector}) = (:empty,)
kanon_attribute(v::AbstractVector, ::Val{:empty}) = isempty(v)

function kanon_decode(::Type{AbstractVector}, raw, ctx)
    raw isa AbstractVector && return raw
    throw(UndecodableValue(AbstractVector, raw, "esperava uma lista."))
end

# --- registro do núcleo ------------------------------------------------------

"""
Os seis tipos e os valores de fábrica. Nenhum apelido de idioma: o núcleo é neutro, e
`aliases` é assunto da camada (§2.2).
"""
function configure!(b::EnvironmentBuilder)
    register_type!(b, AbstractString)
    register_type!(b, NumberValue)
    register_type!(b, Money)
    register_type!(b, Date)
    register_type!(b, Bool)
    register_type!(b, AbstractVector)

    # O estilo do núcleo: numera `1`, `2`, `3.1` e remete como `3.1` (§6.3). Por
    # extenso e ordinal são da camada de idioma, que registra o estilo dela.
    register_block_style!(b, :section;
        unit      = NUMBERING_FREE_UNIT,
        layout    = :prefix,
        separator = ". ",
        number    = (path, ctx) -> join(path, '.'),
        ref       = (path, ctx) -> join(path, '.'))
    return b
end
