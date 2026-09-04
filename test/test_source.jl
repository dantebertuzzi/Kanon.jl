@testset "leitura e normalização" begin
    @testset "NFC" begin
        # `José` com `e` + acento combinante deve virar o mesmo campo que com `é`.
        composed = "kanon 1\n\ndata\n  josé : text !\n\ntext\n\n: b\nx\n"
        decomposed = "kanon 1\n\ndata\n  josé : text !\n\ntext\n\n: b\nx\n"
        @test ok(composed).data.fields[1].name === ok(decomposed).data.fields[1].name
    end

    @testset "fim de linha" begin
        crlf = "kanon 1\r\n\r\ntext\r\n\r\n: b\r\nlinha um\r\n"
        t = ok(crlf)
        @test length(t.text.blocks) == 1
        @test nodes1(t)[1].value == "linha um"
    end

    @testset "BOM é erro, não é ignorado" begin
        e = try
            Kanon.read_source(Vector{UInt8}(codeunits("﻿kanon 1\n")), "t.kanon")
            nothing
        catch err
            err
        end
        @test e isa KanonSyntaxError
        @test [d.code for d in e.diagnostics] == ["K1001"]
    end

    @testset "não-UTF-8 é erro" begin
        e = try
            Kanon.read_source(UInt8[0x6b, 0x61, 0xff, 0xfe], "t.kanon")
            nothing
        catch err
            err
        end
        @test e isa KanonSyntaxError
        @test [d.code for d in e.diagnostics] == ["K1007"]
    end

    @testset "linha final" begin
        # Terminar ou não em `\n` não muda a contagem de linhas do documento.
        a = Kanon.source_from_text("um\ndois\n", "t")
        b = Kanon.source_from_text("um\ndois", "t")
        @test a.lines == b.lines == ["um", "dois"]
    end
end
