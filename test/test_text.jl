@testset "plano do texto" begin
    @testset "bloco, sujeito e marcador" begin
        t = ok("kanon 1\n\ntext\n\n: um\nx\n\n:: dois\ny\n\n::: três <- a.b\nz\n")
        bs = t.text.blocks
        @test [b.name for b in bs] == [:um, :dois, :três]
        @test [(b.unit, b.repeat) for b in bs] == [(':', 1), (':', 2), (':', 3)]
        @test bs[3].subject !== nothing
        @test string(bs[3].subject) == "a.b"
    end

    @testset "a ordem dos blocos é a ordem do arquivo (invariante anti-XSLT)" begin
        t = ok("kanon 1\n\ntext\n\n: c\n1\n\n: a\n2\n\n: b\n3\n")
        @test [b.name for b in t.text.blocks] == [:c, :a, :b]
    end

    @testset "parágrafos separados por linha em branco" begin
        t = ok("kanon 1\n\ntext\n\n: b\num\ndois\n\ntrês\n")
        @test length(t.text.blocks[1].children) == 2
    end

    @testset "interpolação com e sem formatador" begin
        t = ok(withtext("{price} e {price:written}"))
        ns = nodes1(t)
        i1 = ns[1]::Interp
        i2 = ns[3]::Interp
        @test string(i1.path) == "price" && i1.formatter === nothing
        @test i2.formatter === :written
    end

    @testset "caminho com subcampo" begin
        t = ok(withtext("{seller.spouse.name}"))
        @test string((nodes1(t)[1]::Interp).path) == "seller.spouse.name"
    end

    @testset "linha e coluna da interpolação" begin
        t = ok("kanon 1\n\ntext\n\n: b\nabc {x} def\n")
        i = nodes1(t)[2]::Interp
        @test (i.span.line, i.span.col) == (6, 5)
    end

    @testset "remissão a bloco" begin
        t = ok(withtext("ver {::payment} acima"))
        @test (nodes1(t)[2]::BlockRef).target === :payment
    end

    @testset "escapes (D-004, revista na F1)" begin
        # Chaves e parênteses escapam por duplicação; colchetes, por contrabarra —
        # porque grupos aninham e `]]` é produzido pela própria linguagem.
        t = ok(withtext("{{price}} e \\[1\\] e ((a)) e \\\\"))
        ns = nodes1(t)
        @test length(ns) == 1
        @test (ns[1]::TextLit).value == "{price} e [1] e (a) e \\"
    end

    @testset "a contrabarra não é especial fora dos colchetes (D-018)" begin
        # A razão de não unificar tudo na contrabarra: notação alheia atravessa intacta.
        for (entrada, saida) in (
            ("\\(\\alpha\\)", "\\(\\alpha\\)"),   # matemática em linha do LaTeX
            ("C:\\Users\\Ana", "C:\\Users\\Ana"),     # caminho do Windows
            ("\\alpha e \\beta", "\\alpha e \\beta"), # comandos LaTeX
        )
            t = ok(withtext(entrada))
            @test (nodes1(t)[1]::TextLit).value == saida
        end
    end

    @testset "colisão assumida: `\\[` é colchete literal, não matemática em bloco" begin
        t = ok(withtext("\\[x\\]"))
        @test (nodes1(t)[1]::TextLit).value == "[x]"
    end

    @testset "grupos aninhados fecham lado a lado" begin
        # O caso que a duplicação de colchetes tornava inexprimível.
        t = ok(withtext("{a}[, {b}[ e {c}]]"))
        ns = nodes1(t)
        @test length(ns) == 2
        g = ns[2]::Group
        @test g.children[3] isa Group
    end

    @testset "escape de coluna 0" begin
        t = ok("kanon 1\n\ntext\n\n: b\n\\: isto é prosa\n")
        @test (nodes1(t)[1]::TextLit).value == ": isto é prosa"
    end

    @testset "grupos opcionais aninham" begin
        t = ok(withtext("{a}[, {b}[ e {c}]], fim"))
        ns = nodes1(t)
        g = ns[2]::Group
        @test length(g.children) == 3          # ", ", {b}, grupo interno
        @test g.children[3] isa Group
        @test length((g.children[3]::Group).children) == 2
    end

    @testset "grupo não fechado" begin
        @test "K1208" in codes(withtext("{a}[, {b}"))
    end

    @testset "grupo não atravessa fronteira de parágrafo" begin
        @test "K1208" in codes("kanon 1\n\ntext\n\n: b\n[{a}\n\n{b}]\n")
    end

    @testset "colchete de fechamento sem abertura" begin
        @test "K1209" in codes(withtext("fim] disso"))
    end

    @testset "interpolação não fechada" begin
        @test "K1203" in codes(withtext("valor {price"))
        @test "K1203" in codes("kanon 1\n\ntext\n\n: b\nvalor {price\nseguinte}\n")
    end

    @testset "interpolação vazia" begin
        @test "K1204" in codes(withtext("valor {} aqui"))
    end

    @testset "caminho malformado" begin
        @test "K1205" in codes(withtext("{1price}"))
        @test "K1205" in codes(withtext("{a..b}"))
        @test "K1205" in codes(withtext("{price:2x}"))
    end

    @testset "encadeamento é reservado, não aceito com outro sentido (D-007)" begin
        @test "K1206" in codes(withtext("{v:round:written}"))
    end

    @testset "argumentos de formatador são reservados" begin
        @test "K1207" in codes(withtext("{v:round(2)}"))
    end

    @testset "remissão malformada" begin
        @test "K1211" in codes(withtext("{::}"))
        @test "K1211" in codes(withtext("{::a.b}"))
    end

    @testset "texto fora de bloco" begin
        @test "K1210" in codes("kanon 1\n\ntext\nsolto\n\n: b\nx\n")
    end

    @testset "bloco declarado duas vezes" begin
        @test "K1202" in codes("kanon 1\n\ntext\n\n: b\nx\n\n: b\ny\n")
    end

    @testset "nível acima do teto da versão 1" begin
        @test "K1212" in codes("kanon 1\n\ntext\n\n:: a\nx\n\n::::: b\ny\n")
    end

    @testset "comentário do plano do texto" begin
        t = ok("kanon 1\n\ntext\n\n: b\nlinha\n:# some daqui\noutra\n")
        @test (nodes1(t)[1]::TextLit).value == "linha\noutra"
    end

    @testset "# no plano do texto é prosa, não comentário (D-012)" begin
        t = ok(withtext("# CLÁUSULAS"))
        @test (nodes1(t)[1]::TextLit).value == "# CLÁUSULAS"
    end
