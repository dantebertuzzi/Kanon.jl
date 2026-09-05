# O que está sob o cursor, e para onde ele salta.
#
# Cada resposta é lida de uma tabela da `Analysis`. O teste afirma sobre o **conteúdo**
# porque é o conteúdo que distingue este servidor de um que só colore palavras: quando
# ele diz "pode faltar, e não está dentro de nenhum grupo", quem lê aprendeu o teorema da
# lacuna sem abrir a especificação.

const MODELO_CURSOR = """
kanon 1

data
  seller : text !
  note   : text
  price  : money !

text

: preamble <- seller
Preâmbulo de {seller}[, com {note}] a {price:code}.

:: payment
Conforme {::payment}, paga-se {price}.

rules
  payment  when note is present
"""

"O hover na linha `l` (1-based, como o arquivo) e coluna `c` (1-based)."
function hover_em(texto, l, c)
    s = sessao_com(texto)
    id = em(s, "textDocument/hover", l - 1, c - 1)
    r = resposta(rodar!(s), id).result
    r === nothing ? nothing : String(r.contents.value)
end

function def_em(texto, l, c)
    s = sessao_com(texto)
    id = em(s, "textDocument/definition", l - 1, c - 1)
    resposta(rodar!(s), id).result
end

@testset "o que está sob o cursor" begin
    @testset "uma interpolação diz o tipo e se o valor pode faltar" begin
        h = hover_em(MODELO_CURSOR, 11, 16)          # dentro de `{seller}`
        @test occursin("`{seller}`", h)
        @test occursin("tipo: `text`", h)
        @test occursin("o contrato garante que ele está presente", h)
    end

    @testset "um valor que pode faltar diz se está protegido" begin
        h = hover_em(MODELO_CURSOR, 11, 31)          # dentro de `{note}`, que está em grupo
        @test occursin("**pode faltar**", h)
        @test occursin("está dentro de um grupo", h)

        # e o mesmo campo, fora de grupo, diz o contrário
        h2 = hover_em("kanon 1\n\ndata\n  a : text\n\ntext\n\n: b\n{a}\n", 9, 2)
        @test occursin("**não** está dentro de nenhum grupo", h2)
    end

    @testset "o formatador nomeado aparece na resposta" begin
        h = hover_em(MODELO_CURSOR, 11, 41)          # dentro de `{price:code}`
        @test occursin("`{price:code}`", h)
        @test occursin("tipo: `money`", h)
    end

    @testset "a declaração de um campo lista os formatadores que ele aceita" begin
        h = hover_em(MODELO_CURSOR, 6, 4)            # sobre `price  : money !`
        @test occursin("campo do contrato", h)
        @test occursin("**obrigatório**", h)
        @test occursin("`code`", h) && occursin("`symbol`", h)
    end

    @testset "um campo opcional diz que a interpolação dele exige colchetes" begin
        h = hover_em(MODELO_CURSOR, 5, 4)            # sobre `note   : text`
        @test occursin("**opcional**", h)
        @test occursin("exige `[...]`", h)
    end

    @testset "uma remissão diz que número ela rende hoje" begin
        h = hover_em(MODELO_CURSOR, 14, 15)          # dentro de `{::payment}`
        @test occursin("remissão a `payment`", h)
        @test occursin("rende hoje o número `1`", h)
        @test occursin("renumera sozinha", h)
    end

    @testset "um bloco diz o sujeito, a regra e de que arquivo veio" begin
        h = hover_em(MODELO_CURSOR, 13, 3)           # sobre `:: payment`
        @test occursin("bloco `payment`", h)
        @test occursin("**condicional**", h)
        @test occursin("note is present", h)
        @test occursin("vem de `t.kanon`", h)

        h2 = hover_em(MODELO_CURSOR, 10, 3)          # sobre `: preamble <- seller`
        @test occursin("sujeito: `seller`", h2)
        @test occursin("sem regra: sai sempre", h2)
    end

    @testset "um grupo diz o que ele faz" begin
        h = hover_em(MODELO_CURSOR, 11, 22)          # o `[` do grupo
        @test occursin("grupo opcional", h)
    end

    @testset "sem árvore, o cursor não responde nada — e não quebra" begin
        @test hover_em("kanon 1\n\ntext\n\n: b\n{a\n", 6, 2) === nothing
    end
end

@testset "ir para a definição" begin
    @testset "de uma interpolação para a declaração do campo" begin
        loc = def_em(MODELO_CURSOR, 11, 16)          # `{seller}`
        @test loc.range.start.line == 3              # a linha 4, `seller : text !`
        @test String(loc.uri) == "file:///tmp/t.kanon"
    end

    @testset "de uma remissão para o cabeçalho do bloco" begin
        loc = def_em(MODELO_CURSOR, 14, 15)          # `{::payment}`
        @test loc.range.start.line == 12             # a linha 13, `:: payment`
    end

    @testset "do sujeito de um bloco para o campo que ele nomeia" begin
        loc = def_em(MODELO_CURSOR, 10, 3)
        @test loc.range.start.line == 3              # `seller`
    end

    @testset "no plano das regras o salto é o mesmo: do uso para a declaração" begin
        loc = def_em(MODELO_CURSOR, 17, 18)          # `note` em `payment  when note is present`
        @test loc.range.start.line == 4              # a linha 5, `note   : text`
    end

    @testset "o salto atravessa a fronteira do fragmento" begin
        # O campo está declarado no FRAGMENTO e usado no hospedeiro. A `Location` tem de
        # dizer o URI do fragmento, e não o do arquivo aberto — é a mesma informação que
        # a D-035 destravou, consumida por outra funcionalidade.
        dir = mktempdir()
        frag = joinpath(dir, "f.kanon")
        write(frag, "kanon 1\n\ndata\n  quem : text !\n\ntext\n\n: nota\nDo fragmento.\n")
        host = joinpath(dir, "h.kanon")
        texto = "kanon 1\n\ntext\n\n: a\nDe {quem}.\n\ninclude \"f.kanon\"\n"
        write(host, texto)

        uri = KanonLSP.uri_of(host)
        s = sessao_com(texto; uri = uri)
        id = em(s, "textDocument/definition", 5, 5; uri = uri)   # dentro de `{quem}`
        loc = resposta(rodar!(s), id).result

        @test String(loc.uri) == KanonLSP.uri_of(frag)
        @test String(loc.uri) != uri
        @test loc.range.start.line == 3                          # a linha 4 do fragmento
    end
end
