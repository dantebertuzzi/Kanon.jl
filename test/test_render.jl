# `render` — os treze casos normativos, e as invariantes do passo (F3).
#
# Os arquivos de `test/golden/emenda/` foram escritos ANTES deste código, como o risco
# 16.4 manda. Cada um traz modelo, dados e saída exigida, e a suíte compara byte a byte.

const EMENDA = joinpath(@__DIR__, "golden", "emenda")

"""
Lê um arquivo golden: `=== modelo`, `=== dados`, `=== saida`. Linhas iniciadas por `#`
antes da primeira seção são comentário do caso.

Os dados usam uma notação mínima — `chave = "texto"`, `= 12`, `= null` — de propósito:
um JSON exigiria dependência, e Julia avaliada exigiria `eval` numa suíte que testa um
motor que proíbe `eval`.
"""
function read_golden(path)
    secao = nothing
    partes = Dict{String,Vector{String}}()
    for linha in eachline(path)
        if startswith(linha, "=== ")
            secao = strip(linha[5:end])
            partes[secao] = String[]
        elseif secao === nothing
            continue                       # comentário do cabeçalho
        else
            push!(partes[secao], linha)
        end
    end
    (modelo = join(partes["modelo"], "\n") * "\n",
     dados = parse_dados(partes["dados"]),
     saida = join(partes["saida"], "\n"))
end

function parse_dados(linhas)
    d = Dict{String,Any}()
    for l in linhas
        isempty(strip(l)) && continue
        chave, valor = split(l, " = "; limit = 2)
        d[strip(chave)] = parse_valor(strip(valor))
    end
    d
end

function parse_valor(v)
    v == "null" && return nothing
    startswith(v, '"') && return replace(v[2:(end - 1)], "\\n" => "\n")
    occursin('.', v) && return parse(Float64, v)
    parse(Int, v)
end

@testset "os treze casos normativos de elisão (§5.3)" begin
    arquivos = sort(readdir(EMENDA))
    @test length(arquivos) == 13

    for nome in arquivos
        caso = read_golden(joinpath(EMENDA, nome))
        @testset "$nome" begin
            m = load_string(ENVK, caso.modelo; name = nome)
            s = check(m, caso.dados)
            isempty(s) || error("o caso $nome não passa no contrato:\n" *
                                format_diagnostics(s))
            obtido = render(m, caso.dados)
            obtido == caso.saida ||
                println("  esperado: ", repr(caso.saida), "\n  obtido:   ", repr(obtido))
            @test obtido == caso.saida
        end
    end
end

@testset "render: o básico" begin
    env = ENVK

    @testset "prosa literal atravessa intacta" begin
        m = load_string(env, "kanon 1\n\ntext\n\n: b\nUm texto qualquer.\n"; name = "t")
        @test render(m, Dict()) == "Um texto qualquer."
    end

    @testset "interpolação usa o formatador que analyze resolveu" begin
        m = load_string(env, """
kanon 1

data
  p : money !
  n : text  !

text

: b
{n} paga {p} ou {p:code}, em maiúsculas {n:upper}.
"""; name = "t")
        d = Dict("p" => Money("1200.50", :BRL), "n" => "Ana")
        @test render(m, d) == "Ana paga BRL 1200.50 ou BRL 1200.50, em maiúsculas ANA."
    end

    @testset "os escapes já vieram resolvidos do parser" begin
        m = load_string(env, "kanon 1\n\ntext\n\n: b\n{{a}} ((b)) \\[c\\] \\\\d\n"; name = "t")
        @test render(m, Dict()) == "{a} (b) [c] \\d"
    end

    @testset "parágrafos são separados por linha em branco, e a quebra interna fica" begin
        m = load_string(env, "kanon 1\n\ntext\n\n: b\numa\nlinha\n\noutra\n"; name = "t")
        @test render(m, Dict()) == "uma\nlinha\n\noutra"
    end

    @testset "blocos saem na ordem do plano do texto (D-015)" begin
        m = load_string(env, "kanon 1\n\ntext\n\n: a\nA\n\n: b\nB\n\n: c\nC\n"; name = "t")
        @test render(m, Dict()) == "A\n\nB\n\nC"
    end

    @testset "o sujeito do bloco resolve os campos dele" begin
        m = load_string(env, """
kanon 1

data
  seller : person !

text

: g <- seller
{name}, de {address.city}.
"""; name = "t")
        p = Pessoa("Ana", nothing, Endereco("Rua A", "Recife"), 40)
        @test render(m, Dict("seller" => p)) == "Ana, de Recife."
    end

    @testset "today é o injetado, nunca o relógio (§2.2)" begin
        m = load_string(env, """
kanon 1

data
  d : date = today

text

: b
Em {today}, valendo desde {d}.
"""; name = "t")
        @test render(m, Dict(); today = Date(2026, 3, 12)) ==
              "Em 2026-03-12, valendo desde 2026-03-12."
    end
