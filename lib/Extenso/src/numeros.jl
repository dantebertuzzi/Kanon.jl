# Números por extenso.
#
# A parte com mais exceções do projeto, e por isso a que mais precisa de tabela e menos
# de esperteza. Tudo que é irregular está escrito, não derivado.

const UNIDADES = ("zero", "um", "dois", "três", "quatro", "cinco", "seis", "sete",
                  "oito", "nove")

"De dez a dezenove o português não compõe: cada um é uma palavra própria."
const DEZ_A_DEZENOVE = ("dez", "onze", "doze", "treze", "catorze", "quinze", "dezesseis",
                        "dezessete", "dezoito", "dezenove")

const DEZENAS = ("", "", "vinte", "trinta", "quarenta", "cinquenta", "sessenta",
                 "setenta", "oitenta", "noventa")

"`cem` é exato; `cento` é composto. É a exceção que mais aparece."
const CENTENAS = ("", "cento", "duzentos", "trezentos", "quatrocentos", "quinhentos",
                  "seiscentos", "setecentos", "oitocentos", "novecentos")

"Escalas curtas do português, no singular e no plural."
const ESCALAS = (("", ""), ("mil", "mil"), ("milhão", "milhões"), ("bilhão", "bilhões"),
                 ("trilhão", "trilhões"), ("quatrilhão", "quatrilhões"))

"O maior número que este módulo escreve por extenso."
const MAX_EXTENSO = big(10)^(3 * length(ESCALAS)) - 1

"Flexiona o gênero das formas que o têm: `dois`/`duas`, e as centenas."
function genero_numeral(palavra::AbstractString, genero::Symbol)
    genero === :f || return palavra
    palavra == "um" && return "uma"
    palavra == "dois" && return "duas"
    endswith(palavra, "entos") && return palavra[1:(end - 2)] * "as"   # duzentos → duzentas
    return palavra
end

"""
Um grupo de até três dígitos por extenso. `cem` sozinho, `cento` composto.
"""
function grupo_extenso(n::Integer, genero::Symbol)
    n == 0 && return ""
    n == 100 && return "cem"

    partes = String[]
    c, r = divrem(n, 100)
    c > 0 && push!(partes, genero_numeral(CENTENAS[c + 1], genero))

    if r >= 20
        d, u = divrem(r, 10)
        push!(partes, u == 0 ? DEZENAS[d + 1] :
              DEZENAS[d + 1] * " e " * genero_numeral(UNIDADES[u + 1], genero))
    elseif r >= 10
        push!(partes, DEZ_A_DEZENOVE[r - 9])
    elseif r > 0
        push!(partes, genero_numeral(UNIDADES[r + 1], genero))
    end

    join(partes, " e ")
end

"""
    inteiro_extenso(n; genero = :m) -> String

Um inteiro por extenso. Cobre até quatrilhões; acima disso lança, porque escrever um
número que ninguém lê não serve a documento nenhum.

A regra do `e` entre escalas é a que mais erra em implementações apressadas: escreve-se
`mil e duzentos`, mas `mil duzentos e trinta`. O `e` entra quando o último grupo é menor
que cem ou é uma centena exata — e não em qualquer emenda.
"""
function inteiro_extenso(n::Integer; genero::Symbol = :m)
    n < 0 && return "menos " * inteiro_extenso(-n; genero)
    n == 0 && return "zero"
    n > MAX_EXTENSO && throw(ArgumentError("número grande demais para escrever por extenso: $n"))

    grupos = Int[]
    resto = big(n)
    while resto > 0
        resto, g = divrem(resto, 1000)
        push!(grupos, Int(g))
    end

    partes = String[]
    for i in length(grupos):-1:1
        g = grupos[i]
        g == 0 && continue
        escala = ESCALAS[i]
        # o gênero só alcança o último grupo: `duzentas mil casas`, mas `dois milhões`
        gen = i == 1 ? genero : (i == 2 ? genero : :m)
        texto = (i == 2 && g == 1) ? "" : grupo_extenso(g, gen)
        nome = i == 1 ? "" : (g == 1 ? escala[1] : escala[2])
        push!(partes, strip(texto * (isempty(nome) ? "" : " " * nome)))
    end

    juntar_escalas(partes, grupos)
end

"""
`e` entre a penúltima e a última parte quando a última é menor que cem ou centena exata;
vírgula nas demais emendas. É o que separa `mil e duzentos` de `mil duzentos e trinta`.
"""
function juntar_escalas(partes::Vector{String}, grupos::Vector{Int})
    length(partes) <= 1 && return isempty(partes) ? "zero" : partes[1]
    ultimo = grupos[1]
    conector = (ultimo != 0 && (ultimo < 100 || (ultimo % 100 == 0 && ultimo < 1000))) ?
               " e " : ", "
    join(partes[1:(end - 1)], ", ") * conector * partes[end]
