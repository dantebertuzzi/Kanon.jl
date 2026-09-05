# Regras em execução (F5): quais blocos existem, quantas vezes, e com que número.
#
# A invariante anti-XSLT (D-015) é o que esta suíte protege: regras só **removem** ou
# **repetem**. Nunca inserem, nunca substituem, nunca reordenam — e por isso a ordem da
# saída é sempre a ordem do plano do texto.

const CAB_R = """
kanon 1

data
  seller    : person !
  witnesses : person[1..] !
  price     : money !
  notes     : text
  signed    : boolean = true

text

"""

r_render(corpo; dados = Dict{String,Any}()) =
    render(load_string(ENVK, CAB_R * corpo; name = "r.kanon"), dados)

const DADOS_R = Dict{String,Any}(
    "seller" => Pessoa("Ana", nothing, Endereco("R", "C"), 40),
    "witnesses" => [Pessoa("Bia", nothing, Endereco("R", "C"), 30),
                    Pessoa("Caio", nothing, Endereco("R", "C"), 50)],
    "price" => Money("1200.00", :BRL),
)

@testset "`when` remove o bloco" begin
    modelo = """
: a
Primeiro.

: b
Com nota: {notes}.

: c
Terceiro.

rules
  b when notes is present
"""

    @testset "com a condição verdadeira, o bloco fica" begin
        d = merge(DADOS_R, Dict("notes" => "x"))
        @test r_render(modelo; dados = d) == "Primeiro.\n\nCom nota: x.\n\nTerceiro."
    end

    @testset "com a condição falsa, o bloco sai — e nada mais se move" begin
        @test r_render(modelo; dados = DADOS_R) == "Primeiro.\n\nTerceiro."
    end

    @testset "a ordem da saída é sempre a do plano do texto (D-015)" begin
        for d in (DADOS_R, merge(DADOS_R, Dict("notes" => "x")))
            s = r_render(modelo; dados = d)
            @test findfirst("Primeiro", s)[1] < findfirst("Terceiro", s)[1]
        end
    end

    @testset "as condições que a linguagem tem" begin
        cond(c) = r_render(": a\nA\n\n: b\nB\n\nrules\n  b when $c\n"; dados = DADOS_R)
        @test cond("notes is absent") == "A\n\nB"
        @test cond("notes is present") == "A"
        @test cond("price > 0") == "A\n\nB"
        @test cond("price > 9999") == "A"
        @test cond("signed") == "A\n\nB"
        @test cond("not signed") == "A"
        @test cond("signed and price > 0") == "A\n\nB"
        @test cond("signed and notes is present") == "A"
        @test cond("signed or notes is present") == "A\n\nB"
        @test cond("seller is minor") == "A"          # 40 anos
        @test cond("seller is not minor") == "A\n\nB"
    end

    @testset "comparação com valor ausente é falsa, não um erro" begin
        # a pergunta pela ausência é `is absent`; comparar com o que não veio é falso
        @test r_render(": a\nA\n\n: b\nB\n\nrules\n  b when notes == \"x\"\n";
                       dados = DADOS_R) == "A"
    end
end

@testset "`one for each` repete o bloco" begin
    modelo = """
: cada <- witnesses
{name}, de {address.city}.

rules
  cada one for each witnesses
"""

    @testset "uma instância por elemento, com o elemento por sujeito" begin
        @test r_render(modelo; dados = DADOS_R) == "Bia, de C.\n\nCaio, de C."
    end

    @testset "coleção de um só produz uma instância" begin
        d = merge(DADOS_R, Dict("witnesses" => [Pessoa("Bia", nothing, Endereco("R", "C"), 30)]))
        @test r_render(modelo; dados = d) == "Bia, de C."
    end

    @testset "o `when` do bloco repetido é avaliado por iteração (§8.3)" begin
        # "um bloco por testemunha, exceto as menores"
        com_regra = modelo * "  cada when witnesses is not minor\n"
        d = merge(DADOS_R, Dict("witnesses" => [
            Pessoa("Bia", nothing, Endereco("R", "C"), 30),
            Pessoa("Kid", nothing, Endereco("R", "C"), 15),
            Pessoa("Caio", nothing, Endereco("R", "C"), 50)]))
        @test r_render(com_regra; dados = d) == "Bia, de C.\n\nCaio, de C."
    end

    @testset "o orçamento de iterações é contado, não cronometrado" begin
        muitas = [Pessoa("P$i", nothing, Endereco("R", "C"), 30) for i in 1:50]
        d = merge(DADOS_R, Dict("witnesses" => muitas))
        m = load_string(ENVK, CAB_R * modelo; name = "r.kanon")
        e = try; render(m, d; budget = Budget(iterations = 10)); catch err; err; end
        @test e isa KanonResourceError
        @test [x.code for x in e.diagnostics] == ["K4004"]
        @test render(m, d; budget = Budget(iterations = 1000)) isa String
    end
end

