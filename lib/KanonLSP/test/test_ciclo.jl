# O ciclo de vida e o enquadramento — a parte que não é do Kanon e que, se estiver
# errada, faz o servidor não existir para o editor.

@testset "ciclo de vida" begin
    @testset "initialize anuncia o que o servidor faz" begin
        s = Sessao()
        id = pedir!(s, "initialize", (capabilities = (;),))
        msgs = rodar!(s)
        r = resposta(msgs, id).result
        @test r.serverInfo.name == "kanon-lsp"
        @test r.capabilities.hoverProvider
        @test r.capabilities.definitionProvider
        @test r.capabilities.documentSymbolProvider
        @test r.capabilities.textDocumentSync.change == 1     # o texto inteiro
        @test "{" in r.capabilities.completionProvider.triggerCharacters
    end

    @testset "shutdown responde, exit encerra o laço" begin
        s = Sessao()
        pedir!(s, "initialize", (capabilities = (;),))
        id = pedir!(s, "shutdown")
        avisar!(s, "exit")
        pedir!(s, "initialize", (capabilities = (;),))   # depois do exit, ninguém lê
        msgs = rodar!(s)
        @test resposta(msgs, id).result === nothing
        @test length(msgs) == 2                          # o initialize e o shutdown
    end

    @testset "um pedido desconhecido erra; um aviso desconhecido é ignorado" begin
        s = Sessao()
        id = pedir!(s, "textDocument/inventado", (;))
        avisar!(s, "\$/cancelRequest", (id = 1,))
        msgs = rodar!(s)
        @test length(msgs) == 1
        @test resposta(msgs, id).error.code == KanonLSP.ERR_METHOD_NOT_FOUND
    end

    @testset "o Content-Length conta bytes, e não caracteres" begin
        # Um cabeçalho contado em caracteres funciona em inglês e trava no primeiro `ã`,
        # com o servidor esperando bytes que nunca chegam.
        texto = "kanon 1\n\ntext\n\n: b\nSeção — João é aqui.\n"
        s = sessao_com(texto)
        id = pedir!(s, "textDocument/documentSymbol",
                    (textDocument = (uri = "file:///tmp/t.kanon",),))
        msgs = rodar!(s)
        @test ncodeunits(texto) > length(texto)          # o teste só vale se houver acento
        @test length(resposta(msgs, id).result) == 1
    end

    @testset "didChange substitui o texto e republica" begin
        s = sessao_com("kanon 1\n\ndata\n  a : text\n\ntext\n\n: b\n{a}\n")
        avisar!(s, "textDocument/didChange",
                (textDocument = (uri = "file:///tmp/t.kanon", version = 2),
                 contentChanges = [(text = "kanon 1\n\ndata\n  a : text\n\ntext\n\n: b\n[{a}]\n",)]))
        msgs = rodar!(s)
        pub = avisos(msgs, "textDocument/publishDiagnostics")
        @test length(pub) == 2
        @test length(pub[1].params.diagnostics) == 1     # `{a}` fora de grupo
        @test isempty(pub[2].params.diagnostics)         # e agora dentro
    end

    @testset "didClose apaga os diagnósticos do arquivo fechado" begin
        s = sessao_com("kanon 1\n\ndata\n  a : text\n\ntext\n\n: b\n{a}\n")
        avisar!(s, "textDocument/didClose",
                (textDocument = (uri = "file:///tmp/t.kanon",),))
        msgs = rodar!(s)
        pub = avisos(msgs, "textDocument/publishDiagnostics")
        @test isempty(last(pub).params.diagnostics)
    end

    @testset "um pedido sobre arquivo não aberto não derruba o servidor" begin
        s = Sessao()
        id = em(s, "textDocument/hover", 0, 0; uri = "file:///tmp/nao-aberto.kanon")
        id2 = pedir!(s, "initialize", (capabilities = (;),))
        msgs = rodar!(s)
        @test resposta(msgs, id).result === nothing
        @test resposta(msgs, id2).result.serverInfo.name == "kanon-lsp"
    end
end
