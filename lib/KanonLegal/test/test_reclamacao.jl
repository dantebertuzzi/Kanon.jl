# A reclamação trabalhista — **modelo real nº 15**, o último do portão da 1.0.
#
# A reclamação que a procuração nº 12 outorgou poderes para propor, pelo mesmo escritório,
# contra a mesma empresa. Escolhida pela última porta documentada que nenhum documento
# tinha atravessado: o escritório entrega a petição em `.docx`, para o advogado revisar
# antes de protocolar, pelo caminho que a ajuda da CLI dá —
# `kanon render … --to markdown | pandoc -o reclamacao.docx`. O Markdown do acervo
# (`servicos.md`) tinha sido conferido como texto, e nenhum teste passava pelo pandoc.
#
# Cobrou uma coisa, e do tipo mais caro — o documento que sai errado sem aviso:
#
#   * **D-070** — o fecho `Nestes termos,` / `pede deferimento.` e o bloco de assinatura
#     `PAULO HENRIQUE LINS` / `OAB/PE 12.345` saíam **numa linha só** no `.docx`. No
#     Markdown e no Typst a quebra simples é espaço, a §4.1 deixava ao formato decidir se
#     ela é rígida, e os dois formatos não decidiam nada. O texto puro do mesmo modelo
#     estava certo, o Markdown era o que a F8 especificou, e o pandoc fez o que o Markdown
#     manda: cada um certo sozinho, e o documento errado na interseção.
#
# O resto atravessou intacto, e o teste o fixa: `R$` escapado não vira matemática no
# pandoc, o `_` do endereço eletrônico não vira ênfase, o `1.` dos pedidos não vira lista
# renumerada pelo Word (D-044), e a citação da lei sai em bloco.
#
# Os goldens foram escritos à mão antes de renderizar; o motor bateu byte a byte com o
# texto e com o Markdown, e o `.docx` lido de volta mostrou as duas linhas coladas.

const RECLAMACAO = joinpath(RAIZ, "test", "golden", "exemplos", "reclamacao.kanon")
const EX_REC = joinpath(RAIZ, "test", "golden", "exemplos")
const HOJE_R = Date(2026, 9, 15)
const BASE_R = ("--locale", "pt", "--domain", "KanonLegal", "--today", "2026-09-15")

exemplo_r(nome) = joinpath(EX_REC, nome)
lido_r(nome) = rstrip(read(exemplo_r(nome), String), '\n')

"""
O pandoc da máquina: `KANON_PANDOC`, ou o que estiver no `PATH`. No CI ele é obrigatório —
um teste que se pula sozinho onde o redator o usaria é a porta testada fora do lugar.
"""
function pandoc_da_maquina()
    p = get(ENV, "KANON_PANDOC", "")
    isempty(p) || return p
    p = Sys.which("pandoc")
    p === nothing && get(ENV, "CI", "") == "true" &&
        error("o CI precisa do pandoc para o modelo real nº 15; instale-o no workflow")
    p
end

