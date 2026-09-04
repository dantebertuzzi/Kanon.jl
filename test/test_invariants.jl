@testset "invariantes da árvore" begin
    modelo = """
kanon 1

data
  seller : person[1..] !
  notes  : text

text

: preamble
Saibam quantos, aos {date:written}, que:

: grantor <- seller
{name}, brasileiro(a)[, sob o regime da {regime}], doravante.

:: payment
Conforme a {::payment}, o preço é {price}.

rules
  grantor one for each seller
  payment when notes is present
"""

    @testset "I1 — todo nó é imutável" begin
        for T in (FieldDecl, TextLit, Interp, BlockRef, FlexPoint, Group, Paragraph,
                  Block, Rule, PathExpr, LitExpr, NotExpr, BinExpr, AttrExpr,
                  Path, Literal, Span, Cardinality, Template,
                  DataPlane, TextPlane, RulesPlane)
            @test !ismutabletype(T)
        end
    end

    @testset "I2 — nenhum resultado de análise mora no nó" begin
        # O `Block` guarda o marcador COMO ESCRITO; estilo e nível resolvidos exigem o
        # ambiente e por isso não podem ser campos do nó.
        campos = fieldnames(Block)
        @test :unit in campos && :repeat in campos
        for proibido in (:style, :level, :number, :numbering, :resolved, :numbered)
            @test !(proibido in campos)
        end
        # Idem para a interpolação: nada de tipo resolvido nem de nulabilidade.
        for proibido in (:type, :nullable, :guarded, :resolved)
            @test !(proibido in fieldnames(Interp))
        end
    end

    @testset "I3/determinismo — analisar duas vezes dá a mesma árvore" begin
        @test dump_tree(ok(modelo)) == dump_tree(ok(modelo))
    end

    @testset "identificadores de nó são densos e únicos" begin
        t = ok(modelo)
        ids = sort([Kanon.id(n) for n in allnodes(t)])
        @test allunique(ids)
        @test maximum(ids) <= t.nnodes
        @test minimum(ids) >= 1
    end

    @testset "o modelo não conhece ambiente" begin
        # `Template` não tem nenhum campo que amarre a árvore a um ambiente: é o que
        # permite analisar o mesmo modelo com e sem camadas (teste de neutralidade).
        for proibido in (:env, :environment, :locale, :domains, :types)
            @test !(proibido in fieldnames(Template))
        end
    end

    @testset "a árvore preserva a ordem do arquivo" begin
        t = ok(modelo)
        @test [f.name for f in t.data.fields] == [:seller, :notes]
        @test [b.name for b in t.text.blocks] == [:preamble, :grantor, :payment]
        @test [r.block for r in t.rules.rules] == [:grantor, :payment]
    end
end
