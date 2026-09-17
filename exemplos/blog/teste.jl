# A prova de fogo: os erros que um redator comete, plantados numa cópia de `conteudo/`.
#
#     julia --project teste.jl
#
# Cada caso é uma edição que alguém que não programa faria de verdade, e a pergunta é
# sempre a mesma: o site deixa de ser construído, e a mensagem diz o arquivo e o que
# corrigir? No Jekyll com Liquid, quase todos estes casos publicam — sem a descrição, sem
# a assinatura, com a data errada — e ninguém fica sabendo.

using Test
include(joinpath(@__DIR__, "construir.jl"))

"Constrói uma cópia de `conteudo/` depois de `editar!(pasta)`, sem escrever o site."
function construir_com(editar!)
    mktempdir() do dir
        copia = joinpath(dir, "conteudo")
        cp(CONTEUDO, copia)
        editar!(copia)
        io = IOBuffer()
        r = construir(; conteudo = copia, escrever = false, io)
        (; r.ok, r.paginas, r.problemas, saida = String(take!(io)))
    end
end

"Troca um trecho de um arquivo da cópia; falha se o trecho não estiver lá."
function trocar!(pasta, arquivo, de, para)
    caminho = joinpath(pasta, arquivo)
    texto = read(caminho, String)
    occursin(de, texto) || error("`$de` não está em $arquivo")
    write(caminho, replace(texto, de => para; count = 1))
end

const DESVIO = "posts/2026-05-06-desvio-padrao.md"
const MEDIANA = "posts/2026-05-21-mediana.md"

"O problema grave que menciona `trecho`, no arquivo `arquivo`."
recusa(r, arquivo, trecho) =
    any(p -> p.grave && endswith(p.arquivo, arquivo) && occursin(trecho, p.mensagem * something(p.dica, "")),
        r.problemas)

