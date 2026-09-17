"""
    KanonScience

Camada de domínio científico do [`Kanon`](https://github.com/dantebertuzzi/Kanon.jl):
o tipo `measure` — valor com incerteza e unidade — e o estilo de bloco `@`, que numera
teoremas.

**Não depende de `Extenso`, e escreve em inglês canônico.** É a prova, em forma de
pacote, de que a linguagem não é jurídica nem portuguesa: o mesmo núcleo que produz uma
escritura em português produz um relatório científico em inglês, e nenhum dos dois
pacotes sabe da existência do outro.

O `Measure` atravessa a fronteira **como `Measure`**: não há serialização para cadeia no
caminho, e é por isso que o arredondamento do valor e o da incerteza são coerentes entre
si — quem decide os algarismos é o formatador, com os dois números em mãos.
"""
module KanonScience

using Kanon

export Measure

"""
    Measure(value, uncertainty, unit)

Uma grandeza medida. A incerteza não é decoração: é ela que decide quantos algarismos o
valor mostra.
"""
struct Measure
    value::Float64
    uncertainty::Float64
    unit::String
end

Measure(value, uncertainty) = Measure(value, uncertainty, "")

"""
Casas decimais pela incerteza — a convenção que a metrologia usa: o valor mostra até a
casa em que a incerteza é significativa.

A incerteza fica com **um** algarismo significativo, ou **dois** quando o primeiro é 1 ou
2 — é a regra do PDG, e existe porque `1 ± 1` e `1.4 ± 1.4` dizem coisas diferentes e o
arredondamento para um algarismo perderia a diferença justamente onde ela importa.

`0.42 ± 0.07` mostra duas casas; `0.4237 ± 0.0007`, quatro; `12.3 ± 1.4`, uma. Arredondar
o valor por conta própria produziria o `0.42 ± 0.1` que nenhum revisor aceita.
"""
function decimals_for(uncertainty::Float64)
    (uncertainty <= 0 || !isfinite(uncertainty)) && return 2
    primeiro, expoente = decimal_lead(uncertainty)
    primeiro == 0 && return 2
    significativos = primeiro <= 2 ? 2 : 1
    clamp(significativos - 1 - expoente, 0, 12)
end

"""
    decimal_lead(u) -> (primeiro_algarismo, expoente)

O primeiro algarismo significativo de `u` e o expoente decimal dele, lidos da
**representação decimal mais curta que volta ao mesmo `Float64`** — que é o número que
quem mediu escreveu.

Calcular isso por aritmética não funciona, e a forma de não funcionar é sorrateira:
`0.3 / 10.0^-1` vale `2.9999999999999996` em ponto flutuante, e o `floor` devolve **2**.
Uma incerteza cujo primeiro algarismo é 3 caía na regra dos dois algarismos, e o
relatório saía com `21.40 ± 0.30` no lugar de `21.4 ± 0.3` — **uma casa a mais do que a
medição sustenta**, que é exatamente o que a regra do PDG existe para impedir. Quebrava
com `0.3`, `0.03` e `0.0003`, e não com `3.0` nem `30.0`, porque só ali a potência de dez
divide exato.

A leitura decimal é determinística: a conversão mais curta é especificada e não depende
de estado global, ao contrário da precisão do `BigFloat` — é a mesma razão pela qual o
arredondamento do núcleo é por `Rational{BigInt}`.
"""
function decimal_lead(u::Float64)
    s = string(abs(u))

    e10 = 0
    i = findfirst(==('e'), s)
    if i !== nothing
        e10 = parse(Int, s[(i + 1):end])
        s = s[1:(i - 1)]
    end

    ponto = something(findfirst(==('.'), s), length(s) + 1)
    digitos = replace(s, "." => "")
    k = findfirst(c -> '1' <= c <= '9', digitos)
    k === nothing && return (0, 0)              # o zero não tem algarismo significativo

    (digitos[k] - '0', (ponto - 1) - k + e10)
end

"""
Os separadores são do idioma, nunca do tipo (§3.3), e são **dois**: o decimal e o de
milhar. `fixed_number` aplica os dois, e é do núcleo — esta camada não os reimplementa.

A primeira versão trocava só o decimal, à mão. O efeito passou despercebido até um laudo
de avaliação escrever a mesma área duas vezes, uma como `number` do núcleo e outra como
`measure`, e sair `41.250` numa linha e `41250,0` na seguinte (D-041).
"""
localized(x::Float64, d::Int, ctx) = Kanon.fixed_number(x, d, ctx)

function format_measure(v::Measure, ctx)
    d = decimals_for(v.uncertainty)
    corpo = string(localized(v.value, d, ctx), " ", Char(0x00B1), " ",
                   localized(v.uncertainty, d, ctx))
    isempty(v.unit) ? corpo : corpo * " " * v.unit
end

