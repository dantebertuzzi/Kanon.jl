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

    @testset "no typst a barra vai antes do dígito, e só no começo da linha" begin
        # `1. x` no começo de uma linha é enumeração explícita no Typst, e a forma de
        # escrever o parágrafo é `\1. x` — o inverso do Markdown, onde é o ponto que
        # leva a barra. No meio da frase não há marcação nenhuma a desarmar.
        hostil = Dict("nome" => "X\n\n1. Cláusula falsa\n\n- e um item")
        s = render(M_OUT, hostil; to = :typst)
        @test occursin("\\1. Cláusula falsa", s)
        @test occursin("\\- e um item", s)
        @test occursin("é que X", s)
        # e um número no meio da frase sai limpo
        @test occursin("assine, com a nota 12.500,00.",
                       render(M_OUT, Dict("nome" => "A", "nota" => "12.500,00"); to = :typst))
    end

    @testset "no typst um valor não apaga texto: `//`, `~` e `-?` (D-062)" begin
        # Os três compilam sem erro e **somem**: `//` começa um comentário e leva o resto
        # da linha, `~` vira espaço inseparável, `-?` vira hífen opcional. Conferido
        # contra o Typst 0.15.1 ao compilar o golden da procuração nº 12.
        e(x) = Kanon.escape_value(Kanon.Typst(), x, false)
        @test e("processo 123//2026, vara") == "processo 123\\/\\/2026, vara"
        @test e("~200 m²") == "\\~200 m²"
        @test e("sim -? não") == "sim -\\? não"
        # a barra sozinha no meio do valor não forma nada, e não leva barra
        @test e("Petrolina/PE, S/A") == "Petrolina/PE, S/A"
        # na borda do valor a vizinha é prosa, que o escape não vê: `{a}/` com `a = "x/"`
        # formaria `//`, e `-{b}` com `b = "?"` formaria `-?`
        @test e("x/") == "x\\/"
        @test e("/x") == "\\/x"
        @test e("?x") == "\\?x"
        @test e("x-") == "x\\-"
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
        # a barra final é a quebra rígida da D-070, e não escape
        @test linhas[1] == "12\\.345\\"                # começo de linha: pode abrir lista
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
              "1\\. O **importante** é que Ana assine."
    end

    @testset "o rótulo do bloco sai com o número que o motor apurou (D-044)" begin
        # Este teste afirmava o contrário até o modelo real nº 6: o rótulo é estrutura,
        # vem da camada e não dos dados, e por isso não era escapado. A proveniência é a
        # razão certa para a pergunta errada. O risco aqui não é injeção — é que `1. `
        # no começo da linha **é** marcador de lista ordenada em Markdown, e o número
        # que o motor apurou passa a ser um número que o renderizador redefine, enquanto
        # a remissão da prosa continua texto literal apontando para o antigo.
        #
        # O rótulo é a única parte do documento que o motor calcula, e por isso a única
        # que precisa sair intacta em todo formato.
        s = render(M_OUT, Dict("nome" => "A"); to = :markdown)
        @test startswith(s, "1\\. ")
        @test render(M_OUT, Dict("nome" => "A")) |> x -> startswith(x, "1. ")  # texto puro, intacto
    end

    @testset "e no typst o mesmo rótulo leva a barra antes do dígito" begin
        s = render(M_OUT, Dict("nome" => "A"); to = :typst)
        @test startswith(s, "\\1. ")
    end

    @testset "e o escape é do par rótulo+separador, não de cada um" begin
        # O `1` é do rótulo e o `. ` que faz dele um marcador é do separador do estilo:
        # escapar só o rótulo não protegeria nada.
        m = load_string(Environment(), """
kanon 1

data
  a : text !

text

:: um
Primeiro.

::: um_um
Aninhado com {a}.
"""; name = "r.kanon")
        s = render(m, Dict("a" => "x"); to = :markdown)
        @test occursin("1\\. Primeiro.", s)
        # Uma contrabarra basta, e ela vai no primeiro ponto: o marcador de lista é
        # dígitos **seguidos** de `.`, e quebrada a sequência a linha inteira deixa de
        # ser candidata. O segundo ponto sai limpo, e é o que o leitor quer ver.
        @test occursin("1\\.1. Aninhado com x.", s)
        @test !startswith(s, "1. ")
    end
end