end

@testset "render: blocos numerados e remissões" begin
    @testset "o núcleo numera 1, 2, 3.1 e prefixa com \". \" (§6.3, §6.4)" begin
        m = load_string(ENVK, """
kanon 1

text

:: um
Primeiro.

::: um_um
Aninhado.

:: dois
Segundo.
"""; name = "t")
        @test render(m, Dict()) == "1. Primeiro.\n\n1.1. Aninhado.\n\n2. Segundo."
    end

    @testset "a remissão rende o texto de remissão do estilo" begin
        m = load_string(ENVK, """
kanon 1

text

:: pagamento
O preço.

: b
Conforme a {::pagamento}, fica ajustado.
"""; name = "t")
        @test render(m, Dict()) == "1. O preço.\n\nConforme a 1, fica ajustado."
    end

    @testset "a remissão renumera sozinha quando um bloco entra antes" begin
        antes = """
kanon 1

text

:: pagamento
O preço.

: b
Conforme a {::pagamento}.
"""
        depois = replace(antes, ":: pagamento" => ":: objeto\nO objeto.\n\n:: pagamento")
        @test occursin("Conforme a 1.", render(load_string(ENVK, antes; name = "t"), Dict()))
        @test occursin("Conforme a 2.", render(load_string(ENVK, depois; name = "t"), Dict()))
    end

    @testset "layout :heading põe o rótulo em parágrafo próprio" begin
        m = load_string(Environment(domains = [Science]), """
kanon 1

text

@@ teorema
O enunciado.
"""; name = "t")
        @test render(m, Dict()) == "Theorem 1. O enunciado."
    end
end

@testset "render é puro, e só falha por orçamento" begin
    m = load_string(ENVK, """
kanon 1

data
  n : text !

text

: b
{n} e {n} e {n}.
"""; name = "t")

    @testset "mesma entrada, mesma saída byte a byte" begin
        d = Dict("n" => "x")
        @test render(m, d) == render(m, d)
    end

    @testset "não renderiza dados que não passam no contrato — nem como opção" begin
        e = try; render(m, Dict()); catch err; err; end
        @test e isa KanonContractError
        @test "K3001" in [x.code for x in e.diagnostics]
    end

    @testset "o orçamento é contado, nunca cronometrado (D-010)" begin
        e = try; render(m, Dict("n" => "x"); budget = Budget(nodes = 2)); catch err; err; end
        @test e isa KanonResourceError
        @test [x.code for x in e.diagnostics] == ["K4001"]
        @test occursin("contagem, não um tempo", e.diagnostics[1].hint)

        e = try; render(m, Dict("n" => "x"); budget = Budget(bytes = 3)); catch err; err; end
        @test e isa KanonResourceError
        @test [x.code for x in e.diagnostics] == ["K4002"]

        # o mesmo orçamento dá o mesmo resultado, em qualquer máquina
        @test render(m, Dict("n" => "x"); budget = Budget(nodes = 50)) == "x e x e x."
    end

    @testset "só campos declarados chegam ao documento (§11.4)" begin
        d = Dict("n" => "x", "segredo" => "não deve aparecer")
        @test !occursin("segredo", render(m, d))
        @test !occursin("não deve aparecer", render(m, d))
    end
end

@testset "o teorema da lacuna, no texto produzido" begin
    m = load_string(ENVK, """
kanon 1

data
  a : text !
  b : text

text

: p
Começo {a}[, com {b}] e fim.
"""; name = "t")

    @testset "com o valor, o grupo fica" begin
        @test render(m, Dict("a" => "A", "b" => "B")) == "Começo A, com B e fim."
    end

    @testset "sem o valor, o grupo sai inteiro — e nada de vazio aparece" begin
        s = render(m, Dict("a" => "A"))
        @test s == "Começo A e fim."
        @test !occursin(", ,", s) && !occursin("  ", s)
    end

    @testset "branco normalizado elide igual (D-008)" begin
        # é o buraco que D-008 fecha: sem ela, sairia "Começo A, com  e fim."
        @test render(m, Dict("a" => "A", "b" => "   ")) == "Começo A e fim."
    end
end
