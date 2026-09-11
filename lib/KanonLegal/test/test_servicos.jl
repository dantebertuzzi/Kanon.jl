# O contrato de prestação de serviços — **modelo real nº 11** do portão da 1.0.
#
# Escolhido pelo caminho que o documento percorre **antes de estar pronto**. Dez modelos
# reais foram escritos, e todos renderizam de uma vez, com os dados completos, chamados
# de dentro de Julia. Três interseções estavam vazias, e são as três que este documento
# atravessa:
#
#   1. o **rascunho** de um documento de verdade — com camada de domínio, bloco repetido,
#      grupos opcionais e remissão —, e não os campos de um modelo de teste;
#   2. a **linha de comando**, que é como o redator chega ao motor;
#   3. um **golden em Markdown**, que o acervo não tinha.
#
# Cobrou duas coisas, e a segunda estava escondida atrás da primeira:
#
#   * **D-057** — um bloco repetido sobre coleção **garantida** ausente sumia do
#     rascunho. O contrato promete ao menos uma cópia, e o rascunho mostrava zero: a
#     minuta escondia justamente a parte que o redator abriu o rascunho para ver.
#   * **D-058** — a CLI **não tinha como carregar uma camada de domínio**. `--locale` era
#     a única opção de ambiente, e por isso nenhum dos dez modelos reais anteriores podia
#     ser processado pela linha de comando: todos, menos um, usam camada.
#
# E uma divergência que **não** era defeito do motor: o golden em Markdown foi escrito à
# mão com `R$ 42.000,00`, e o motor escreve `R\$`. O motor está certo — o cifrão abre
# matemática em Pandoc e no GitHub, e escapado é literal nos três dialetos. O comentário
# do `output.jl` é que citava `R\$` como exemplo de ruído desnecessário, contradizendo a
# tabela ao lado.

const SERVICOS = joinpath(RAIZ, "test", "golden", "exemplos", "servicos.kanon")
const EX_SERV = joinpath(RAIZ, "test", "golden", "exemplos")
const ENV_SERV = Environment(locale = :pt, domains = [KanonLegal])
const HOJE_S = Date(2026, 9, 11)

"Roda a CLI capturando os fluxos, como `test_cli.jl` faz no núcleo."
function cli_serv(args...)
    o, e = IOBuffer(), IOBuffer()
    codigo = Kanon.main(String[args...]; out = o, err = e)
    (codigo = codigo, out = String(take!(o)), err = String(take!(e)))
end

