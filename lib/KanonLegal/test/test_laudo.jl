# O laudo de avaliação — **modelo real nº 5** do portão da 1.0.
#
# O primeiro documento que precisa de **dois domínios ao mesmo tempo**: o instrumento é
# jurídico e as medidas são de engenharia. `KanonLegal` traz `pessoa`, `parte`, `imovel` e
# o marcador `§`; `KanonScience` traz `measure`. Nenhum dos dois sabe da existência do
# outro, e este arquivo é o primeiro lugar onde eles se encontram — que é exatamente o
# lugar onde o motor nunca tinha sido posto à prova.
#
# Três coisas só aparecem aqui:
#
#   1. **Dois estilos de numeração no mesmo documento**, cada um com a sua família de
#      contadores (§6.2). A `CLÁUSULA TERCEIRA` e o item `1.` são vizinhos e independentes.
#   2. **Nulabilidade que atravessa o tipo composto** (§3.1, D-023): `imovel.area` e
#      `requerente.representante` são opcionais **dentro** do tipo.
#   3. Um `measure` formatado **em português**, que é a fronteira que a `exemplos.md` §2.3
#      chamou de "o menor teste possível entre as camadas" — e que estava quebrada: a mesma
#      área saía `41.250` numa linha e `41250,0` na seguinte (D-041).

const LAUDO = joinpath(RAIZ, "test", "golden", "exemplos", "laudo.kanon")
const SAIDA_LAUDO = joinpath(RAIZ, "test", "golden", "exemplos", "laudo.txt")

const HOJE_L2 = Date(2026, 9, 5)

const HELENA = Pessoa("Helena Duarte Pires", :f, "solteira", "456.789.123-22",
                      "Rua Coronel Amorim, 12, Petrolina/PE")

const DADOS_LAUDO = Dict{String,Any}(
    "perito" => Pessoa("Marcos Vinícius Andrade", :m, "casado", "555.444.333-22",
                       "Rua da Aurora, 55, Petrolina/PE"),
    "requerente" => Parte("Agropecuária Vale do São Francisco Ltda.", :f,
                          "12.345.678/0001-90", "Rodovia BR-428, km 12, Petrolina/PE";
                          empresa = true, representante = HELENA),
    "imovel" => Imovel("98.765", :rural,
        "gleba de terras destinada à fruticultura irrigada, situada no Núcleo 7 do " *
        "Projeto Senador Nilo Coelho"; area = 41250.0),
    "area" => Measure(41250.0, 0.8, "m²"),
    "frente" => Measure(15.2, 0.05, "m"),
    "unitario" => Kanon.Money("15.00", :BRL),
    "valor" => Kanon.Money("618750.00", :BRL),
    "metodo" => "método comparativo direto de dados de mercado",
    "vistoria" => Date(2026, 8, 18),
    "ressalva" => "não foi apresentada a certidão de ônus reais atualizada",
)

