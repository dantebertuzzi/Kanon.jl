# Diagnósticos: o que o editor sublinha.
#
# É a funcionalidade que sozinha justifica o servidor — o motor já sabe tudo o que ela
# precisa dizer, e o que faltava era dizê-lo enquanto o redator digita, e não depois.

@testset "diagnósticos" begin
    @testset "o código, a severidade e a dica chegam inteiros" begin
        s = sessao_com("kanon 1\n\ndata\n  a : text\n\ntext\n\n: b\nNota {a}.\n")
        msgs = rodar!(s)
        d = only(only(avisos(msgs, "textDocument/publishDiagnostics")).params.diagnostics)
        @test d.code == "K2012"
        @test d.severity == 1                      # erro
        @test d.source == "kanon"
        @test occursin("pode faltar", d.message)
        # a dica é metade do valor de um diagnóstico deste motor, e o LSP não tem campo
        # para ela: ela entra na mensagem, depois de uma linha em branco
        @test occursin("\n\nEnvolva o trecho", d.message)
    end

    @testset "a posição vira o trecho, com o zero do LSP" begin
        s = sessao_com("kanon 1\n\ndata\n  a : text\n\ntext\n\n: b\nNota {a}.\n")
        msgs = rodar!(s)
        d = only(only(avisos(msgs, "textDocument/publishDiagnostics")).params.diagnostics)
        @test d.range.start.line == 8              # a linha 9 do Kanon
        @test d.range.start.character == 5         # a coluna 6, menos um
    end

    @testset "um aviso é severidade 2" begin
        # `K2039`: a regra pode deixar o nível 2 sem o nível 1.
        s = sessao_com("kanon 1\n\ndata\n  f : boolean !\n\ntext\n\n:: p\nP.\n\n::: q\nQ.\n\n" *
                       "rules\n  p when f\n")
        msgs = rodar!(s)
        d = only(only(avisos(msgs, "textDocument/publishDiagnostics")).params.diagnostics)
        @test d.code == "K2039"
        @test d.severity == 2
    end

    @testset "erro de sintaxe: sem árvore, e ainda assim com diagnóstico" begin
        s = sessao_com("kanon 1\n\ntext\n\n: b\nNota {a\n")
        msgs = rodar!(s)
        d = only(only(avisos(msgs, "textDocument/publishDiagnostics")).params.diagnostics)
        @test d.code == "K1203"
    end

    @testset "um arquivo limpo publica a lista vazia" begin
        # Sem isto, o editor guarda para sempre o erro que o redator acabou de corrigir.
        s = sessao_com("kanon 1\n\ntext\n\n: b\nTudo certo.\n")
        msgs = rodar!(s)
        @test isempty(only(avisos(msgs, "textDocument/publishDiagnostics")).params.diagnostics)
    end

    @testset "o problema do fragmento vai para o URI do fragmento (D-035)" begin
        dir = mktempdir()
        write(joinpath(dir, "frag.kanon"),
              "kanon 1\n\ndata\n  obs : text\n\ntext\n\n: nota\nUma.\nOutra.\nA nota diz {obs}.\n")
        host = joinpath(dir, "host.kanon")
        texto = "kanon 1\n\ntext\n\n: a\nA.\n\ninclude \"frag.kanon\"\n"
        write(host, texto)

        uri = KanonLSP.uri_of(host)
        s = sessao_com(texto; uri = uri)
        msgs = rodar!(s)
        pub = avisos(msgs, "textDocument/publishDiagnostics")
        por_uri = Dict(String(p.params.uri) => p.params.diagnostics for p in pub)

        @test isempty(por_uri[uri])                                  # o hospedeiro está limpo
        frag_uri = KanonLSP.uri_of(joinpath(dir, "frag.kanon"))
        @test haskey(por_uri, frag_uri)
        d = only(por_uri[frag_uri])
        @test d.code == "K2012"
        @test d.range.start.line == 10                               # a linha 11 do fragmento

        # e o hospedeiro tem 8 linhas: sem a D-035 este erro apontaria uma linha
        # que não existe no arquivo apontado
        @test countlines(host) < 11
    end
end
