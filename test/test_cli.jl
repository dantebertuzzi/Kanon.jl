# A interface de linha de comando (F3, §12).
#
# `Kanon.main` recebe os fluxos como argumento e devolve o código de saída, em vez de
# encerrar o processo. É o que permite testar os cinco códigos sem processo filho.

const TMP = mktempdir()

"Escreve um arquivo no diretório temporário da suíte e devolve o caminho."
function tmpfile(nome, conteudo)
    caminho = joinpath(TMP, nome)
    write(caminho, conteudo)
    caminho
end

const MODELO_CLI = tmpfile("m.kanon", """
kanon 1

data
  nome  : text !
  preco : number !
  nota  : text
  data  : date = today

text

: b
{nome} paga {preco}[, com a nota {nota}], em {data}.
""")

const DADOS_CLI = tmpfile("d.kdata", """
# comentário
nome = "Ana"
preco = 1200
nota = null
""")

"Roda a CLI capturando stdout, stderr e o código de saída."
function cli(args...)
    o, e = IOBuffer(), IOBuffer()
    codigo = Kanon.main(String[args...]; out = o, err = e)
    (codigo = codigo, out = String(take!(o)), err = String(take!(e)))
end

@testset "CLI: os comandos" begin
    @testset "render escreve o documento" begin
        r = cli("render", MODELO_CLI, DADOS_CLI, "--today", "2026-03-12")
        @test r.codigo == Kanon.EXIT_OK
        @test strip(r.out) == "Ana paga 1200, em 2026-03-12."
    end

    @testset "-o escreve em arquivo" begin
        alvo = joinpath(TMP, "saida.md")
        r = cli("render", MODELO_CLI, DADOS_CLI, "--today", "2026-03-12", "-o", alvo)
        @test r.codigo == Kanon.EXIT_OK
        @test isempty(r.out)
        @test strip(read(alvo, String)) == "Ana paga 1200, em 2026-03-12."
    end

    @testset "check sem dados valida só o modelo" begin
        r = cli("check", MODELO_CLI)
        @test r.codigo == Kanon.EXIT_OK
        @test occursin("modelo válido", r.err)
    end

    @testset "check com dados valida os dois" begin
        r = cli("check", MODELO_CLI, DADOS_CLI, "--today", "2026-03-12")
        @test r.codigo == Kanon.EXIT_OK
        @test occursin("válidos", r.err)
    end

    @testset "contract emite o checklist" begin
        r = cli("contract", MODELO_CLI)
        @test r.codigo == Kanon.EXIT_OK
        @test occursin("json-schema.org/draft/2020-12", r.out)
        @test occursin("\"nome\"", r.out)
    end
end

