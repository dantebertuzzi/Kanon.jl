# O certificado de calibração — **modelo real nº 8** do portão da 1.0.
#
# Escolhido pela via que os dados percorrem na prática. A D-046 abriu o arquivo para o
# domínio jurídico e parou ali: `KanonScience` ficou sem `kanon_decode`, e a camada cujo
# tipo é um **número medido** — a única que um instrumento produz — era a única que um
# JSON não alcançava.
#
# Quatro interseções estavam vazias, e este documento atravessa as quatro:
#
#   1. `measure` vindo de arquivo, sozinho e dentro de lista;
#   2. a camada científica num modelo em **português**, com os separadores do idioma
#      aplicados a um número que veio de fora — `1000.4` no JSON é `1.000,4` no texto;
#   3. um campo **opcional de um tipo de camada** dentro de grupo, num tipo que guarda a
#      ausência como cadeia vazia porque o `struct` não tem `nothing` para pôr no lugar;
#   4. a incerteza relativa decidindo o texto, por iteração.
#
# Cobrou quatro coisas, e a primeira delas não tinha diagnóstico nenhum:
#
#   * **D-048** — a ressalva de um ponto, escrita como bloco **filho** do bloco repetido,
#     saía numerada `3.4.1`: pendurada no quarto ponto, falando do primeiro. A versão 1
#     não emparelha repetições, e o documento mentia sem um único aviso. Agora é `K2048`.
#   * **D-047** — nenhuma camada científica implementava `kanon_decode`.
#   * **D-049** — `{padrao.unit}` não elidia quando a medição não traz unidade: `check`
#     lia o campo em branco como ausente desde a F2, e o `render` o lia como presente e
#     vazio. O certificado saía com `expressos em ,`.
#   * **D-050** — o diagnóstico de um elemento defeituoso não dizia **qual** elemento.
#
# E confirmou a dívida que o modelo nº 6 tinha puxado: num modelo `pt` o motor citava
# `one for each` e `is present`, que o autor não escreveu (D-051).

const ENSAIO = joinpath(RAIZ, "test", "golden", "exemplos", "ensaio.kanon")
const DADOS_ENSAIO_JSON = joinpath(RAIZ, "test", "golden", "exemplos", "ensaio.json")
const SAIDA_ENSAIO = joinpath(RAIZ, "test", "golden", "exemplos", "ensaio.txt")

const ENV_ENSAIO = Environment(locale = :pt, domains = [KanonScience])
const HOJE_E = Date(2026, 9, 10)

# Os mesmos valores do JSON, construídos em Julia: é a comparação que prova que a origem
# dos dados não altera o documento.
const DADOS_ENSAIO = Dict{String,Any}(
    "laboratorio" => "Laboratório de Metrologia Térmica do Vale",
    "acreditacao" => "CAL 0472",
    "cliente" => "Usina Termelétrica do Salitre S.A.",
    "instrumento" => "termômetro digital com termopar tipo K",
    "fabricante" => "Fluke",
    "serie" => "AH-2291-K",
    "norma" => "ABNT NBR ISO/IEC 17025:2017",
    "padrao" => Measure(100.0, 0.05, "°C"),
    "temperatura" => Measure(23.0, 1.0, "°C"),
    "umidade" => Measure(47.0, 5.0, "%"),
    "pontos" => [Measure(20.1, 0.3, "°C"), Measure(100.2, 0.4, "°C"),
                 Measure(200.5, 0.6, "°C"), Measure(1000.4, 1.5, "°C")],
    "ciclos" => 5,
    "observacao" => "o instrumento foi recebido com a bainha do termopar deformada, e a " *
                    "deformação não foi corrigida antes da calibração",
)

