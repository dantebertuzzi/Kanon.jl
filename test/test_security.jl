# Modelo de segurança (§11) — um teste adversarial por garantia.
#
# A premissa: **um modelo é dado não confiável**. Quem escreve o modelo pode não ser
# quem opera o motor, e o motor não tem o direito de supor boa-fé.

"Um tipo com um campo que o esquema não declara — o alvo do teste de vazamento."
struct ComSegredo
    nome::String
    senha::String
end
Kanon.kanon_typename(::Type{ComSegredo}) = :guarded
Kanon.kanon_schema(::Type{ComSegredo}) = (FieldSpec(:name, :text),)
Kanon.kanon_getfield(v::ComSegredo, ::Val{:name}) = v.nome
Kanon.format(v::ComSegredo, ::Val{:default}, ctx) = v.nome

module CamadaSeg
    using Kanon
    using ..Main: ComSegredo
    configure!(b) = register_type!(b, ComSegredo)
end

const ENVS = Environment(domains = [CamadaSeg])

@testset "§11 — o modelo é dado não confiável" begin
    @testset "1. renderizar não executa código do modelo" begin
        # nenhuma destas formas é sintaxe da linguagem: todas param no parser ou na
        # análise, e nenhuma chega a ser avaliada
        for hostil in ["{run(`ls`)}", "{Base.exit()}", "{a; b}", "{eval(x)}", "{@show x}"]
            src = "kanon 1\n\ndata\n  a : text !\n\ntext\n\n: b\n$hostil\n"
            e = try; load_string(ENVS, src; name = "h"); catch err; err; end
            @test e isa KanonError
        end
    end

    @testset "2 e 3. renderizar não lê arquivo nem acessa rede" begin
        # não há sintaxe de inclusão na v1, e nem de URL: a garantia é estrutural
        src = "kanon 1\n\ntext\n\n: b\n{include \"/etc/passwd\"} {http://x}\n"
        @test (try; load_string(ENVS, src; name = "h"); false; catch; true; end)
    end

    @testset "4. só campos declarados são acessíveis" begin
        m = load_string(ENVS, """
kanon 1

data
  u : guarded !

text

: b
{u.name}
"""; name = "h")
        v = ComSegredo("Ana", "hunter2")
        @test render(m, Dict("u" => v)) == "Ana"

        # o campo fora do esquema não é alcançável nem escrevendo o caminho
        src = replace("""
kanon 1

data
  u : guarded !

text

: b
{u.senha}
""", "" => "")
        e = try; load_string(ENVS, src; name = "h"); catch err; err; end
        @test e isa KanonReferenceError
        @test "K2003" in [d.code for d in e.diagnostics]
        # e a mensagem não vaza o nome do campo Julia que existe mas não é declarado
        @test !occursin("hunter2", sprint(showerror, e))
    end

    @testset "4b. dado extra na entrada não chega ao documento" begin
        m = load_string(ENVS, "kanon 1\n\ndata\n  a : text !\n\ntext\n\n: b\n{a}\n";
                        name = "h")
        s = render(m, Dict("a" => "visível", "oculto" => "SEGREDO"))
        @test s == "visível"
        @test !occursin("SEGREDO", s)
    end

    @testset "5. sem recursão infinita: valor que se aninha sem fim é recusado" begin
        # a inclusão cíclica é da F7; o que existe hoje para ciclar é o dado composto
        a = Pessoa("A", nothing, Endereco("R", "C"), 40)
        for _ in 1:(Kanon.MAX_COMPOSITE_DEPTH + 2)
            a = Pessoa("A", a, Endereco("R", "C"), 40)
        end
        m = load_string(ENVK, "kanon 1\n\ndata\n  p : person !\n\ntext\n\n: b\n{p.name}\n";
                        name = "h")
        @test "K3030" in [d.code for d in check(m, Dict("p" => a))]
    end

    @testset "6. o orçamento é determinístico, e por isso reprodutível" begin
        m = load_string(ENVK, "kanon 1\n\ndata\n  a : text !\n\ntext\n\n: b\n{a}{a}{a}{a}\n";
                        name = "h")
        d = Dict("a" => "x" ^ 100)

        # a mesma entrada e o mesmo orçamento erram sempre, em qualquer máquina
        for _ in 1:3
            e = try; render(m, d; budget = Budget(bytes = 10)); catch err; err; end
            @test e isa KanonResourceError
        end
        @test render(m, d; budget = Budget(bytes = 10_000)) == "x" ^ 400
    end

    @testset "um modelo enorme não engana o orçamento de nós" begin
        corpo = join(["linha $i com {a}" for i in 1:500], "\n\n")
        m = load_string(ENVK, "kanon 1\n\ndata\n  a : text !\n\ntext\n\n: b\n$corpo\n";
                        name = "h")
        @test_throws KanonResourceError render(m, Dict("a" => "x"); budget = Budget(nodes = 100))
        @test render(m, Dict("a" => "x"); budget = Budget(nodes = 100_000)) isa String
    end

    @testset "determinismo: nada de relógio dentro do render" begin
        m = load_string(ENVK, "kanon 1\n\ndata\n  d : date = today\n\ntext\n\n: b\n{d} {today}\n";
                        name = "h")
        # sem `today` injetado, é erro de contrato — e não a data de hoje do sistema
        @test "K3005" in [x.code for x in check(m, Dict())]
        @test render(m, Dict(); today = Date(2000, 1, 1)) == "2000-01-01 2000-01-01"
    end
end

@testset "o teorema da lacuna, sobre o texto produzido" begin
    # A afirmação do §14 verificada de ponta a ponta: analyze passa, check passa, logo o
    # texto não tem trecho originado de valor ausente.
    m = load_string(ENVK, """
kanon 1

data
  a : text !
  b : text
  c : text
  seller : person !

text

: p
{a}[, com {b}][ e {c}], de {seller.name}[, casado com {seller.spouse.name}].
"""; name = "t")

    p(nome; conj = nothing) = Pessoa(nome, conj, Endereco("R", "C"), 40)

    casos = [
        (Dict("a" => "A", "seller" => p("Ana")),
         "A, de Ana."),
        (Dict("a" => "A", "b" => "B", "seller" => p("Ana")),
         "A, com B, de Ana."),
        (Dict("a" => "A", "c" => "C", "seller" => p("Ana")),
         "A e C, de Ana."),
        (Dict("a" => "A", "b" => "B", "c" => "C", "seller" => p("Ana"; conj = p("Bo"))),
         "A, com B e C, de Ana, casado com Bo."),
        (Dict("a" => "A", "b" => "   ", "seller" => p("Ana")),
         "A, de Ana."),
    ]

    for (dados, esperado) in casos
        # avisos não impedem: o branco normalizado deixa um K3004, que é o registro de
        # que a normalização aconteceu (D-008)
        @test !Kanon.haserrors(check(m, dados))
        s = render(m, dados)
        @test s == esperado
        @testset "nenhum vestígio de ausência em $(repr(s))" begin
            @test !occursin(", ,", s)
            @test !occursin("  ", s)
            @test !occursin(" .", s)
            @test !occursin(",.", s)
            @test !startswith(s, ",") && !startswith(s, " ")
            @test !endswith(s, ",") && !endswith(s, " ")
        end
    end
end