@testset "a reclamação trabalhista — modelo real nº 15" begin
    m = load_template(ENV_LEGAL, RECLAMACAO)
    dados = Kanon.read_json(exemplo_r("reclamacao.json"))

    @testset "o modelo carrega sem um único diagnóstico" begin
        isempty(m.analysis.diagnostics) ||
            error("o modelo não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(m.analysis.diagnostics)))
        @test isempty(m.analysis.diagnostics)
        @test isempty(check(m, dados; today = HOJE_R))
    end

    @testset "byte a byte, em texto e em Markdown" begin
        txt = render(m, dados; today = HOJE_R)
        txt == lido_r("reclamacao.txt") || println(txt)
        @test txt == lido_r("reclamacao.txt")

        md = render(m, dados; today = HOJE_R, to = :markdown)
        md == lido_r("reclamacao.md") || println(md)
        @test md == lido_r("reclamacao.md")
        # as duas linhas que o `.docx` colava (D-070)
        @test occursin("Nestes termos,\\\npede deferimento.", md)
        @test occursin("PAULO HENRIQUE LINS\\\nOAB/PE 12.345", md)
        # e o que é do autor passa intacto: o negrito, a citação em bloco
        @test occursin("\n\n**I — DOS FATOS**\n\n", md)
        @test occursin("\n\n> § 8º A inobservância", md)
    end

    @testset "os pedidos que faltam saem, e a numeração acompanha" begin
        d = copy(dados)
        delete!(d, "jornada")
        delete!(d, "horas_extras")
        delete!(d, "email_reclamante")
        d["gratuidade"] = false
        txt = render(m, d; today = HOJE_R)
        @test !occursin("Cumpria jornada", txt)
        @test !occursin("horas extraordinárias", txt)
        @test occursin("4. honorários advocatícios", txt)
        @test !occursin("\n5. ", txt)
        @test !occursin("justiça gratuita", txt)
        @test occursin("Petrolina/PE, por seu advogado", txt)

        d["danos_morais"] = Dict("amount" => "10000.00", "currency" => "BRL")
        txt = render(m, d; today = HOJE_R)
        @test occursin("4. indenização por danos morais, R\$ 10.000,00;\n\n5. honorários", txt)
    end

    @testset "o caminho da ajuda da CLI: bin/kanon | pandoc, num processo novo (D-070)" begin
        pandoc = pandoc_da_maquina()
        if pandoc === nothing
            @warn "pandoc não encontrado: o fluxo do .docx do modelo real nº 15 não rodou. " *
                  "Instale-o ou aponte KANON_PANDOC para ele."
            @test_skip false
        else
            dir = mktempdir()
            docx = joinpath(dir, "reclamacao.docx")
            julia = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project())`
            kanon = joinpath(RAIZ, "bin", "kanon")

            # exatamente a linha da ajuda: o Markdown pelo stdout, o pandoc lendo o stdin
            err_kanon, err_pandoc = IOBuffer(), IOBuffer()
            cadeia = run(pipeline(
                pipeline(ignorestatus(`$julia $kanon render $RECLAMACAO
                                        $(exemplo_r("reclamacao.json")) $BASE_R
                                        --to markdown`); stderr = err_kanon),
                pipeline(ignorestatus(`$pandoc -o $docx`); stderr = err_pandoc)))
            mensagens = String(take!(err_kanon))
            @test cadeia.processes[1].exitcode == Kanon.EXIT_OK
            @test cadeia.processes[2].exitcode == 0
            @test !occursin("Stacktrace", mensagens)
            @test !occursin("kanon:", mensagens)
            @test isempty(String(take!(err_pandoc)))    # nem aviso do pandoc
            @test isfile(docx)

            # O `.docx` lido de volta, como o redator o lê: um parágrafo por parágrafo, a
            # quebra de linha onde o modelo quebrou, e nenhuma marcação sobrando.
            lido = IOBuffer()
            # `--eol=lf`: no Windows o pandoc escreve CRLF, e o golden é um só
            run(pipeline(`$pandoc $docx -t plain --wrap=none --eol=lf`; stdout = lido))
            texto = rstrip(String(take!(lido)), '\n')
            texto == lido_r("reclamacao.docx.txt") || println(texto)
            @test texto == lido_r("reclamacao.docx.txt")
            @test occursin("\nNestes termos,\npede deferimento.\n", texto)
            @test endswith(texto, "\nPAULO HENRIQUE LINS\nOAB/PE 12.345")
            @test occursin("R\$ 40.466,93", texto)                 # não virou matemática
            @test occursin("marta_soares@correio.com.br", texto)    # não virou ênfase

            # e a estrutura, que o texto não mostra
            nativo = IOBuffer()
            run(pipeline(`$pandoc $docx -t native --eol=lf`; stdout = nativo))
            arvore = String(take!(nativo))
            @test count("LineBreak", arvore) == 2
            @test count("BlockQuote", arvore) == 1
            # o `1.` de cada pedido é o número que o motor apurou, e não uma lista que o
            # Word renumeraria (D-044)
            @test !occursin("OrderedList", arvore)
            @test occursin("Str \"1.\"", arvore)
        end
    end
end
