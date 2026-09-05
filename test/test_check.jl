# `check(modelo, dados)` — os dados contra o contrato (F2.6).
#
# É aqui que "o que não satisfaz o contrato não renderiza" deixa de ser uma frase.
#
# Usa `Pessoa` e `Endereco` de `test_analyze.jl`, e dá a eles o `kanon_getfield` que a
# D-023 exige: o esquema diz `name`, a `struct` guarda `nome`.

Kanon.kanon_getfield(v::Pessoa, ::Val{:name}) = v.nome
Kanon.kanon_getfield(v::Pessoa, ::Val{:spouse}) = v.conjuge
Kanon.kanon_getfield(v::Pessoa, ::Val{:address}) = v.endereco
Kanon.kanon_getfield(v::Pessoa, ::Val{:age}) = v.idade
Kanon.kanon_getfield(v::Endereco, ::Val{:street}) = v.rua
Kanon.kanon_getfield(v::Endereco, ::Val{:city}) = v.cidade

"Um tipo cujo esquema promete o que o valor não entrega — o que D-023 torna detectável."
struct Torto
    outra_coisa::String
end
Kanon.kanon_typename(::Type{Torto}) = :crooked
Kanon.kanon_schema(::Type{Torto}) = (FieldSpec(:name, :text),)
Kanon.format(v::Torto, ::Val{:default}, ctx) = v.outra_coisa

module CamadaCheck
    using Kanon
    using ..Main: Pessoa, Endereco, Torto
    function configure!(b)
        register_type!(b, Pessoa)
        register_type!(b, Endereco)
        register_type!(b, Torto)
        return b
    end
end

const ENVK = Environment(domains = [CamadaCheck])

const MODELO_K = """
kanon 1

data
  seller     : person !
  buyer      : person
  price      : money  !
  notes      : text
  witnesses  : person[2] !
  quorum     : number[1..] !
  signed     : boolean = true
  quando     : date = today

text

: preamble
{seller.name} vende por {price}[, observado que {notes}].
"""

const MODELO = load_string(ENVK, MODELO_K; name = "e.kanon")

pessoa(nome; conjuge = nothing) = Pessoa(nome, conjuge, Endereco("Rua A", "Sao Paulo"), 40)

"Dados que satisfazem o contrato inteiro."
completos() = Dict{String,Any}(
    "seller" => pessoa("Ana"),
    "price" => Money("1200.00", :BRL),
    "witnesses" => [pessoa("Bia"), pessoa("Caio")],
    "quorum" => [3, 5],
)

kcodes(d; today = Date(2026, 9, 4)) = [x.code for x in check(MODELO, d; today)]

@testset "check: o caso que passa" begin
    s = check(MODELO, completos(); today = Date(2026, 9, 4))
    isempty(s) || error("os dados completos deveriam passar:\n" * format_diagnostics(s))
    @test isempty(s)

    b = Kanon.bind(MODELO, completos(); today = Date(2026, 9, 4))
    @test !Kanon.haserrors(b)
    @test Kanon.value(b, :seller) isa Pessoa
    @test Kanon.value(b, :notes) === nothing        # opcional ausente
    @test Kanon.value(b, :signed) === true          # o padrão preenche
    @test Kanon.value(b, :quando) == Date(2026, 9, 4)
    @test length(b.values) == length(MODELO.template.data.fields)
end

@testset "um só conceito de ausência (§2.3)" begin
    @testset "chave ausente, null, nothing e missing são o mesmo nulo" begin
        for ausencia in (nothing, missing)
            d = completos(); d["seller"] = ausencia
            @test "K3001" in kcodes(d)
        end
        d = completos(); delete!(d, "seller")
        @test "K3001" in kcodes(d)

        # e no campo opcional, todas passam igual
        for ausencia in (nothing, missing)
            d = completos(); d["notes"] = ausencia
            @test isempty(kcodes(d))
        end
    end

    @testset "a mensagem nomeia o campo e a linha da declaração (§10.4)" begin
        d = completos(); delete!(d, "price")
        x = [y for y in check(MODELO, d; today = Date(2026, 9, 4)) if y.code == "K3001"][1]
        @test x.category === :contract
        @test x.path == "price"
        @test occursin("price", x.message) && occursin("linha 6", x.message)
    end

    @testset "lista vazia não é nula: `[]` é uma coleção de zero (§2.3)" begin
        d = completos(); d["quorum"] = Int[]
        @test kcodes(d) == ["K3002"]      # viola `[1..]`, e não "está ausente"
    end
end

