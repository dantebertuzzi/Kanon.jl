# O teste de neutralidade — a espinha dorsal da arquitetura (roadmap, F6).
#
# A invariante 3: **nada de idioma nem de domínio dentro de `Kanon.jl`.** Ela é o que
# sustenta as outras: uma linguagem que soubesse o que é uma cláusula não seria uma
# linguagem, seria um gerador de escrituras.
#
# Esta suíte roda no núcleo, **sem nenhuma camada carregada**. É de propósito: um teste
# que precisasse de `Extenso` para provar que `Extenso` não vazou não provaria nada.

@testset "neutralidade: o núcleo não depende de camada nenhuma" begin
    projeto = read(joinpath(@__DIR__, "..", "Project.toml"), String)

    @testset "o Project.toml não conhece as camadas" begin
        for camada in ("Extenso", "KanonLegal", "KanonScience")
            @test !occursin(camada, projeto)
        end
    end

    @testset "as dependências são as da biblioteca padrão" begin
        secao(nome) = begin
            i = findfirst(nome, projeto)
            i === nothing && return ""
            resto = projeto[(last(i) + 1):end]
            j = findfirst("\n[", resto)
            corpo = j === nothing ? resto : resto[1:first(j)]
            sort([strip(split(l, "=")[1]) for l in split(corpo, "\n") if occursin("=", l)])
        end

        @test secao("[deps]") == ["Dates", "Unicode"]

        @testset "e as extensões são `weakdeps`, que não pesam em quem só quer o motor" begin
            # `Tables` e `JSON3` dão ingestão a quem os tem; quem não os tem não os carrega
            @test secao("[weakdeps]") == ["JSON3", "Tables"]
            for w in secao("[weakdeps]")
                @test !(w in secao("[deps]"))
            end
        end

        @testset "nenhuma extensão traz idioma nem domínio" begin
            # uma weakdep de camada seria o mesmo vazamento, por outra porta
            for w in secao("[weakdeps]")
                @test !(w in ["Extenso", "KanonLegal", "KanonScience"])
            end
        end
    end

    @testset "nenhum arquivo do núcleo carrega uma camada" begin
        for f in readdir(joinpath(@__DIR__, "..", "src"); join = true)
            endswith(f, ".jl") || continue
            fonte = read(f, String)
            for camada in ("Extenso", "KanonLegal", "KanonScience")
                @test !occursin("using $camada", fonte)
                @test !occursin("import $camada", fonte)
            end
        end
    end
end

@testset "neutralidade: o vocabulário do núcleo é o inglês canônico" begin
    @testset "as palavras-chave são as da §9, e nenhuma outra" begin
        kt = canonical_keywords()
        @test kt.lang === nothing
        for w in ("data", "text", "rules", "when", "one", "for", "each",
                  "and", "or", "not", "is", "present", "absent", "today")
            @test Kanon.keyword(kt, w) === Symbol(w)
        end
    end

    @testset "e nenhuma palavra em português é reconhecida" begin
        kt = canonical_keywords()
        for w in ("dados", "texto", "regras", "quando", "e", "ou", "não", "é",
                  "presente", "ausente", "hoje", "um", "para", "cada",
                  "verdadeiro", "falso", "nulo")
            @test Kanon.keyword(kt, w) === nothing
        end
    end

    @testset "os tipos do núcleo têm nome em inglês, e nenhum é de domínio" begin
        env = Environment()
        @test typenames(env) == [:boolean, :date, :list, :money, :number, :text]
        for nome in (:pessoa, :imovel, :parte, :measure, :dinheiro, :texto, :data)
            @test typefor(env, nome) === nothing
        end
    end

    @testset "o único estilo de bloco é `:`, e nenhum marcador de domínio existe" begin
        env = Environment()
        @test [s.name for s in env.styles] == [:section]
        for unidade in ('§', '¶', '@', '%', '&', '*')
            @test stylefor(env, unidade) === nothing
        end
    end

    @testset "não há marca de flexão, nem gancho de idioma" begin
        env = Environment()
        @test isempty(env.marks)
        @test env.inflect === nothing
        @test env.repair === nothing
        @test env.joiner === nothing
        @test env.locale === nothing
    end

    @testset "os valores de fábrica não são de nenhum país" begin
        env = Environment()
        @test env.decimal_separator == "."       # e não ","
        @test env.group_separator == ""          # e não "."
        @test env.date_pattern == "yyyy-mm-dd"   # ISO, e não dd/mm/yyyy
        @test isempty(env.currency)              # nenhum símbolo de moeda embutido
        @test currency_symbol(env, :BRL) == "BRL"
    end
