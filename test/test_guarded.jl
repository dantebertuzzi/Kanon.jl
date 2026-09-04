# A tabela `guarded` e o teorema da lacuna (F2.3).
#
# É o incremento que carrega a fase. Sem ele o teorema vale só no primeiro nível, o que
# é o mesmo que não valer: `{seller.spouse.name}` com cônjuge ausente renderizaria vazio
# e nenhum princípio teria sido formalmente violado.
#
# Usa o ambiente e os tipos de `test_analyze.jl`, que já rodou.

const CONTRATO_G = """
kanon 1

data
  seller : person !
  buyer  : person
  price  : money  !
  notes  : text

text

: preamble
"""

mod_g(corpo) = CONTRATO_G * corpo * "\n"

"Códigos emitidos pelo corpo de texto `corpo`, com o contrato padrão desta suíte."
gcodes(corpo) = [d.code for d in anl(mod_g(corpo)).diagnostics]

@testset "o teorema da lacuna, verificado" begin
    @testset "campo opcional fora de grupo é erro; dentro, não" begin
        @test gcodes("O texto {notes} continua.") == ["K2012"]
        @test gcodes("O texto[, {notes},] continua.") == []
    end

    @testset "campo obrigatório ou com padrão não precisa de grupo" begin
        @test gcodes("O preco e {price}.") == []
        @test gcodes("Vende {seller.name}.") == []
    end

    @testset "a nulabilidade vinda de dentro do composto também exige grupo" begin
        # É este caso que distingue o teorema de valer só no primeiro nível.
        @test gcodes("Casado com {seller.spouse.name}.") == ["K2012"]
        @test gcodes("[Casado com {seller.spouse.name}.]") == []
        # e o irmão não-nulável continua livre
        @test gcodes("Mora em {seller.address.city}.") == []
    end

    @testset "a nulabilidade do sujeito exige grupo dentro do bloco (D-020)" begin
        @test [d.code for d in anl(mod_g("x") * "\n: b <- buyer\n{name}\n").diagnostics] ==
              ["K2012"]
        @test [d.code for d in anl(mod_g("x") * "\n: b <- buyer\n[{name}]\n").diagnostics] ==
              []
        # sujeito obrigatório: nada a envolver
        @test [d.code for d in anl(mod_g("x") * "\n: b <- seller\n{name}\n").diagnostics] ==
              []
    end

    @testset "qualquer grupo protege: a exigência é estar dentro de >= 1" begin
        # o grupo interno já basta para a guarda; o externo é acusado por outro motivo
        @test !("K2012" in gcodes("[[{notes}]]"))
        @test !("K2012" in gcodes("[a [b {notes}] c {price}]"))
        # o aninhamento legítimo: cada grupo com uma nulável direta sua
        @test gcodes("[casado com {seller.spouse.name}[, e {notes}]]") == []
    end

    @testset "a mensagem nomeia o segmento que introduz a ausência" begin
        d = anl(mod_g("O texto {notes} continua.")).diagnostics[1]
        @test d.code == "K2012"
        @test d.path == "notes"
        @test occursin("o contrato declara `notes` opcional", d.message)
        @test occursin("colchetes", d.hint)

        # o culpado não é `seller`, que é obrigatório, e a mensagem não pode dizer que é
        d = anl(mod_g("Casado com {seller.spouse.name}.")).diagnostics[1]
        @test occursin("`spouse` é opcional em `person`", d.message)
        @test !occursin("`seller` é opcional", d.message)

        # e a terceira origem possível: o sujeito do bloco
        d = anl(mod_g("x") * "\n: b <- buyer\n{name}\n").diagnostics[1]
        @test occursin("sujeito", d.message) && occursin("buyer", d.message)
    end

    @testset "a tabela guarded diz, por nó, se ele está dentro de um grupo" begin
        t, a = anl2(mod_g("{price} e [{notes}] e [{buyer.name} [{seller.spouse.name}]]"))
        interps = all_interps(t)
        @test [string(n.path) for n in interps] ==
              ["price", "notes", "buyer.name", "seller.spouse.name"]
        @test [a.guarded[Kanon.id(n)] for n in interps] == [false, true, true, true]
        @test length(a.guarded) == t.nnodes
        @test a.guarded isa AbstractVector{Bool}
    end

    @testset "caminho que não resolve não gera erro de guarda também" begin
        # um erro por defeito, nunca dois
        @test gcodes("{inexistente}") == ["K2001"]
    end
end

