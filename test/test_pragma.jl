@testset "linha de versão" begin
    @test ok("kanon 1\n\ntext\n\n: b\nx\n").version == LangVersion(1, 0)
    @test ok("kanon 1.0\n\ntext\n\n: b\nx\n").version == LangVersion(1, 0)

    @testset "comentários e linhas em branco podem preceder" begin
        t = ok("# minuta de escritura\n\nkanon 1\n\ntext\n\n: b\nx\n")
        @test t.version == LangVersion(1, 0)
    end

    @testset "ausente" begin
        @test codes("text\n\n: b\nx\n") == ["K1002"]
        @test codes("") == ["K1002"]
    end

    @testset "malformada" begin
        @test codes("kanon\n\ntext\n\n: b\nx\n") == ["K1003"]
        @test codes("kanon um\n\ntext\n\n: b\nx\n") == ["K1003"]
        @test codes("kanon 1 pt extra\n\ntext\n\n: b\nx\n") == ["K1003"]
    end

    @testset "versão maior desconhecida é recusada, nunca interpretada" begin
        @test "K1004" in codes("kanon 2\n\ntext\n\n: b\nx\n")
    end

    @testset "versão menor acima da suportada é recusada" begin
        @test "K1005" in codes("kanon 1.7\n\ntext\n\n: b\nx\n")
    end

    @testset "idioma sem camada carregada" begin
        cs = codes("kanon 1 pt\n\ntext\n\n: b\nx\n")
        @test "K1006" in cs
    end

    @testset "idioma declarado bate com a tabela fornecida" begin
        pt = KeywordTable(:pt, Dict("text" => :text, "data" => :data, "rules" => :rules))
        t = parse_string("kanon 1 pt\n\ntext\n\n: b\nx\n"; keywords = pt)
        @test t.language === :pt
    end
end
