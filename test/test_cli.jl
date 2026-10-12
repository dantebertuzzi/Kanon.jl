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
        r = cli("render", MODELO_CLI, DADOS_CLI, "--today", "2026-03-12", "--budget", "bytes=10")
        @test r.codigo == Kanon.EXIT_RESOURCE
        @test occursin("[K4002]", r.err)
        @test occursin("--budget bytes=", r.err)        # a dica fala a língua de quem a lê
        @test isempty(r.out)
    end

    @testset "arquivo que não existe é erro de uso, não uma pilha de Julia" begin
        r = cli("check", joinpath(TMP, "nao-existe.kanon"))
        @test r.codigo == Kanon.EXIT_USAGE
        @test occursin("kanon:", r.err)
        @test !occursin("Stacktrace", r.err)
    end
end

@testset "CLI: o orçamento se ajusta pela linha de comando (#28)" begin
    comum = ("--today", "2026-03-12")
    r = cli("render", MODELO_CLI, DADOS_CLI, comum...)
    @test r.codigo == Kanon.EXIT_OK
    @test cli("render", MODELO_CLI, DADOS_CLI, comum..., "--budget", "nodes=1").codigo ==
          Kanon.EXIT_RESOURCE
    # e o teto alto devolve o mesmo documento: o orçamento não muda o texto, só o deixa sair
    alto = cli("render", MODELO_CLI, DADOS_CLI, comum..., "--budget", "nodes=5000000",
               "--budget", "bytes=1000000000", "--budget", "iterations=1000000")
    @test alto.codigo == Kanon.EXIT_OK
    @test alto.out == r.out

    # o check e o preview também montam o plano, e lá vivem as iterações
    rep = tmpfile("rep.kanon", "kanon 1\n\ndata\n  itens : text[] !\n\ntext\n\n: b <- itens\nItem.\n\n" *
                               "rules\n  b one for each itens\n")
    rep_dados = tmpfile("rep.json", "{\"itens\": [\"a\", \"b\", \"c\"]}")
    for cmd in ("check", "preview", "render")
        @test cli(cmd, rep, rep_dados, "--budget", "iterations=2").codigo == Kanon.EXIT_RESOURCE
        @test cli(cmd, rep, rep_dados, "--budget", "iterations=3").codigo == Kanon.EXIT_OK
    end

    @testset "o que não é limite é erro de uso, dizendo os que existem" for ruim in
            ("nodes", "nodes=", "nodes=0", "nodes=-3", "nodes=1e6", "depth=10", "tempo=5")
        r = cli("check", MODELO_CLI, "--budget", ruim)
        @test r.codigo == Kanon.EXIT_USAGE
        @test occursin("kanon:", r.err)
    end
    @test occursin("`nodes`, `bytes`, `iterations`", cli("check", MODELO_CLI, "--budget", "depth=10").err)
    @test occursin("duas vezes",
                   cli("check", MODELO_CLI, "--budget", "nodes=10", "--budget", "nodes=20").err)
    @test cli("check", MODELO_CLI, "--budget").codigo == Kanon.EXIT_USAGE
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

# --- a camada de domínio na linha de comando (D-058) -------------------------
#
# Descoberto pelo modelo real nº 11: `--locale` era a única opção de ambiente, e por isso
# a CLI não alcançava nenhum documento com camada de domínio — que são quase todos. Quem
# manda carregar é o **usuário**, na linha de comando, e nunca o modelo: um arquivo que
# pudesse nomear o pacote a carregar seria dado não confiável mandando executar código
# (invariante 4).

@testset "CLI: --domain carrega a camada, e só o usuário a pede" begin
    @testset "camada que não está no ambiente é erro de uso" begin
        r = cli("check", MODELO_CLI, "--domain", "KanonInexistente")
        @test r.codigo == Kanon.EXIT_USAGE
        @test occursin("não está disponível neste ambiente Julia", r.err)
        @test occursin("Pkg.add", r.err)
        @test !occursin("Stacktrace", r.err)
    end

    @testset "a mesma camada duas vezes é erro de uso" begin
        r = cli("check", MODELO_CLI, "--domain", "A", "--domain", "A")
        @test r.codigo == Kanon.EXIT_USAGE
        @test occursin("duas vezes", r.err)
    end

    @testset "`--domain` sem nome é erro de uso" begin
        @test cli("check", MODELO_CLI, "--domain").codigo == Kanon.EXIT_USAGE
    end

    @testset "idioma sem camada é erro de uso, e diz o que digitar (D-068)" begin
        # "carregue o pacote" é a forma de quem está dentro de Julia; na linha de comando
        # o pacote do idioma se carrega com `--domain`, como qualquer camada.
        r = cli("check", MODELO_CLI, "--locale", "zz")
        @test r.codigo == Kanon.EXIT_USAGE
        @test occursin("o idioma `zz` não tem camada carregada", r.err)
        @test occursin("--locale zz --domain NOME", r.err)
        @test !occursin("Stacktrace", r.err)
    end

    @testset "um módulo sem `configure!` carrega e não muda nada" begin
        # `Dates` é um módulo Julia que não é camada de Kanon: a §5 diz que o construtor
        # chama `configure!` de quem o define, e passa adiante quem não o define.
        r = cli("check", MODELO_CLI, "--domain", "Dates")
        @test r.codigo == Kanon.EXIT_OK
    end
end

@testset "CLI: o arquivo `chave = valor` não adivinha `1.320` (D-084)" begin
    # Num idioma em que o ponto separa os milhares, `drenagem = 1.320` tem duas leituras.
    # O arquivo lia `1.32`, e o documento saía com `1,32` onde o autor escreveu mil trezentos
    # e vinte — o mesmo defeito que a D-069 tirou do `ask`, pelo outro caminho dos dados.
    env = Environment(locale = :xx)
    modelo = tmpfile("drenagem.kanon", """
    kanon 1 xx

    dados
      drenagem : number !
      processo : text !

    texto

    : b
    {drenagem} m, processo {processo}.
    """)
    roda(cmd, dados) = begin
        o, e = IOBuffer(), IOBuffer()
        c = Kanon.main(String[cmd, modelo, tmpfile("drenagem.kdata", dados)];
                       out = o, err = e, env = env)
        (codigo = c, out = String(take!(o)), err = String(take!(e)))
    end

    r = roda("render", "drenagem = 1.320\nprocesso = \"7\"\n")
    @test r.codigo == Kanon.EXIT_CONTRACT
    @test isempty(r.out)
    @test occursin("`1.320` é ambíguo", r.err)
    @test occursin("Escreva `1320` se é o número inteiro, ou `1.32` se é decimal", r.err)

    # as duas grafias que a mensagem manda escrever passam, e dizem o que dizem
    @test roda("render", "drenagem = 1320\nprocesso = \"7\"\n").out == "1.320 m, processo 7.\n"
    @test roda("render", "drenagem = 1.32\nprocesso = \"7\"\n").out == "1,32 m, processo 7.\n"

    # a forma do documento vem com a forma de entrada pronta
    r = roda("check", "drenagem = 12.480,50\nprocesso = \"7\"\n")
    @test occursin("sem separador de milhar na entrada: `12480.50`", r.err)

    # no campo de texto, a mesma grafia é o que o autor escreveu, e é o que sai
    @test roda("render", "drenagem = 1320\nprocesso = 1.320\n").out == "1.320 m, processo 1.320.\n"

    # sem idioma não há separador de milhar, e `1.320` só tem uma leitura
    @test Kanon.read_data(tmpfile("n.kdata", "n = 1.320\n"))["n"] == 1.32
end
