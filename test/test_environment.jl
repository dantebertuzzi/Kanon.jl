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

"Uma camada de idioma de mentira, registrada como uma real: por despacho."
Kanon.configure_locale!(b::Kanon.EnvironmentBuilder, ::Val{:xx}) = begin
    register_aliases!(b, :xx, (data = "dados", text = "texto", rules = "regras",
                               when = "quando", present = "presente"))
    register_inflection!(b, :xx; marks = ("(a)", "(s)"),
                         apply = (word, mark, subject, ctx) -> word)
    register_repair_hook!(b, :xx, (text, seams, ctx) -> text)
    register_separators!(b; decimal = ",", group = ".")
    b
end

@testset "ambiente" begin
    @testset "o núcleo puro tem os seis tipos e nada de idioma" begin
        env = Environment()
        @test env.locale === nothing
        @test isempty(env.domains)
        @test typenames(env) == [:boolean, :date, :list, :money, :number, :text]
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

    @testset "apelido para algo que não é palavra-chave é erro" begin
        b = EnvironmentBuilder(:xx)
        b.domain = :Teste
        @test_throws KanonEnvironmentError register_aliases!(b, :xx, (nao_existe = "nada",))
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
