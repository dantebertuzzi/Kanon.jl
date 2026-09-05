"Uma camada com estilo `:heading`, que é o caso que o formato de saída muda."
module CamadaTitulo
    using Kanon
    configure!(b) = register_block_style!(b, :secao;
        unit = '%', layout = :heading, separator = " ",
        number = (path, ctx) -> "Seção " * join(path, "."),
        ref = (path, ctx) -> join(path, "."))
end

# Formatos de saída (F8).
#
# O que esta suíte protege é uma frase: **o valor interpolado nunca altera a estrutura
# do documento.** A prosa do autor passa intacta; o dado que veio de fora é escapado.
#
# É a mesma preocupação de quem escapa HTML, pela mesma razão — e aqui ela tem o peso
# extra de que o documento pode ser assinado.

const M_OUT = load_string(Environment(), """
kanon 1

data
  nome : text !
  nota : text

text

:: clausula
O **importante** é que {nome} assine[, com a nota {nota}].
"""; name = "o.kanon")

@testset "o dado é escapado, a prosa do autor não" begin
    d = Dict("nome" => "Ana *Maria* [Silva]")

    @testset "texto puro não toca em nada" begin
        @test render(M_OUT, d) ==
              "1. O **importante** é que Ana *Maria* [Silva] assine."
        @test render(M_OUT, d; to = :text) == render(M_OUT, d)
    end

    @testset "markdown escapa o valor e preserva a marcação do modelo" begin
        s = render(M_OUT, d; to = :markdown)
        @test occursin("O **importante** é que", s)          # o autor quis negrito
        @test occursin("Ana \\*Maria\\* \\[Silva\\]", s)      # o dado, não
        @test !occursin("Ana *Maria*", s)
    end

    @testset "typst escapa o que o typst leria" begin
        s = render(M_OUT, Dict("nome" => "Ana #1 \$x\$ <a>"); to = :typst)
        @test occursin("Ana \\#1 \\\$x\\\$ \\<a\\>", s)
    end

    @testset "um valor não consegue abrir marcação nenhuma" begin
        hostil = Dict("nome" => "X\n\n# Cláusula falsa\n\nAssinado por outro")
        s = render(M_OUT, hostil; to = :markdown)
        @test !occursin("\n# Cláusula falsa", s)      # o `#` foi escapado
        @test occursin("\\# Cláusula falsa", s)
    end

    @testset "o que só é marcação no início de linha não é escapado no meio" begin
        # sem isto, `12.345` viraria `12\.345` e nenhum valor sairia legível
        m = load_string(Environment(), """
kanon 1

data
  a : text !
  b : text !

text

: b
{a}
Matrícula {b} da comarca.
"""; name = "p.kanon")
        s = render(m, Dict("a" => "12.345", "b" => "12.345"); to = :markdown)
        linhas = split(s, "\n")
        @test linhas[1] == "12\\.345"                  # começo de linha: pode abrir lista
        @test linhas[2] == "Matrícula 12.345 da comarca."   # no meio: não é marcação
    end

    @testset "e o que é marcação em qualquer posição continua escapado" begin
        m = load_string(Environment(), "kanon 1\n\ndata\n  a : text !\n\ntext\n\n: b\nNota {a} fim.\n";
                        name = "q.kanon")
        @test occursin("Nota \\*x\\* fim.", render(m, Dict("a" => "*x*"); to = :markdown))
        @test occursin("Nota \\[y\\] fim.", render(m, Dict("a" => "[y]"); to = :markdown))
    end

    @testset "e nem sequer com contrabarra" begin
        s = render(M_OUT, Dict("nome" => "A\\*B\\*"); to = :markdown)
        @test occursin("A\\\\\\*B\\\\\\*", s)          # a barra do dado também escapa
    end
end

@testset "o escape não atrapalha o resto do motor" begin
    @testset "a elisão continua funcionando com o valor escapado" begin
        d = Dict("nome" => "Ana", "nota" => "*urgente*")
        s = render(M_OUT, d; to = :markdown)
        @test occursin("assine, com a nota \\*urgente\\*.", s)
        # e sem a nota, o grupo sai inteiro, sem vírgula órfã
        @test render(M_OUT, Dict("nome" => "Ana"); to = :markdown) ==
              "1. O **importante** é que Ana assine."
    end

    @testset "o rótulo do bloco é do estilo, e não é escapado" begin
        # ele é estrutura, e vem da camada — não dos dados
        s = render(M_OUT, Dict("nome" => "A"); to = :markdown)
        @test startswith(s, "1. ")
    end
end

@testset "layout :heading vira título de verdade" begin
    env_sci = Environment(domains = [Science])
    m = load_string(env_sci, """
kanon 1

text

@@ um
Primeiro.

@@@ um_um
Aninhado.
"""; name = "h.kanon")

    @testset "em texto puro, o rótulo é prefixo" begin
        @test occursin("Theorem 1. Primeiro.", render(m, Dict()))
    end

    @testset "com layout :heading, o markdown usa `#` e o typst usa `=`" begin
        # o estilo de `Science` é :prefix; o de um estilo :heading vira título
        env2 = Environment(domains = [CamadaTitulo])
        m2 = load_string(env2, "kanon 1\n\ntext\n\n%% a\nTexto.\n\n%%% b\nMais.\n";
                         name = "t.kanon")
        @test render(m2, Dict(); to = :markdown) == "# Seção 1\n\nTexto.\n\n## Seção 1.1\n\nMais."
        @test render(m2, Dict(); to = :typst) == "= Seção 1\n\nTexto.\n\n== Seção 1.1\n\nMais."
        @test render(m2, Dict()) == "Seção 1\n\nTexto.\n\nSeção 1.1\n\nMais."
    end
end

@testset "o formato desconhecido erra nomeando os que existem" begin
    e = try; render(M_OUT, Dict("nome" => "A"); to = :pdf); catch err; err; end
    @test e isa ArgumentError
    @test occursin("markdown", e.msg) && occursin("typst", e.msg)
    @test occursin("text", e.msg)
end

@testset "a CLI aceita --to" begin
    caminho = joinpath(mktempdir(), "m.kanon")
    write(caminho, "kanon 1\n\ndata\n  n : text !\n\ntext\n\n: b\nValor: {n}.\n")
    dados = joinpath(dirname(caminho), "d.kdata")
    write(dados, "n = \"a*b*\"\n")

    r = cli("render", caminho, dados, "--to", "markdown")
    @test r.codigo == Kanon.EXIT_OK
    @test occursin("a\\*b\\*", r.out)

    r = cli("render", caminho, dados, "--to", "text")
    @test occursin("a*b*", r.out)

    r = cli("render", caminho, dados, "--to", "pdf")
    @test r.codigo == Kanon.EXIT_USAGE
    @test occursin("não é um formato", r.err)
end
