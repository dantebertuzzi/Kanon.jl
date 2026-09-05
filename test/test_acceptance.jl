# O critério de aceite da F2, na parte que não precisa de dados.
#
# `docs/exemplos.md` §2.1: o modelo científico, escrito em inglês canônico e sem camada
# de idioma nenhuma, analisa limpo. É a prova de que a linguagem não é jurídica nem
# portuguesa — e é o modelo que a suíte inteira existe para conseguir carregar.
#
# A parte com dados (`check` recusando um JSON sem `effect`) entra na F2.6.

"""
Uma camada científica mínima, escrita **só com a API pública**: métodos das funções
genéricas para o comportamento, `configure!` para os nomes.
"""
struct Measure
    value::Float64
    uncertainty::Float64
    unit::String
end

Kanon.kanon_typename(::Type{Measure}) = :measure
Kanon.format(v::Measure, ::Val{:default}, ctx) =
    string(Kanon.plain_number(v.value, ctx), " ", Char(0x00B1), " ",
           Kanon.plain_number(v.uncertainty, ctx), " ", v.unit)
Kanon.format(v::Measure, ::Val{:bare}, ctx) = Kanon.plain_number(v.value, ctx)
Kanon.kanon_getfield(v::Measure, ::Val{:value}) = v.value
Kanon.kanon_attributes(::Type{Measure}) = (:precise,)
Kanon.kanon_attribute(v::Measure, ::Val{:precise}) = v.uncertainty < 0.01

module Science
    using Kanon
    using ..Main: Measure
    function configure!(b)
        register_type!(b, Measure)
        register_block_style!(b, :theorem;
            unit = '@', layout = :prefix, separator = ". ",
            number = (path, ctx) -> "Theorem " * join(path, '.'),
            ref = (path, ctx) -> "Theorem " * join(path, '.'))
        return b
    end
end

const RELATORIO = """
kanon 1

data
  effect  : measure !
  sample  : number  !
  method  : text    !
  caveat  : text

text

: abstract
We estimated the treatment effect over {sample} subjects using {method}.
The estimated effect was {effect}[, with the caveat that {caveat}].

@@ unbiasedness
For any sample of size at least {sample}, the estimator defined above is unbiased.

@@ consistency
The estimator converges in probability to the true effect as the sample grows.

: discussion
By {::unbiasedness}, the value {effect} is reported without further correction.
"""

@testset "aceite da F2: o modelo científico de exemplos.md §2.1" begin
    env = Environment(domains = [Science])

    @testset "analisa sem um único diagnóstico" begin
        a = analyze(env, parse_string(RELATORIO; name = "report.kanon",
                                      keywords = env.keywords))
        isempty(a.diagnostics) ||
            error("o modelo de aceite não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(a.diagnostics)))
        @test isempty(a.diagnostics)
    end

    m = load_string(env, RELATORIO; name = "report.kanon")

    @testset "e carrega" begin
        @test m isa Model
        @test [f.name for f in m.template.data.fields] == [:effect, :sample, :method, :caveat]
    end

    @testset "o campo opcional está guardado, e os obrigatórios não precisam estar" begin
        interps = all_interps(m.template)
        por_caminho = Dict(string(n.path) => n for n in interps)
        @test m.analysis.guarded[Kanon.id(por_caminho["caveat"])]
        @test !m.analysis.guarded[Kanon.id(por_caminho["sample"])]
    end

    @testset "o tipo da camada resolve, e o formatador dele também" begin
        rp = resolved(m.analysis, Dict(string(n.path) => n
                                       for n in all_interps(m.template))["effect"])
        @test rp.typename === :measure
        @test rp.nullable == false
        @test kanon_formats(Measure) == (:bare,)
    end

    @testset "o estilo `@` da camada numera, e a remissão aponta um bloco dele" begin
        e = stylefor(env, '@')
        @test e !== nothing && e.name === :theorem
        @test e.number(Int32[1], nothing) == "Theorem 1"
        @test [first(p) for p in m.analysis.block_index] ==
              [:abstract, :consistency, :discussion, :unbiasedness]
    end

    @testset "sem a camada, o mesmo modelo é recusado — com o nome do que falta" begin
        e = try
            load_string(Environment(), RELATORIO; name = "report.kanon")
        catch err
            err
        end
        @test e isa KanonReferenceError
        codigos = Set(d.code for d in e.diagnostics)
        @test "K2005" in codigos      # `measure` não existe no núcleo puro
        @test "K2030" in codigos      # nem o marcador `@`
    end

    @testset "o documento sai byte a byte igual ao de exemplos.md §2.3" begin
        # Este texto foi escrito na F0, antes de qualquer código, como a saída que a
        # linguagem deveria produzir. É o teste mais duro da fase, porque nada nele foi
        # ajustado depois: ou o motor produz exatamente isso, ou a especificação e a
        # implementação divergiram em algum ponto.
        dados = Dict("effect" => Measure(0.42, 0.07, "mm"),
                     "sample" => 1200,
                     "method" => "ordinary least squares",
                     "caveat" => nothing)
        esperado = rstrip(read(joinpath(@__DIR__, "golden", "report.output.txt"), String), '\n')
        obtido = render(m, dados)
        obtido == esperado || println(obtido)
        @test obtido == esperado
    end

    @testset "com a nota presente, o grupo fica" begin
        dados = Dict("effect" => Measure(0.42, 0.07, "mm"), "sample" => 1200,
                     "method" => "OLS", "caveat" => "the sample was not randomized")
        @test occursin(", with the caveat that the sample was not randomized.",
                       render(m, dados))
    end

    @testset "o núcleo não conhece nada de português nem de direito" begin
        # o modelo de aceite é inglês canônico e não declara idioma
        @test m.template.language === nothing
        @test m.env.locale === nothing
    end
end