@testset "texto em branco (D-008)" begin
    @testset "em campo opcional, vira nulo com aviso listado" begin
        d = completos(); d["notes"] = "   "
        s = check(MODELO, d; today = Date(2026, 9, 4))
        @test [x.code for x in s] == ["K3004"]
        @test s[1].severity === :warning
        @test !Kanon.haserrors(s)

        b = Kanon.bind(MODELO, d; today = Date(2026, 9, 4))
        @test Kanon.value(b, :notes) === nothing     # normalizado, e não " "
    end

    @testset "em campo garantido, é erro" begin
        # tornar `notes` garantido obriga a tirar os colchetes junto: um grupo cujas
        # diretas são todas garantidas nunca elide (D-021)
        m2 = load_string(ENVK,
                 replace(replace(MODELO_K, "  notes      : text\n" => "  notes      : text !\n"),
                         "[, observado que {notes}]" => ", observado que {notes}");
                 name = "e2.kanon")
        d = completos(); d["notes"] = "  \t "
        s = check(m2, d; today = Date(2026, 9, 4))
        @test [x.code for x in s] == ["K3003"]
        @test s[1].severity === :error
    end

    @testset "o branco fechado é o buraco por onde a lacuna voltaria" begin
        # sem D-008, `[, observado que {notes}]` com notes=" " renderizaria
        # ", observado que  " — e nenhum princípio teria sido formalmente violado
        d = completos(); d["notes"] = ""
        b = Kanon.bind(MODELO, d; today = Date(2026, 9, 4))
        @test Kanon.value(b, :notes) === nothing
    end
end

@testset "tipos e decodificação" begin
    @testset "não há coerção implícita (§3.4)" begin
        d = completos(); d["price"] = 1200
        x = [y for y in check(MODELO, d; today = Date(2026, 9, 4)) if y.code == "K3010"][1]
        @test occursin("money", x.message)
        @test occursin("currency", x.message)      # a mensagem do próprio tipo
        @test occursin("§3.4", x.hint)
    end

    @testset "a data em texto não vira data sozinha" begin
        m3 = load_string(ENVK, replace(MODELO_K, "  quando     : date = today" => "  quando     : date !");
                         name = "e3.kanon")
        d = completos(); d["quando"] = "12/03/2026"
        @test "K3010" in [x.code for x in check(m3, d)]
        d["quando"] = "2026-03-12"                 # ISO, o formato declarado
        @test isempty(check(m3, d))
    end

    @testset "o tipo decide o que é um valor bem-formado" begin
        d = completos(); d["quorum"] = ["tres"]
        @test "K3010" in kcodes(d)
    end
end

@testset "cardinalidade" begin
    @testset "valor único onde se espera coleção, e vice-versa" begin
        d = completos(); d["witnesses"] = pessoa("Bia")
        @test kcodes(d) == ["K3002"]
        d = completos(); d["price"] = [Money(1, :BRL), Money(2, :BRL)]
        @test kcodes(d) == ["K3002"]
    end

    @testset "a dica de um campo `list` não manda o autor para `list[]` (D-033)" begin
        # `list[]` é uma lista **de listas**: seguir a sugestão renderia um `K3010` por
        # elemento. O tipo `list` do núcleo não é alcançável pelo plano de dados, e o que
        # o autor quer é a cardinalidade sobre o tipo do elemento.
        m = load_string(ENVP, """
        kanon 1

        data
          items : list

        text

        : b
        Com [{items}].
        """; name = "l.kanon")
        x = only([d for d in check(m, Dict("items" => ["a", "b"]))])
        @test x.code == "K3002"
        @test occursin("items : text[]", x.hint)
        @test !occursin("items : list[]", x.hint)
    end

    @testset "a contagem exata" begin
        d = completos(); d["witnesses"] = [pessoa("Bia")]
        x = [y for y in check(MODELO, d; today = Date(2026, 9, 4)) if y.code == "K3002"][1]
        @test occursin("exatamente 2", x.message) && occursin("vieram 1", x.message)
        d["witnesses"] = [pessoa("a"), pessoa("b"), pessoa("c")]
        @test kcodes(d) == ["K3002"]
    end

    @testset "pelo menos" begin
        d = completos(); d["quorum"] = [1]
        @test isempty(kcodes(d))
        d["quorum"] = Int[]
        x = [y for y in check(MODELO, d; today = Date(2026, 9, 4))][1]
        @test occursin("pelo menos 1", x.message)
    end

    @testset "uma coleção não tem buracos" begin
        d = completos(); d["witnesses"] = [pessoa("Bia"), nothing]
        s = check(MODELO, d; today = Date(2026, 9, 4))
        @test [x.code for x in s] == ["K3001"]
        @test occursin("2º valor", s[1].message)
        @test s[1].path == "witnesses[2]"
    end
end