@testset "o laudo de avaliação — modelo real nº 5" begin
    m = load_template(ENV_LAUDO, LAUDO)
    saida = render(m, DADOS_LAUDO; today = HOJE_L2)

    @testset "o modelo carrega sem um único diagnóstico, com os dois domínios" begin
        isempty(m.analysis.diagnostics) ||
            error("o modelo não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(m.analysis.diagnostics)))
        @test isempty(m.analysis.diagnostics)
        @test isempty(check(m, DADOS_LAUDO; today = HOJE_L2))
        @test :measure in typenames(ENV_LAUDO) && :pessoa in typenames(ENV_LAUDO)
    end

    @testset "byte a byte" begin
        esperado = rstrip(read(SAIDA_LAUDO, String), '\n')
        saida == esperado || println(saida)
        @test saida == esperado
    end

    @testset "dois estilos, dois contadores, e nenhum atrapalha o outro (§6.2)" begin
        # As cláusulas correm por `§` e os itens medidos por `:`. Se os contadores fossem
        # um só, o item depois da CLÁUSULA SEGUNDA seria `3.` — e a cláusula seguinte
        # seria a QUINTA.
        @test occursin("CLÁUSULA SEGUNDA. A vistoria", saida)
        @test occursin("1. Área do terreno:", saida)
        @test occursin("2. Testada para a via pública:", saida)
        @test occursin("CLÁUSULA TERCEIRA. A avaliação seguiu", saida)
        @test !occursin("3. ", saida)
        @test occursin("na forma da cláusula quarta", saida)     # e a remissão acompanha
    end

    @testset "o mesmo número sai igual, venha do núcleo ou da camada (D-041)" begin
        # `imovel.area` é `number` do núcleo; `area` é `measure` de `KanonScience`. Os
        # dois passam pelo mesmo agrupamento de milhares, que é do idioma e não do tipo.
        @test occursin("área registrada de 41.250 metros quadrados", saida)
        @test occursin("Área do terreno: 41.250,0 ± 0,8 m²", saida)
        @test !occursin("41250", saida)
    end

    @testset "o measure em português: vírgula decimal e algarismos da incerteza" begin
        @test occursin("15,20 ± 0,05 m.", saida)          # incerteza 0,05: duas casas
        @test occursin("41.250,0 ± 0,8 m²", saida)        # incerteza 0,8: uma casa
    end

    @testset "nulabilidade que atravessa o composto, nos dois sentidos (D-023)" begin
        # Presentes: os dois grupos saem.
        @test occursin("neste ato representada por Helena Duarte Pires", saida)
        @test occursin("com área registrada de", saida)

        # Ausentes: os dois grupos elidem, sem vírgula órfã nem espaço duplo.
        sem = copy(DADOS_LAUDO)
        sem["requerente"] = Parte("Agropecuária Vale do São Francisco Ltda.", :f,
                                  "12.345.678/0001-90", "Rodovia BR-428, km 12, Petrolina/PE";
                                  empresa = true)
        sem["imovel"] = Imovel("98.765", :rural, "gleba de terras")
        s = render(m, sem; today = HOJE_L2)
        @test occursin("com endereço em Rodovia BR-428, km 12, Petrolina/PE.", s)
        @test occursin("matriculado sob o nº 98.765.", s)
        @test !occursin("representad", s) && !occursin("área registrada", s)
        @test !occursin(", ,", s) && !occursin("  ", s)
    end

    @testset "a flexão vem do tipo de domínio: o perito é ele, a requerente é ela" begin
        @test occursin("portador do CPF 555.444.333-22, engenheiro avaliador, nomeado", saida)
        @test occursin("inscrita sob o nº 12.345.678/0001-90", saida)
        @test occursin("representada por", saida)
    end

    @testset "a regra lê um atributo do tipo de domínio" begin
        @test occursin("CLÁUSULA QUINTA. Por se tratar de imóvel rural", saida)

        urbano = merge(DADOS_LAUDO, Dict{String,Any}(
            "imovel" => Imovel("98.765", :urbano, "lote urbano"; area = 41250.0)))
        s = render(m, urbano; today = HOJE_L2)
        @test !occursin("imóvel rural", s)
        @test occursin("CLÁUSULA QUINTA. Este laudo é apresentado", s)   # a ressalva renumerou
    end

    @testset "sem a camada científica, o mesmo modelo é recusado nomeando o tipo" begin
        e = try
            load_template(Environment(locale = :pt, domains = [KanonLegal]), LAUDO)
        catch err
            err
        end
        @test e isa KanonReferenceError
        # Um por declaração, e não um por uso: o tipo desconhecido é dito na declaração,
        # e as interpolações não repetem (F2.2).
        ds = [x for x in e.diagnostics if x.code == "K2005"]
        @test length(ds) == 2                       # `area` e `frente`
        @test all(occursin("measure", d.message) for d in ds)
        @test occursin("carregue-a e passe-a em `domains = [...]`", first(ds).hint)
    end
end
