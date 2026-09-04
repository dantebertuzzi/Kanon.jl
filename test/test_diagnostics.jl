@testset "diagnósticos" begin
    @testset "todo código emitido está registrado" begin
        # A construção de `Diagnostic` já afirma isso; aqui garantimos que o registro
        # não tem entrada órfã com título vazio.
        @test all(!isempty, values(CODE_TITLES))
        @test all(c -> occursin(r"^K[0-9]{4}$", c), keys(CODE_TITLES))
    end

    @testset "acumula todos os problemas, não só o primeiro" begin
        cs = codes("""
kanon 1

data
  a text !
  b : person[x]
  c : text ! = "x"

text

: bloco
{price
{v:round:written}
""")
        @test "K1101" in cs
        @test "K1102" in cs
        @test "K1103" in cs
        @test "K1203" in cs
        @test "K1206" in cs
        @test length(cs) >= 5
    end

    @testset "ordem determinística: arquivo, linha, coluna, código" begin
        d = diags("""
kanon 1

text

: b
{v:round:written}
{price
""")
        ls = [x.line for x in d]
        @test issorted(ls)
    end

    @testset "toda mensagem nomeia linha e coluna" begin
        d = diags(withtext("{v:round:written}"))
        @test all(x -> x.line > 0 && x.col > 0, d)
    end

    @testset "o formato é o da especificação §10.4" begin
        out = format_diagnostics(diags(withtext("{v:round(2)}")))
        @test occursin("1 problema encontrado", out)
        @test occursin("[K1207]", out)
        @test occursin("sintaxe,", out)
        @test occursin("linha 6", out)
    end

    @testset "vocabulário de redator, não de implementação" begin
        out = format_diagnostics(diags(withtext("{price")))
        for banido in ("AST", "token", "MethodError", "Val{", "nothing", "Symbol")
            @test !occursin(banido, out)
        end
    end
end