@testset "numeração com regras (§6.2)" begin
    @testset "bloco removido não consome número" begin
        modelo = """
:: um
A.

:: dois
B.

:: tres
C.

rules
  dois when notes is present
"""
        # sem a nota, `dois` sai e `tres` vira 2 — a numeração é dos dados
        @test r_render(modelo; dados = DADOS_R) == "1. A.\n\n2. C."
        d = merge(DADOS_R, Dict("notes" => "x"))
        @test r_render(modelo; dados = d) == "1. A.\n\n2. B.\n\n3. C."
    end

    @testset "bloco repetido consome um número por iteração" begin
        modelo = """
:: cada <- witnesses
{name}.

:: fim
Fim.

rules
  cada one for each witnesses
"""
        @test r_render(modelo; dados = DADOS_R) == "1. Bia.\n\n2. Caio.\n\n3. Fim."
    end

    @testset "os níveis zeram como no plano estático" begin
        modelo = """
:: um
A.

::: um_um
B.

:: dois
C.

::: dois_um
D.
"""
        @test r_render(modelo; dados = DADOS_R) ==
              "1. A.\n\n1.1. B.\n\n2. C.\n\n2.1. D."
    end

    @testset "a remissão renumera junto com a remoção" begin
        modelo = """
:: um
A.

:: dois
B.

: fecho
Conforme a {::dois}.

rules
  um when notes is present
"""
        # sem a nota, `um` sai e `dois` passa a ser 1
        @test r_render(modelo; dados = DADOS_R) == "1. B.\n\nConforme a 1."
        d = merge(DADOS_R, Dict("notes" => "x"))
        @test r_render(modelo; dados = d) == "1. A.\n\n2. B.\n\nConforme a 2."
    end
end

@testset "remissão a bloco que as regras removeram é erro de contrato" begin
    modelo = CAB_R * """
:: alvo
Alvo.

: fecho
Conforme a {::alvo}.

rules
  alvo when notes is present
"""
    m = load_string(ENVK, modelo; name = "r.kanon")

    @testset "o modelo carrega com aviso, porque o autor pode saber que coincidem" begin
        @test [d.code for d in m.analysis.diagnostics] == ["K2035"]
        @test !Kanon.haserrors(m.analysis)
    end

    @testset "com os dados que mantêm o bloco, tudo bem" begin
        d = merge(DADOS_R, Dict("notes" => "x"))
        @test isempty(check(m, d))
        @test render(m, d) == "1. Alvo.\n\nConforme a 1."
    end

    @testset "com os dados que o removem, é erro — e antes de renderizar" begin
        s = check(m, DADOS_R)
        @test [d.code for d in s] == ["K3040"]
        @test s[1].path == "alvo"
        @test occursin("as regras removeram", s[1].message)
        @test_throws KanonContractError render(m, DADOS_R)
    end
end

@testset "o plano é dado, e a Analysis continua estática" begin
    m = load_string(ENVK, CAB_R * """
:: um
A.

:: dois
B.

rules
  um when notes is present
""" ; name = "r.kanon")

    @testset "a Analysis numera como se nada fosse removido" begin
        @test m.analysis.numbering == [Int32[1], Int32[2]]
    end

    @testset "e o plano numera conforme os dados" begin
        b = Kanon.bind(m, DADOS_R)
        @test b.plan.present == [false, true]
        @test b.plan.numbers == [Int32[], Int32[1]]
        @test length(b.plan.instances) == 1

        b2 = Kanon.bind(m, merge(DADOS_R, Dict("notes" => "x")))
        @test b2.plan.present == [true, true]
        @test b2.plan.numbers == [Int32[1], Int32[2]]
    end

    @testset "render puro: mesma entrada, mesma saída" begin
        @test render(m, DADOS_R) == render(m, DADOS_R)
    end
end

@testset "D-020, 2ª revisão: o `when` garante o campo em todo o texto do bloco" begin
    @testset "o padrão mais natural da linguagem não pede colchetes redundantes" begin
        # `b when notes is present` já diz que o bloco só existe com a nota
        m = load_string(ENVK, CAB_R * """
: b
Com nota: {notes}.

rules
  b when notes is present
"""; name = "r.kanon")
        @test isempty(m.analysis.diagnostics)
        @test render(m, merge(DADOS_R, Dict("notes" => "x"))) == "Com nota: x."
    end

    @testset "as três formas de afirmar presença" begin
        for cond in ("notes is present", "notes is not absent", "not (notes is absent)")
            m = load_string(ENVK, CAB_R * ": b\n{notes}\n\nrules\n  b when $cond\n";
                            name = "r.kanon")
            @test isempty(m.analysis.diagnostics)
        end
    end

    @testset "numa conjunção, basta um termo afirmar" begin
        m = load_string(ENVK, CAB_R * """
: b
{notes}

rules
  b when signed and notes is present
"""; name = "r.kanon")
        @test isempty(m.analysis.diagnostics)
    end

    @testset "um `or` não garante, e a exigência de grupo fica" begin
        codigos = [d.code for d in anl(CAB_R * """
: b
{notes}

rules
  b when signed or notes is present
"""; env = ENVK).diagnostics]
        @test codigos == ["K2012"]
    end

    @testset "a garantia é do bloco que tem a regra, e não vaza para os outros" begin
        codigos = [d.code for d in anl(CAB_R * """
: a
{notes}

: b
{notes}

rules
  b when notes is present
"""; env = ENVK).diagnostics]
        @test codigos == ["K2012"]                 # só o bloco `a` é acusado
    end

    @testset "a garantia cobre o prefixo, não o caminho inteiro" begin
        # `seller is present` não diz nada sobre `spouse`, que é opcional em `person`
        codigos = [d.code for d in anl(CAB_R * """
: b
{seller.spouse.name}

rules
  b when seller is present
"""; env = ENVK).diagnostics]
        @test "K2012" in codigos
        # e, de quebra, o aviso de que a condição é tautologia: `seller` é obrigatório
        @test "K2047" in codigos
    end
end
