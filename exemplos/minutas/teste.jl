# A prova do gerador de minutas.
#
#     julia --project teste.jl
#
# Três perguntas, da mais barata à mais cara:
#
#   1. O checklist diz a verdade? O JSON real de cada modelo passa num validador de JSON
#      Schema de terceiros (JSONSchema.jl) — a promessa da D-009, que antes da D-079 falhava
#      em todo documento jurídico.
#   2. O gerador produz o documento do acervo? Com os mesmos dados e a mesma data, o texto que
#      ele baixa é, byte a byte, o golden que a suíte do KanonLegal confere.
#   3. O formulário montado só do checklist carrega o modelo inteiro? A página real, num
#      Chrome sem janela, preenche o exemplo pelos campos que ela mesma gerou, e a minuta
#      tem de ficar pronta — o que só acontece se nenhum campo, aninhado ou em lista, se
#      perdeu no caminho. Pulado quando não há Chrome.

using Test, Dates, JSON3, JSONSchema, HTTP
include(joinpath(@__DIR__, "motor.jl"))
using .Minutas
include(joinpath(@__DIR__, "servidor.jl"))          # só as funções: `main` não roda sob include

"A data de cada golden, a mesma da suíte que o confere."
const HOJE = Dict("procuracao" => Date(2026, 9, 13), "notificacao" => Date(2026, 9, 14),
                  "servicos" => Date(2026, 9, 11), "reclamacao" => Date(2026, 9, 15),
                  "doacao" => Date(2026, 9, 7))

@testset "o gerador de minutas" begin

    @testset "o checklist de $(e.id) aceita o JSON real do modelo" for e in catalogo()
        esquema = JSONSchema.Schema(JSON3.read(contrato(e), Dict{String,Any}))
        dados = JSON3.read(exemplo(e), Dict{String,Any})
        @test JSONSchema.validate(esquema, dados) === nothing
        # e o `$id` não carrega o caminho da máquina (D-079)
        @test JSON3.read(contrato(e))[Symbol("\$id")] == "kanon:$(e.id).kanon"
    end

    @testset "$(e.id): o documento baixado é o golden" for e in catalogo()
        dados = ler_dados(exemplo(e))
        r = documento(e, dados, "txt"; hoje = HOJE[e.id])
        @test r.ok
        golden = rstrip(read(joinpath(Minutas.EXEMPLOS, "$(e.id).txt"), String), '\n')
        @test rstrip(String(r.bytes), '\n') == golden
    end

    @testset "a prévia vazia mostra o documento, e diz o que falta campo a campo" begin
        e = Minutas.entrada("procuracao")
        p = previa(e, Dict{String,Any}(); hoje = HOJE["procuracao"])
        @test !p.completo
        @test occursin("«finalidade»", p.html)
        @test sort([x.caminho for x in p.problemas]) == ["advogado", "finalidade", "oab", "outorgante", "substabelecer"]
    end

    @testset "o problema de um item de lista aponta o item" begin
        e = Minutas.entrada("procuracao")
        dados = ler_dados(exemplo(e))
        delete!(dados["outorgante"][2], "genero")
        dados["outorgante"][1]["nome"] = ""
        p = previa(e, dados; hoje = HOJE["procuracao"])
        @test !p.completo
        caminhos = [x.caminho for x in p.problemas]
        @test "outorgante[1].nome" in caminhos
        @test "outorgante[2]" in caminhos                   # a chave que falta no objeto
        @test any(x -> occursin("genero", x.mensagem), p.problemas)
    end

    @testset "o documento incompleto não se baixa" begin
        e = Minutas.entrada("servicos")
        r = documento(e, Dict{String,Any}("objeto" => "manutenção"), "md")
        @test !r.ok
        @test any(x -> x.caminho == "contratante", r.problemas)
    end

    @testset "o servidor: rotas, erros e o formulário no navegador" begin
        porta = 18000 + rand(0:999)
        servidor = HTTP.serve!(atender, "127.0.0.1", porta)
        base = "http://127.0.0.1:$porta"
        try
            @test HTTP.get("$base/").status == 200
            @test length(JSON3.read(HTTP.get("$base/api/modelos").body)) == length(catalogo())
            @test HTTP.get("$base/api/modelos/nada/contrato"; status_exception = false).status == 404
            @test HTTP.post("$base/api/modelos/procuracao/previa", [], "{nao e json"; status_exception = false).status == 400
            r = HTTP.post("$base/api/modelos/procuracao/documento?formato=md", [], "{}"; status_exception = false)
            @test r.status == 422

            chrome = something(Sys.which("google-chrome-stable"), Sys.which("google-chrome"),
                               Sys.which("chromium"), Sys.which("chromium-browser"), Some(nothing))
            if chrome === nothing
                @info "sem Chrome: a prova do formulário no navegador foi pulada"
            else
                @testset "o formulário de $(e.id), preenchido pelo exemplo, fecha a minuta" for e in catalogo()
                    url = "$base/#$(e.id)/exemplo"
                    dom = read(`$chrome --headless=new --disable-gpu --no-sandbox --virtual-time-budget=15000 --dump-dom $url`, String)
                    # o estado do indicador, e não a frase: "Minuta pronta" também está escrita
                    # no JavaScript da página, e a busca pela frase passava com tudo quebrado
                    @test occursin(r"<span id=\"situacao\"[^>]*class=\"pronta\"[^>]*>Minuta pronta</span>", dom)
                    doc = match(r"<div id=\"documento\">(.*?)</div>\s*</article>"s, dom)
                    @test doc !== nothing
                    @test doc !== nothing && !occursin("<mark", doc.captures[1])   # nenhum «marcador» sobrou
                end
            end
        finally
            close(servidor)
        end
    end
end
