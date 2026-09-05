# Semântica do plano das regras (F2.5).
#
# O que esta suíte protege: não há veracidade implícita, comparar exige que o tipo diga
# como, e a redundância entre `<- C` e `one for each C` é verificada — se ela não for,
# não serve para nada.
#
# Usa `Pessoa` e o ambiente de `test_analyze.jl`.

Kanon.kanon_attributes(::Type{Pessoa}) = (:minor,)
Kanon.kanon_attribute(v::Pessoa, ::Val{:minor}) = v.idade < 18

const CONTRATO_R = """
kanon 1

data
  seller     : person !
  buyer      : person
  witnesses  : person[2] !
  price      : money !
  notes      : text
  signed     : boolean = true
  assinatura : date !

text

: preamble
{price}

"""

"Modelo com o contrato desta suíte, um corpo de texto e um plano de regras."
mod_r(regras; corpo = "") = CONTRATO_R * corpo * "\nrules\n" * regras * "\n"

scodes(regras; corpo = "") = [d.code for d in anl(mod_r(regras; corpo); env = ENVP).diagnostics]
sdiags(regras; corpo = "") = anl(mod_r(regras; corpo); env = ENVP).diagnostics

@testset "sem veracidade implícita (§8.1)" begin
    @testset "um caminho isolado só é condição se o tipo for boolean" begin
        @test scodes("preamble when signed") == []
        d = sdiags("preamble when notes")[1]
        @test d.code == "K2040"
        @test occursin("text", d.message)
        @test occursin("is present", d.hint)
    end

    @testset "a forma correta passa" begin
        @test scodes("preamble when notes is present") == []
        @test scodes("preamble when notes is absent") == []
    end

    @testset "a exigência atravessa `and`, `or` e `not`" begin
        @test scodes("preamble when notes and signed") == ["K2040"]
        @test scodes("preamble when signed or notes") == ["K2040"]
        @test scodes("preamble when not notes") == ["K2040"]
        @test scodes("preamble when notes is present and signed") == []
        @test scodes("preamble when not (notes is present)") == []
    end

    @testset "um literal solto também não é condição" begin
        @test scodes("preamble when price > 0 and 3") == ["K2040"]
        @test scodes("preamble when true") == []      # este é booleano
    end
end

@testset "atributos" begin
    @testset "present e absent valem para qualquer campo" begin
        @test scodes("preamble when buyer is present") == []
        @test scodes("preamble when buyer is absent") == []
    end

    @testset "os demais vêm do tipo" begin
        @test scodes("preamble when price is zero") == []
        @test scodes("preamble when seller is minor") == []
        @test scodes("preamble when seller is not minor") == []
    end

    @testset "atributo que o tipo não tem, com a lista e a sugestão" begin
        d = sdiags("preamble when seller is rural")[1]
        @test d.code == "K2041"
        @test occursin("person", d.message)
        @test occursin("minor", d.hint) && occursin("present", d.hint)

        d = sdiags("preamble when seller is minr")[1]
        @test occursin("Você quis dizer `minor`?", d.hint)
    end

    @testset "o atributo canônico é o que chega à análise, em qualquer idioma" begin
        # `present` e `absent` são palavras-chave: o parser as canonicaliza, senão elas
        # não existiriam num modelo que não fosse inglês
        t = parse_string(mod_r("preamble when notes is present"); name = "t",
                         keywords = canonical_keywords())
        @test t.rules.rules[1].when.attr === :present
        t = parse_string(mod_r("preamble when notes is not absent"); name = "t",
                         keywords = canonical_keywords())
        @test t.rules.rules[1].when.attr === :absent
        # um atributo de domínio não é palavra-chave e passa como está
        t = parse_string(mod_r("preamble when seller is minor"); name = "t",
                         keywords = canonical_keywords())
        @test t.rules.rules[1].when.attr === :minor
    end

    @testset "condição sempre verdadeira sobre campo garantido é aviso" begin
        ds = sdiags("preamble when price is present")
        @test [d.code for d in ds] == ["K2047"]
        @test ds[1].severity === :warning
        @test occursin("sempre verdadeira", ds[1].message)

        ds = sdiags("preamble when price is absent")
        @test occursin("sempre falsa", ds[1].message)

        # sobre campo opcional, nada a avisar
        @test scodes("preamble when notes is present") == []
    end
