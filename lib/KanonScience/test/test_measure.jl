# O tipo `measure`, e o que a incerteza decide.

@testset "measure" begin
    ctx = FormatContext(ENV_SCI)

    @testset "os algarismos vêm da incerteza, não do valor" begin
        # a convenção da metrologia: o valor mostra até a casa em que a incerteza começa
        @test Kanon.format(Measure(0.42, 0.07, "mm"), Val(:default), ctx) == "0.42 ± 0.07 mm"
        @test Kanon.format(Measure(0.4237, 0.0007, "mm"), Val(:default), ctx) ==
              "0.4237 ± 0.0007 mm"
        @test Kanon.format(Measure(12.3, 1.4), Val(:default), ctx) == "12.3 ± 1.4"
        @test Kanon.format(Measure(1200.0, 30.0, "kg"), Val(:default), ctx) ==
              "1200 ± 30 kg"
    end

    @testset "o valor e a incerteza são arredondados juntos" begin
        # arredondar cada um por conta própria daria `0.42 ± 0.1`, que nenhum revisor aceita
        s = Kanon.format(Measure(0.42, 0.07), Val(:default), ctx)
        valor, incerteza = split(s, " ± ")
        @test length(split(valor, ".")[2]) == length(split(incerteza, ".")[2])
    end

    @testset "os formatadores nomeados" begin
        m = Measure(0.42, 0.07, "mm")
        @test Kanon.format(m, Val(:bare), ctx) == "0.42"
        @test Kanon.format(m, Val(:relative), ctx) == "16.7%"
        @test kanon_formats(Measure) == (:bare, :relative)
    end

    @testset "os atributos" begin
        @test kanon_attribute(Measure(1.0, 0.001), Val(:precise))
        @test !kanon_attribute(Measure(1.0, 0.5), Val(:precise))
        @test kanon_attribute(Measure(1.0, 0.1), Val(:dimensionless))
        @test !kanon_attribute(Measure(1.0, 0.1, "m"), Val(:dimensionless))
    end

    @testset "comparar, com outra medida e com número" begin
        @test kanon_compare(Measure(2.0, 0.1), Measure(1.0, 0.1)) == 1
        @test kanon_compare(Measure(1.0, 0.1), 2) == -1
    end

    @testset "o esquema, e o campo lido por kanon_getfield" begin
        @test [f.name for f in kanon_schema(Measure)] == [:value, :uncertainty, :unit]
        @test kanon_schema(Measure)[3].optional
        @test kanon_getfield(Measure(1.0, 0.1, "m"), Val(:unit)) == "m"
    end

    @testset "o separador decimal é do idioma, e este pacote não tem idioma" begin
        # o mesmo `Measure`, num ambiente com locale, sai com vírgula — sem que este
        # pacote saiba o que é uma vírgula decimal
        @test Kanon.kanon_format_locale(Measure, Val(:bare)) === nothing
        @test :bare in kanon_formats(Measure, ENV_SCI)
    end
end
