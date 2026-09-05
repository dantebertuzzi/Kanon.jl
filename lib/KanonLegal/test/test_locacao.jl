# O contrato de locação residencial — **modelo real nº 2** do portão da 1.0.
#
# Escrito depois do motor pronto, e não antes, com a pergunta do roadmap: o que este
# documento cobra da linguagem que a escritura não cobrou? Cobrou quatro coisas, e as
# três primeiras viraram correção:
#
#   1. O tipo `lista` do núcleo (§3.3) é **inalcançável** pelo plano de dados: qualquer
#      lista de verdade num campo `: lista` é violação de cardinalidade, e a sugestão da
#      mensagem (`lista[]`) pede uma lista de listas. O que o autor quer é `texto[]` —
#      e `texto[]` já faz tudo o que `lista` prometia. Registrado no roadmap; a decisão
#      sobre remover ou alcançar o tipo é de versão maior.
#   2. `quando flag` era recusado em português e aceito em inglês (corrigido: veja
#      `Extenso/test/test_camada.jl`).
#   3. Uma regra que remove a cláusula deixava o parágrafo dela órfão, numerado `0.1`
#      (corrigido: `K2039`, veja `test/test_rule_semantics.jl`).
#   4. A pontuação que encadeia blocos não é reparada quando um bloco inteiro some. É
#      correto — o reparo é local à emenda, dentro do parágrafo (§5.1) —, e está fixado
#      abaixo para que ninguém o descubra por susto.
#
# Exercita, num documento só, o que a escritura não exercitava: numeração aninhada com
# rótulo de parágrafo, junção de lista com conjunção, `um para cada` sobre lista
# opcional, três blocos condicionais que renumeram, ordinal, e número por extenso.

const LOCACAO = joinpath(RAIZ, "test", "golden", "exemplos", "locacao.kanon")
const SAIDA_LOCACAO = joinpath(RAIZ, "test", "golden", "exemplos", "locacao.txt")

const HOJE_L = Date(2026, 3, 20)

const DADOS_LOCACAO = Dict{String,Any}(
    "locador" => [Pessoa("Carlos Menezes da Rocha", :m, "casado", "321.654.987-11",
                         "Rua Osvaldo Cruz, 88, Centro, Petrolina/PE")],
    "locatario" => [Pessoa("Helena Duarte Pires", :f, "solteira", "456.789.123-22",
                           "Rua Coronel Amorim, 12, Centro, Petrolina/PE")],
    "fiador" => [Pessoa("Rubens Tavares Filho", :m, "casado", "654.321.987-33",
                        "Avenida Souza Filho, 700, Petrolina/PE")],
    "imovel" => Imovel("54.321", :urbano,
        "apartamento nº 402 do Edifício Aurora, situado na Avenida Guararapes, " *
        "nº 1.500, Petrolina/PE"),
    "aluguel" => Kanon.Money("1800.00", :BRL),
    "caucao" => Kanon.Money("5400.00", :BRL),
    "vencimento" => 5,
    "prazo" => 30,
    "inicio" => Date(2026, 4, 1),
    "termino" => Date(2028, 9, 30),
    "moveis" => ["uma geladeira", "um fogão de quatro bocas", "um sofá de três lugares"],
)

