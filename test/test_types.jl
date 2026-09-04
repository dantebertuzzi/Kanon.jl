# O protocolo de tipo (F2.1).
#
# O teste que carrega a fase é `kanon_formats` por introspecção: um formatador
# acrescentado só por despacho, sem tocar em nenhuma fachada, tem de aparecer na
# validação e na mensagem de erro. É a promessa da §2.1 de `docs/api-extensao.md`.

"Um tipo de camada, definido aqui como uma camada real o definiria: por despacho."
struct Medida
    valor::Float64
    unidade::String
end

Kanon.kanon_typename(::Type{Medida}) = :measure
Kanon.format(v::Medida, ::Val{:default}, ctx) = string(v.valor, " ", v.unidade)
Kanon.format(v::Medida, ::Val{:bare}, ctx) = string(v.valor)
Kanon.kanon_schema(::Type{Medida}) = (FieldSpec(:valor, :number),
                                      FieldSpec(:unidade, :text; optional = true))
Kanon.kanon_attributes(::Type{Medida}) = (:exact,)
Kanon.kanon_attribute(v::Medida, ::Val{:exact}) = isinteger(v.valor)

"Tipo sem nenhum método do protocolo — o que o núcleo deve recusar nomeadamente."
struct Anonimo end

@testset "protocolo de tipo" begin
    env = Environment()
    ctx = FormatContext(env)

    @testset "kanon_formats enumera por introspecção, ordenado e sem :default" begin
        @test kanon_formats(String) == (:lower, :title, :upper)
        @test kanon_formats(Money) == (:code, :plain, :symbol)
        @test kanon_formats(Date) == (:iso, :numeric)
        @test kanon_formats(Int) == (:fixed2, :integer)
        @test kanon_formats(Bool) == ()
        @test !(:default in kanon_formats(String))
    end

    @testset "um formatador por despacho direto existe sem registro nenhum" begin
        # `Medida` nunca passou por `register_type!` nem por fachada alguma.
        @test kanon_formats(Medida) == (:bare,)
        @test format(Medida(2.0, "m"), Val(:bare), ctx) == "2.0"

        # e a mensagem de erro o lista.
        e = try; format(Medida(2.0, "m"), Val(:nope), ctx); catch err; err; end
        @test e isa UnknownFormatter
        msg = sprint(showerror, e)
        @test occursin("measure", msg) && occursin("bare", msg)
    end

    @testset "Bool não é number" begin
        # Em Julia `Bool <: Integer`. Se o núcleo definisse `number` sobre `Real`,
        # `{flag:fixed2}` passaria na validação.
        @test kanon_typename(Bool) === :boolean
        @test kanon_typename(Int) === :number
        @test !(Bool <: Kanon.NumberValue)
        @test_throws UnknownFormatter format(true, Val(:fixed2), ctx)
    end

    @testset "tipo sem protocolo é recusado com o nome do tipo Julia" begin
        e = try; kanon_typename(Anonimo); catch err; err; end
        @test e isa UnregisteredType
        @test occursin("Anonimo", sprint(showerror, e))
    end

    @testset "esquema: () para escalar, campos para composto" begin
        @test kanon_schema(String) == ()
        @test kanon_schema(Money) == ()
        esquema = kanon_schema(Medida)
        @test [f.name for f in esquema] == [:valor, :unidade]
        @test esquema[1].optional == false
        @test esquema[2].optional == true      # o que estende o teorema da lacuna
    end

    @testset "atributos" begin
        @test kanon_attributes(Money) == (:negative, :positive, :zero)
        @test kanon_attribute(Money(0, :BRL), Val(:zero))
        @test !kanon_attribute(Money(1, :BRL), Val(:zero))
        @test kanon_attributes(Medida) == (:exact,)
        @test kanon_attribute(Medida(2.0, "m"), Val(:exact))

        e = try; kanon_attribute(Medida(2.0, "m"), Val(:rural)); catch err; err; end
        @test e isa UnknownAttribute
        @test occursin("exact", sprint(showerror, e))

        # `present` e `absent` são do motor, não do tipo: nenhum tipo os declara.
        @test Kanon.UNIVERSAL_ATTRIBUTES == (:absent, :present)
        for T in (String, Money, Date, Bool, Vector{Int})
            @test isempty(intersect(kanon_attributes(T), Kanon.UNIVERSAL_ATTRIBUTES))
        end
    end
end

