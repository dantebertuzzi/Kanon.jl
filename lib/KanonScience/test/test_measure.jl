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

    @testset "o primeiro algarismo da incerteza é lido em decimal, não em ponto flutuante" begin
        # Descoberto ao escrever o modelo real nº 3: `0.3 / 10.0^-1` vale
        # `2.9999999999999996`, e o `floor` devolvia 2. A incerteza caía na regra dos
        # dois algarismos e o relatório saía com UMA CASA A MAIS do que a medição
        # sustenta — que é exatamente o que a regra do PDG existe para impedir.
        #
        # Quebrava com 0.3, 0.03 e 0.0003, e não com 3.0 nem 30.0: só ali a potência de
        # dez divide exato. Um defeito que depende do dado é um defeito que passa na
        # revisão.
        @test Kanon.format(Measure(21.4, 0.3, "°C"), Val(:default), ctx) == "21.4 ± 0.3 °C"
        @test Kanon.format(Measure(1.25, 0.03), Val(:default), ctx) == "1.25 ± 0.03"
        @test Kanon.format(Measure(0.12341, 0.0003), Val(:default), ctx) == "0.1234 ± 0.0003"

        # e os que já funcionavam continuam
        @test Kanon.format(Measure(17.0, 3.0), Val(:default), ctx) == "17 ± 3"
        @test Kanon.format(Measure(170.0, 30.0), Val(:default), ctx) == "170 ± 30"

        @testset "o primeiro algarismo e o expoente, um a um" begin
            # A regra: dois algarismos significativos quando o primeiro é 1 ou 2, um nos
            # demais. Afirmada aqui sobre o algarismo, e não sobre a saída formatada,
            # porque é dele que a saída depende.
            for (u, primeiro, expoente) in
                ((0.1, 1, -1), (0.2, 2, -1), (0.3, 3, -1), (0.9, 9, -1),
                 (0.03, 3, -2), (0.0003, 3, -4), (0.008, 8, -3), (0.015, 1, -2),
                 (1.4, 1, 0), (3.0, 3, 0), (12.0, 1, 1), (30.0, 3, 1), (3.0e-5, 3, -5))
                @test KanonScience.decimal_lead(u) == (primeiro, expoente)
            end
            @test KanonScience.decimal_lead(0.0) == (0, 0)
        end
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

    @testset "os separadores são DOIS, e os dois vêm do ambiente (D-041)" begin
        # Descoberto ao escrever o modelo real nº 5: a mesma área saía `41.250` como
        # `number` do núcleo e `41250,0` como `measure`, duas linhas depois, no mesmo
        # laudo. A camada trocava o separador decimal à mão e nunca agrupava os milhares.
        #
        # A §3.3 diz "separadores" no plural e cita `measure` pelo nome. O que faltava era
        # uma função do núcleo que os **aplicasse** — sem ela, cada camada reimplementa o
        # agrupamento, e a primeira a fazê-lo esqueceu metade.
        pt = FormatContext(Environment(locale = :pt, domains = [KanonScience]))
        @test Kanon.format(Measure(41250.0, 0.8, "m²"), Val(:default), pt) ==
              "41.250,0 ± 0,8 m²"
        @test Kanon.format(Measure(1200.0, 30.0, "kg"), Val(:default), pt) ==
              "1.200 ± 30 kg"

        # e o mesmo valor, como `number` do núcleo, sai igual — que é o ponto
        @test Kanon.format(41250, Val(:default), pt) == "41.250"

        @testset "sem idioma, o núcleo não agrupa nem troca vírgula" begin
            @test Kanon.format(Measure(41250.0, 0.8, "m²"), Val(:default), ctx) ==
                  "41250.0 ± 0.8 m²"
            @test Kanon.format(41250, Val(:default), ctx) == "41250"
        end
    end

    @testset "o separador decimal é do idioma, e este pacote não tem idioma" begin
        # o mesmo `Measure`, num ambiente com locale, sai com vírgula — sem que este
        # pacote saiba o que é uma vírgula decimal
        @test Kanon.kanon_format_locale(Measure, Val(:bare)) === nothing
        @test :bare in kanon_formats(Measure, ENV_SCI)
    end
end