@testset "o esquema do tipo composto é exigido (D-023)" begin
    @testset "campo obrigatório do esquema não pode chegar nulo" begin
        # `person` declara `name` obrigatório: um `person` sem nome abriria no texto
        # o buraco que `{seller.name}` supõe impossível
        d = completos(); d["seller"] = Pessoa("", nothing, Endereco("R", "C"), 40)
        s = check(MODELO, d; today = Date(2026, 9, 4))
        @test [x.code for x in s] == ["K3001"]
        @test s[1].path == "seller.name"
        @test occursin("person", s[1].message)
    end

    @testset "campo opcional do esquema pode" begin
        d = completos(); d["seller"] = pessoa("Ana"; conjuge = nothing)
        @test isempty(kcodes(d))
        d["seller"] = pessoa("Ana"; conjuge = pessoa("Bo"))
        @test isempty(kcodes(d))
    end

    @testset "a exigência desce nos aninhados e nas coleções" begin
        d = completos()
        d["seller"] = pessoa("Ana"; conjuge = Pessoa("", nothing, Endereco("R", "C"), 40))
        s = check(MODELO, d; today = Date(2026, 9, 4))
        @test s[1].path == "seller.spouse.name"

        d = completos(); d["witnesses"] = [pessoa("Bia"), Pessoa("", nothing, Endereco("R","C"), 40)]
        @test [x.path for x in check(MODELO, d; today = Date(2026, 9, 4))] == ["witnesses[2].name"]
    end

    @testset "esquema que promete o que o valor não tem" begin
        m4 = load_string(ENVK, """
kanon 1

data
  x : crooked !

text

: b
{x.name}
"""; name = "e4.kanon")
        s = check(m4, Dict("x" => Torto("nada")))
        @test [d.code for d in s] == ["K3012"]
        @test occursin("kanon_getfield", s[1].hint)
    end

    @testset "um ciclo nos dados para, e diz que parou" begin
        a = Pessoa("A", nothing, Endereco("R", "C"), 40)
        # um ciclo de verdade exige mutabilidade; a cadeia longa prova o mesmo teto
        for _ in 1:(Kanon.MAX_COMPOSITE_DEPTH + 2)
            a = Pessoa("A", a, Endereco("R", "C"), 40)
        end
        d = completos(); d["seller"] = a
        @test "K3030" in kcodes(d)
    end
end

@testset "today é injetado, nunca lido do relógio (§2.2)" begin
    @testset "sem today, o modelo que o usa não passa" begin
        s = check(MODELO, completos())
        @test [d.code for d in s] == ["K3005"]
        @test occursin("relógio", s[1].hint)
    end

    @testset "cada uso de today aponta a sua linha" begin
        m5 = load_string(ENVK, """
kanon 1

data
  d : date = today

text

: b
Em {today}, e em {d}.
"""; name = "e5.kanon")
        s = check(m5, Dict())
        @test [x.code for x in s] == ["K3005", "K3005"]
        @test [x.line for x in s] == [4, 9]      # a declaração e a interpolação
    end

    @testset "com today, o padrão é preenchido com ele" begin
        b = Kanon.bind(MODELO, completos(); today = Date(2027, 1, 31))
        @test Kanon.value(b, :quando) == Date(2027, 1, 31)
    end
end

@testset "campo a mais nos dados é aviso (D-022)" begin
    d = completos(); d["sellerr"] = pessoa("X")
    s = check(MODELO, d; today = Date(2026, 9, 4))
    @test [x.code for x in s] == ["K3021"]
    @test s[1].severity === :warning
    @test !Kanon.haserrors(s)
    @test occursin("Você quis dizer `seller`?", s[1].hint)
    @test s[1].line == 0                          # o problema está nos dados, não no arquivo
end

@testset "as quatro formas de entrada" begin
    p, w, q = pessoa("Ana"), [pessoa("B"), pessoa("C")], [3]
    m = Money("1.00", :BRL)
    hoje = Date(2026, 9, 4)

    @testset "Dict de string, Dict de símbolo e NamedTuple dão o mesmo" begin
        ds = Dict("seller" => p, "price" => m, "witnesses" => w, "quorum" => q)
        sy = Dict(:seller => p, :price => m, :witnesses => w, :quorum => q)
        nt = (seller = p, price = m, witnesses = w, quorum = q)
        for d in (ds, sy, nt)
            @test isempty(check(MODELO, d; today = hoje))
        end
    end

    @testset "uma struct qualquer também serve" begin
        @test isempty(check(MODELO, (; seller = p, price = m, witnesses = w, quorum = q);
                            today = hoje))
    end
end

@testset "check acumula, e não lança" begin
    s = check(MODELO, Dict())
    @test length(s) >= 4                         # todos os que faltam, de uma vez
    @test issorted([(x.line, x.col, x.code) for x in s])
    @test Set(x.code for x in s) == Set(["K3001", "K3005"])
    @test s isa DiagnosticSet
end

@testset "aceite da F2: check recusa o JSON sem `effect`" begin
    env = Environment(domains = [Science])
    m = load_string(env, RELATORIO; name = "report.kanon")

    bons = Dict("effect" => Measure(0.42, 0.07, "mm"),
                "sample" => 1200,
                "method" => "ordinary least squares",
                "caveat" => nothing)
    @test isempty(check(m, bons))

    faltando = copy(bons); delete!(faltando, "effect")
    s = check(m, faltando)
    @test [d.code for d in s] == ["K3001"]
    @test s[1].path == "effect"
    @test occursin("effect", s[1].message)
    @test occursin("linha 4", s[1].message)      # nomeia o campo E aponta a linha
end