end

# --- ordinais ----------------------------------------------------------------

const ORDINAIS_UNIDADE = ("", "primeir", "segund", "terceir", "quart", "quint",
                          "sext", "sétim", "oitav", "non")
const ORDINAIS_DEZENA = ("", "décim", "vigésim", "trigésim", "quadragésim",
                         "quinquagésim", "sexagésim", "septuagésim", "octogésim",
                         "nonagésim")
const ORDINAIS_CENTENA = ("", "centésim", "ducentésim", "trecentésim", "quadringentésim",
                          "quingentésim", "sexcentésim", "septingentésim",
                          "octingentésim", "noningentésim")

"O maior ordinal que este módulo escreve. Acima disso, documento nenhum precisa."
const MAX_ORDINAL = 999

"""
    ordinal_extenso(n; genero = :m) -> String

`1` ⟶ `primeiro`, `2ª` ⟶ `segunda`, `21` ⟶ `vigésimo primeiro`.

Ordinal é onde a numeração de cláusula vive (`CLÁUSULA PRIMEIRA`), e por isso o gênero é
argumento e não suposição.
"""
function ordinal_extenso(n::Integer; genero::Symbol = :m)
    (1 <= n <= MAX_ORDINAL) ||
        throw(ArgumentError("ordinal fora do alcance (1 a $MAX_ORDINAL): $n"))
    sufixo = genero === :f ? "a" : "o"
    partes = String[]
    c, r = divrem(n, 100)
    d, u = divrem(r, 10)
    c > 0 && push!(partes, ORDINAIS_CENTENA[c + 1] * sufixo)
    d > 0 && push!(partes, ORDINAIS_DEZENA[d + 1] * sufixo)
    u > 0 && push!(partes, ORDINAIS_UNIDADE[u + 1] * sufixo)
    join(partes, " ")
end

# --- valores monetários ------------------------------------------------------

"Nome de moeda no singular e no plural, e o da subunidade. Só as que o português usa."
const MOEDAS = Dict(
    :BRL => (("real", "reais"), ("centavo", "centavos"), :m),
    :EUR => (("euro", "euros"), ("cêntimo", "cêntimos"), :m),
    :USD => (("dólar", "dólares"), ("cent", "cents"), :m),
)

"""
    dinheiro_extenso(quantia, moeda) -> String

`250000.00 BRL` ⟶ `duzentos e cinquenta mil reais`.

A quantia entra como `Rational`, nunca como ponto flutuante: um documento que diz
`duzentos e cinquenta mil reais` não pode depender de arredondamento binário.
"""
function dinheiro_extenso(quantia::Real, moeda::Symbol)
    nomes = get(MOEDAS, moeda, nothing)
    nomes === nothing && throw(ArgumentError("moeda sem nome em português: $moeda"))
    (unidade, subunidade, genero) = nomes

    negativo = quantia < 0
    total = round(BigInt, Rational{BigInt}(abs(quantia)) * 100, RoundNearestTiesAway)
    inteiros, centavos = divrem(total, 100)

    partes = String[]
    if inteiros > 0 || centavos == 0
        push!(partes, inteiro_extenso(inteiros; genero) * " " *
                      (inteiros == 1 ? unidade[1] : unidade[2]))
    end
    if centavos > 0
        push!(partes, inteiro_extenso(centavos; genero = :m) * " " *
                      (centavos == 1 ? subunidade[1] : subunidade[2]))
    end
    (negativo ? "menos " : "") * join(partes, " e ")
end

# --- datas -------------------------------------------------------------------

const MESES = ("janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho",
               "agosto", "setembro", "outubro", "novembro", "dezembro")

"""
    data_extenso(d) -> String

`2026-03-12` ⟶ `doze dias do mês de março do ano de dois mil e vinte e seis`.

É a forma dos instrumentos públicos, com duas concordâncias que a língua exige e nenhuma
regra deriva: o dia 1 é **ordinal** (`primeiro dia`, nunca `um dia`), e só ele fica no
singular.
"""
function data_extenso(d::Date)
    dia = Dates.day(d)
    escrito = dia == 1 ? ordinal_extenso(1) : inteiro_extenso(dia)
    string(escrito, dia == 1 ? " dia" : " dias",
           " do mês de ", MESES[Dates.month(d)],
           " do ano de ", inteiro_extenso(Dates.year(d)))
end

"""
`2026-03-12` ⟶ `12 de março de 2026`. A forma corrente, mais curta que a dos
instrumentos — e nela o dia 1 se escreve `1º`, como na escrita comum.
"""
data_corrente(d::Date) =
    string(Dates.day(d) == 1 ? "1º" : string(Dates.day(d)),
           " de ", MESES[Dates.month(d)], " de ", Dates.year(d))