@testset "o contrato de prestação de serviços — modelo real nº 11" begin
    m = load_template(ENV_SERV, SERVICOS)
    dados = Kanon.read_json(joinpath(EX_SERV, "servicos.json"))
    minuta = Kanon.read_json(joinpath(EX_SERV, "servicos.minuta.json"))
    saida = render(m, dados; today = HOJE_S)

    @testset "o modelo carrega sem um único diagnóstico" begin
        isempty(m.analysis.diagnostics) ||
            error("o modelo não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(m.analysis.diagnostics)))
        @test isempty(m.analysis.diagnostics)
        @test isempty(check(m, dados; today = HOJE_S))
    end

    @testset "byte a byte" begin
        esperado = rstrip(read(joinpath(EX_SERV, "servicos.txt"), String), '\n')
        saida == esperado || println(saida)
        @test saida == esperado
    end

    @testset "byte a byte em Markdown" begin
        md = render(m, dados; today = HOJE_S, to = :markdown)
        esperado = rstrip(read(joinpath(EX_SERV, "servicos.md"), String), '\n')
        md == esperado || println(md)
        @test md == esperado

        # o rótulo da camada atravessa intacto — é a única parte que o motor calcula, e
        # `CLÁUSULA PRIMEIRA. ` não é lista para o renderizador redefinir (D-044)
        @test occursin("CLÁUSULA PRIMEIRA. Constitui objeto", md)
        @test occursin("PARÁGRAFO SEGUNDO. Integra o objeto", md)

        # e o valor é escapado: `A_2` é um prédio, e abriria ênfase; `R$` abre
        # matemática em Pandoc e no GitHub
        @test occursin("edifício A\\_2 do campus", md)
        @test occursin("R\\\$ 42.000,00", md)
        @test occursin("edifício A_2 do campus", saida)      # e o texto puro não escapa
        @test occursin("R\$ 42.000,00", saida)
    end

    @testset "o rascunho, byte a byte" begin
        r = preview(m, minuta; today = HOJE_S)
        esperado = rstrip(read(joinpath(EX_SERV, "servicos.rascunho.txt"), String), '\n')
        r == esperado || println(r)
        @test r == esperado
    end

    @testset "o bloco repetido aparece no rascunho da coleção garantida (D-057)" begin
        r = preview(m, minuta; today = HOJE_S)
        # `entregas : texto[1..] !` — o documento terá ao menos uma, e o rascunho a mostra
        @test occursin("PARÁGRAFO PRIMEIRO. Integra o objeto a entrega seguinte: " *
                       "«entregas»,", r)
        @test count("PARÁGRAFO", r) == 1
        # e o valor garantido que falta vira marcador, inclusive nas duas grafias do
        # mesmo campo (D-024)
        @test occursin("a importância de «valor» («valor»)", r)
        @test occursin("contados de «inicio»,", r)
        # o que é opcional continua elidindo, como elidiria no documento
        @test !occursin("«garantia»", r) && !occursin("«responsavel»", r)
        @test occursin("do edifício A_2 do campus.", r)
        @test occursin("em seis parcelas mensais e sucessivas.", r)

        # a outra metade da decisão: coleção **opcional** ausente não ganha cópia, porque
        # o documento pronto pode não ter nenhuma
        fonte = replace(read(SERVICOS, String), "entregas    : texto[1..] !" =>
                                                "entregas    : texto[]     ")
        m2 = load_string(ENV_SERV, fonte; name = "s.kanon")
        r2 = preview(m2, minuta; today = HOJE_S)
        @test !occursin("PARÁGRAFO", r2)
        @test !occursin("«entregas»", r2)
    end

    @testset "o rascunho não relaxa o motor" begin
        # os mesmos dados que o rascunho aceita, o render recusa — é comando à parte, e
        # não modo leniente
        e = try; render(m, minuta; today = HOJE_S); catch err; err; end
        @test e isa KanonContractError
        @test "K3001" in Set(d.code for d in e.diagnostics)
    end

    @testset "a CLI alcança um documento com camada de domínio (D-058)" begin
        modelo, completos = SERVICOS, joinpath(EX_SERV, "servicos.json")
        incompletos = joinpath(EX_SERV, "servicos.minuta.json")
        base = ("--locale", "pt", "--domain", "KanonLegal", "--today", "2026-09-11")

        @testset "render escreve o documento, e em Markdown" begin
            r = cli_serv("render", modelo, completos, base...)
            @test r.codigo == Kanon.EXIT_OK
            @test rstrip(r.out, '\n') == rstrip(read(joinpath(EX_SERV, "servicos.txt"), String), '\n')

            md = cli_serv("render", modelo, completos, base..., "--to", "markdown")
            @test md.codigo == Kanon.EXIT_OK
            @test rstrip(md.out, '\n') == rstrip(read(joinpath(EX_SERV, "servicos.md"), String), '\n')
        end

        @testset "preview sai com 0 e avisa no stderr; render dos mesmos dados sai com 1" begin
            r = cli_serv("preview", modelo, incompletos, base...)
            @test r.codigo == Kanon.EXIT_OK
            @test rstrip(r.out, '\n') ==
                  rstrip(read(joinpath(EX_SERV, "servicos.rascunho.txt"), String), '\n')
            @test occursin("[K3001]", r.err)
            @test occursin("rascunho", r.err)

            r2 = cli_serv("render", modelo, incompletos, base...)
            @test r2.codigo == Kanon.EXIT_CONTRACT
            @test isempty(r2.out)                    # e não escreve documento nenhum
        end

        @testset "sem a camada, o mesmo modelo é recusado com o código do modelo" begin
            r = cli_serv("check", modelo, "--locale", "pt")
            @test r.codigo == Kanon.EXIT_MODEL
            @test occursin("[K2005]", r.err)
            # e a dica diz como carregá-la **na linha de comando**, que é onde o autor está
            @test occursin("--domain", r.err)
        end

        @testset "camada que não existe é erro de uso, e não uma pilha de Julia" begin
            r = cli_serv("check", modelo, "--locale", "pt", "--domain", "KanonInventado")
            @test r.codigo == Kanon.EXIT_USAGE
            @test occursin("não está disponível neste ambiente Julia", r.err)
            @test !occursin("Stacktrace", r.err)
        end

        @testset "a mesma camada pedida duas vezes é erro de uso" begin
            r = cli_serv("check", modelo, "--locale", "pt",
                         "--domain", "KanonLegal", "--domain", "KanonLegal")
            @test r.codigo == Kanon.EXIT_USAGE
            @test occursin("duas vezes", r.err)
        end

        @testset "o checklist sai pela CLI, e conhece os tipos da camada" begin
            r = cli_serv("contract", modelo, base...)
            @test r.codigo == Kanon.EXIT_OK
            @test occursin("\"x-kanon\"", r.out)
            @test occursin("pessoa", r.out)
        end
    end
end
