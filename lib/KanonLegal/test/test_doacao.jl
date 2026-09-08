# A escritura de doação — **modelo real nº 7** do portão da 1.0.
#
# Escolhido pelo que o **plano das regras** ainda não tinha sofrido. Os seis modelos
# anteriores condicionam bloco por presença e por atributo, e repetem bloco sem
# condicioná-lo; nenhum tinha comparado coisa nenhuma. Os seis operadores da §8.1, o
# `and`/`or` da §8.2 e o exemplo da própria §8.3 — "um bloco para cada vendedor, exceto os
# menores" — existiam só em teste de unidade.
#
# Cinco interseções estavam vazias, e este documento atravessa as cinco:
#
#   1. `um para cada` e `quando` **no mesmo bloco**, com a condição avaliada por iteração;
#   2. comparação com **literal de data**, sobre um campo do elemento corrente — a forma
#      que a docstring de `maior` prescreve desde a F6, porque a maioridade depende de uma
#      data de referência e não pode ser atributo do tipo;
#   3. comparação de **dinheiro com número** — o `price > 0` da §8.1, num documento;
#   4. **`ou`** numa condição, e um **caminho booleano isolado**;
#   5. os dados vindos de um **arquivo JSON**, com tipos de domínio dentro.
#
# Cobrou duas, e a segunda fechava a porta pela qual os dados chegam na prática:
#
#   * **D-045** — a garantia de presença que a regra do bloco dá era colhida numa grafia e
#     consultada noutra, e comparação nenhuma a produzia. `{nascimento}` num bloco que só
#     existe quando `donatarios.nascimento > 2008-09-07` exigia grupo opcional — um trecho
#     de reserva para um caso que o plano das regras já tinha eliminado.
#   * **D-046** — nenhuma camada implementava `kanon_decode`, e por isso **nenhum JSON
#     alcançava documento jurídico nenhum**: `check` recusava com "esperava um valor de
#     `pessoa`" e não havia nada que o autor do JSON pudesse escrever.

const DOACAO = joinpath(RAIZ, "test", "golden", "exemplos", "doacao.kanon")
const DADOS_DOACAO_JSON = joinpath(RAIZ, "test", "golden", "exemplos", "doacao.json")
const SAIDA_DOACAO = joinpath(RAIZ, "test", "golden", "exemplos", "doacao.txt")

const HOJE_D = Date(2026, 9, 7)

const DOADOR = Pessoa("Raimundo Nonato de Alencar", :m, "casado", "222.333.444-55",
                      "Rua Cardeal, 220, Petrolina/PE";
                      regime = "comunhão parcial de bens", nascimento = Date(1958, 4, 19))

const DADOS_DOACAO = Dict{String,Any}(
    "doador" => DOADOR,
    "donatarios" => [
        Pessoa("Ana Beatriz de Alencar", :f, "solteira", "777.888.999-00",
               "Rua Cardeal, 220, Petrolina/PE"; nascimento = Date(1996, 11, 3)),
        Pessoa("Tomás de Alencar", :m, "solteiro", "333.222.111-00",
               "Rua Cardeal, 220, Petrolina/PE"; nascimento = Date(2012, 2, 29)),
    ],
    "imovel" => Imovel("54.321", :urbano,
                       "casa residencial situada na Rua Cardeal, nº 220"; area = 360.0),
    "valor" => Kanon.Money("480000.00", :BRL),
    "usufruto" => true,
    "cartorio" => "Cartório do 2º Ofício de Notas de Petrolina",
    "livro" => 118,
    "folha" => 43,
)

