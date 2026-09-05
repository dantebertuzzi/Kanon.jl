using Test
using Dates
using Kanon
using KanonScience

const ENV_SCI = Environment(domains = [KanonScience])
const RAIZ = normpath(joinpath(@__DIR__, "..", "..", ".."))

include("test_measure.jl")
include("test_relatorio.jl")
include("test_medicao.jl")
