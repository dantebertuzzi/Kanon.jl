"Uma camada de idioma mínima: só os separadores, para provar a fronteira sem depender de `Extenso`."
Kanon.configure_locale!(b::Kanon.EnvironmentBuilder, ::Val{:xx}) =
    register_separators!(b; decimal = ",", group = ".")

# O relatório de `docs/exemplos.md` §2 — inglês canônico, sem camada de idioma.
#
# É a prova, em forma de exemplo, de que a linguagem não é jurídica nem portuguesa: o
# mesmo núcleo que produz uma escritura em português produz isto, e nenhum dos dois
# pacotes de camada sabe da existência do outro.

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

const DADOS = Dict{String,Any}(
    "effect" => Measure(0.42, 0.07, "mm"),
    "sample" => 1200,
    "method" => "ordinary least squares",
    "caveat" => nothing,
)

@testset "o relatório de exemplos.md §2" begin
    m = load_string(ENV_SCI, RELATORIO; name = "report.kanon")

    @testset "carrega sem diagnóstico, e sem camada de idioma nenhuma" begin
        @test isempty(m.analysis.diagnostics)
        @test m.env.locale === nothing
        @test m.template.language === nothing
        @test isempty(check(m, DADOS))
    end

    saida = render(m, DADOS)

    @testset "a saída exigida, byte a byte" begin
        esperado = rstrip(read(joinpath(RAIZ, "test", "golden", "report.output.txt"),
                               String), '\n')
        saida == esperado || println(saida)
        @test saida == esperado
    end

    @testset "o Measure atravessa a fronteira como Measure" begin
        # não há serialização para cadeia no caminho: quem arredonda é o formatador,
        # com o valor e a incerteza em mãos
        @test occursin("0.42 ± 0.07 mm", saida)
        @test Kanon.value(Kanon.bind(m, DADOS), :effect) isa Measure
    end

    @testset "o grupo opcional elide, e o texto fecha sem emenda visível" begin
        @test occursin("The estimated effect was 0.42 ± 0.07 mm.", saida)
        @test !occursin(", with the caveat", saida)
        @test !occursin("  ", saida)

        com = render(m, merge(DADOS, Dict("caveat" => "the sample was not randomized")))
        @test occursin("mm, with the caveat that the sample was not randomized.", com)
    end

    @testset "o estilo `@` numera teoremas, e a remissão os nomeia" begin
        @test occursin("Theorem 1. For any sample", saida)
        @test occursin("Theorem 2. The estimator converges", saida)
        @test occursin("By Theorem 1, the value", saida)
    end

    @testset "com um idioma carregado, o mesmo modelo troca só os separadores" begin
        # `docs/exemplos.md` §2.3: é o menor teste possível da fronteira entre as camadas.
        #
        # A camada de idioma é de mentira, e registra só os separadores, de propósito:
        # usar `Extenso` aqui obrigaria este pacote a conhecê-lo, e a independência entre
        # os dois domínios é justamente o que esta suíte existe para provar.
        env_sep = Environment(locale = :xx, domains = [KanonScience])
        m2 = load_string(env_sep, RELATORIO; name = "report.kanon")
        s = render(m2, DADOS)
        @test occursin("0,42 ± 0,07 mm", s)
        @test occursin("over 1.200 subjects", s)
        # e o texto continua em inglês: o idioma da saída é do modelo, não do ambiente
        @test occursin("The estimated effect was", s)
        @test occursin("Theorem 1.", s)
    end
end

@testset "sem a camada científica, o mesmo modelo é recusado" begin
    e = try
        load_string(Environment(), RELATORIO; name = "report.kanon")
    catch err
        err
    end
    @test e isa KanonReferenceError
    codigos = Set(d.code for d in e.diagnostics)
    @test "K2005" in codigos      # `measure`
    @test "K2030" in codigos      # o marcador `@`
    @test occursin("measure", sprint(showerror, e))
end
