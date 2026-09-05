# A estrutura do arquivo: a primeira coluna do editor, e o `detail` de cada bloco é a
# segunda — a regra ao lado dele, que é o que a F9 pediu.

const MODELO_ESTRUTURA = """
kanon 1

data
  seller : text !
  note   : text

text

: preamble
Preâmbulo com {seller}[ e {note}].

:: payment
O pagamento.

::: late
O atraso.

rules
  late  when note is present
"""

@testset "estrutura do arquivo" begin
    s = sessao_com(MODELO_ESTRUTURA)
    id = pedir!(s, "textDocument/documentSymbol",
                (textDocument = (uri = "file:///tmp/t.kanon",),))
    syms = resposta(rodar!(s), id).result

    @testset "o contrato vem primeiro, com um filho por campo" begin
        data = syms[1]
        @test data.name == "data"
        @test [String(c.name) for c in data.children] == ["seller", "note"]
        @test data.children[1].detail == "text !"
        @test data.children[2].detail == "text opcional"
    end

    @testset "cada bloco traz a regra que o governa no `detail`" begin
        blocos = Dict(String(x.name) => x for x in syms[2:end])
        @test Set(keys(blocos)) == Set(["preamble", "payment", "late"])
        @test blocos["preamble"].detail == ""            # sem número, sem sujeito, sem regra
        @test occursin("1", blocos["payment"].detail)    # o número que ele consome
        @test occursin("quando note is present", blocos["late"].detail)
    end

    @testset "o trecho de um bloco cobre o bloco inteiro" begin
        # É o que faz o editor destacar o bloco quando o cursor está nele.
        b = only([x for x in syms if x.name == "preamble"])
        @test b.range.start.line == 8                    # a linha 9, o cabeçalho
        @test b.range.var"end".line >= 9                 # e vai até o texto
        @test b.selectionRange.start.line == 8
    end

    @testset "os campos usados aparecem dentro do bloco, e o que pode faltar é dito" begin
        b = only([x for x in syms if x.name == "preamble"])
        usos = Dict(String(c.name) => String(c.detail) for c in b.children)
        @test usos["seller"] == "text"
        @test occursin("pode faltar, protegido", usos["note"])
    end

    @testset "um campo nulável fora de grupo é gritado, não sussurrado" begin
        s2 = sessao_com("kanon 1\n\ndata\n  a : text\n\ntext\n\n: b\n{a}\n")
        id2 = pedir!(s2, "textDocument/documentSymbol",
                     (textDocument = (uri = "file:///tmp/t.kanon",),))
        syms2 = resposta(rodar!(s2), id2).result
        b = only([x for x in syms2 if x.name == "b"])
        @test occursin("PODE FALTAR, sem grupo", String(only(b.children).detail))
    end

    @testset "sem árvore, a estrutura é vazia e nada quebra" begin
        s3 = sessao_com("kanon 1\n\ntext\n\n: b\n{a\n")
        id3 = pedir!(s3, "textDocument/documentSymbol",
                     (textDocument = (uri = "file:///tmp/t.kanon",),))
        @test isempty(resposta(rodar!(s3), id3).result)
    end
end