@testset "o contrato de locação — modelo real nº 2" begin
    m = load_template(ENV_LEGAL, LOCACAO)
    saida = render(m, DADOS_LOCACAO; today = HOJE_L)

    @testset "o modelo carrega sem um único diagnóstico" begin
        isempty(m.analysis.diagnostics) ||
            error("o modelo não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(m.analysis.diagnostics)))
        @test isempty(m.analysis.diagnostics)
        @test isempty(check(m, DADOS_LOCACAO; today = HOJE_L))
    end

    @testset "byte a byte" begin
        esperado = rstrip(read(SAIDA_LOCACAO, String), '\n')
        saida == esperado || println(saida)
        @test saida == esperado
    end

    @testset "numeração aninhada: o parágrafo é da cláusula, e recomeça em cada uma" begin
        @test occursin("CLÁUSULA PRIMEIRA. O LOCADOR dá em locação", saida)
        @test occursin("PARÁGRAFO PRIMEIRO. O imóvel é entregue mobiliado", saida)
        @test occursin("CLÁUSULA TERCEIRA. O aluguel mensal", saida)
        @test occursin("PARÁGRAFO PRIMEIRO. O atraso no pagamento", saida)
        # dois parágrafos primeiros, porque o contador do nível 2 zera a cada cláusula
        @test count("PARÁGRAFO PRIMEIRO", saida) == 2
        @test !occursin("PARÁGRAFO SEGUNDO", saida)
    end

    @testset "a lista se junta com conjunção, e não com vírgula (D-025)" begin
        @test occursin("com uma geladeira, um fogão de quatro bocas e um sofá de três lugares,",
                       saida)
    end

    @testset "número por extenso, ordinal, e a data na forma corrente" begin
        @test occursin("pelo prazo de trinta meses", saida)
        @test occursin("até o quinto dia de cada mês", saida)
        @test occursin("com início em 1º de abril de 2026", saida)   # o dia 1 é `1º`
        @test occursin("término em 30 de setembro de 2028", saida)
        @test occursin("R\$ 1.800,00 (mil e oitocentos reais)", saida)
        @test occursin("R\$ 5.400,00 (cinco mil e quatrocentos reais)", saida)
    end

    @testset "flexão: um locador, uma locatária, um fiador" begin
        @test occursin("portador do CPF 321.654.987-11", saida)
        @test occursin("denominado LOCADOR;", saida)
        @test occursin("portadora do CPF 456.789.123-22", saida)
        @test occursin("residente e domiciliada na Rua Coronel Amorim", saida)
        @test occursin("denominada LOCATÁRIA;", saida)
        # o bloco da fiança tem a lista inteira por sujeito, e ela tem um elemento só
        @test occursin("O FIADOR responde solidariamente", saida)
    end

    @testset "a remissão renumera com as cláusulas que sobram" begin
        @test occursin("previsto na cláusula terceira", saida)
    end
end

@testset "locação sem fiador, sem caução e sem móveis" begin
    m = load_template(ENV_LEGAL, LOCACAO)
    magro = copy(DADOS_LOCACAO)
    delete!(magro, "fiador")
    delete!(magro, "caucao")
    delete!(magro, "moveis")
    saida = render(m, magro; today = HOJE_L)

    @testset "os dados continuam satisfazendo o contrato" begin
        @test isempty(check(m, magro; today = HOJE_L))
    end

    @testset "`um para cada` sobre lista ausente não produz bloco nenhum" begin
        # E não exigiu colchetes no texto: a iteração entrega um elemento, nunca o nulo
        # (D-020, revisão da F2.5). Sem isso, `{nome}` num bloco de sujeito opcional
        # pediria grupo, e o modelo teria colchetes que não protegem nada.
        @test !occursin("FIADOR", saida)
    end

    @testset "os três blocos condicionais somem, e as cláusulas renumeram" begin
        @test !occursin("mobiliado", saida)
        @test !occursin("caução", saida)
        @test !occursin("benefício de ordem", saida)
        @test occursin("CLÁUSULA QUARTA. Fica eleito o foro", saida)   # era a sexta
        @test !occursin("CLÁUSULA QUINTA", saida)
        @test occursin("previsto na cláusula terceira", saida)         # a remissão acompanha
    end

    @testset "só o parágrafo da cláusula que ficou sobrevive" begin
        @test count("PARÁGRAFO PRIMEIRO", saida) == 1
        @test occursin("PARÁGRAFO PRIMEIRO. O atraso no pagamento", saida)
    end

    @testset "a pontuação entre blocos não é reparada, e é assim de propósito" begin
        # O último qualificado passa a ser a locatária, cujo bloco termina em `;` — a
        # lista de partes fica sem o ponto final. O reparo de emenda é local à remoção,
        # dentro do parágrafo (§5.1): remover um bloco inteiro não é uma emenda, e o
        # motor não tem o direito de editar prosa que ele não removeu. Quem quer o ponto
        # escreve um bloco de fecho da qualificação.
        @test occursin("denominada LOCATÁRIA;\n\nCLÁUSULA PRIMEIRA", saida)
    end
end
