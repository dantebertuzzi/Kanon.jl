# O atestado de capacidade técnica — **modelo real nº 14** do portão da 1.0.
#
# Escolhido por duas dívidas que esperavam exatamente este documento. Um modelo em
# português **sem camada de domínio** nunca tinha passado pelo `bin/kanon`: o certificado
# nº 4 e o edital nº 6 rodam dentro de Julia, e o `Extenso` só chegava à linha de comando
# como dependência de uma camada. E nenhum `numero` tinha sido preenchido pelo `kanon ask`
# num modelo `pt`, onde o documento escreve `1.320` para mil trezentos e vinte.
#
# Os dados do contrato vêm do sistema de contratos, num JSON; os quantitativos o fiscal
# digita no `ask`; o atestado sai pelo `bin/kanon`, num processo novo.
#
# Cobrou três coisas:
#
#   * **D-068** — `kanon ask atestado.kanon --locale pt` saía com "o idioma `pt` não tem
#     camada carregada", com o `Extenso` instalado, e não havia o que digitar: a mensagem
#     mandava "carregar o pacote", que é a forma de quem está dentro de Julia. E o
#     `--domain Extenso` tentado em seguida acusava "o tipo `text` é registrado por `kanon`
#     e por `Extenso`" — o construtor do ambiente chamava o `configure!` **do núcleo**, que
#     a camada importa com `using Kanon`.
#   * **D-069** — o fiscal digitou `1.320` metros de drenagem, o `ask` leu `1.32`, o
#     `check` não tinha o que objetar, e o atestado dizia `1,32 m`. Nenhum aviso. E
#     `12.480,50` era recusado com "esperava um numero", sem a forma a escrever.
#   * **um limite da gramática, que não é defeito**: a enumeração de trechos opcionais.
#     Com a drenagem e sem a sinalização, a frase sai `…quente, 1.320 m de rede de
#     drenagem pluvial, o que corresponde…` — sem o `e` antes do último presente. A
#     conjunção depende de qual trecho é o último presente, e a gramática não diz isso.
#
# Os goldens foram gerados pelo `bin/kanon` e lidos linha a linha.

const ATESTADO = joinpath(RAIZ_KANON, "test", "golden", "exemplos", "atestado.kanon")
const EX_AT = joinpath(RAIZ_KANON, "test", "golden", "exemplos")
const HOJE_A = Date(2026, 9, 14)
const BASE_A = ("--locale", "pt", "--domain", "Extenso", "--today", "2026-09-14")

exemplo_a(nome) = joinpath(EX_AT, nome)
lido_a(nome) = rstrip(read(exemplo_a(nome), String), '\n')

function cli_at(args...; entrada = "")
    o, e = IOBuffer(), IOBuffer()
    codigo = Kanon.main(String[args...]; out = o, err = e, input = IOBuffer(entrada))
    (codigo = codigo, out = String(take!(o)), err = String(take!(e)))
end