"""
A incerteza relativa, em porcento — **com os algarismos da regra do PDG**, e não com uma
casa fixa.

É uma incerteza, e a regra que decide os algarismos de uma incerteza é uma só. A primeira
versão fixava uma casa decimal, e com isso uma balança de 20 t com incerteza de 5 kg saía
com incerteza relativa de `0,0%` — nula, que é o que a frase afirma —, e um padrão de
`100,00 ± 0,05 °C` saía com `0,1%`, o **dobro** dos `0,05%` que ele tem (D-053). É a
D-034 do outro lado da mesma medição: algarismos que a medição não sustenta, ou a falta
dos que ela sustenta.
"""
function format_relative(v::Measure, ctx)
    # Uma leitura de **zero** é medição legítima — o branco de um laboratório, um desvio
    # nulo, um instrumento no ponto de referência —, e a incerteza relativa dela não
    # existe: é dividir por zero. Saía `DivideError` cru, de dentro do formatador, num
    # valor que o `check` tinha aprovado. Recusar dizendo o que escrever no lugar é o que
    # o motor faz com todo valor que não se escreve.
    iszero(v.value) && throw(Kanon.UnwritableValue(Measure, v,
        "a incerteza relativa de uma medição de valor zero não existe — seria dividir " *
        "por zero. Escreva `{campo}` ou `{campo:bare}`, que não dependem do valor."))
    r = 100 * v.uncertainty / abs(v.value)
    localized(r, decimals_for(r), ctx) * "%"
end

@kanon_type measure Measure begin
    schema = (FieldSpec(:value, :number),
              FieldSpec(:uncertainty, :number),
              FieldSpec(:unit, :text; optional = true))
    getfield   = (value = :value, uncertainty = :uncertainty, unit = :unit)
    default    = (v, ctx) -> format_measure(v, ctx)
    formats    = (bare = (v, ctx) -> localized(v.value, decimals_for(v.uncertainty), ctx),
                  relative = (v, ctx) -> format_relative(v, ctx))
    attributes = (precise = v -> v.uncertainty / abs(v.value) < 0.01,
                  dimensionless = v -> isempty(v.unit))
    compare    = (a, b) -> b isa Measure ? cmp(a.value, b.value) : cmp(a.value, b)
    decode     = (raw, ctx) -> measure_de(raw, ctx)
end

# --- leitura de dados externos -----------------------------------------------
#
# Um laboratório não digita medição em Julia: ele exporta o que o instrumento registrou.
# `kanon_decode` é o **único** ponto em que o objeto lido vira `Measure` (§3.4), e sem
# ele esta camada era a única que um arquivo não alcançava — a D-046 abriu essa porta
# para o domínio jurídico e parou ali (D-047).
#
# A leitura é estrita, como a do outro domínio: chave que falta é erro, e o que é
# opcional no esquema é opcional aqui. O que esta camada acrescenta é uma recusa que o
# domínio jurídico não tinha por que ter — **um número solto não é uma medição**.

"""
A incerteza não é opcional, e a mensagem diz por quê.

Aceitar `21.4` como `measure` daria incerteza zero a um número que ninguém mediu com
incerteza zero — e a incerteza é justamente quem decide quantos algarismos o valor
mostra. O erro seria silencioso e sairia impresso: `21.400000` no lugar de `21.4 ± 0.3`.
"""
function measure_de(raw, ctx)
    raw isa Measure && return raw
    raw isa AbstractDict || throw(UndecodableValue(Measure, raw,
        "esperava um objeto com as chaves `value` e `uncertainty`" *
        (raw isa Union{Real,AbstractString} ?
         "; um número solto não é uma medição, porque não diz a incerteza." : ".")))
    Measure(numero_de(raw, "value", ctx),
            numero_de(raw, "uncertainty", ctx),
            unidade_de(raw, ctx))
end

"Um número obrigatório, pelo decodificador do núcleo — a mensagem de tipo é a dele."
function numero_de(raw::AbstractDict, nome::AbstractString, ctx)
    v = get(raw, nome, nothing)
    v === nothing && throw(UndecodableValue(Measure, raw, "falta a chave `$nome`."))
    Float64(kanon_decode(Kanon.NumberValue, v, ctx))
end

"""
A unidade, que pode faltar — e falta como cadeia vazia, que é como o tipo a guarda.

`null` e chave ausente valem o mesmo aqui, pela razão da D-046: distingui-los faria a
origem dos dados mudar o significado do contrato.
"""
function unidade_de(raw::AbstractDict, ctx)
    v = get(raw, "unit", nothing)
    v === nothing ? "" : String(kanon_decode(AbstractString, v, ctx))
end

"""
`Theorem 1`, `Theorem 3.1` — inglês canônico, porque este domínio não tem idioma; e
`Teorema 1` num modelo cujo idioma tenha palavra para a chave `:theorem`.

Perguntar não é ter idioma: a camada continua sem conhecer língua nenhuma, e escreve a
palavra inglesa sempre que ninguém tenha registrado outra. Quem traduz é a camada de
idioma, para quem `teorema` é uma palavra do próprio dicionário (D-056).
"""
theorem_number(path, ctx) = Kanon.term(ctx, :theorem, "Theorem") * " " * join(path, ".")

"""
    configure!(b)

Os nomes: o tipo `measure` e o marcador `@`. O comportamento já existe por despacho.
"""
function configure!(b::Kanon.EnvironmentBuilder)
    register_type!(b, Measure)
    register_block_style!(b, :theorem;
        unit      = '@',
        layout    = :prefix,
        separator = ". ",
        number    = theorem_number,
        ref       = theorem_number)
    return b
end

end # module
