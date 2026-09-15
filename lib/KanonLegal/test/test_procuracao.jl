# A procuração ad judicia et extra — **modelo real nº 12** do portão da 1.0.
#
# Escolhida pela porta por onde os dados entram no balcão: as partes vêm do cadastro, num
# JSON; o resto o atendente digita respondendo ao `kanon ask`; e o documento sai em Typst
# para virar PDF. Nenhum dos onze modelos anteriores tinha passado pelo `ask`, pelo
# `bin/kanon` num processo novo, nem por um Typst com camada de domínio.
#
# Cobrou quatro coisas, e as duas primeiras desfazem uma correção dada como feita:
#
#   * **D-059** — o `--domain` da D-058 carregava a camada num mundo que o resto da
#     execução não enxergava. Pelo `bin/kanon` de verdade, `--locale pt --domain
#     KanonLegal` saía com "o idioma `pt` não tem camada carregada". A suíte da D-058
#     passava porque o `runtests.jl` já tinha feito `using KanonLegal`.
#   * **D-060** — o `bin/kanon` não carrega o JSON3, e um `.json` — o único formato de
#     dados que carrega uma `pessoa` — saía como **pilha de Julia**. Somadas, as duas
#     deixavam a linha de comando sem alcançar documento jurídico nenhum.
#   * **D-061** — o `ask` emitia `outorgado = Dict{String, Any}(...)`, que o `render`
#     recusava; nunca perguntava o opcional, que é onde a procuração varia; e conferia a
#     resposta só depois da última pergunta, sem dizer a forma em que ela se escreve.
#   * **D-062** — no Typst, `//` num valor começa um comentário e apaga o resto da linha;
#     `~` e `-?` também somem. Achado ao compilar este golden com o Typst 0.15.1.
#
# Os goldens foram gerados pelo `bin/kanon`, lidos linha a linha, e o `.typ` compilado
# pelo Typst: o texto do PDF é o do `.txt`.

const PROCURACAO = joinpath(RAIZ, "test", "golden", "exemplos", "procuracao.kanon")
const EX_PROC = joinpath(RAIZ, "test", "golden", "exemplos")
const HOJE_P = Date(2026, 9, 13)
const BASE_P = ("--locale", "pt", "--domain", "KanonLegal", "--today", "2026-09-13")

exemplo_p(nome) = joinpath(EX_PROC, nome)
lido_p(nome) = rstrip(read(exemplo_p(nome), String), '\n')

function cli_proc(args...; entrada = "")
    o, e = IOBuffer(), IOBuffer()
    codigo = Kanon.main(String[args...]; out = o, err = e, input = IOBuffer(entrada))
    (codigo = codigo, out = String(take!(o)), err = String(take!(e)))
end

"Tira as contrabarras de escape do Typst — o que sobra tem de ser o texto puro."
desescapa_typst(s) = replace(s, r"\\(.)" => s"\1")

