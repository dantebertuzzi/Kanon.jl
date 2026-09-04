# Remissões, estilos de bloco, níveis e a ligação regra-bloco (F2.4).
#
# Tudo aqui é nome que precisa existir, verificado sem dados. Usa o ambiente de
# `test_analyze.jl`.

"Um domínio que registra um estilo numerado, para exercitar marcador que não é o do núcleo."
module CamadaClausulas
    using Kanon
    configure!(b) = register_block_style!(b, :clause;
        unit = Char(0x00A7), layout = :prefix, separator = ". ",
        number = (path, ctx) -> "CLAUSULA " * join(path, '.'),
        ref = (path, ctx) -> "clausula " * join(path, '.'))
end

const ENVC = Environment(domains = [CamadaPessoas, CamadaClausulas])

const CABECA = """
kanon 1

data
  price : money !
  notes : text

text

"""

ref_codes(corpo; env = ENVC) = [d.code for d in anl(CABECA * corpo; env).diagnostics]
ref_diags(corpo; env = ENVC) = anl(CABECA * corpo; env).diagnostics

@testset "estilos de bloco e níveis" begin
    @testset "o núcleo registra `:`, e sozinho ele é o bloco não numerado" begin
        env = Environment()
        e = stylefor(env, ':')
        @test e !== nothing && e.name === :section
        @test e.layout === :prefix && e.separator == ". "
        @test ref_codes(": a\ntexto\n"; env) == []
        @test ref_codes(":: a\ntexto\n"; env) == []
    end

    @testset "marcador sem estilo neste ambiente" begin
        # `§` existe no conjunto fechado do parser, mas nenhuma camada o registrou
        d = ref_diags("§§ a\ntexto\n"; env = Environment())[1]
        @test d.code == "K2030"
        @test occursin("estilo", d.message)
        @test occursin(":", d.hint)
        # com a camada carregada, passa
        @test ref_codes("§§ a\ntexto\n") == []
    end

    @testset "só o núcleo tem forma não numerada" begin
        d = ref_diags("§ a\ntexto\n")[1]
        @test d.code == "K2032"
        @test occursin("§§", d.hint)
    end

    @testset "um nível só existe dentro do anterior" begin
        @test ref_codes(":: a\nx\n\n::: b\ny\n") == []
        @test ref_codes("::: b\ny\n") == ["K2031"]
        d = ref_diags(":: a\nx\n\n:::: c\ny\n")[1]
        @test d.code == "K2031"
        @test occursin("nível 3", d.message) && occursin("nível 2", d.message)
    end

    @testset "voltar de nível fecha os de baixo" begin
        # 1, 2, 1, 3 — o 3 não tem mais um 2 aberto antes dele
        @test ref_codes(":: a\nx\n\n::: b\nx\n\n:: c\nx\n\n:::: d\nx\n") == ["K2031"]
        # 1, 2, 1, 2 é legítimo
        @test ref_codes(":: a\nx\n\n::: b\nx\n\n:: c\nx\n\n::: d\nx\n") == []
    end

    @testset "cada estilo tem a sua sequência" begin
        # o `§§` de nível 1 não abre caminho para o `:::` de nível 2
        @test ref_codes("§§ a\nx\n\n::: b\nx\n") == ["K2031"]
        @test ref_codes("§§ a\nx\n\n§§§ b\nx\n") == []
    end

    @testset "o bloco não numerado fica fora da sequência" begin
        @test ref_codes(":: a\nx\n\n: meio\nx\n\n::: b\nx\n") == []
    end
end

@testset "remissões" begin
    @testset "remissão a bloco numerado existente" begin
        @test ref_codes(":: pagamento\nx\n\n: b\nConforme a {::pagamento}.\n") == []
    end

    @testset "remissão a bloco inexistente, com sugestão" begin
        d = ref_diags(":: pagamento\nx\n\n: b\nConforme a {::pagamneto}.\n")[1]
        @test d.code == "K2033"
        @test occursin("Você quis dizer `pagamento`?", d.hint)
    end

    @testset "remissão a bloco não numerado" begin
        d = ref_diags(": simples\nx\n\n: b\nConforme a {::simples}.\n")[1]
        @test d.code == "K2038"
        @test occursin("número", d.message)
    end

    @testset "remissão a bloco repetido é erro: não há como nomear uma cópia" begin
        src = """
kanon 1

data
  price   : money !
  parcelas : number[] !

text

:: cada <- parcelas
{price}

: b
Conforme a {::cada}.

rules
  cada one for each parcelas
"""
        d = [x for x in anl(src; env = ENVC).diagnostics if x.code == "K2034"]
        @test length(d) == 1
        @test occursin("one for each", d[1].message)
        @test d[1].severity === :error
    end

    @testset "remissão a bloco removível é aviso, não erro" begin
        src = CABECA * """
:: opcional
x

: b
Conforme a {::opcional}.

rules
  opcional when notes is present
"""
        ds = anl(src; env = ENVC).diagnostics
        @test [d.code for d in ds] == ["K2035"]
        @test ds[1].severity === :warning
        @test occursin("coincidem", ds[1].hint)

        # aviso não impede carregar: o autor pode saber que as condições coincidem
        m = load_string(ENVC, src)
        @test m isa Model
        @test length(m.analysis.diagnostics) == 1
        @test !Kanon.haserrors(m.analysis)
    end

    @testset "remissão não conta como interpolação direta de grupo (§4.4)" begin
        src = CABECA * ":: alvo\nx\n\n: b\n[Conforme a {::alvo}.]\n"
        @test "K2010" in [d.code for d in anl(src; env = ENVC).diagnostics]
    end
