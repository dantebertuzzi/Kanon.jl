# Flexão por marca, e o invariante D-013.

"Um sujeito de mentira, com gênero e número declarados — o que uma camada de domínio faz."
struct Parte
    nome::String
    g::Symbol
end
Extenso.genero(p::Parte) = p.g

const ELE = Parte("João", :m)
const ELA = Parte("Maria", :f)

@testset "flexão por marca" begin
    @testset "gênero: a marca ocupa a desinência" begin
        @test flexionar("brasileiro", "(a)", ELA) == "brasileira"
        @test flexionar("brasileiro", "(a)", ELE) == "brasileiro"
        @test flexionar("casado", "(a)", ELA) == "casada"
        @test flexionar("denominado", "(a)", ELA) == "denominada"
    end

    @testset "gênero: sem desinência, a marca anexa" begin
        @test flexionar("portador", "(a)", ELA) == "portadora"
        @test flexionar("portador", "(a)", ELE) == "portador"
        @test flexionar("VENDEDOR", "(A)", ELA) == "VENDEDORA"
    end

    @testset "número: a marca vem depois da desinência, não no lugar dela" begin
        dois = [ELE, ELE]
        @test flexionar("legítimo", "(s)", dois) == "legítimos"
        @test flexionar("proprietário", "(s)", dois) == "proprietários"
        @test flexionar("O", "(s)", dois) == "Os"
        @test flexionar("O", "(s)", [ELE]) == "O"
        @test flexionar("VENDEDOR", "(ES)", dois) == "VENDEDORES"
        @test flexionar("declara", "(m)", dois) == "declaram"
        @test flexionar("ser", "(em)", dois) == "serem"
    end

    @testset "gênero e número na mesma marca" begin
        elas = [ELA, ELA]
        @test flexionar("denominado", "(as)", elas) == "denominadas"
        @test flexionar("denominado", "(as)", [ELE, ELA]) == "denominado"   # misto ⇒ m
        @test flexionar("casado", "(os)", [ELE, ELA]) == "casados"
    end

    @testset "a caixa da marca é a caixa do sufixo" begin
        @test flexionar("outorgante", "(s)", [ELE, ELE]) == "outorgantes"
        @test flexionar("OUTORGANTE", "(S)", [ELE, ELE]) == "OUTORGANTES"
    end

    @testset "grupo misto é masculino — a regra do português" begin
        @test genero([ELE, ELA]) === :m
        @test genero([ELA, ELA]) === :f
        @test genero([ELE, ELE]) === :m
        @test numero([ELE]) === :singular
        @test numero([ELE, ELA]) === :plural
    end

    @testset "gênero desconhecido não flexiona, e não vira masculino em silêncio" begin
        @test genero("uma cadeia qualquer") === nothing
        @test flexionar("brasileiro", "(a)", "cadeia") == "brasileiro"
        @test flexionar("brasileiro", "(a)", nothing) == "brasileiro"
        # mas a marca de número, que não depende de gênero, continua funcionando
        @test flexionar("item", "(s)", [ELE, ELE]) == "items"
    end

    @testset "forma que não é marca volta a ser prosa" begin
        @test flexionar("sigla", "(xyz)", ELA) == "sigla(xyz)"
    end
end

@testset "D-013 — só a palavra que carrega a marca muda" begin
    # O invariante inteiro cabe numa afirmação: `flexionar` recebe uma palavra e devolve
    # uma palavra. Não há assinatura por onde a prosa em volta possa entrar.
    @test all(m -> hasmethod(flexionar, Tuple{String,String,Any}), (nothing,))

    @testset "a prosa em volta é intocada, e o teste é o exemplo da decisão" begin
        elas = [ELA, ELA]
        # `residente e domiciliado(a)` com sujeito feminino plural
        sem_marca = "residente" ; com_marca = flexionar("domiciliado", "(a)", elas)
        @test sem_marca * " e " * com_marca == "residente e domiciliada"
        # para o resultado completo, o autor marca as duas palavras
        @test flexionar("residente", "(s)", elas) * " e " *
              flexionar("domiciliado", "(as)", elas) == "residentes e domiciliadas"
    end
end

@testset "recapitalização depois da elisão (§5.4)" begin
    rec(t, e) = Extenso.recapitalizar(t, e, nothing)

    @testset "o começo do parágrafo elidido recapitaliza" begin
        @test rec("a parte declara.", [1]) == "A parte declara."
    end

    @testset "depois de um terminador, também" begin
        @test rec("Fim. a parte declara.", [6]) == "Fim. A parte declara."
    end

    @testset "no meio da frase, não — a minúscula pode ser o que o autor quis" begin
        @test rec("A parte, a saber, declara.", [10]) == "A parte, a saber, declara."
    end

    @testset "sem emenda, nada muda" begin
        @test rec("a parte declara.", Int[]) == "a parte declara."
    end
end
