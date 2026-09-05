using Test
using Dates
using Kanon
using KanonScience
using Extenso   # só para o teste dos separadores: o pacote não depende dele

const ENV_SCI = Environment(domains = [KanonScience])
const RAIZ = normpath(joinpath(@__DIR__, "..", "..", ".."))

include("test_measure.jl")
include("test_relatorio.jl")
include("test_medicao.jl")