@testset "a procuração ad judicia — modelo real nº 12" begin
    m = load_template(ENV_LEGAL, PROCURACAO)
    dados = Kanon.read_json(exemplo_p("procuracao.json"))
    respostas = read(exemplo_p("procuracao.respostas.txt"), String)

    @testset "o modelo carrega sem um único diagnóstico" begin
        isempty(m.analysis.diagnostics) ||
            error("o modelo não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(m.analysis.diagnostics)))
        @test isempty(m.analysis.diagnostics)
        @test isempty(check(m, dados; today = HOJE_P))
    end

    @testset "byte a byte, em texto e em Typst" begin
        txt = render(m, dados; today = HOJE_P)
        txt == lido_p("procuracao.txt") || println(txt)
        @test txt == lido_p("procuracao.txt")

        typ = render(m, dados; today = HOJE_P, to = :typst)
        typ == lido_p("procuracao.typ") || println(typ)
        @test typ == lido_p("procuracao.typ")

        # o escape só acrescenta contrabarras: tirá-las devolve o documento em texto
        @test desescapa_typst(typ) == txt
        # `_` abriria ênfase e `@` uma referência, no endereço eletrônico
        @test occursin("paulo\\_lins\\@lins.adv.br", typ)
        # e o rótulo que os outorgantes flexionam atravessa intacto
        @test occursin("os OUTORGANTES nomeiam seu bastante procurador", typ)
        @test occursin("Conferem-lhe ainda", typ)
    end

    @testset "o que o ask emite é o golden, e o render o lê de volta (D-061)" begin
        r = cli_proc("ask", PROCURACAO, exemplo_p("procuracao.partes.json"), BASE_P...;
                     entrada = respostas)
        @test r.codigo == Kanon.EXIT_OK
        r.out == read(exemplo_p("procuracao.json"), String) || println(r.out)
        @test r.out == read(exemplo_p("procuracao.json"), String)
        # a entrada era JSON, e a saída também: a `pessoa` sai como objeto
        @test !occursin("Dict{", r.out)
        @test occursin("\"advogado\": {", r.out)
    end

    @testset "o ask pergunta o opcional, e diz a forma da resposta (D-061)" begin
        r = cli_proc("ask", PROCURACAO, exemplo_p("procuracao.partes.json"), BASE_P...;
                     entrada = respostas)
        @test occursin("reu — texto, linha", r.err)
        @test occursin("processo — texto, linha", r.err)
        @test occursin("opcional: Enter deixa em branco", r.err)
        @test occursin("verdadeiro ou falso", r.err)       # na língua do arquivo
        @test occursin("aaaa-mm-dd", r.err)
        @test occursin("Enter mantém \"Petrolina\"", r.err)
        @test occursin("Enter mantém hoje", r.err)
        # o que já veio do cadastro não se pergunta
        @test !occursin("advogado —", r.err)
        # e o campo que veio do fragmento diz de que arquivo é a linha: `linha 17` sozinho
        # mandava o redator à linha 17 da procuração, onde está outra coisa (D-064)
        @test occursin("oab — texto, " * joinpath("fragmentos", "procurador.kanon") * ", linha 17",
                       r.err)
        # e o processo, deixado em branco, não entra nos dados
        @test !occursin("\"processo\"", r.out)
    end

    @testset "a resposta recusada é perguntada de novo, com a mensagem do check (D-061)" begin
        r = cli_proc("ask", PROCURACAO, exemplo_p("procuracao.partes.json"), BASE_P...;
                     entrada = respostas)
        # `sim` não é booleano; `13/09/2027` não é a forma da data
        @test occursin("`substabelecer` é do tipo `booleano`, e o valor recebido não serve", r.err)
        @test occursin("a data se escreve `aaaa-mm-dd`", r.err)
        @test count("substabelecer = ", r.err) == 2
        @test count("validade = ", r.err) == 2
        @test occursin("\"substabelecer\": true", r.out)
        @test occursin("\"validade\": \"2027-09-13\"", r.out)
    end

    @testset "chave = valor não escreve pessoa: é erro de uso, e não um Dict de Julia" begin
        destino = joinpath(mktempdir(), "dados.kdata")
        r = cli_proc("ask", PROCURACAO, exemplo_p("procuracao.partes.json"), BASE_P...,
                     "-o", destino; entrada = respostas)
        @test r.codigo == Kanon.EXIT_USAGE
        @test occursin("não o escreve", r.err)
        @test occursin("-o dados.json", r.err)
        @test !isfile(destino)
    end

    @testset "o fluxo do balcão pelo bin/kanon, num processo novo (D-059, D-060)" begin
        # Num processo à parte, e não `Kanon.main`: esta suíte já carregou `KanonLegal` e
        # `JSON3`, e dentro dela nenhum dos dois defeitos existe. Foi assim que a D-058
        # passou verde.
        dir = mktempdir()
        dados_saida = joinpath(dir, "dados.json")
        typ_saida = joinpath(dir, "procuracao.typ")
        julia = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project())`
        kanon = joinpath(RAIZ, "bin", "kanon")

        err_ask = IOBuffer()
        ask = run(pipeline(ignorestatus(`$julia $kanon ask $PROCURACAO
                                          $(exemplo_p("procuracao.partes.json")) $BASE_P
                                          -o $dados_saida`);
                           stdin = exemplo_p("procuracao.respostas.txt"), stderr = err_ask))
        mensagens = String(take!(err_ask))
        @test ask.exitcode == Kanon.EXIT_OK
        @test !occursin("não tem camada carregada", mensagens)
        @test !occursin("Stacktrace", mensagens)
        @test read(dados_saida, String) == read(exemplo_p("procuracao.json"), String)

        err_render = IOBuffer()
        render_p = run(pipeline(ignorestatus(`$julia $kanon render $PROCURACAO $dados_saida
                                               $BASE_P --to typst -o $typ_saida`);
                                stderr = err_render))
        @test render_p.exitcode == Kanon.EXIT_OK
        # `isempty` seria frágil: um processo novo pode avisar de pré-compilação no stderr
        mensagens_render = String(take!(err_render))
        @test !occursin("Stacktrace", mensagens_render)
        @test !occursin("kanon:", mensagens_render)
        @test rstrip(read(typ_saida, String), '\n') == lido_p("procuracao.typ")
    end
end
