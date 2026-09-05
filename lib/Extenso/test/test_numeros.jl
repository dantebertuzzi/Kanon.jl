# Números por extenso — a parte com mais exceções do projeto.
#
# A suíte é uma tabela porque o assunto é uma tabela: cada linha é uma forma que a
# língua tem e que nenhuma regra deriva.

@testset "inteiros por extenso" begin
    @testset "as formas que não se derivam de nada" begin
        casos = [0 => "zero", 1 => "um", 2 => "dois", 9 => "nove",
                 10 => "dez", 11 => "onze", 12 => "doze", 14 => "catorze",
                 15 => "quinze", 16 => "dezesseis", 19 => "dezenove",
                 20 => "vinte", 100 => "cem", 1000 => "mil"]
        for (n, esperado) in casos
            @test inteiro_extenso(n) == esperado
        end
    end

    @testset "`cem` sozinho, `cento` composto" begin
        @test inteiro_extenso(100) == "cem"
        @test inteiro_extenso(101) == "cento e um"
        @test inteiro_extenso(110) == "cento e dez"
        @test inteiro_extenso(199) == "cento e noventa e nove"
        @test inteiro_extenso(100_000) == "cem mil"
    end

    @testset "o `e` entre escalas não é sempre" begin
        # é o que separa `mil e duzentos` de `mil duzentos e trinta`
        @test inteiro_extenso(1200) == "mil e duzentos"
        @test inteiro_extenso(1230) == "mil, duzentos e trinta"
        @test inteiro_extenso(1002) == "mil e dois"
        @test inteiro_extenso(2026) == "dois mil e vinte e seis"
        @test inteiro_extenso(1_234_567) ==
              "um milhão, duzentos e trinta e quatro mil, quinhentos e sessenta e sete"
    end

    @testset "escalas no singular e no plural" begin
        @test inteiro_extenso(1_000_000) == "um milhão"
        @test inteiro_extenso(2_000_000) == "dois milhões"
        @test inteiro_extenso(1_000_000_000) == "um bilhão"
        @test inteiro_extenso(250_000) == "duzentos e cinquenta mil"
    end

    @testset "o gênero alcança as formas que o têm" begin
        @test inteiro_extenso(1; genero = :f) == "uma"
        @test inteiro_extenso(2; genero = :f) == "duas"
        @test inteiro_extenso(200; genero = :f) == "duzentas"
        @test inteiro_extenso(3; genero = :f) == "três"      # não tem gênero
        @test inteiro_extenso(10; genero = :f) == "dez"
    end

    @testset "negativo, e o teto" begin
        @test inteiro_extenso(-5) == "menos cinco"
        @test_throws ArgumentError inteiro_extenso(big(10)^20)
    end
end

@testset "ordinais" begin
    @test ordinal_extenso(1) == "primeiro"
    @test ordinal_extenso(2) == "segundo"
    @test ordinal_extenso(3) == "terceiro"
    @test ordinal_extenso(9) == "nono"
    @test ordinal_extenso(10) == "décimo"
    @test ordinal_extenso(11) == "décimo primeiro"
    @test ordinal_extenso(20) == "vigésimo"
    @test ordinal_extenso(21) == "vigésimo primeiro"
    @test ordinal_extenso(100) == "centésimo"
    @test ordinal_extenso(999) == "noningentésimo nonagésimo nono"

    @testset "o gênero é argumento, não suposição — a cláusula é feminina" begin
        @test ordinal_extenso(1; genero = :f) == "primeira"
        @test ordinal_extenso(2; genero = :f) == "segunda"
        @test ordinal_extenso(3; genero = :f) == "terceira"
        @test ordinal_extenso(11; genero = :f) == "décima primeira"
    end

    @testset "fora do alcance é erro, não um ordinal inventado" begin
        @test_throws ArgumentError ordinal_extenso(0)
        @test_throws ArgumentError ordinal_extenso(MAX_ORDINAL + 1)
    end
end

@testset "dinheiro por extenso" begin
    @test dinheiro_extenso(250_000, :BRL) == "duzentos e cinquenta mil reais"
    @test dinheiro_extenso(1, :BRL) == "um real"
    @test dinheiro_extenso(2, :BRL) == "dois reais"
    @test dinheiro_extenso(0, :BRL) == "zero reais"

    @testset "os centavos entram com `e`, e no masculino" begin
        @test dinheiro_extenso(123457//100, :BRL) ==
              "mil, duzentos e trinta e quatro reais e cinquenta e sete centavos"
        @test dinheiro_extenso(1//100, :BRL) == "um centavo"
        @test dinheiro_extenso(101//100, :BRL) == "um real e um centavo"
    end

    @testset "a quantia não passa por ponto flutuante" begin
        # 0.1 + 0.2 em Float64 não é 0.3; em Rational é
        # e a quantia sem parte inteira é só os centavos, como se diz
        @test dinheiro_extenso(1//10 + 2//10, :BRL) == "trinta centavos"
    end

    @testset "outras moedas, e a que não tem nome em português" begin
        @test dinheiro_extenso(1, :EUR) == "um euro"
        @test dinheiro_extenso(3, :USD) == "três dólares"
        @test_throws ArgumentError dinheiro_extenso(1, :JPY)
    end

    @test dinheiro_extenso(-1, :BRL) == "menos um real"
end

@testset "datas" begin
    @test data_extenso(Date(2026, 3, 12)) ==
          "doze dias do mês de março do ano de dois mil e vinte e seis"
    @testset "o dia 1 é ordinal, e é o único no singular" begin
        # `ao primeiro dia do mês de` é a forma dos instrumentos; `um dia` não existe
        @test data_extenso(Date(2026, 3, 1)) ==
              "primeiro dia do mês de março do ano de dois mil e vinte e seis"
        @test data_corrente(Date(2026, 3, 1)) == "1º de março de 2026"
    end
    @test data_corrente(Date(2026, 3, 12)) == "12 de março de 2026"
    @test length(MESES) == 12
end
