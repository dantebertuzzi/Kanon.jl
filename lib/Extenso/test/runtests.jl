using Test
using Tables
using JSON3   # só a suíte: o atestado lê o contrato de um JSON
using Dates
using Kanon
using Extenso
using Extenso: MARCAS, MESES, MAX_ORDINAL

const RAIZ_KANON = normpath(joinpath(@__DIR__, "..", "..", ".."))
const ENV_PT_NU = Environment(locale = :pt)

include("test_numeros.jl")
include("test_flexao.jl")
include("test_camada.jl")
include("test_certificado.jl")
include("test_edital.jl")
include("test_atestado.jl")
