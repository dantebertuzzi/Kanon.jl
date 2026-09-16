# O ambiente (F2.1).
#
# O que esta suíte precisa provar: conflito de nome é detectado na CONSTRUÇÃO, com os
# dois domínios na mensagem; o ambiente congelado não tem como ser mutado; e dois
# ambientes com camadas diferentes coexistem sem interferência.

# --- camadas de mentira, escritas como camadas reais seriam ------------------

struct Parte
    nome::String
    empresa::Bool
end

Kanon.kanon_typename(::Type{Parte}) = :party
Kanon.format(v::Parte, ::Val{:default}, ctx) = v.nome
Kanon.kanon_schema(::Type{Parte}) = (FieldSpec(:nome, :text),)

module CamadaLegal
    using Kanon
    using ..Main: Parte
    function configure!(b)
        register_type!(b, Parte; aliases = (xx = :parte,))
        register_block_style!(b, :clause;
            unit = Char(0x00A7), layout = :prefix, separator = ". ",
            number = (path, ctx) -> "CLAUSULA " * string(path[1]),
            ref = (path, ctx) -> "clausula " * string(path[1]))
        register_currency!(b, :BRL, "R\$")
        return b
    end
end

"Um domínio que disputa o nome `party` com `CamadaLegal`."
struct Ator
    nome::String
end
Kanon.kanon_typename(::Type{Ator}) = :party
Kanon.format(v::Ator, ::Val{:default}, ctx) = v.nome

module CamadaRival
    using Kanon
    using ..Main: Ator
    configure!(b) = register_type!(b, Ator)
end

"Um domínio que disputa o marcador de bloco."
module CamadaMarcador
    using Kanon
    configure!(b) = register_block_style!(b, :section;
        unit = Char(0x00A7),
        number = (path, ctx) -> string(path[1]),
        ref = (path, ctx) -> string(path[1]))
end

"""
Um pacote de idioma passado como domínio — o que a linha de comando faz com `--domain
Extenso`. Importa o `configure!` do núcleo com `using Kanon`, e não define o seu.
"""
module CamadaSoDeIdioma
    using Kanon
end

"Uma camada de idioma de mentira, registrada como uma real: por despacho."
Kanon.configure_locale!(b::Kanon.EnvironmentBuilder, ::Val{:xx}) = begin
    register_aliases!(b, :xx, (data = "dados", text = "texto", rules = "regras",
                               when = "quando", present = "presente"))
    register_inflection!(b, :xx; marks = ("(a)", "(s)"),
                         apply = (word, mark, subject, ctx) -> word)
    register_repair_hook!(b, :xx, (text, seams, ctx) -> text)
    register_separators!(b; decimal = ",", group = ".")
    register_attribute_alias!(b, :xx, :vazio, :empty)
    register_attribute_alias!(b, :xx, :vazia, :empty)
    register_formatter_alias!(b, :xx, :maiusculo, :upper)
    b
end