end

@testset "a ligação entre regra e bloco" begin
    @testset "as tabelas apontam a regra pela posição do bloco" begin
        src = CABECA * """
: a
x

:: b
y

rules
  b when notes is present
"""
        t, a = anl2(src; env = ENVC)
        @test length(a.block_rule) == length(t.text.blocks)
        @test a.block_rule == Int32[0, 1]        # a regra 1 prende o bloco 2
        @test all(iszero, a.block_foreach)
    end

    @testset "regra que nomeia bloco inexistente, com sugestão" begin
        src = CABECA * ": preamble\nx\n\nrules\n  preambulo when notes is present\n"
        d = anl(src; env = ENVC).diagnostics[1]
        @test d.code == "K2036"
        @test occursin("Você quis dizer `preamble`?", d.hint)
    end

    @testset "dois `when` para o mesmo bloco é erro, nunca conjunção implícita (D-002)" begin
        src = CABECA * """
: a
x

rules
  a when notes is present
  a when notes is absent
"""
        ds = anl(src; env = ENVC).diagnostics
        @test [d.code for d in ds] == ["K2037"]
        @test occursin("and", ds[1].hint) || occursin("or", ds[1].hint)
        @test occursin("linha", ds[1].message)     # aponta a outra regra
    end

    @testset "dois `one for each` para o mesmo bloco também" begin
        src = """
kanon 1

data
  xs : number[] !
  ys : number[] !

text

: a <- xs
{xs}

rules
  a one for each xs
  a one for each ys
"""
        @test "K2037" in [d.code for d in anl(src; env = ENVC).diagnostics]
    end

    @testset "when e one for each coexistem no mesmo bloco (D-002)" begin
        src = """
kanon 1

data
  xs    : person[] !
  notes : text

text

: a <- xs
{name}

rules
  a one for each xs
  a when notes is present
"""
        t, a = anl2(src; env = ENVC)
        @test isempty(a.diagnostics)
        @test a.block_foreach == Int32[1]
        @test a.block_rule == Int32[2]
    end
end

@testset "dentro do bloco iterado, o caminho é o elemento (§8.3)" begin
    src = """
kanon 1

data
  witnesses : person[2] !
  valores   : number[]  !

text

: cada <- witnesses
{witnesses} assina, e o nome e {witnesses.name}, ou so {name}.

: outro <- valores
O valor e {valores}.

rules
  cada  one for each witnesses
  outro one for each valores
"""
    t, a = anl2(src; env = ENVC)
    @test isempty(a.diagnostics)

    interps = [n for p in t.text.blocks[1].children for n in p.children if n isa Interp]
    @test [string(n.path) for n in interps] == ["witnesses", "witnesses.name", "name"]

    @testset "o caminho iterado vale um elemento, não a coleção" begin
        rp = resolved(a, interps[1])
        @test rp.typename === :person
        @test !Kanon.islist(rp.card)        # sem isto, a lista inteira sairia por iteração
        @test rp.nullable == false          # iterar nunca entrega nulo
    end

    @testset "descer a partir dele é campo do elemento, não K2008" begin
        @test resolved(a, interps[2]).typename === :text
        @test resolved(a, interps[3]).kind === :subject_field
    end

    @testset "lista de escalares pode ser iterada: o sujeito sem campos é legítimo" begin
        rp = resolved(a, [n for p in t.text.blocks[2].children
                            for n in p.children if n isa Interp][1])
        @test rp.typename === :number && !Kanon.islist(rp.card)
    end

    @testset "fora do bloco iterado, o mesmo caminho volta a ser a coleção" begin
        src2 = replace(src, "\nrules\n" => "\n: fim\nSao {witnesses:count} testemunhas.\n\nrules\n")
        t2, a2 = anl2(src2; env = ENVC)
        rp = resolved(a2, [n for p in t2.text.blocks[3].children
                             for n in p.children if n isa Interp][1])
        @test Kanon.islist(rp.card)
    end

    @testset "sujeito escalar sem iteração continua sendo erro" begin
        src3 = CABECA * ": b <- price\n{price}\n"
        @test "K2007" in ref_codes(": b <- price\n{price}\n")
    end
end
