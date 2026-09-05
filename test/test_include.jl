# Inclusão de fragmentos (F7, D-005).
#
# Duas coisas se provam aqui: que a inclusão **compõe com o contrato** — que é a razão de
# ela existir no lugar da herança — e que o carregador trata o modelo como **dado não
# confiável**, porque ele é (§11.2).

const INC = mktempdir()

function frag(nome, conteudo)
    caminho = joinpath(INC, nome)
    mkpath(dirname(caminho))
    write(caminho, conteudo)
    caminho
end

const HOST = frag("host.kanon", """
kanon 1

data
  nome  : text !
  preco : money

text

: abertura
Contrato de {nome}.

include "clausulas.kanon"

: fecho
Assinado.
""")

frag("clausulas.kanon", """
kanon 1

data
  preco : money !
  prazo : number !

text

:: pagamento
O preço é {preco}, em {prazo} dias.
""")

@testset "a inclusão compõe, e a leitura linear continua valendo" begin
    m = load_template(Environment(), HOST)

    @testset "os blocos do fragmento entram no ponto em que ele foi escrito" begin
        @test [b.name for b in m.template.text.blocks] == [:abertura, :pagamento, :fecho]
        @test isempty(m.template.text.includes)      # depois de composto, não há vestígio
    end

    @testset "o modelo composto sabe de que arquivo veio cada coisa" begin
        @test length(m.template.sources) == 2
        @test basename.(m.template.sources) == ["host.kanon", "clausulas.kanon"]
    end

    @testset "e renderiza como se fosse um arquivo só" begin
        d = Dict("nome" => "Ana", "preco" => Money("10.00", :BRL), "prazo" => 30)
        @test render(m, d) == "Contrato de Ana.\n\n1. O preço é BRL 10.00, em 30 dias.\n\nAssinado."
    end
end

@testset "unificação de contratos (D-005)" begin
    m = load_template(Environment(), HOST)
    campo(n) = m.template.data.fields[findfirst(f -> f.name === n, m.template.data.fields)]

    @testset "mesmo nome e mesmo tipo fundem" begin
        @test campo(:preco).type === :money
        @test count(f -> f.name === :preco, m.template.data.fields) == 1
    end

    @testset "a obrigatoriedade é a mais forte das duas" begin
        # `preco` é opcional no hospedeiro e obrigatório no fragmento
        @test campo(:preco).presence === REQUIRED
        @test [d.code for d in check(m, Dict("nome" => "A", "prazo" => 1))] == ["K3001"]
    end

    @testset "o campo que só o fragmento declara entra no contrato" begin
        @test campo(:prazo).type === :number
        @test campo(:prazo).presence === REQUIRED
    end

    @testset "o checklist do composto é derivado" begin
        s = contract(m)
        for n in ("nome", "preco", "prazo")
            @test occursin("\"$n\"", s)
        end
    end

    @testset "tipos diferentes com o mesmo nome é erro na carga, não no render" begin
        h = frag("conflito.kanon", """
kanon 1

data
  x : text !

text

: a
{x}

include "conflito-frag.kanon"
""")
        frag("conflito-frag.kanon", "kanon 1\n\ndata\n  x : number !\n\ntext\n\n: b\n{x}\n")
        e = try; load_template(Environment(), h); catch err; err; end
        @test e isa KanonReferenceError
        @test [d.code for d in e.diagnostics] == ["K2053"]
        @test occursin("`text` no modelo e `number` no fragmento", e.diagnostics[1].message)
    end

    @testset "cardinalidades diferentes também" begin
        h = frag("card.kanon", """
kanon 1

data
  x : text !

text

: a
{x}

include "card-frag.kanon"
""")
        frag("card-frag.kanon", "kanon 1\n\ndata\n  x : text[2] !\n\ntext\n\n: b\ny\n")
        e = try; load_template(Environment(), h); catch err; err; end
        @test "K2053" in [d.code for d in e.diagnostics]
    end

    @testset "bloco de mesmo nome é erro: as regras apontam por nome" begin
        h = frag("dup.kanon", "kanon 1\n\ntext\n\n: a\nA\n\ninclude \"dup-frag.kanon\"\n")
        frag("dup-frag.kanon", "kanon 1\n\ntext\n\n: a\nOutro A\n")
        e = try; load_template(Environment(), h); catch err; err; end
        @test [d.code for d in e.diagnostics] == ["K2054"]
    end