@testset "o blog em Franklin, com o Kanon como contrato" begin

    @testset "o conteúdo como está constrói, e o rascunho fica de fora" begin
        r = construir_com(identity)
        @test r.ok
        @test isempty(r.problemas)
        @test sort(collect(keys(r.paginas))) == ["index.md", "posts/desvio-padrao.md",
            "posts/intervalo-interquartil.md", "posts/media.md", "posts/mediana.md",
            "posts/standard-deviation.md", "posts/variancia.md", "sobre.md"]

        post = r.paginas["posts/mediana.md"]
        @test occursin("em 21 de maio de 2026; atualizado em 2 de junho de 2026.", post)
        @test occursin("Etiquetas: Estatística e Medidas de posição.", post)
        @test !occursin("Também em inglês", post)            # sem `ref`, o grupo sai inteiro

        # a tradução é achada pelo `ref`, nos dois sentidos, e o post em inglês não tem
        # data por extenso: não existe camada de idioma inglesa
        @test occursin("""Também em inglês: <a href="/posts/standard-deviation/">""", r.paginas["posts/desvio-padrao.md"])
        @test occursin("""Also in Portuguese: <a href="/posts/desvio-padrao/">""", r.paginas["posts/standard-deviation.md"])
        @test occursin("By <strong>Dante Bertuzzi</strong>, 2026-05-06.", r.paginas["posts/standard-deviation.md"])

        # a inicial lista os posts em português, do mais novo ao mais antigo
        inicio = r.paginas["index.md"]
        i, j, k = (findfirst(t, inicio).start for t in ("Mediana:", "Média:", "Desvio padrão"))
        @test i < j < k
        @test !occursin("Standard deviation", inicio)
        @test !occursin("Moda", inicio)
    end

    @testset "os cards: o que o Liquid fazia com `forloop`, e o que o Kanon escreve" begin
        r = construir_com(identity)
        inicio = r.paginas["index.md"]
        cards = collect(eachmatch(r"<article class=\"card( post-oculto)?\">(.*?)</article>"s, inicio))
        @test length(cards) == 5
        # o selo só no mais novo
        @test occursin("<strong>Novo</strong>", cards[1].captures[2])
        @test count("<strong>Novo</strong>", inicio) == 1
        # os três primeiros à vista, o resto escondido, e o botão porque há mais que três
        @test [c.captures[1] === nothing for c in cards] == [true, true, true, false, false]
        @test occursin("""<button type="button" id="mostrar-mais" hidden>""", inicio)
        # a imagem é um grupo: o card sem imagem não tem `<img>` nenhum
        @test occursin("<img src=\"/assets/imagens/diagrama-de-caixa.svg\"", cards[1].captures[2])
        @test !occursin("<img", cards[2].captures[2])
        # sem `descricao`, o resumo são as primeiras 20 palavras do corpo, sem a marcação
        @test occursin("A variância é a média dos quadrados dos afastamentos até a média. É o número que existe antes da raiz…",
                       cards[2].captures[2])

        # com três posts ou menos, não há botão
        menos = construir_com(c -> foreach(f -> rm(joinpath(c, "posts", f)),
            ["2026-06-10-variancia.md", "2026-06-24-intervalo-interquartil.md"]))
        @test menos.ok
        @test !occursin("mostrar-mais", menos.paginas["index.md"])
    end

    @testset "o título com aspas e sinais não quebra o card" begin
        # O Kanon escapa para CommonMark, e o CommonMark.jl escreve o `alt` e o texto: o
        # título chega inteiro, e nada dele vira HTML.
        r = construir_com(c -> trocar!(c, "posts/2026-06-24-intervalo-interquartil.md",
            "titulo = \"Intervalo interquartil: a dispersão que ignora os extremos\"",
            "titulo = \"O \\\"meio\\\" <b>dos</b> dados\""))
        @test r.ok
        inicio = r.paginas["index.md"]
        @test occursin("alt=\"O &quot;meio&quot; &lt;b&gt;dos&lt;/b&gt; dados\"", inicio)
        @test occursin(">O &quot;meio&quot; &lt;b&gt;dos&lt;/b&gt; dados</a>", inicio)
        @test !occursin("<b>dos</b>", inicio)
    end

    @testset "a imagem que não existe, e a que não é imagem" begin
        IIQ = "posts/2026-06-24-intervalo-interquartil.md"
        r = construir_com(c -> trocar!(c, IIQ, "diagrama-de-caixa.svg", "diagrama-da-caixa.svg"))
        @test !r.ok
        @test recusa(r, IIQ, "a imagem `/assets/imagens/diagrama-da-caixa.svg` não existe")

        r = construir_com(c -> trocar!(c, IIQ, "\"/assets/imagens/diagrama-de-caixa.svg\"", "\"javascript:alert(1)\""))
        @test !r.ok
        @test recusa(r, IIQ, "não é uma imagem deste site")
    end

    @testset "o título que faltou" begin
        r = construir_com(c -> trocar!(c, DESVIO, "titulo = \"Desvio padrão explicado sem mistério\"\n", ""))
        @test !r.ok
        @test recusa(r, DESVIO, "titulo")
        # o post recusado não entra na lista da inicial — ele não existe
        @test !haskey(r.paginas, "posts/desvio-padrao.md")
    end

    @testset "o autor que não existe" begin
        r = construir_com(c -> trocar!(c, MEDIANA, "\"dante-bertuzzi\"", "\"dante-bertuzi\""))
        @test !r.ok
        @test recusa(r, MEDIANA, "não há autor `dante-bertuzi`")
        @test recusa(r, MEDIANA, "`dante-bertuzzi`")          # a lista dos que existem
    end

    @testset "o nome do campo com acento" begin
        # O TOML não aceita acento num nome sem aspas, e a recusa vem antes do Kanon.
        r = construir_com(c -> trocar!(c, MEDIANA, "descricao =", "descrição ="))
        @test !r.ok
        @test recusa(r, MEDIANA, "linha 3 do arquivo")
        @test recusa(r, MEDIANA, "sem acento, como `descricao`")
    end

    @testset "o nome do campo digitado errado" begin
        # O Liquid publicaria o post sem descrição. O Kanon ignora o campo com aviso (K3021),
        # e o site trata esse aviso como erro.
        r = construir_com(c -> trocar!(c, MEDIANA, "descricao =", "descricoa ="))
        @test !r.ok
        @test recusa(r, MEDIANA, "`descricoa`")
        @test recusa(r, MEDIANA, "`descricao`")               # a sugestão do nome certo
    end

    @testset "a data escrita do jeito brasileiro" begin
        r = construir_com(c -> trocar!(c, MEDIANA, "atualizado = 2026-06-02", "atualizado = \"02/06/2026\""))
        @test !r.ok
        @test recusa(r, MEDIANA, "aaaa-mm-dd")
    end

    @testset "o texto sem aspas" begin
        r = construir_com(c -> trocar!(c, MEDIANA, "serie = \"Medidas de posição\"", "serie = Medidas de posição"))
        @test !r.ok
        @test recusa(r, MEDIANA, "linha 7 do arquivo")
        @test recusa(r, MEDIANA, "entre aspas")
    end

    @testset "a lista de etiquetas vazia" begin
        r = construir_com(c -> trocar!(c, MEDIANA, "tags = [\"Estatística\", \"Medidas de posição\"]", "tags = []"))
        @test !r.ok
        @test recusa(r, MEDIANA, "tags")
    end

    @testset "a data do nome do arquivo e a do cabeçalho discordam" begin
        r = construir_com(c -> trocar!(c, MEDIANA, "data = 2026-05-21", "data = 2026-05-12"))
        @test !r.ok
        @test recusa(r, MEDIANA, "o nome do arquivo diz 2026-05-21")
    end

    @testset "o cifrão sem contrabarra" begin
        r = construir_com(c -> trocar!(c, MEDIANA, "R\\\$ 150", "R\$ 150"))
        @test !r.ok
        @test recusa(r, MEDIANA, "linha 25")
        @test recusa(r, MEDIANA, "R\\\$ 3.000")
    end

    @testset "o `ref` que não é texto" begin
        r = construir_com(c -> trocar!(c, DESVIO, "ref = \"desvio-padrao\"", "ref = 12"))
        @test !r.ok
        @test recusa(r, DESVIO, "`ref`")
    end

    @testset "a descrição em branco é aviso, e o grupo sai inteiro" begin
        r = construir_com(c -> trocar!(c, MEDIANA,
            "descricao = \"Como encontrar a mediana com número par e ímpar de valores, e por que ela resiste aos extremos.\"",
            "descricao = \"\""))
        @test r.ok
        @test any(p -> !p.grave && endswith(p.arquivo, MEDIANA), r.problemas)
        @test !occursin("<p><em></em></p>", r.paginas["posts/mediana.md"])
    end

    @testset "o rascunho aparece na pré-visualização, com o que falta marcado" begin
        mktempdir() do dir
            copia = joinpath(dir, "conteudo")
            cp(CONTEUDO, copia)
            r = construir(; conteudo = copia, escrever = false, servir = true, io = devnull)
            @test r.ok
            moda = r.paginas["posts/moda.md"]
            @test occursin("Por <strong>«autor»</strong>, em «data».", moda)
            @test !occursin("Moda", r.paginas["index.md"])     # e nem assim entra na inicial
        end
    end

    @testset "o rascunho com valor errado avisa, e não se confunde com o que falta" begin
        # «data» na pré-visualização dizia as duas coisas ao mesmo tempo: "ainda não
        # escrevi" e "escrevi e foi recusado". A primeira é o rascunho funcionando; a
        # segunda o redator só descobria ao tirar o `rascunho`.
        # só na pré-visualização: publicando, o rascunho nem é lido
        servindo(editar!) = mktempdir() do dir
            copia = joinpath(dir, "conteudo")
            cp(CONTEUDO, copia)
            editar!(copia)
            construir(; conteudo = copia, escrever = false, servir = true, io = devnull)
        end

        r = servindo(c -> trocar!(c, "posts/2026-09-16-moda.md", "rascunho = true",
                                  "rascunho = true\ndata = \"ontem\""))
        @test r.ok                                   # o rascunho não derruba o site
        avisos = [p for p in r.problemas if endswith(p.arquivo, "moda.md")]
        @test !isempty(avisos)
        @test all(p -> !p.grave, avisos)
        @test any(p -> occursin("`data`", p.mensagem), avisos)
        # e o que apenas falta continua calado: é para isso que o rascunho serve
        @test isempty([p for p in servindo(identity).problemas if endswith(p.arquivo, "moda.md")])
    end

    @testset "o cifrão do peso uruguaio também é achado" begin
        # `(R|US|U\$S)?\$` nunca casava `U$S`: o cifrão dele é o do meio, e a alternativa
        # exigia outro depois. No Franklin ele abre fórmula do mesmo jeito.
        r = construir_com(c -> trocar!(c, MEDIANA, "R\\\$ 150", "U\$S 150"))
        @test !r.ok
        @test recusa(r, MEDIANA, "U\$S")
    end

    @testset "o título com cifrão não executa nada no Franklin" begin
        r = construir_com(c -> trocar!(c, MEDIANA, "titulo = \"Mediana: o centro que não se mexe\"",
                                       "titulo = \"Mediana: \$(run(`false`))\""))
        @test r.ok
        @test occursin("title = \"Mediana: \\\$(run(`false`))\"", r.paginas["posts/mediana.md"])
    end
end