@testset "a linha que o autor quebrou continua quebrada (D-070)" begin
    # Achado pelo modelo real nº 15, a reclamação trabalhista entregue em `.docx`: no
    # Markdown e no Typst a quebra simples é espaço, e o fecho `Nestes termos,` /
    # `pede deferimento.` e o bloco de assinatura saíam numa linha só no documento — com o
    # texto puro do mesmo modelo certo, e sem aviso nenhum. Conferido contra o pandoc 3.11
    # (leitores `markdown`, `commonmark` e `gfm`) e o Typst 0.15.1.
    fecho = load_string(Environment(), """
kanon 1

data
  advogado : text !
  oab      : text !

text

: fecho
Nestes termos,
pede deferimento.

: assinatura
{advogado}
OAB/PE {oab}
"""; name = "f.kanon")
    d = Dict("advogado" => "PAULO HENRIQUE LINS", "oab" => "12.345")

    @testset "texto puro: a linha já é a linha" begin
        @test render(fecho, d) ==
              "Nestes termos,\npede deferimento.\n\nPAULO HENRIQUE LINS\nOAB/PE 12.345"
    end

    @testset "markdown e typst: contrabarra no fim, que os dois leem como quebra rígida" begin
        esperado = "Nestes termos,\\\npede deferimento.\n\nPAULO HENRIQUE LINS\\\nOAB/PE 12.345"
        @test render(fecho, d; to = :markdown) == esperado
        @test render(fecho, d; to = :typst) == esperado
        # a última linha do parágrafo não leva barra: no fim do bloco ela sai literal
        @test !endswith(render(fecho, d; to = :markdown), "\\")
    end

    lb(f, s) = Kanon.line_breaks(f, s)
    md, ty = Kanon.Markdown(), Kanon.Typst()

    @testset "a marcação de bloco do autor passa intacta" begin
        # a barra ali quebraria a tabela e sairia literal no fim do item e do título
        # (conferido no pandoc): lista, tabela e título são do autor (D-028)
        for s in ("- a\n- b", "1. a\n2. b", "a) um\nb) dois", "(1) um\n(2) dois",
                  "| x | y |\n|---|---|\n| 1 | 2 |", "## Título\ntexto",
                  "> cita\n> segue", "    código\n    mais", "```\nx\n```",
                  "Termo\n: definição", "título\n===", "<div>\nx\n</div>")
            @test lb(md, s) == s
        end
        for s in ("- a\n- b", "+ a\n+ b", "= Título\ntexto", "/ Termo: x\nmais",
                  "1. a\n2. b", "#set text(size: 12pt)\ntexto", "linha\n// comentário")
            @test lb(ty, s) == s
        end
        # e só o trecho que tem a marcação: o parágrafo de prosa ao lado ganha a quebra
        @test lb(md, "a\nb\n\n- c\n- d") == "a\\\nb\n\n- c\n- d"
    end

    @testset "o que o escape já desarmou não conta como bloco" begin
        # um valor que começa a linha com `#` ou `1.` chega escapado e não abre nada,
        # e a linha seguinte continua sendo a linha seguinte
        m = load_string(Environment(), "kanon 1\n\ndata\n  a : text !\n\ntext\n\n: b\n{a}\nfim.\n";
                        name = "e.kanon")
        @test render(m, Dict("a" => "# não é título"); to = :markdown) ==
              "\\# não é título\\\nfim."
        @test render(m, Dict("a" => "1. não é item"); to = :markdown) ==
              "1\\. não é item\\\nfim."
        @test render(m, Dict("a" => "1. não é item"); to = :typst) ==
              "\\1. não é item\\\nfim."
    end

    @testset "a linha em branco que um valor traz continua separando parágrafos" begin
        s = render(M_OUT, Dict("nome" => "X\n\n# Cláusula falsa\n\nAssinado por outro");
                   to = :markdown)
        @test occursin("é que X\n\n\\# Cláusula falsa\n\nAssinado por outro assine.", s)
    end

    @testset "a contrabarra no fim: ímpar já é quebra, par é contrabarra escapada" begin
        @test lb(md, "a\\\nb") == "a\\\nb"          # o autor já quebrou
        @test lb(md, "a\\\\\nb") == "a\\\\\\\nb"    # `\\` é literal, e ainda falta a quebra
        @test lb(md, "a  \nb") == "a  \\\nb"         # os dois espaços, que o editor apaga
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