@testset "ambiente" begin
    @testset "o núcleo puro tem os cinco tipos declaráveis e nada de idioma" begin
        env = Environment()
        @test env.locale === nothing
        @test isempty(env.domains)
        @test typenames(env) == [:boolean, :date, :money, :number, :text]
        # a coleção existe, e não se declara (D-071)
        @test typefor(env, :list) !== nothing
        @test env.inflect === nothing
        @test isempty(env.marks)
        @test env.decimal_separator == "." && env.group_separator == ""
        @test typefor(env, :money) === Money
        @test typefor(env, :parte) === nothing
    end

    @testset "o ambiente congelado é imutável" begin
        @test !ismutabletype(Environment)
        @test ismutabletype(EnvironmentBuilder)   # só o construtor muta
        env = Environment()
        # Não existe `register_*!` sobre um `Environment`: as assinaturas exigem builder.
        @test !hasmethod(register_type!, Tuple{Environment,Type})
        @test !hasmethod(register_aliases!, Tuple{Environment,Symbol,NamedTuple})
    end

    @testset "domínio registra tipo, apelido e estilo" begin
        env = Environment(locale = :xx, domains = [CamadaLegal])
        @test env.domains == [:CamadaLegal]
        @test typefor(env, :party) === Parte
        @test typefor(env, :parte) === Parte          # apelido do idioma ativo
        @test :parte in typenames(env)
        estilo = stylefor(env, Char(0x00A7))
        @test estilo !== nothing && estilo.name === :clause && estilo.layout === :prefix
        @test currency_symbol(env, :BRL) == "R\$"
        @test currency_symbol(env, :USD) == "USD"     # sem símbolo declarado, o código
    end

    @testset "apelido de tipo só entra no idioma ativo" begin
        env = Environment(domains = [CamadaLegal])    # sem locale
        @test typefor(env, :party) === Parte
        @test typefor(env, :parte) === nothing
    end

    @testset "conflito de nome de tipo é erro na construção, com os dois domínios" begin
        e = try
            Environment(domains = [CamadaLegal, CamadaRival])
        catch err
            err
        end
        @test e isa KanonEnvironmentError
        msg = sprint(showerror, e)
        @test occursin("party", msg)
        @test occursin("CamadaLegal", msg) && occursin("CamadaRival", msg)
    end

    @testset "conflito de marcador de bloco é erro na construção" begin
        e = try
            Environment(domains = [CamadaLegal, CamadaMarcador])
        catch err
            err
        end
        @test e isa KanonEnvironmentError
        msg = sprint(showerror, e)
        @test occursin("clause", msg) && occursin("section", msg)
    end

    @testset "o mesmo domínio duas vezes é erro" begin
        @test_throws KanonEnvironmentError Environment(domains = [CamadaLegal, CamadaLegal])
    end

    @testset "um módulo sem `configure!` próprio não registra o núcleo de novo (D-068)" begin
        # `isdefined(m, :configure!)` enxerga o que o módulo importou: o construtor chamava
        # o `configure!` do núcleo, e o conflito acusava a camada de registrar `text`.
        env = Environment(locale = :xx, domains = [CamadaSoDeIdioma])
        @test length(env.types) == 6
        @test env.domains == [:CamadaSoDeIdioma]
    end

    @testset "idioma sem camada carregada falha com o nome do idioma" begin
        e = try; Environment(locale = :zz); catch err; err; end
        @test e isa KanonEnvironmentError
        @test occursin("zz", sprint(showerror, e))
    end

    @testset "camada de idioma: apelidos, marcas, ganchos e separadores" begin
        env = Environment(locale = :xx)
        @test env.locale === :xx
        @test env.marks == ["(a)", "(s)"]
        @test hasmark(env, "(a)") && !hasmark(env, "(os)")
        @test env.inflect !== nothing && env.repair !== nothing
        @test env.decimal_separator == "," && env.group_separator == "."
    end

    @testset "a tabela de palavras-chave é a do idioma, sem mistura (D-003)" begin
        env = Environment(locale = :xx)
        kt = env.keywords
        @test kt.lang === :xx
        @test Kanon.keyword(kt, "dados") === :data
        @test Kanon.keyword(kt, "quando") === :when
        # a forma inglesa da palavra traduzida deixa de existir: misturar é erro
        @test Kanon.keyword(kt, "data") === nothing
        @test Kanon.keyword(kt, "when") === nothing
        # o que a camada não traduziu continua na forma canônica
        @test Kanon.keyword(kt, "absent") === :absent
    end

    @testset "e a tabela sabe voltar: a forma que este arquivo escreve (D-051)" begin
        # O motor não pode citar o que o autor não escreveu. `written` é o inverso de
        # `keyword`, e mora na tabela porque `parse` também precisa dela e não consulta o
        # ambiente (invariante 8).
        kt = Environment(locale = :xx).keywords
        @test Kanon.written(kt, :when) == "quando"
        @test Kanon.written(kt, :present) == "presente"
        # o que a camada não traduziu volta na forma canônica, e não em branco
        @test Kanon.written(kt, :absent) == "absent"
        @test Kanon.written_foreach(kt) == "one for each"

        # e no inglês canônico ela é a identidade
        en = canonical_keywords()
        @test Kanon.written(en, :when) == "when"
        @test Kanon.written_foreach(en) == "one for each"

        # duas formas para a mesma palavra: vale a menor, e a escolha é determinística
        # porque chega a mensagem de erro (I4)
        dupla = Kanon.KeywordTable(:zz, Dict("se" => :when, "quando" => :when))
        @test Kanon.written(dupla, :when) == "se"
    end

    @testset "apelido para algo que não é palavra-chave é erro" begin
        b = EnvironmentBuilder(:xx)
        b.domain = :Teste
        @test_throws KanonEnvironmentError register_aliases!(b, :xx, (nao_existe = "nada",))
    end

    @testset "apelido de atributo e de formatador: aditivo, e resolvido pelo tipo (D-076)" begin
        env = Environment(locale = :xx)
        V, S = Vector{String}, String
        @test Kanon.attribute_name(env, V, :vazio) === :empty
        @test Kanon.attribute_name(env, V, :vazia) === :empty
        @test Kanon.attribute_name(env, V, :empty) === :empty        # o canônico continua
        @test Kanon.attribute_name(env, Bool, :vazio) === nothing     # o tipo não o tem
        @test Kanon.formatter_name(env, S, :maiusculo) === :upper
        @test Kanon.formatter_name(env, S, :upper) === :upper
        @test Kanon.formatter_name(env, Date, :maiusculo) === nothing

        # o primeiro apelido registrado é o que a mensagem escreve
        @test Kanon.written_attributes(env, (:empty, :present, :absent)) == [:absent, :presente, :vazio]
        @test Kanon.written_formatters(env, S) == sort!([:lower, :maiusculo, :title])

        # só no idioma ativo: o núcleo puro não tem apelido nenhum
        neutro = Environment()
        @test Kanon.attribute_name(neutro, V, :vazio) === nothing
        @test Kanon.formatter_name(neutro, S, :maiusculo) === nothing
        @test Kanon.written_formatters(neutro, S) == [:lower, :title, :upper]
    end

    @testset "o modelo escreve o apelido, e o motor executa o canônico (D-076)" begin
        env = Environment(locale = :xx)
        fonte(attr, fmt) = "kanon 1 xx\n\ndados\n  nome : text !\n  itens : text[]\n\ntexto\n\n" *
                           ": a\n{nome:$fmt}\n\n: b\nSem itens.\n\nregras\n  b  quando itens is $attr\n"
        xx = load_string(env, fonte("vazio", "maiusculo"))
        en = load_string(env, fonte("empty", "upper"))
        for d in (Dict("nome" => "ana", "itens" => String[]), Dict("nome" => "ana", "itens" => ["x"]))
            @test render(xx, d) == render(en, d)
        end
        @test render(xx, Dict("nome" => "ana", "itens" => String[])) == "ANA\n\nSem itens."

        # o nó guarda o que o autor escreveu; a tabela lateral, o canônico (I2)
        r = only(xx.template.rules.rules)
        @test r.when.attr === :vazio
        @test Kanon.attribute(xx.analysis, r.when) === :empty
    end

    @testset "o apelido errado é recusado na língua do modelo (D-076)" begin
        env = Environment(locale = :xx)
        a = Kanon.load_source(env, "kanon 1 xx\n\ndados\n  nome : text !\n  itens : text[]\n\ntexto\n\n" *
                                   ": a\n{nome:maiuscula}\n\n: b\nx\n\nregras\n  b  quando itens is vazo\n")
        f = only(filter(d -> d.code == "K2020", collect(a.diagnostics)))
        @test occursin("`maiusculo`", f.hint) && !occursin("upper", f.hint)
        g = only(filter(d -> d.code == "K2041", collect(a.diagnostics)))
        @test occursin("`vazio`", g.hint)
        @test occursin("absent, presente, vazio", g.hint)
    end

    @testset "apelido de atributo e de formatador: os conflitos (D-076)" begin
        b = EnvironmentBuilder(:xx)
        b.domain = :Um
        register_attribute_alias!(b, :xx, :preciso, :precise)
        register_attribute_alias!(b, :xx, :preciso, :precise)            # repetir é inócuo
        b.domain = :Dois
        e = try; register_attribute_alias!(b, :xx, :preciso, :exact); catch err; err; end
        @test e isa KanonEnvironmentError
        @test occursin("`Um`", sprint(showerror, e)) && occursin("`Dois`", sprint(showerror, e))
        @test_throws KanonEnvironmentError register_formatter_alias!(b, :xx, :upper, :upper)

        # outro idioma: não entra
        register_formatter_alias!(b, :zz, :grande, :upper)
        @test isempty(b.formatteraliases)

        # o apelido que é palavra-chave do idioma nunca chegaria ao ambiente: o parser o
        # leria antes. Recusado na construção.
        k = EnvironmentBuilder(:xx)
        register_aliases!(k, :xx, (present = "presente",))
        register_attribute_alias!(k, :xx, :presente, :precise)
        e = try; Kanon.freeze(k, Symbol[]); catch err; err; end
        @test e isa KanonEnvironmentError
        @test occursin("palavra-chave", sprint(showerror, e))
    end

    @testset "separadores chegam à formatação pelo contexto" begin
        ctx = FormatContext(Environment(locale = :xx))
        @test format(1234567.89, Val(:fixed2), ctx) == "1.234.567,89"
        @test format(1200, Val(:default), ctx) == "1.200"
        @test format(Money("1234.57", :BRL), Val(:code), ctx) == "BRL 1.234,57"
    end

    @testset "dois ambientes coexistem sem interferência" begin
        neutro = Environment()
        legal = Environment(locale = :xx, domains = [CamadaLegal])
        @test typefor(neutro, :party) === nothing
        @test typefor(legal, :party) === Parte
        @test currency_symbol(neutro, :BRL) == "BRL"
        @test currency_symbol(legal, :BRL) == "R\$"
        # o comportamento, ao contrário do nome, é global e aditivo
        @test format(Parte("Ana", false), Val(:default), FormatContext(neutro)) == "Ana"
    end

    @testset "toda lista que alcança uma mensagem é ordenada (I4)" begin
        env = Environment(locale = :xx, domains = [CamadaLegal])
        @test issorted(typenames(env))
        @test issorted([e.name for e in env.types])
        @test issorted(env.marks)
        @test issorted([first(p) for p in env.currency])
        @test typenames(env) == typenames(Environment(locale = :xx, domains = [CamadaLegal]))
    end
end
