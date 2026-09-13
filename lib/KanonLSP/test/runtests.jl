using Test
using JSON3
using Kanon
using KanonLSP
using KanonLegal   # só o modelo real: a camada de verdade, e não o domínio de mentira

include("protocolo.jl")
include("dominio_teste.jl")
include("test_posicoes.jl")
include("test_ciclo.jl")
include("test_diagnosticos.jl")
include("test_estrutura.jl")
include("test_cursor.jl")
include("test_completar.jl")
include("test_modelos_reais.jl")
