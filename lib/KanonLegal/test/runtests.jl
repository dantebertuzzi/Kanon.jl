using Test
using Dates
using Kanon
using Extenso
using KanonLegal
using KanonLegal: rotulo_clausula, remissao_clausula, idade, maior

const ENV_LEGAL = Environment(locale = :pt, domains = [KanonLegal])
const RAIZ = normpath(joinpath(@__DIR__, "..", "..", ".."))

include("test_tipos.jl")
include("test_escritura.jl")
