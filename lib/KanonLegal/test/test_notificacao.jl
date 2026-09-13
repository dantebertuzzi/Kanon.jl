# A notificação extrajudicial — **modelo real nº 13** do portão da 1.0.
#
# Escolhida pela porta que faltava: o **servidor de linguagem**, por onde o redator escreve
# o modelo, e que nenhum documento real tinha atravessado. E pelo que a inclusão existe
# para fazer e nunca tinha feito: a qualificação do advogado mora em
# `fragmentos/procurador.kanon`, e a procuração nº 12 a inclui também.
#
# O que o servidor cobrou está na suíte do `KanonLSP` (`test_modelos_reais.jl`), que roda
# o `kanon-lsp` de verdade. Aqui fica o documento, e o que ele cobrou fora do servidor:
#
#   * **D-063** — `R$ 18.750,00` saía `dezoito mil, setecentos e cinquenta reais`. A
#     docstring do `inteiro_extenso`, a do `juntar_escalas` e o comentário do teste diziam
#     `mil duzentos e trinta`, sem vírgula, e as asserções logo abaixo exigiam a vírgula. O
#     laudo nº 5, publicado, tinha `seiscentos e dezoito mil, setecentos e cinquenta reais`.
#   * **D-064** — no `ask` da procuração, o campo que veio do fragmento dizia `linha 17`
#     sem dizer de que arquivo.

const NOTIFICACAO = joinpath(RAIZ, "test", "golden", "exemplos", "notificacao.kanon")
const EX_NOT = joinpath(RAIZ, "test", "golden", "exemplos")
const HOJE_N = Date(2026, 9, 14)

@testset "a notificação extrajudicial — modelo real nº 13" begin
    m = load_template(ENV_LEGAL, NOTIFICACAO)
    dados = Kanon.read_json(joinpath(EX_NOT, "notificacao.json"))
    saida = render(m, dados; today = HOJE_N)

    @testset "o modelo carrega sem um único diagnóstico" begin
        isempty(m.analysis.diagnostics) ||
            error("o modelo não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(m.analysis.diagnostics)))
        @test isempty(m.analysis.diagnostics)
        @test isempty(check(m, dados; today = HOJE_N))
    end

    @testset "byte a byte" begin
        esperado = rstrip(read(joinpath(EX_NOT, "notificacao.txt"), String), '\n')
        saida == esperado || println(saida)
        @test saida == esperado
    end

    @testset "o valor por extenso não leva vírgula entre as classes (D-063)" begin
        @test occursin("R\$ 18.750,00 (dezoito mil setecentos e cinquenta reais)", saida)
        @test !occursin("mil,", saida)
    end

    @testset "o fragmento serve aos dois documentos, e sai igual nos dois" begin
        procuracao = load_template(ENV_LEGAL, joinpath(EX_NOT, "procuracao.kanon"))
        texto_p = render(procuracao, Kanon.read_json(joinpath(EX_NOT, "procuracao.json"));
                         today = Date(2026, 9, 13))
        paragrafo(t) = only(filter(l -> startswith(l, "PROCURADOR: "), split(t, '\n')))
        @test paragrafo(saida) == paragrafo(texto_p)

        # o contrato do fragmento entra nos dois contratos compostos, com a mesma
        # obrigatoriedade
        for modelo in (m, procuracao)
            campos = Dict(f.name => f for f in modelo.template.data.fields)
            @test campos[:advogado].presence === Kanon.REQUIRED
            @test campos[:oab].presence === Kanon.REQUIRED
            @test campos[:email].presence === Kanon.OPTIONAL
        end
    end

    @testset "a flexão pela parte: a empresa notificada é feminina" begin
        @test occursin("NOTIFICADA: Frutas do Vale", saida)
        @test occursin("inscrita no CNPJ", saida)
        @test occursin("Fica Vossa Senhoria constituída em mora e notificada", saida)
        # e o grupo do representante some quando a parte não o tem
        sem = deepcopy(dados)
        delete!(sem["notificado"], "representante")
        s2 = render(m, sem; today = HOJE_N)
        @test occursin("Distrito Industrial, Petrolina/PE.\n", s2)
        @test !occursin("representante legal", s2)
    end
end
