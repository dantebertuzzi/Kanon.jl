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

using Printf
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
    expoente = floor(Int, log10(uncertainty))
    primeiro = floor(Int, uncertainty / 10.0^expoente)     # 1 a 9
    significativos = primeiro <= 2 ? 2 : 1
    clamp(significativos - 1 - expoente, 0, 12)
end

"O separador decimal é do idioma, nunca do tipo (§3.3): ele vem do contexto."
function localized(x::Float64, d::Int, ctx)
    s = @sprintf("%.*f", d, x)
    sep = Kanon.decimal_separator(ctx)
    sep == "." ? s : replace(s, "." => sep)
end

function format_measure(v::Measure, ctx)
    d = decimals_for(v.uncertainty)
    corpo = string(localized(v.value, d, ctx), " ", Char(0x00B1), " ",
                   localized(v.uncertainty, d, ctx))
    isempty(v.unit) ? corpo : corpo * " " * v.unit
end

@kanon_type measure Measure begin
    schema = (FieldSpec(:value, :number),
              FieldSpec(:uncertainty, :number),
              FieldSpec(:unit, :text; optional = true))
    getfield   = (value = :value, uncertainty = :uncertainty, unit = :unit)
    default    = (v, ctx) -> format_measure(v, ctx)
    formats    = (bare = (v, ctx) -> localized(v.value, decimals_for(v.uncertainty), ctx),
                  relative = (v, ctx) -> localized(100 * v.uncertainty / v.value, 1, ctx) * "%")
    attributes = (precise = v -> v.uncertainty / abs(v.value) < 0.01,
                  dimensionless = v -> isempty(v.unit))
    compare    = (a, b) -> b isa Measure ? cmp(a.value, b.value) : cmp(a.value, b)
end

"`Theorem 1`, `Theorem 3.1` — inglês canônico, porque este domínio não tem idioma."
theorem_number(path, ctx) = "Theorem " * join(path, ".")

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
