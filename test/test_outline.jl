# O esqueleto do modelo e `kanon ask` (F9).
#
# O roadmap pede um editor de três colunas, e diz que ele não é extra. O editor é uma
# aplicação; o que a biblioteca entrega é o que ele consome — a estrutura do modelo já
# resolvida, para que a interface não reimplemente a análise (D-029).

const M_OUT_L = load_string(ENVK, """
kanon 1

data
  seller    : person !
  witnesses : person[1..] !
  price     : money !
  notes     : text

text

: preambulo
Contrato de {seller.name}[, com a nota {notes}].

:: pagamento
O preço é {price}.

: cada <- witnesses
{name}.

rules
  pagamento when price > 0 and notes is present
  cada      one for each witnesses
"""; name = "o.kanon")

@testset "outline: a estrutura que o editor consome" begin
    blocos = outline(M_OUT_L)

    @testset "um por bloco, na ordem do arquivo — que é a da saída" begin
        @test [b.name for b in blocos] == [:preambulo, :pagamento, :cada]
        @test [b.line for b in blocos] == [11, 14, 17]
    end

    @testset "a regra de cada bloco é a coluna do meio" begin
        @test blocos[1].rule === nothing && blocos[1].foreach === nothing
        @test blocos[2].rule == "price > 0 and notes is present"
        @test blocos[3].foreach == "witnesses"
        @test Kanon.conditional(blocos[2]) && !Kanon.repeated(blocos[2])
        @test Kanon.repeated(blocos[3]) && !Kanon.conditional(blocos[3])
    end

    @testset "a condição é reconstruída da árvore, com a precedência explícita" begin
        # o editor mostra o que o motor entendeu, e não o que o arquivo diz
        m = load_string(ENVK, """
kanon 1

data
  a : boolean = true
  b : boolean = true
  c : boolean = true

text

: x
X.

rules
  x when a and b or c
"""; name = "p.kanon")
        @test outline(m)[1].rule == "(a and b) or c"
    end

    @testset "o número e o rótulo vêm do estilo, sem dados" begin
        @test blocos[1].number == Int32[]         # não numerado
        @test blocos[2].number == Int32[1]
        @test blocos[2].label == "1"              # o estilo do núcleo
        @test blocos[2].level == 1
    end

    @testset "o sujeito e os parágrafos" begin
        @test blocos[3].subject == "witnesses"
        @test blocos[1].subject === nothing
        @test all(b -> b.paragraphs >= 1, blocos)
    end

    @testset "os campos que cada bloco usa, com o que o editor precisa sinalizar" begin
        usos = blocos[1].fields
        @test [u.path for u in usos] == ["seller.name", "notes"]
        @test usos[1].typename === :text && !usos[1].nullable
        @test usos[2].nullable && usos[2].guarded          # está em grupo, como deve
        @test all(u -> u.formatter === :default, usos)
    end

    @testset "um campo nulável fora de grupo é o que a coluna sinaliza em vermelho" begin
        # o modelo nem carrega assim, mas `outline` roda sobre a análise, e a análise
        # do editor é a de um modelo em edição
        t = parse_string("kanon 1\n\ndata\n  n : text\n\ntext\n\n: b\n{n}\n";
                         name = "e.kanon")
        a = analyze(ENVK, t)
        m = Kanon.Model(ENVK, t, a)
        u = outline(m)[1].fields[1]
        @test u.nullable && !u.guarded
    end
end

@testset "format_outline: as duas primeiras colunas, no terminal" begin
    s = format_outline(M_OUT_L)

    @testset "cada bloco com a condição ao lado" begin
        @test occursin("preambulo", s) && occursin("sempre", s)
        @test occursin("quando price > 0 and notes is present", s)
        @test occursin("um por witnesses", s)
    end

    @testset "os marcadores dizem o que o bloco faz" begin
        @test occursin("?", s) && occursin("*", s)
        @test occursin("? bloco condicional", s)
        @test occursin("* bloco repetido", s)
    end

    @testset "o campo que pode faltar e não está guardado é apontado" begin
        t = parse_string("kanon 1\n\ndata\n  n : text\n\ntext\n\n: b\n{n}\n"; name = "e")
        m = Kanon.Model(ENVK, t, analyze(ENVK, t))
        @test occursin("pode faltar, e não está em grupo", format_outline(m))
    end

    @testset "modelo sem bloco diz isso, em vez de sair vazio" begin
        t = parse_string("kanon 1\n\ntext\n"; name = "v")
        @test occursin("não tem bloco nenhum", format_outline(Kanon.Model(ENVK, t, analyze(ENVK, t))))
    end