@testset "a escritura de doação — modelo real nº 7" begin
    m = load_template(ENV_LEGAL, DOACAO)
    saida = render(m, DADOS_DOACAO; today = HOJE_D)

    @testset "o modelo carrega sem um único diagnóstico" begin
        isempty(m.analysis.diagnostics) ||
            error("o modelo não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(m.analysis.diagnostics)))
        @test isempty(m.analysis.diagnostics)
        @test isempty(check(m, DADOS_DOACAO; today = HOJE_D))
    end

    @testset "byte a byte" begin
        esperado = rstrip(read(SAIDA_DOACAO, String), '\n')
        saida == esperado || println(saida)
        @test saida == esperado
    end

    @testset "o mesmo documento, com os dados vindos do JSON (D-046)" begin
        dados = Kanon.read_json(DADOS_DOACAO_JSON)
        @test isempty(check(m, dados; today = HOJE_D))
        # byte a byte igual ao que os valores construídos em Julia produzem: a origem dos
        # dados não altera o documento, que é a única coisa que a ingestão pode prometer.
        @test render(m, dados; today = HOJE_D) == saida
    end

    @testset "a comparação por iteração separa os donatários (§8.3)" begin
        # A maioridade não é atributo do tipo — depende da data de referência —, e por
        # isso se pergunta comparando. Os dois blocos repetem sobre a mesma lista e cada
        # donatário cai em exatamente um deles.
        @test occursin("CLÁUSULA SEGUNDA. É donatária Ana Beatriz de Alencar, solteira,", saida)
        @test occursin("CLÁUSULA TERCEIRA. É donatário Tomás de Alencar, menor nascido em " *
                       "29 de fevereiro de 2012,", saida)
        @test !occursin("Ana Beatriz de Alencar, menor", saida)
        @test !occursin("Tomás de Alencar, solteiro,", saida)
    end

    @testset "quem não tem data de nascimento não some da escritura" begin
        # Ausência nunca satisfaz comparação: sem o `é ausente` explícito no primeiro
        # bloco, um donatário sem data não cairia em nenhum dos dois.
        sem = merge(DADOS_DOACAO, Dict{String,Any}("donatarios" => [
            Pessoa("Clara Menezes", :f, "casada", "999.888.777-66", "Rua B, 3")]))
        s = render(m, sem; today = HOJE_D)
        @test occursin("É donatária Clara Menezes, casada,", s)
        @test !occursin("menor nascid", s)
    end

    @testset "a garantia da regra dispensa o grupo, na grafia do sujeito (D-045)" begin
        # `{nascimento}` está fora de qualquer colchete, e o modelo carrega limpo: o bloco
        # só existe quando a comparação é verdadeira, e ela é falsa quando o valor falta.
        n = count(x -> x.code == "K2012", m.analysis.diagnostics)
        @test n == 0

        # e a garantia não é atacado de largueza: sem a regra, o mesmo texto é recusado
        fonte = replace(read(DOACAO, String),
                        "  donatario_menor  quando donatarios.nascimento > 2008-09-07\n" => "")
        e = try; load_string(ENV_LEGAL, fonte; name = "d.kanon"); catch err; err; end
        @test e isa KanonReferenceError
        @test any(d -> d.code == "K2012", collect(e.diagnostics))
    end

    @testset "dinheiro compara com número, e `ou` combina as condições (§8.1, §8.2)" begin
        @test occursin("CLÁUSULA QUINTA. Por exceder o valor de referência", saida)

        barato = merge(DADOS_DOACAO,
                       Dict{String,Any}("valor" => Kanon.Money("80000.00", :BRL)))
        s = render(m, barato; today = HOJE_D)
        @test !occursin("valor de referência", s)
        # o outro lado do `ou`: com encargo, a cláusula volta mesmo abaixo do valor
        com = merge(barato, Dict{String,Any}("encargo" => "a conservação do imóvel"))
        @test occursin("valor de referência", render(m, com; today = HOJE_D))
    end

    @testset "o caminho booleano isolado é a única forma de um booleano entrar" begin
        @test occursin("CLÁUSULA QUARTA. O DOADOR reserva para si o usufruto", saida)
        sem = merge(DADOS_DOACAO, Dict{String,Any}("usufruto" => false))
        s = render(m, sem; today = HOJE_D)
        @test !occursin("usufruto vitalício", s)
        # e as cláusulas seguintes renumeram, com a remissão acompanhando
        @test occursin("CLÁUSULA QUARTA. Por exceder", s)
        @test occursin("na forma da cláusula quinta", s)
    end

    @testset "o ordinal concorda com o substantivo que o autor escreveu" begin
        # `livro` é masculino e `folha` é feminina: são dois formatadores, e não um com
        # gênero adivinhado — um `numero` não tem gênero a declarar (§7.1).
        @test occursin("livro nº centésimo décimo oitavo, folha quadragésima terceira", saida)
    end

    @testset "o JSON que não diz a moeda é recusado dizendo o que escrever" begin
        e = try
            Kanon.kanon_decode(Kanon.Money, "480000.00", nothing)
        catch err
            err
        end
        @test e isa UndecodableValue
        @test occursin("\"currency\"", sprint(showerror, e))
    end

    @testset "o objeto sem uma chave obrigatória é recusado nomeando a chave" begin
        e = try
            Kanon.kanon_decode(Pessoa, Dict("nome" => "X", "genero" => "m"), nothing)
        catch err
            err
        end
        @test e isa UndecodableValue
        @test occursin("estado_civil", sprint(showerror, e))

        g = try
            Kanon.kanon_decode(Pessoa, Dict("nome" => "X", "genero" => "masculino",
                                            "estado_civil" => "solteiro", "cpf" => "1",
                                            "endereco" => "Rua A"), nothing)
        catch err
            err
        end
        @test g isa UndecodableValue
        @test occursin("`m` ou `f`", sprint(showerror, g))
    end
end