@testset "os seis tipos do núcleo" begin
    env = Environment()
    ctx = FormatContext(env)

    @testset "text" begin
        @test format("casa velha", Val(:default), ctx) == "casa velha"
        @test format("casa velha", Val(:upper), ctx) == "CASA VELHA"
        @test format("CASA", Val(:lower), ctx) == "casa"
        @test format("casa velha", Val(:title), ctx) == "Casa Velha"
        @test kanon_compare("a", "b") == -1
    end

    @testset "number: a forma natural, e as duas fixas" begin
        @test format(1200, Val(:default), ctx) == "1200"
        @test format(3.0, Val(:default), ctx) == "3"          # 3.0 é o inteiro 3
        @test format(0.42, Val(:default), ctx) == "0.42"
        @test format(-7, Val(:default), ctx) == "-7"
        @test format(1234.567, Val(:fixed2), ctx) == "1234.57"
        @test format(1//4, Val(:default), ctx) == "0.25"
        @test format(1//3, Val(:default), ctx) == "0.333333"  # teto de MAX_DECIMALS

        # meio para longe do zero, e não o arredondamento bancário do `round` padrão
        @test format(2.5, Val(:integer), ctx) == "3"
        @test format(-2.5, Val(:integer), ctx) == "-3"
        @test format(3.5, Val(:integer), ctx) == "4"
    end

    @testset "money: exato, com duas casas, e o símbolo vem do ambiente" begin
        m = Money("1234.57", :BRL)
        @test m.amount == 123457//100
        @test format(m, Val(:plain), ctx) == "1234.57"
        @test format(m, Val(:code), ctx) == "BRL 1234.57"
        # ambiente neutro não declara símbolo: cai no código da moeda
        @test format(m, Val(:symbol), ctx) == "BRL 1234.57"
        @test format(m, Val(:default), ctx) == format(m, Val(:symbol), ctx)

        # a quantia não passa por ponto flutuante em momento nenhum
        @test Money("0.1", :USD).amount + Money("0.2", :USD).amount == 3//10

        @test kanon_compare(Money(2, :BRL), Money(1, :BRL)) == 1
        @test_throws IncomparableValues kanon_compare(Money(1, :BRL), Money(1, :USD))
    end

    @testset "date" begin
        d = Date(2026, 3, 12)
        @test format(d, Val(:iso), ctx) == "2026-03-12"
        @test format(d, Val(:default), ctx) == "2026-03-12"
        @test format(d, Val(:numeric), ctx) == "2026-03-12"   # padrão de fábrica é ISO
        @test kanon_compare(d, Date(2026, 1, 1)) == 1
    end

    @testset "boolean" begin
        @test format(true, Val(:default), ctx) == "true"
        @test kanon_attribute(true, Val(Symbol("true")))
        @test kanon_attribute(false, Val(Symbol("false")))
    end

    @testset "list: a única convenção tipográfica do núcleo" begin
        @test format([1, 2, 3], Val(:default), ctx) == "1, 2, 3"
        @test format(["a", "b"], Val(:default), ctx) == "a, b"
        @test format([1, 2, 3], Val(:count), ctx) == "3"
        @test kanon_attribute(Int[], Val(:empty))
    end
end

@testset "decodificação da entrada externa" begin
    env = Environment()
    ctx = FormatContext(env)

    @test kanon_decode(AbstractString, "casa", ctx) == "casa"
    @test kanon_decode(Date, "2026-03-12", ctx) == Date(2026, 3, 12)
    @test kanon_decode(Bool, true, ctx) === true
    @test kanon_decode(Kanon.NumberValue, 42, ctx) == 42
    @test kanon_decode(Money, Dict("amount" => "1234.57", "currency" => "BRL"), ctx) ==
          Money("1234.57", :BRL)
    @test kanon_decode(Money, (amount = 10, currency = "USD"), ctx) == Money(10, :USD)

    @testset "não há coerção implícita, em lugar nenhum" begin
        @test_throws UndecodableValue kanon_decode(Date, "12/03/2026", ctx)
        @test_throws UndecodableValue kanon_decode(Kanon.NumberValue, "42", ctx)
        @test_throws UndecodableValue kanon_decode(AbstractString, 42, ctx)
        @test_throws UndecodableValue kanon_decode(Bool, 1, ctx)
        # verdadeiro não é 1
        @test_throws UndecodableValue kanon_decode(Kanon.NumberValue, true, ctx)
    end

    @testset "dinheiro sem moeda falha alto, e a mensagem diz o que escrever" begin
        e = try; kanon_decode(Money, 1200, ctx); catch err; err; end
        @test e isa UndecodableValue
        @test occursin("currency", sprint(showerror, e))
    end

    @testset "comparar exige que o tipo declare como" begin
        @test_throws IncomparableValues kanon_compare(Medida(1.0, "m"), Medida(2.0, "m"))
    end
end