end

@testset "kanon ask: o que falta, perguntado um a um" begin
    dir = mktempdir()
    modelo = joinpath(dir, "a.kanon")
    write(modelo, """
kanon 1

data
  nome  : text !
  idade : number !
  ativo : boolean !
  preco : money !
  nota  : text

text

: b
{nome}, {idade}, {ativo}, {preco}[, {nota}].
""")

    ask(entrada, args...) = begin
        o, e = IOBuffer(), IOBuffer()
        c = Kanon.main(String["ask", modelo, args...];
                       out = o, err = e, input = IOBuffer(entrada))
        (codigo = c, out = String(take!(o)), err = String(take!(e)))
    end

    @testset "a resposta é convertida pelo tipo declarado, não adivinhada" begin
        r = ask("Ana\n40\ntrue\n")
        @test occursin("nome = \"Ana\"", r.out)      # texto entre aspas
        @test occursin("idade = 40", r.out)          # número sem aspas
        @test occursin("ativo = true", r.out)
    end

    @testset "o que não cabe numa linha fica para o arquivo" begin
        r = ask("Ana\n40\ntrue\n")
        @test occursin("preco", r.err)
        @test occursin("não cabe numa linha", r.err)
        @test !occursin("preco =", r.out)
    end

    @testset "campo opcional não se pergunta: ele pode faltar" begin
        r = ask("Ana\n40\ntrue\n")
        @test !occursin("nota —", r.err)
    end

    @testset "sai com erro de contrato enquanto os dados não bastam" begin
        r = ask("Ana\n40\ntrue\n")
        @test r.codigo == Kanon.EXIT_CONTRACT
        @test occursin("[K3001]", r.err)
        @test occursin("ainda não bastam", r.err)
    end

    @testset "as perguntas vão ao stderr, e os dados ao stdout" begin
        # é o que faz `kanon ask m.kanon > dados.kdata` funcionar
        r = ask("Ana\n40\ntrue\n")
        @test occursin("idade — number", r.err)
        @test !occursin("—", r.out)
    end

    @testset "e o que o ask emite, o render lê de volta" begin
        simples = joinpath(dir, "s.kanon")
        write(simples, "kanon 1\n\ndata\n  nome : text !\n  n : number !\n\ntext\n\n: b\n{nome} tem {n}.\n")
        o, e = IOBuffer(), IOBuffer()
        c = Kanon.main(["ask", simples]; out = o, err = e, input = IOBuffer("Ana\n40\n"))
        @test c == Kanon.EXIT_OK
        dados = joinpath(dir, "d.kdata")
        write(dados, String(take!(o)))
        r = cli("render", simples, dados)
        @test r.codigo == Kanon.EXIT_OK
        @test strip(r.out) == "Ana tem 40."
    end

    @testset "ask parte dos dados que já existem" begin
        parciais = joinpath(dir, "p.kdata")
        write(parciais, "nome = \"Bo\"\n")
        r = ask("41\ntrue\n", parciais)
        @test occursin("nome = \"Bo\"", r.out)
        @test occursin("idade = 41", r.out)
        @test !occursin("nome —", r.err)      # já tinha, não perguntou
    end
end

@testset "kanon outline" begin
    dir = mktempdir()
    modelo = joinpath(dir, "o.kanon")
    write(modelo, """
kanon 1

data
  n : text !

text

:: um
{n}

: dois
Fixo.

rules
  dois when n is present
""")
    r = cli("outline", modelo)
    @test r.codigo == Kanon.EXIT_OK
    @test occursin("um", r.out) && occursin("dois", r.out)
    @test occursin("quando n is present", r.out)
    @test occursin("{n} : text", r.out)
end
