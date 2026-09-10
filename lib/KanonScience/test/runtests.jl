using Test
using Dates
using Kanon
using KanonScience
using Extenso   # só para o teste dos separadores: o pacote não depende dele
using JSON3     # só para o certificado: é ele que lê as medições de um arquivo
using CSV       # só para a verificação: é ela que lê uma planilha de verdade
using Tables

const ENV_SCI = Environment(domains = [KanonScience])
const RAIZ = normpath(joinpath(@__DIR__, "..", "..", ".."))

include("test_measure.jl")
include("test_relatorio.jl")
include("test_medicao.jl")
include("test_ensaio.jl")
include("test_verificacao.jl")
