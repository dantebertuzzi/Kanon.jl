# O relatório de medição — **modelo real nº 3** do portão da 1.0.
#
# Escolhido pelo que o modelo nº 2 ensinou: o buraco mora na interseção de coisas
# testadas separadamente. Três interseções estavam vazias, e este documento atravessa as
# três de uma vez — um modelo em **arquivo**, com **fragmento incluído**, na camada
# **científica**, emitido também em **markdown**.
#
# Cobrou duas coisas, ambas silenciosas:
#
#   1. Uma incerteza cujo primeiro algarismo é 3 recebia uma casa decimal a mais do que a
#      medição sustenta — `21.40 ± 0.30` no lugar de `21.4 ± 0.3`. Ponto flutuante:
#      `0.3 / 10.0^-1` vale `2.9999999999999996`. Corrigido em `decimal_lead`.
#   2. Todo diagnóstico sobre algo vindo de fragmento nomeava o **hospedeiro**, com a
#      linha do **fragmento** — um ponteiro para uma linha que muitas vezes nem existe
#      no arquivo apontado. Corrigido em `source_of` (veja `test/test_include.jl`).

const RELATORIO = joinpath(RAIZ, "test", "golden", "exemplos", "relatorio.kanon")
const SAIDA_RELATORIO = joinpath(RAIZ, "test", "golden", "exemplos", "relatorio.txt")
const RAIZ_EXEMPLOS = joinpath(RAIZ, "test", "golden", "exemplos")

const DADOS_MEDICAO = Dict{String,Any}(
    "study" => "Thermal drift of the reference cavity",
    "instrument" => "Zygo interferometer",
    "operator" => "R. Tavares",
    "reviewer" => "H. Duarte",
    "effect" => Measure(4.237, 0.008, "mm"),
    "baseline" => Measure(1.102, 0.015, "mm"),
    "temperature" => Measure(21.4, 0.3, "°C"),
    "runs" => 12,
    "caveat" => "the cavity was not re-evacuated between the seventh and eighth runs",
    "dataset" => "doi:10.5281/zenodo.9999999",
    "preregistered" => true,
    "date" => Date(2026, 9, 5),
)

@testset "o relatório de medição — modelo real nº 3" begin
    m = load_template(ENV_SCI, RELATORIO; root = RAIZ_EXEMPLOS)
    saida = render(m, DADOS_MEDICAO)

    @testset "o modelo carrega sem um único diagnóstico" begin
        isempty(m.analysis.diagnostics) ||
            error("o modelo não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(m.analysis.diagnostics)))
        @test isempty(m.analysis.diagnostics)
        @test isempty(check(m, DADOS_MEDICAO))
    end

    @testset "byte a byte" begin
        esperado = rstrip(read(SAIDA_RELATORIO, String), '\n')
        saida == esperado || println(saida)
        @test saida == esperado
    end

    @testset "o fragmento traz o próprio contrato, e a carga unifica os dois" begin
        # `dataset` está nos dois com o mesmo tipo e funde; `license` e `preregistered`
        # são só do fragmento, e o hospedeiro não precisa saber que existem. É a razão
        # pela qual a D-005 escolheu inclusão e não herança.
        campos = Dict(f.name => f for f in m.template.data.fields)
        @test campos[:dataset].presence === Kanon.REQUIRED
        @test campos[:license].presence === Kanon.DEFAULTED
        @test campos[:preregistered].type === :boolean
        @test !occursin("license", read(RELATORIO, String))
    end

    @testset "a numeração atravessa a fronteira do fragmento" begin
        # Os blocos do fragmento continuam o contador do hospedeiro, e não começam outro.
        # Sem isso o documento teria dois `Theorem 1`.
        @test occursin("Theorem 3. This report carries one caveat", saida)   # hospedeiro
        @test occursin("Theorem 4. The data supporting this report", saida)  # fragmento
        @test occursin("Theorem 5. The analysis plan", saida)                # fragmento
        @test count("Theorem 1.", saida) == 2      # o `Theorem 1.` e o `Theorem 1.1.`
    end

    @testset "a regra do fragmento vale sobre o bloco do fragmento" begin
        d = merge(DADOS_MEDICAO, Dict{String,Any}("preregistered" => false))
        s = render(m, d)
        @test !occursin("registered before collection", s)
        @test occursin("Theorem 4. The data supporting", s)   # e o irmão fica
    end

    @testset "numeração aninhada, condicionada pelo atributo do tipo" begin
        @test occursin("Theorem 1.1. The effect is resolved", saida)

        # `effect is precise` é `incerteza/|valor| < 1%`. Com uma medida grosseira o
        # teorema aninhado sai, e o de nível 1 que o contém fica.
        d = merge(DADOS_MEDICAO, Dict{String,Any}("effect" => Measure(4.2, 0.9, "mm")))
        s = render(m, d)
        @test !occursin("Theorem 1.1", s)
        @test occursin("Theorem 1. The reported effect is 4.2 ± 0.9 mm", s)
    end

    @testset "os algarismos são os que a medição sustenta, e nem um a mais" begin
        @test occursin("4.237 ± 0.008 mm", saida)     # incerteza com primeiro algarismo 8
        @test occursin("1.102 ± 0.015 mm", saida)     # com 1: dois significativos
        @test occursin("21.4 ± 0.3 °C", saida)        # com 3: um significativo
        @test !occursin("21.40", saida)
        @test occursin("relative uncertainty is 0.2%", saida)
        @test occursin("central value is 4.237,", saida)
    end

    @testset "a remissão a um teorema, e a elisão do grupo do revisor" begin
        @test occursin("By Theorem 1, the value above", saida)
        @test occursin("on 2026-09-05, reviewed by H. Duarte.", saida)

        d = copy(DADOS_MEDICAO); delete!(d, "reviewer"); delete!(d, "temperature")
        s = render(m, d)
        @test occursin("on 2026-09-05. By Theorem 1", s)          # sem vírgula órfã
        @test occursin("baseline of 1.102 ± 0.015 mm.\n", s)      # nem aqui
        @test !occursin(", ,", s) && !occursin("  ", s)
    end

    @testset "em markdown: a prosa do autor é marcação, o valor não é (D-028)" begin
        md = render(m, DADOS_MEDICAO; to = :markdown)

        # O `#` da linha `# {study}` foi digitado pelo autor, e é um título de verdade.
        # É o que a D-012 comprou ao tirar o comentário `#` do plano do texto.
        @test startswith(md, "# Thermal drift of the reference cavity\n")

        hostil = merge(DADOS_MEDICAO, Dict{String,Any}(
            "study" => "Drift of *cavity* [ref]",
            "dataset" => "doi:10/x_y_z"))
        s = render(m, hostil; to = :markdown)
        @test occursin("# Drift of \\*cavity\\* \\[ref\\]", s)
        @test occursin("doi:10/x\\_y\\_z", s)
    end

    @testset "sem camada nenhuma, o mesmo modelo é recusado nomeando o que falta" begin
        e = try
            load_template(Environment(), RELATORIO; root = RAIZ_EXEMPLOS)
        catch err
            err
        end
        @test e isa KanonReferenceError
        codigos = Set(d.code for d in e.diagnostics)
        @test "K2005" in codigos      # o tipo `measure`
        @test "K2030" in codigos      # o marcador `@`
    end
end
