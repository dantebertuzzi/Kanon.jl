using Test
using Dates
using Kanon
using Extenso
using KanonLegal
using KanonScience   # o modelo nº 5 precisa dos dois domínios
using KanonLegal: rotulo_clausula, remissao_clausula, idade, maior

const ENV_LEGAL = Environment(locale = :pt, domains = [KanonLegal])
const ENV_LAUDO = Environment(locale = :pt, domains = [KanonLegal, KanonScience])
const RAIZ = normpath(joinpath(@__DIR__, "..", "..", ".."))

include("test_tipos.jl")
include("test_escritura.jl")
include("test_locacao.jl")
include("test_laudo.jl")