end

@testset "o carregador trata o modelo como dado não confiável (§11.2)" begin
    fora = joinpath(INC, "..", "fora.kanon")
    write(normpath(fora), "kanon 1\n\ntext\n\n: x\nSegredo.\n")

    codigos(caminho_incluido) = begin
        h = frag("ataque.kanon",
                 "kanon 1\n\ntext\n\n: a\nA\n\ninclude \"$caminho_incluido\"\n")
        e = try; load_template(Environment(), h); catch err; err; end
        e isa KanonError ? [d.code for d in e.diagnostics] : String[]
    end

    @testset "caminho absoluto" begin
        @test codigos("/etc/passwd") == ["K2050"]
        @test codigos(normpath(fora)) == ["K2050"]
    end

    @testset "travessia com `..`" begin
        @test codigos("../fora.kanon") == ["K2050"]
        @test codigos("sub/../../fora.kanon") == ["K2050"]
    end

    @testset "link simbólico que aponta para fora da raiz" begin
        # `normpath` sozinho não vê isto: o link está dentro da raiz e o destino não
        link = joinpath(INC, "atalho.kanon")
        isfile(link) || symlink(normpath(fora), link)
        @test codigos("atalho.kanon") == ["K2050"]
    end

    @testset "arquivo que não existe" begin
        @test codigos("nao-existe.kanon") == ["K2052"]
    end

    @testset "sem raiz configurada, não se lê arquivo nenhum" begin
        e = try
            load_string(Environment(), "kanon 1\n\ntext\n\n: a\nA\n\ninclude \"x.kanon\"\n";
                        name = "s.kanon")
        catch err
            err
        end
        @test [d.code for d in e.diagnostics] == ["K2055"]
        @test occursin("não lê arquivo", e.diagnostics[1].hint)
    end

    @testset "um fragmento que se inclui fecha um ciclo, e o ciclo para (§11.5)" begin
        frag("ciclo-a.kanon", "kanon 1\n\ntext\n\n: ca\nA\n\ninclude \"ciclo-b.kanon\"\n")
        frag("ciclo-b.kanon", "kanon 1\n\ntext\n\n: cb\nB\n\ninclude \"ciclo-a.kanon\"\n")
        h = frag("ciclo.kanon", "kanon 1\n\ntext\n\n: h\nH\n\ninclude \"ciclo-a.kanon\"\n")
        e = try; load_template(Environment(), h); catch err; err; end
        @test e isa KanonReferenceError
        @test "K2051" in [d.code for d in e.diagnostics]
    end

    @testset "e o modelo que se inclui a si mesmo também" begin
        h = frag("eu.kanon", "kanon 1\n\ntext\n\n: e\nE\n\ninclude \"eu.kanon\"\n")
        e = try; load_template(Environment(), h); catch err; err; end
        @test "K2051" in [d.code for d in e.diagnostics]
    end
end