@testset "o certificado de calibração — modelo real nº 8" begin
    m = load_template(ENV_ENSAIO, ENSAIO)
    saida = render(m, DADOS_ENSAIO; today = HOJE_E)

    @testset "o modelo carrega sem um único diagnóstico" begin
        isempty(m.analysis.diagnostics) ||
            error("o modelo não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(m.analysis.diagnostics)))
        @test isempty(m.analysis.diagnostics)
        @test isempty(check(m, DADOS_ENSAIO; today = HOJE_E))
    end

    @testset "byte a byte" begin
        esperado = rstrip(read(SAIDA_ENSAIO, String), '\n')
        saida == esperado || println(saida)
        @test saida == esperado
    end

    @testset "o mesmo certificado, com as medições vindas do JSON (D-047)" begin
        dados = Kanon.read_json(DADOS_ENSAIO_JSON)
        @test isempty(check(m, dados; today = HOJE_E))
        # byte a byte igual ao que os `Measure` construídos em Julia produzem: a origem
        # dos dados não altera o documento, que é a única coisa que a ingestão promete.
        @test render(m, dados; today = HOJE_E) == saida
    end

    @testset "os separadores são do idioma, e o valor veio de fora" begin
        # `1000.4` no arquivo, `1.000,4` no certificado — decimal e milhar, os dois, e a
        # incerteza na mesma casa que o valor (D-041, agora atravessando a decodificação).
        @test occursin("1.000,4 ± 1,5 °C", saida)
        @test occursin("\"value\": 1000.4", read(DADOS_ENSAIO_JSON, String))
    end

    @testset "os algarismos são os que a incerteza sustenta" begin
        @test occursin("20,1 ± 0,3 °C", saida)      # primeiro algarismo 3: um só (D-034)
        @test !occursin("20,10", saida)
        @test occursin("100,00 ± 0,05 °C", saida)   # com 5: um algarismo, duas casas
        @test occursin("47 ± 5 %", saida)           # com 5 em unidades: casa nenhuma
        # o mesmo campo, no mesmo parágrafo, com casas diferentes: quem decide é a
        # incerteza, e não quem escreveu o modelo
        @test occursin("de 23,0 ± 1,0 °C e umidade relativa de 47 ± 5 %", saida)
    end

    @testset "a incerteza relativa decide o texto, por iteração" begin
        # `quando não (pontos é precise)` — um ponto em quatro, e é o de menor valor:
        # a incerteza é quase a mesma em toda a faixa, e por isso pesa mais embaixo.
        @test count("tem incerteza superior a um centésimo", saida) == 1
        @test occursin("A indicação de 20,1 ± 0,3 °C tem incerteza superior", saida)
        @test occursin("3.1. Indicação média de 20,1 ± 0,3 °C, com incerteza relativa " *
                       "de 1,5%.", saida)
        @test occursin("3.4. Indicação média de 1.000,4 ± 1,5 °C, com incerteza " *
                       "relativa de 0,15%.", saida)
    end

    @testset "a unidade que falta elide o grupo (D-049)" begin
        # `measure` guarda a ausência de unidade como `""`, porque `unit` é `String` no
        # `struct`. `check_composite!` já lia isso como ausente desde a F2; era o render
        # que não lia, e o certificado saía com `expressos em ,`.
        sem = merge(DADOS_ENSAIO, Dict{String,Any}("padrao" => Measure(100.0, 0.05)))
        @test isempty(check(m, sem; today = HOJE_E))
        s = render(m, sem; today = HOJE_E)
        @test occursin("Mediram-se os pontos adiante relacionados, e a incerteza", s)
        @test !occursin("expressos em", s)
        @test !occursin(" ,", s)                    # nem a vírgula órfã do grupo elidido
        @test occursin("de 100,00 ± 0,05, cuja incerteza", s)   # e a medição fica

        # e o grupo é exigido: sem ele, o teorema da lacuna recusa o modelo
        fonte = replace(read(ENSAIO, String),
                        "[, todos expressos em {padrao.unit}]" => ", todos expressos em {padrao.unit}")
        e = try; load_string(ENV_ENSAIO, fonte; name = "e.kanon"); catch err; err; end
        @test e isa KanonReferenceError
        @test any(d -> d.code == "K2012", collect(e.diagnostics))
    end

    @testset "a ressalva pendurada no ponto errado é recusada (D-048)" begin
        # A forma óbvia — a ressalva como bloco **filho** do ponto — numerava `3.4.1` a
        # ressalva do primeiro ponto. A numeração é mecanicamente correta e o sentido é
        # falso, e por isso é erro: não há leitura em que aquele número esteja certo.
        fonte = replace(read(ENSAIO, String),
                        "::: ponto_impreciso <- pontos" => ":::: ponto_impreciso <- pontos")
        e = try; load_string(ENV_ENSAIO, fonte; name = "e.kanon"); catch err; err; end
        @test e isa KanonReferenceError
        d = only(filter(x -> x.code == "K2048", collect(e.diagnostics)))
        @test occursin("se repete", d.message)
        @test occursin("último número dele", d.message)
        # a saída não é adivinhação: a mensagem diz as duas formas que funcionam
        @test occursin("não emparelha repetições", something(d.hint, ""))

        # o mesmo vale para um filho que **não** se repete: ele sairia sob o último
        # número do pai, e é a mesma mentira com uma cópia só
        fixo = replace(read(ENSAIO, String),
                       "::: ponto_impreciso <- pontos" => ":::: nota",
                       "  ponto_impreciso  um para cada pontos\n" => "",
                       "  ponto_impreciso  quando não (pontos é precise)\n" => "")
        e2 = try; load_string(ENV_ENSAIO, fixo; name = "e.kanon"); catch err; err; end
        @test e2 isa KanonReferenceError
        @test any(x -> x.code == "K2048", collect(e2.diagnostics))
    end

    @testset "o elemento defeituoso é nomeado pela posição (D-050)" begin
        dados = Kanon.read_json(DADOS_ENSAIO_JSON)
        dados["pontos"][3] = Dict("value" => 200.5, "unit" => "°C")
        probs = check(m, dados; today = HOJE_E)
        @test !isempty(probs)
        d = only(collect(probs))
        @test d.code == "K3010"
        @test occursin("o 3º valor de `pontos`", d.message)
        @test occursin("falta a chave `uncertainty`", d.message)
    end

    @testset "um número solto não é uma medição" begin
        dados = merge(DADOS_ENSAIO, Dict{String,Any}("padrao" => 100.0))
        d = only(collect(check(m, dados; today = HOJE_E)))
        @test d.code == "K3010"
        @test occursin("um número solto não é uma medição", d.message)
        @test occursin("`value` e `uncertainty`", d.message)

        # aceitá-lo daria incerteza zero a um número que ninguém mediu assim, e o erro
        # sairia impresso: a incerteza é quem decide quantos algarismos o valor mostra
        e = try
            Kanon.kanon_decode(Measure, Dict("value" => 20.1), nothing)
        catch err
            err
        end
        @test e isa UndecodableValue
        @test occursin("falta a chave `uncertainty`", sprint(showerror, e))
    end

    @testset "o esqueleto cita o que o autor escreveu, e não a forma inglesa (D-051)" begin
        s = Kanon.format_outline(m)
        @test occursin("um para cada pontos", s)
        @test occursin("quando observacao é presente", s)
        @test occursin("quando não (pontos é precise)", s)
        @test !occursin("one for each", s)
        @test !occursin("is present", s)
        # o tipo de um campo de composto também: `text` do esquema é `texto` aqui
        @test occursin("{padrao.unit} : texto opcional", s)
        # e o que emoldura a citação continua em português, que é a língua dos
        # diagnósticos (D-027)
        @test occursin("bloco condicional", s) && occursin("bloco repetido", s)
    end

    @testset "e a remissão a bloco repetido cita a regra na língua do arquivo" begin
        fonte = replace(read(ENSAIO, String),
                        "do item {::resultados}" => "do item {::ponto}")
        e = try; load_string(ENV_ENSAIO, fonte; name = "e.kanon"); catch err; err; end
        d = only(filter(x -> x.code == "K2034", collect(e.diagnostics)))
        @test occursin("`um para cada`", d.message)
        @test !occursin("one for each", d.message)
    end

    @testset "sem a camada científica, o mesmo certificado é recusado" begin
        e = try
            load_template(Environment(locale = :pt), ENSAIO)
        catch err
            err
        end
        @test e isa KanonReferenceError
        @test "K2005" in Set(d.code for d in e.diagnostics)     # o tipo `measure`
    end
end