end

@testset "comparações" begin
    @testset "vale quando o tipo declara como comparar" begin
        @test scodes("preamble when price > 0") == []
        @test scodes("preamble when price == 0") == []
        @test scodes("preamble when assinatura > 2026-01-01") == []
        @test scodes("preamble when signed == true") == []
        @test scodes("preamble when notes == \"x\"") == []
    end

    @testset "não vale quando ele não declara" begin
        d = sdiags("preamble when notes > 3")[1]
        @test d.code == "K2043"
        @test occursin("text", d.message) && occursin("number", d.message)
        @test occursin("declara", d.hint)

        @test scodes("preamble when assinatura > \"x\"") == ["K2043"]
        @test scodes("preamble when seller > 3") == ["K2043"]
    end

    @testset "a ordem dos operandos não importa" begin
        @test scodes("preamble when 0 < price") == []
    end

    @testset "comparar com null é erro, e a mensagem manda usar is absent" begin
        d = sdiags("preamble when notes == null")[1]
        @test d.code == "K2044"
        @test occursin("notes is absent", d.hint)
        @test scodes("preamble when null != notes") == ["K2044"]
    end

    @testset "comparação entre dois caminhos" begin
        @test scodes("preamble when price > price") == []
        @test scodes("preamble when notes > assinatura") == ["K2043"]
    end

    @testset "caminho que não resolve não gera erro de comparação por cima" begin
        @test scodes("preamble when inexistente > 0") == ["K2001"]
    end
end

@testset "one for each" begin
    corpo_cada = "\n: cada <- witnesses\n{name}\n"

    @testset "a forma correta" begin
        @test scodes("cada one for each witnesses"; corpo = corpo_cada) == []
    end

    @testset "repetir sobre um valor único é erro" begin
        d = sdiags("preamble one for each price")[1]
        @test d.code == "K2045"
        @test occursin("money", d.message)
        @test occursin("[]", d.hint)
    end

    @testset "o cabeçalho tem de declarar o sujeito, e o mesmo caminho (§8.3)" begin
        # sem `<-` nenhum
        d = sdiags("preamble one for each witnesses")[1]
        @test d.code == "K2046"
        @test occursin("<- witnesses", d.hint)

        # com `<-` divergente
        d = sdiags("cada one for each witnesses";
                   corpo = "\n: cada <- seller\n{name}\n")[1]
        @test d.code == "K2046"
        @test occursin("seller", d.message) && occursin("witnesses", d.message)
    end

    @testset "o when do bloco repetido enxerga o elemento, não a coleção (§8.3)" begin
        # `witnesses` é `person[2]`; dentro da iteração ele é uma `person`, e `minor` é
        # atributo de `person` — sobre a coleção, seria atributo de `list`
        @test scodes("cada one for each witnesses\n  cada when witnesses is not minor";
                     corpo = corpo_cada) == []
        @test scodes("cada one for each witnesses\n  cada when witnesses.age > 18";
                     corpo = corpo_cada) == []
    end

    @testset "fora da iteração, o mesmo caminho é a coleção" begin
        @test scodes("preamble when witnesses is minor") == ["K2041"]
    end
end