@testset "CLI: os cinco códigos de saída (§12)" begin
    @testset "0 — sucesso" begin
        @test cli("render", MODELO_CLI, DADOS_CLI, "--today", "2026-03-12").codigo == 0
    end

    @testset "1 — erro de contrato: os dados não bastam" begin
        vazio = tmpfile("vazio.kdata", "nome = \"Ana\"\n")
        r = cli("render", MODELO_CLI, vazio, "--today", "2026-03-12")
        @test r.codigo == Kanon.EXIT_CONTRACT
        @test occursin("[K3001]", r.err)
        @test isempty(r.out)          # nada de documento pela metade
    end

    @testset "2 — erro de modelo: sintaxe" begin
        ruim = tmpfile("ruim.kanon", "kanon 1\n\ntext\n\n: b\n{nao_fecha\n")
        r = cli("check", ruim)
        @test r.codigo == Kanon.EXIT_MODEL
        @test occursin("sintaxe", r.err)
    end

    @testset "2 — erro de modelo: referência" begin
        ruim = tmpfile("ref.kanon", "kanon 1\n\ndata\n  a : text !\n\ntext\n\n: b\n{b}\n")
        r = cli("check", ruim)
        @test r.codigo == Kanon.EXIT_MODEL
        @test occursin("[K2001]", r.err)
    end

    @testset "3 — erro de uso" begin
        @test cli().codigo == Kanon.EXIT_USAGE
        @test cli("inventado", MODELO_CLI).codigo == Kanon.EXIT_USAGE
        @test cli("render", MODELO_CLI).codigo == Kanon.EXIT_USAGE       # faltam dados
        @test cli("check").codigo == Kanon.EXIT_USAGE                    # falta o modelo
        @test cli("check", MODELO_CLI, "-x").codigo == Kanon.EXIT_USAGE
        @test cli("check", MODELO_CLI, "--today", "12/03/2026").codigo == Kanon.EXIT_USAGE
        @test cli("check", MODELO_CLI, "--locale", "zz").codigo == Kanon.EXIT_USAGE
    end

    @testset "4 — recurso" begin
        # o orçamento não é exposto na CLI ainda; a garantia é que o código existe e é
        # o que `render` produz quando o orçamento estoura
        m = load_string(Environment(), "kanon 1\n\ndata\n  a : text !\n\ntext\n\n: b\n{a}\n";
                        name = "t")
        e = try; render(m, Dict("a" => "x"); budget = Budget(bytes = 0)); catch err; err; end
        @test e isa KanonResourceError
        @test Kanon.EXIT_RESOURCE == 4
    end

    @testset "arquivo que não existe é erro de uso, não uma pilha de Julia" begin
        r = cli("check", joinpath(TMP, "nao-existe.kanon"))
        @test r.codigo == Kanon.EXIT_USAGE
        @test occursin("kanon:", r.err)
        @test !occursin("Stacktrace", r.err)
    end
end

@testset "CLI: preview é o único que produz saída incompleta (§12)" begin
    faltando = tmpfile("falta.kdata", "preco = 1200\n")

    @testset "sai com 0 mesmo faltando campo, e marca o que falta" begin
        r = cli("preview", MODELO_CLI, faltando, "--today", "2026-03-12")
        @test r.codigo == Kanon.EXIT_OK
        @test occursin("«nome»", r.out)
        @test occursin("[K3001]", r.err)          # o que falta vai para o stderr
        @test occursin("rascunho", r.err)
    end

    @testset "o aviso de não exportar é sempre escrito" begin
        r = cli("preview", MODELO_CLI, DADOS_CLI, "--today", "2026-03-12")
        @test r.codigo == Kanon.EXIT_OK
        @test occursin("não exporte", r.err)
        @test !occursin("«", r.out)               # nada faltando: sem marcador
    end

    @testset "preview não relaxa o motor: render continua recusando" begin
        r = cli("render", MODELO_CLI, faltando, "--today", "2026-03-12")
        @test r.codigo == Kanon.EXIT_CONTRACT
    end

    @testset "o marcador vive no texto, não nos dados" begin
        # `«preco»` não é um `money`: injetá-lo como dado faria o rascunho falhar
        # exatamente onde ele precisa funcionar
        m = load_string(Environment(), """
kanon 1

data
  p : money !
  n : text
  d : date !

text

: b
{p}[, nota {n}], em {d}.
"""; name = "t")
        s = preview(m, Dict())
        @test s == "«p», em «d»."
        # o campo nulável que falta continua elidindo, como faria no documento de verdade
        @test !occursin("«n»", s)
        # e o valor que veio é formatado normalmente
        @test preview(m, Dict("p" => Money("10.00", :BRL))) == "BRL 10.00, em «d»."
    end

    @testset "today sem injeção também vira marcador no rascunho" begin
        m = load_string(Environment(), "kanon 1\n\ntext\n\n: b\nEm {today}.\n"; name = "t")
        @test preview(m, Dict()) == "Em «today»."
        @test render(m, Dict(); today = Date(2026, 1, 1)) == "Em 2026-01-01."
    end
end

@testset "CLI: ajuda e versão" begin
    @test cli("--help").codigo == Kanon.EXIT_OK
    @test occursin("kanon render", cli("--help").out)
    @test occursin("kanon 1.0", cli("--version").out)
    @test occursin("kanon check", cli().err)      # sem argumento, a ajuda vai ao stderr
end
