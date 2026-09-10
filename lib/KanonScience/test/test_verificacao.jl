# O certificado de verificação de balança — **modelo real nº 9** do portão da 1.0.
#
# Escolhido pelo caminho que os dados de um laboratório percorrem de fato: o sistema
# exporta uma **planilha**, e o laboratório emite um certificado por linha. Duas coisas
# existiam separadas e nenhum documento as tinha juntado:
#
#   * o certificado nº 4 lê planilha, mas só `texto` e `numero` — e nem é uma planilha: é
#     um `NamedTuple` montado em Julia, com listas dentro das células, que CSV nenhum tem;
#   * o certificado nº 8 lê `measure`, mas de um JSON, onde a medição chega como objeto.
#
# Este lê `measure` de um **arquivo CSV de verdade**, pelo `CSV.jl`. Cobrou três coisas:
#
#   * **D-052** — nenhuma planilha alcançava tipo composto, e todo tipo de domínio do
#     projeto é composto: `render_each`, que existe para planilhas, não alcançava camada
#     de domínio nenhuma. E a mensagem mandava fazer a coisa errada — dizia que `carga`
#     "não foi informado", quando o arquivo o trazia em três colunas. Agora a extensão de
#     tabelas aninha as colunas com ponto.
#   * **D-053** — o formatador `relative` usava uma casa decimal fixa: a balança
#     rodoviária saía com incerteza relativa de `0,0%`, que é afirmar incerteza nula, e o
#     padrão do certificado nº 8, publicado dois dias antes, saía com o dobro da dele.
#   * e a posição do registro: o diagnóstico dizia `linha 1 da tabela` logo depois de
#     `linha 13, coluna 3`, que é a do modelo — e a linha 1 de um CSV é o cabeçalho.

const VERIFICACAO = joinpath(RAIZ, "test", "golden", "exemplos", "verificacao.kanon")
const PLANILHA = joinpath(RAIZ, "test", "golden", "exemplos", "verificacao.csv")
const SAIDA_VERIFICACAO = joinpath(RAIZ, "test", "golden", "exemplos", "verificacao.txt")

const ENV_VERIF = Environment(locale = :pt, domains = [KanonScience])
const HOJE_V = Date(2026, 9, 10)

"Um CSV a partir do texto: o cabeçalho do arquivo real, com as linhas dadas."
function planilha(linhas...)
    cabecalho = first(eachline(PLANILHA))
    CSV.File(IOBuffer(join((cabecalho, linhas...), "\n") * "\n"))
end

"A primeira linha do arquivo real, com uma coluna trocada."
function linha_1(; kw...)
    tab = CSV.File(PLANILHA)
    cols = collect(Tables.columnnames(tab))
    vals = Any[getproperty(first(tab), c) for c in cols]
    for (k, v) in kw
        vals[findfirst(==(Symbol(replace(String(k), "__" => "."))), cols)] = v
    end
    join((v === missing ? "" : string(v) for v in vals), ",")
end

@testset "o certificado de verificação — modelo real nº 9" begin
    m = load_template(ENV_VERIF, VERIFICACAO)
    tab = CSV.File(PLANILHA)
    docs = render_each(m, tab; today = HOJE_V)

    @testset "o modelo carrega sem um único diagnóstico" begin
        isempty(m.analysis.diagnostics) ||
            error("o modelo não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(m.analysis.diagnostics)))
        @test isempty(m.analysis.diagnostics)
    end

    @testset "um certificado por registro, byte a byte" begin
        esperados = split(rstrip(read(SAIDA_VERIFICACAO, String), '\n'), "\n\n=====\n\n")
        @test length(docs) == length(esperados) == 3
        for (d, e) in zip(docs, esperados)
            d == e || println(d)
            @test d == e
        end
    end

    @testset "a coluna com ponto é o campo do composto (D-052)" begin
        # O que o `CSV.jl` entrega é plano — `carga.value` é o nome de uma coluna. A
        # extensão de tabelas o aninha, e o objeto chega a `kanon_decode` do `measure` na
        # mesma forma em que chegaria de um JSON.
        r = first(rows(tab))
        @test r["carga"] == Dict("value" => 20000.0, "uncertainty" => 1.2, "unit" => "kg")
        @test !haskey(r, "carga.value")

        # e a origem dos dados não altera o documento
        julia = Dict{String,Any}(
            "numero" => "V-2026/0311", "cliente" => "Frigorífico Vale do Pajeú Ltda.",
            "instrumento" => "balança rodoviária", "serie" => "BR-80-0147",
            "capacidade" => 80000, "carga" => Measure(20000.0, 1.2, "kg"),
            "indicacao" => Measure(20003.5, 5.0, "kg"),
            "temperatura" => Measure(27.0, 1.0, "°C"), "verificacao" => Date(2026, 9, 8))
        @test render(m, julia; today = HOJE_V) == docs[1]
    end

    @testset "o grupo de células todo vazio é o campo ausente" begin
        # a balança de plataforma não teve a temperatura registrada: as três células
        # vazias são a única forma de uma linha dizer que a medição opcional não existe
        @test !haskey(rows(tab)[2], "temperatura")
        @test occursin("capacidade máxima de 300 kg.\n", docs[2])
        @test !occursin("temperatura ambiente", docs[2])
    end

    @testset "o grupo pela metade é recusado, nomeando o registro e a chave" begin
        # célula vazia é chave ausente (D-046), e `measure` sem incerteza não é medição
        t = planilha(linha_1(temperatura__uncertainty = missing))
        e = try; render_each(m, t; today = HOJE_V); catch err; err; end
        @test e isa KanonContractError
        d = only(collect(e.diagnostics))
        @test d.code == "K3010"
        @test occursin("no 1º registro da tabela", d.message)
        @test occursin("falta a chave `uncertainty`", d.message)
        # "registro", e não "linha": a linha 1 de um CSV é o cabeçalho
        @test !occursin("linha 1 da tabela", d.message)
    end

    @testset "a coluna inteira e as partes dela, juntas, são recusadas" begin
        # a mesma linha diria o valor duas vezes, e escolher uma das duas é adivinhar
        t = CSV.File(IOBuffer("carga,carga.value\n1,2\n"))
        e = try; rows(t); catch err; err; end
        @test e isa ArgumentError
        @test occursin("`carga`", sprint(showerror, e))
    end

    @testset "a incerteza relativa tem os algarismos de uma incerteza (D-053)" begin
        # uma casa fixa dizia `0,0%` das duas primeiras — incerteza nula, que é o que a
        # frase afirma de um instrumento que tem incerteza de 5 kg
        @test occursin("incerteza relativa de 0,025%.", docs[1])
        @test occursin("incerteza relativa de 0,020%.", docs[2])
        @test occursin("incerteza relativa de 2,0%.", docs[3])
        @test !any(d -> occursin("0,0%", d), docs)
    end

    @testset "a ressalva sai só onde a incerteza passa de um centésimo" begin
        @test count(d -> occursin("não deve ser usado", d), docs) == 1
        @test occursin("2. A incerteza da indicação excede um centésimo", docs[3])
        @test occursin("3. Registra-se a seguinte observação", docs[3])
    end

    @testset "o separador de milhar é do idioma, e o valor veio de um CSV" begin
        @test occursin("capacidade máxima de 80.000 kg", docs[1])
        @test occursin("20.000,0 ± 1,2 kg", docs[1])
        @test occursin("capacidade máxima de 0,2 kg", docs[3])
    end
end