@testset "D-020 refinado: quando o sujeito é presente por construção" begin
    corpo_b = "\n: b <- buyer\n{name} assina.\n"

    @testset "sem regra, o sujeito opcional exige grupo" begin
        @test scodes(""; corpo = corpo_b) == ["K2012"]
    end

    @testset "when <sujeito> is present dispensa o grupo" begin
        @test scodes("b when buyer is present"; corpo = corpo_b) == []
        @test scodes("b when buyer is not absent"; corpo = corpo_b) == []
        @test scodes("b when not (buyer is absent)"; corpo = corpo_b) == []
    end

    @testset "numa conjunção, basta um termo afirmar a presença" begin
        @test scodes("b when signed and buyer is present"; corpo = corpo_b) == []
        @test scodes("b when buyer is present and price > 0"; corpo = corpo_b) == []
    end

    @testset "um `or` não garante nada, e a exigência fica" begin
        @test scodes("b when signed or buyer is present"; corpo = corpo_b) == ["K2012"]
    end

    @testset "a regra tem de falar do sujeito, não de outro campo" begin
        @test scodes("b when notes is present"; corpo = corpo_b) == ["K2012"]
    end

    @testset "a nulabilidade de dentro do composto não é afetada" begin
        # nenhuma regra sobre o sujeito diz coisa alguma sobre `spouse`
        @test scodes("b when buyer is present";
                     corpo = "\n: b <- buyer\n{name} e {spouse.name}.\n") == ["K2012"]
        @test scodes("b when buyer is present";
                     corpo = "\n: b <- buyer\n{name} e [{spouse.name}].\n") == []
    end

    @testset "o bloco repetido também tem o sujeito por construção" begin
        @test scodes("cada one for each witnesses";
                     corpo = "\n: cada <- witnesses\n{name}\n") == []
    end
end

# --- K2039: a §6.2 vista com as regras na mão --------------------------------
#
# `index_blocks!` verifica a sequência de níveis sobre o texto como está escrito. As
# regras podem produzir em execução o estado que aquela checagem proíbe no texto: basta
# que o nível 1 seja condicional e o nível 2 não seja. O documento sai com um `1.1`
# encabeçando a página, subordinado a um `1` que não está lá.
#
# Descoberto ao escrever o contrato de locação (modelo real nº 2), onde a cláusula do
# objeto tem um parágrafo sobre a mobília.

"Um modelo de dois níveis no estilo do núcleo, com o plano de regras dado."
function niveis(regras)
    """
    kanon 1

    data
      flag : boolean !

    text

    :: pai
    Do pai.

    ::: filho
    Do filho.

    :: outro
    De outro.

    rules
    $regras
    """
end

ncodes(regras) = [d.code for d in anl(niveis(regras)).diagnostics]

@testset "regra que pode deixar um nível sem o anterior (K2039)" begin
    @testset "o nível 1 condicional e o nível 2 não, é aviso" begin
        d = anl(niveis("  pai when flag")).diagnostics
        @test [x.code for x in d] == ["K2039"]
        @test d[1].severity === :warning
        @test occursin("pai", d[1].message)      # nomeia o bloco que abre o nível
        @test d[1].line == 11                    # e aponta o filho, que é o que se corrige
    end

    @testset "a mesma condição nos dois dispensa o aviso" begin
        @test ncodes("  pai when flag\n  filho when flag") == []
    end

    @testset "condição só no nível 2 não é problema" begin
        # o pai fica; o filho sai. A sequência nunca quebra.
        @test ncodes("  filho when flag") == []
    end

    @testset "sem regra nenhuma, nada a avisar" begin
        @test ncodes("  outro when flag") == []
    end

    @testset "duas condições diferentes avisam, ainda que próximas na intenção" begin
        # o reconhecimento é estrutural e conservador de propósito: dizer que garante
        # quando não garante reabriria o buraco.
        @test ncodes("  pai when flag\n  filho when not not flag") == ["K2039"]
    end

    @testset "o aviso é aviso: o modelo carrega, e o documento é o anunciado" begin
        m = load_string(ENVP, niveis("  pai when flag"); name = "n.kanon")
        @test render(m, Dict("flag" => true)) ==
              "1. Do pai.\n\n1.1. Do filho.\n\n2. De outro."

        # Sem o pai, o filho não vira `1.1`: vira `0.1`. O contador do nível 1 nunca foi
        # incrementado, e o rótulo diz isso. É a saída que o aviso existe para anunciar,
        # e é pior do que um número fora de lugar — é um número que não existe.
        @test render(m, Dict("flag" => false)) == "0.1. Do filho.\n\n1. De outro."
    end
end
