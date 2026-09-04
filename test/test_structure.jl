@testset "estrutura dos planos" begin
    @testset "só o plano de texto é obrigatório" begin
        t = ok("kanon 1\n\ntext\n\n: b\nolá\n")
        @test isempty(t.data.fields)
        @test isempty(t.rules.rules)
        @test length(t.text.blocks) == 1
    end

    @testset "plano de texto ausente" begin
        @test "K1013" in codes("kanon 1\n\ndata\n  x : text !\n")
    end

    @testset "plano duplicado" begin
        @test "K1011" in codes("kanon 1\n\ntext\n\n: a\nx\n\ntext\n\n: b\ny\n")
    end

    @testset "ordem fixa" begin
        @test "K1012" in codes("kanon 1\n\ntext\n\n: b\nx\n\ndata\n  y : text !\n")
        @test isempty(codes("kanon 1\n\ndata\n  y : text !\n\ntext\n\n: b\nx\n\nrules\n  b when y is present\n"))
    end

    @testset "conteúdo fora de qualquer plano" begin
        @test "K1010" in codes("kanon 1\n\nperdido\n\ntext\n\n: b\nx\n")
    end
end