@testset "a linha de inclusão" begin
    @testset "malformada é erro de sintaxe, com o que escrever" begin
        for (fonte, trecho) in (("include frag.kanon", "entre aspas"),
                                ("include \"\"", "vazio"),
                                ("include \"a.kanon\" sobra", "sobra"))
            e = try
                parse_string("kanon 1\n\ntext\n\n: a\nA\n\n$fonte\n"; name = "t")
            catch err
                err
            end
            @test e isa KanonSyntaxError
            @test [d.code for d in e.diagnostics] == ["K1214"]
            @test occursin(trecho, e.diagnostics[1].message)
        end
    end

    @testset "só vale na coluna 0: recuada, é prosa" begin
        t = parse_string("kanon 1\n\ntext\n\n: a\n  include \"x.kanon\"\n"; name = "t")
        @test isempty(t.text.includes)
    end

    @testset "sem inclusão, a composição não toca no modelo" begin
        t = parse_string("kanon 1\n\ntext\n\n: a\nA\n"; name = "t")
        @test Kanon.compose(t, Loader(INC), canonical_keywords()) === t
    end

    @testset "um problema no fragmento aponta o fragmento" begin
        # Descoberto ao escrever o modelo real nº 3. `Span` sempre guardou o índice do
        # arquivo; quem emitia o diagnóstico é que o ignorava e usava o nome do
        # hospedeiro. O resultado era um ponteiro para **a linha do fragmento no arquivo
        # do hospedeiro** — uma linha que muitas vezes nem existe lá, e que manda quem
        # for corrigir o erro para o lugar errado.
        h = frag("ptr.kanon", "kanon 1\n\ntext\n\n: a\nA.\n\ninclude \"ptr-frag.kanon\"\n")
        frag("ptr-frag.kanon",
             "kanon 1\n\ndata\n  obs : text\n\ntext\n\n: nota\nUma linha.\nOutra linha.\nA nota diz {obs}.\n")

        e = try; load_template(Environment(), h); catch err; err; end
        @test e isa KanonReferenceError
        d = collect(e.diagnostics)[1]
        @test d.code == "K2012"
        @test endswith(d.file, "ptr-frag.kanon")
        @test d.line == 11                      # a linha 11 do fragmento; o hospedeiro tem 8
        @test countlines(h) < d.line            # e é por isso que o ponteiro antigo não servia
    end

    @testset "com dois arquivos, cada problema diz de qual é" begin
        # A linha sozinha não localiza nada quando há mais de um arquivo, e o cabeçalho
        # só sabe dizer "2 arquivos".
        h = frag("dois.kanon",
                 "kanon 1\n\ndata\n  tit : text\n\ntext\n\n: a\nAbertura {tit}.\n\ninclude \"dois-frag.kanon\"\n")
        frag("dois-frag.kanon",
             "kanon 1\n\ndata\n  obs : text\n\ntext\n\n: nota\nA nota diz {obs}.\n")

        e = try; load_template(Environment(), h); catch err; err; end
        texto = sprint(showerror, e)
        @test occursin("2 arquivos: 2 problemas encontrados", texto)
        @test occursin("dois.kanon, linha 9, coluna 10", texto)
        @test occursin("dois-frag.kanon, linha 9, coluna 12", texto)
    end

    @testset "com um arquivo só, a linha continua nua" begin
        # O nome do arquivo em cada problema seria ruído quando ele é sempre o mesmo, e
        # o cabeçalho já o disse.
        e = try
            load_string(Environment(), "kanon 1\n\ndata\n  a : text\n\ntext\n\n: b\n{a}\n";
                        name = "um.kanon")
        catch err
            err
        end
        texto = sprint(showerror, e)
        @test occursin("um.kanon: 1 problema encontrado", texto)
        @test occursin("    linha 9, coluna 1:", texto)
        @test !occursin("um.kanon, linha", texto)
    end

    @testset "a posição da inclusão é onde os blocos entram" begin
        h = frag("pos.kanom", "")
        h = frag("pos.kanon", """
kanon 1

text

include "pos-frag.kanon"

: depois
D.
""")
        frag("pos-frag.kanon", "kanon 1\n\ntext\n\n: antes\nA.\n")
        m = load_template(Environment(), h)
        @test [b.name for b in m.template.text.blocks] == [:antes, :depois]
        @test render(m, Dict()) == "A.\n\nD."
    end
end