end

@testset "pontos de flexão" begin
    @testset "marca colada à palavra vira candidato" begin
        t = ok(withtext("portador(a) do CPF"))
        f = nodes1(t)[1]::FlexPoint
        @test f.word == "portador"
        @test f.mark == "(a)"
    end

    @testset "só a palavra marcada é separada" begin
        t = ok(withtext("residente e domiciliado(a) na"))
        ns = nodes1(t)
        @test (ns[1]::TextLit).value == "residente e "
        @test (ns[2]::FlexPoint).word == "domiciliado"
    end

    @testset "parêntese com espaço antes não é flexão" begin
        t = ok(withtext("item (a) da lista"))
        @test length(nodes1(t)) == 1
        @test (nodes1(t)[1]::TextLit).value == "item (a) da lista"
    end

    @testset "parêntese depois de interpolação não é flexão" begin
        t = ok(withtext("{nome}(a)"))
        ns = nodes1(t)
        @test ns[1] isa Interp
        @test (ns[2]::TextLit).value == "(a)"
    end

    @testset "escape por duplicação de parênteses" begin
        t = ok(withtext("portador((a))"))
        @test length(nodes1(t)) == 1
        @test (nodes1(t)[1]::TextLit).value == "portador(a)"
    end

    @testset "conteúdo longo entre parênteses não é marca" begin
        t = ok(withtext("nota(observação)"))
        @test length(nodes1(t)) == 1
    end
end
