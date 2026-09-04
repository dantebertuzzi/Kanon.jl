using Test
include("helpers.jl")

@testset "Kanon — F1 e F2" begin
    include("test_source.jl")
    include("test_pragma.jl")
    include("test_structure.jl")
    include("test_data.jl")
    include("test_text.jl")
    include("test_rules.jl")
    include("test_diagnostics.jl")
    include("test_invariants.jl")
    include("test_types.jl")
    include("test_environment.jl")
    include("test_analyze.jl")
    include("test_guarded.jl")
end