end

@testset "neutralidade: o que o núcleo produz sozinho" begin
    env = Environment()
    ctx = FormatContext(env)

    @testset "números e datas saem no formato neutro" begin
        @test format(1200, Val(:default), ctx) == "1200"
        @test format(0.42, Val(:default), ctx) == "0.42"
        @test format(Date(2026, 3, 12), Val(:default), ctx) == "2026-03-12"
        @test format(Money("1234.57", :BRL), Val(:default), ctx) == "BRL 1234.57"
    end

    @testset "a lista junta por vírgula, sem conjunção de idioma nenhum" begin
        @test format(["a", "b", "c"], Val(:default), ctx) == "a, b, c"
    end

    @testset "a numeração é `1`, `2`, `3.1` — sem ordinal nem palavra" begin
        m = load_string(env, "kanon 1\n\ntext\n\n:: a\nA\n\n::: b\nB\n\n:: c\nC\n"; name = "n")
        @test render(m, Dict()) == "1. A\n\n1.1. B\n\n2. C"
    end

    @testset "uma marca de flexão não registrada volta a ser prosa (§7.1)" begin
        m = load_string(env, "kanon 1\n\ntext\n\n: b\numa casa(s) e um portador(a)\n"; name = "f")
        @test render(m, Dict()) == "uma casa(s) e um portador(a)"
    end
end

@testset "neutralidade: um modelo de domínio é recusado, e o erro nomeia o que falta" begin
    env = Environment()

    @testset "modelo em português" begin
        e = try
            load_string(env, "kanon 1 pt\n\ndados\n  a : texto !\n\ntexto\n\n: b\n{a}\n";
                        name = "pt.kanon")
        catch err
            err
        end
        @test e isa KanonSyntaxError
        @test "K1006" in [d.code for d in e.diagnostics]
    end

    @testset "modelo com tipo e marcador de domínio" begin
        e = try
            load_string(env, "kanon 1\n\ndata\n  p : pessoa !\n\ntext\n\n§§ c\n{p}\n";
                        name = "d.kanon")
        catch err
            err
        end
        @test e isa KanonReferenceError
        codigos = Set(d.code for d in e.diagnostics)
        @test "K2005" in codigos && "K2030" in codigos
        texto = sprint(showerror, e)
        @test occursin("pessoa", texto)      # nomeia o tipo que falta
    end
end

@testset "neutralidade: o núcleo não sabe o que é gênero, número ou cláusula" begin
    @testset "nenhuma função do núcleo se chama assim" begin
        # `Extenso.genero` e `Extenso.numero` são protocolo da camada de idioma (§7.1),
        # e o núcleo não tem nada equivalente.
        for n in (:genero, :numero, :gender, :number, :inflect, :plural, :clausula)
            @test !isdefined(Kanon, n)
        end
    end

    @testset "o núcleo entrega `(palavra, marca, sujeito)` e recebe a palavra (D-013)" begin
        # o gancho é uma função no ambiente, e o núcleo não interpreta a marca
        env = Environment()
        @test env.inflect === nothing
        @test fieldnames(Kanon.BlockStyle) ==
              (:name, :unit, :layout, :separator, :number, :ref, :domain)
        # `number` e `ref` são funções da camada: o núcleo não sabe como um número se lê
        @test fieldtype(Kanon.BlockStyle, :number) === Function
    end
end