@testset "grupos que nunca elidem" begin
    @testset "grupo sem interpolação direta nenhuma" begin
        @test gcodes("Texto [fixo] aqui.") == ["K2010"]
        d = anl(mod_g("Texto [fixo] aqui.")).diagnostics[1]
        @test occursin("nunca elide", d.message)
        @test occursin("colchetes", d.hint)
    end

    @testset "grupo cujas interpolações diretas são todas garantidas (D-021)" begin
        @test gcodes("Texto [no valor de {price}] aqui.") == ["K2011"]
        d = anl(mod_g("[{price} e {seller.name}]")).diagnostics[1]
        @test d.code == "K2011"
        @test occursin("price", d.message) && occursin("seller.name", d.message)
    end

    @testset "basta uma direta nulável para o grupo poder elidir" begin
        @test gcodes("[{price} e {notes}]") == []
    end

    @testset "a interpolação de um grupo aninhado não conta para o de fora" begin
        # o externo só tem `price` como direta, e `price` é garantido
        @test gcodes("[{price} [{notes}]]") == ["K2011"]
        # invertido: agora o culpado é o interno
        @test gcodes("[{notes} [{price}]]") == ["K2011"]
        # e um grupo que só contém outro grupo não tem direta nenhuma
        @test gcodes("[[{notes}]]") == ["K2010"]
    end

    @testset "remissão a bloco não conta como interpolação direta" begin
        src = mod_g("[Conforme a {::outro}.]") * "\n:: outro\ntexto\n"
        @test "K2010" in [d.code for d in anl(src).diagnostics]
    end

    @testset "grupo com caminho que não resolve não acusa nunca-elide por cima" begin
        @test gcodes("[{inexistente}]") == ["K2001"]
    end
end

@testset "pontuação que a elisão deixaria órfã" begin
    @testset "parênteses que abrem dentro e fecham fora" begin
        @test gcodes("Texto [(veja {notes}] fim).") == ["K2013"]
        @test gcodes("Texto (veja [{notes}) fim].") == ["K2013"]
    end

    @testset "parênteses inteiros dentro, ou inteiros fora, passam" begin
        @test gcodes("Texto [(veja {notes}) ] fim.") == []
        @test gcodes("Texto (veja [{notes}] ) fim.") == []
    end

    @testset "aspas em número ímpar dentro do grupo" begin
        @test gcodes("Chamado [\\\"{notes}] adiante.") == ["K2014"]
        @test gcodes("Chamado [\\\"{notes}\\\"] adiante.") == []
    end

    @testset "apóstrofo não é aspa: não pode gerar falso positivo" begin
        @test gcodes("[o valor d'agua de {notes}]") == []
    end

    @testset "a contagem atravessa o grupo aninhado" begin
        @test "K2013" in gcodes("[a [(b {notes}] c) {price}]")
        # o parêntese do grupo interno fecha no externo: sobra órfão só para o interno
        @test gcodes("[(a [b {notes}) c] {seller.spouse.name}]") == ["K2013"]
    end

    @testset "a mensagem explica a órfã, não a contagem" begin
        d = anl(mod_g("Texto [(veja {notes}] fim).")).diagnostics[1]
        @test occursin("sozinho", d.hint)
        @test !occursin("balance", lowercase(d.message))
    end
end

@testset "o teorema como propriedade" begin
    # A afirmação do §14, verificada mecanicamente sobre um corpus pequeno: se `analyze`
    # não acusou nada, então toda interpolação nulável está dentro de algum grupo.
    corpus = [
        "{price}",
        "[{notes}]",
        "{seller.name} e [{seller.spouse.name}]",
        "[{notes}] e [{buyer.name}]",
        "[{notes} [{seller.spouse.address.city}] fim]",
        "{price} [{notes} {buyer.age}]",
    ]
    for corpo in corpus
        t, a = anl2(mod_g(corpo))
        @test isempty(a.diagnostics)
        for n in nodes1(t)
            n isa Interp || continue
            rp = resolved(a, n)
            rp === nothing && continue
            # a implicação do teorema, nó a nó
            @test !rp.nullable || a.guarded[Kanon.id(n)]
        end
    end

    @testset "e o corpus que deve ser recusado é recusado" begin
        for corpo in ["{notes}",
                      "{seller.spouse.name}",
                      "[{notes}] e {buyer.name}",
                      "[{notes} b] {seller.spouse.age}"]
            @test "K2012" in gcodes(corpo)
        end
    end
end