@testset "o atestado de capacidade técnica — modelo real nº 14" begin
    m = load_template(ENV_PT_NU, ATESTADO)
    dados = Kanon.read_json(exemplo_a("atestado.json"))
    respostas = read(exemplo_a("atestado.respostas.txt"), String)

    @testset "o modelo carrega sem um único diagnóstico, e sem domínio nenhum" begin
        isempty(m.analysis.diagnostics) ||
            error("o modelo não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(m.analysis.diagnostics)))
        @test isempty(m.analysis.diagnostics)
        @test isempty(check(m, dados; today = HOJE_A))
        @test length(m.env.types) == 6          # só os do núcleo
    end

    @testset "byte a byte" begin
        txt = render(m, dados; today = HOJE_A)
        txt == lido_a("atestado.txt") || println(txt)
        @test txt == lido_a("atestado.txt")
        # o que o fiscal mediu, na forma do documento
        @test occursin("12.480,5 m² de pavimentação", txt)
        @test occursin("1.320 m de rede de drenagem pluvial", txt)
    end

    @testset "a ressalva troca o parágrafo, e não consome número a mais" begin
        d = copy(dados)
        d["ressalvas"] = "o trecho da Rua 7 teve o meio-fio refeito às expensas da contratada"
        txt = render(m, d; today = HOJE_A)
        @test occursin("3. Os serviços foram recebidos com a seguinte ressalva", txt)
        @test !occursin("de forma satisfatória", txt)
        @test !occursin("4.", txt)
    end

    @testset "os quantitativos opcionais" begin
        d = copy(dados)
        delete!(d, "drenagem")
        @test occursin("usinado a quente e 860 m² de sinalização horizontal, o que",
                       render(m, d; today = HOJE_A))
        delete!(d, "sinalizacao")
        @test occursin("usinado a quente, o que corresponde a 100%", render(m, d; today = HOJE_A))
    end

    @testset "o que o ask emite é o golden" begin
        r = cli_at("ask", ATESTADO, exemplo_a("atestado.contrato.json"), BASE_A...;
                   entrada = respostas)
        @test r.codigo == Kanon.EXIT_OK
        r.out == read(exemplo_a("atestado.json"), String) || println(r.out)
        @test r.out == read(exemplo_a("atestado.json"), String)
        # o que veio do sistema de contratos não se pergunta
        @test !occursin("contratada —", r.err)
        @test !occursin("valor —", r.err)
    end

    @testset "o número na forma do documento é recusado, com a forma da resposta (D-069)" begin
        r = cli_at("ask", ATESTADO, exemplo_a("atestado.contrato.json"), BASE_A...;
                   entrada = respostas)
        # `1.320` vale mil trezentos e vinte no documento, e `1.32` na resposta
        @test occursin("`1.320` é ambíguo", r.err)
        @test occursin("Escreva `1320` se é o número inteiro, ou `1.32` se é decimal.", r.err)
        @test count("drenagem = ", r.err) == 2
        @test occursin("\"drenagem\": 1320", r.out)
        # `12.480,50` não é número em forma nenhuma da entrada: a recusa dá a forma pronta
        @test occursin("`12.480,50` está na forma do documento", r.err)
        @test occursin("sem separador de milhar: `12480.50`", r.err)
        @test count("pavimentacao = ", r.err) == 2
        # e a resposta que só tem uma leitura passa direto
        @test count("sinalizacao = ", r.err) == 1
    end

    @testset "as recusas, uma a uma (D-069)" begin
        f(nome) = only(filter(c -> c.name === nome, m.template.data.fields))
        recusa(t) = Kanon.recusa_da_forma(m.env, f(:drenagem), t)
        @test occursin("ambíguo", recusa("12.480"))
        @test occursin("`12480` se é o número inteiro, ou `12.48` se é decimal", recusa("12.480"))
        @test occursin("`1.325` é ambíguo", recusa("1.325"))
        @test occursin("ou `1.3250` se é decimal", recusa("1.325"))
        # dois grupos não são decimal: só a leitura do documento, com a forma pronta
        @test occursin("`1.234.567` está na forma do documento", recusa("1.234.567"))
        @test occursin("`1234567`", recusa("1.234.567"))
        @test occursin("`-1320`", recusa("-1.320"))
        # só tem uma leitura: um zero à esquerda não separa milhar, e duas casas não são grupo
        @test recusa("0.500") === nothing
        @test recusa("1.32") === nothing
        @test recusa("1320") === nothing
        @test recusa("87.25") === nothing
        # a vírgula decimal ganha a forma da resposta
        @test occursin("`87.25`", recusa("87,25"))
        # e o que não é número fica para o `check`, que diz a forma
        @test recusa("mil") === nothing
        @test Kanon.recusa_da_forma(m.env, f(:responsavel), "1.320") === nothing
    end

    @testset "o fluxo do balcão pelo bin/kanon, num processo novo (D-068)" begin
        # Num processo à parte, e não `Kanon.main`: esta suíte já carregou `Extenso`, e
        # dentro dela o idioma sempre esteve carregado.
        dir = mktempdir()
        dados_saida = joinpath(dir, "dados.json")
        txt_saida = joinpath(dir, "atestado.txt")
        julia = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project())`
        kanon = joinpath(RAIZ_KANON, "bin", "kanon")
        contrato = exemplo_a("atestado.contrato.json")

        # sem a camada, a recusa diz o que digitar — e não "carregue o pacote"
        err_sem = IOBuffer()
        sem = run(pipeline(ignorestatus(`$julia $kanon check $ATESTADO --locale pt`);
                           stderr = err_sem))
        mensagem = String(take!(err_sem))
        @test sem.exitcode == Kanon.EXIT_USAGE
        @test occursin("--locale pt --domain NOME", mensagem)
        @test !occursin("Stacktrace", mensagem)

        err_ask = IOBuffer()
        ask = run(pipeline(ignorestatus(`$julia $kanon ask $ATESTADO $contrato $BASE_A
                                          -o $dados_saida`);
                           stdin = exemplo_a("atestado.respostas.txt"), stderr = err_ask))
        mensagens = String(take!(err_ask))
        @test ask.exitcode == Kanon.EXIT_OK
        @test !occursin("não tem camada carregada", mensagens)
        @test !occursin("é registrado por `kanon`", mensagens)
        @test !occursin("Stacktrace", mensagens)
        @test read(dados_saida, String) == read(exemplo_a("atestado.json"), String)

        err_render = IOBuffer()
        render_a = run(pipeline(ignorestatus(`$julia $kanon render $ATESTADO $dados_saida
                                               $BASE_A -o $txt_saida`);
                                stderr = err_render))
        @test render_a.exitcode == Kanon.EXIT_OK
        mensagens_render = String(take!(err_render))
        @test !occursin("Stacktrace", mensagens_render)
        @test !occursin("kanon:", mensagens_render)
        @test rstrip(read(txt_saida, String), '\n') == lido_a("atestado.txt")
    end
end
