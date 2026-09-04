# `contract(modelo)` — o checklist em JSON Schema (F2.7).
#
# O que esta suíte protege é a promessa da D-009: a saída é **comparável em `diff`**.
# Um checklist versionado ao lado do modelo mostra, no `diff` de um commit, exatamente o
# que o contrato passou a exigir — e isso só vale se a mesma entrada der sempre a mesma
# cadeia, byte a byte.

const GOLDEN = joinpath(@__DIR__, "golden", "report.contract.json")

@testset "o checklist do modelo de aceite, byte a byte" begin
    env = Environment(domains = [Science])
    m = load_string(env, RELATORIO; name = "report.kanon")
    saida = contract(m)

    if get(ENV, "KANON_REGEN_GOLDEN", "") == "1"
        write(GOLDEN, saida)
    end
    esperado = read(GOLDEN, String)
    saida == esperado || println(saida)
    @test saida == esperado
end

@testset "determinismo (D-009)" begin
    env = Environment(domains = [Science])
    m = load_string(env, RELATORIO; name = "report.kanon")

    @testset "duas chamadas dão a mesma cadeia" begin
        @test contract(m) == contract(m)
    end

    @testset "dois carregamentos do mesmo texto também" begin
        m2 = load_string(env, RELATORIO; name = "report.kanon")
        @test contract(m) == contract(m2)
    end

    @testset "e nada depende da ordem de iteração de um Dict (I4)" begin
        # `$defs` sai em ordem alfabética, e `properties` na ordem do arquivo
        s = contract(m)
        defs = [m.captures[1] for m in eachmatch(r"^    \"([a-z]+)\": \{$"m,
                                                 s[findfirst("\"\$defs\"", s)[1]:end])]
        @test issorted(defs)
    end
end

const MODELO_C = """
kanon 1

data
  seller     : person !
  price      : money  !
  notes      : text
  witnesses  : person[2]
  quorum     : number[1..] !
  faixa      : number[2..5]
  teto       : number[..3]
  livre      : number[]
  signed     : boolean = true
  quando     : date = today
  limite     : date = 2026-12-31

text

: b
{seller.name} paga {price:code} e {price:plain}[, nota {notes}].
"""

const M_C = load_string(ENVK, MODELO_C; name = "c.kanon")
const S_C = contract(M_C)

"O bloco `x-kanon` de um campo, como texto."
function xkanon(nome::AbstractString)
    i = findfirst("\"$nome\": {", S_C)
    i === nothing && return ""
    j = findnext("\"x-kanon\": {", S_C, first(i))
    k = findnext("\n      }", S_C, first(j))
    S_C[first(j):last(k)]
end

@testset "a forma do checklist (§7)" begin
    @testset "cabeçalho e identidade" begin
        @test occursin("\"\$schema\": \"https://json-schema.org/draft/2020-12/schema\"", S_C)
        @test occursin("\"\$id\": \"kanon:c.kanon\"", S_C)
        @test occursin("\"type\": \"object\"", S_C)
        @test occursin("\"additionalProperties\": false", S_C)
    end

    @testset "required traz só os obrigatórios, na ordem do arquivo" begin
        bloco = S_C[findfirst("\"required\": [", S_C)[1]:findfirst("\"additionalProperties\"", S_C)[1]]
        nomes = [m.captures[1] for m in eachmatch(r"\"([a-z]+)\"", bloco)][2:end]
        @test nomes == ["seller", "price", "quorum"]
        # o campo com padrão não é exigido: o padrão o preenche (§2.1)
        @test !("signed" in nomes) && !("quando" in nomes)
    end

    @testset "properties na ordem de declaração, que é a ordem do checklist" begin
        corpo = S_C[findfirst("\"properties\": {", S_C)[1]:(findfirst("\"\$defs\": {", S_C)[1] - 1)]
        nomes = [m.captures[1] for m in eachmatch(r"^    \"([a-z]+)\": \{$"m, corpo)]
        @test nomes == [String(f.name) for f in M_C.template.data.fields]
    end

    @testset "x-kanon carrega o que o JSON Schema não expressa" begin
        @test occursin("\"type\": \"money\"", xkanon("price"))
        @test occursin("\"line\": 5", xkanon("price"))
        @test occursin("\"presence\": \"required\"", xkanon("price"))
        @test occursin("\"presence\": \"optional\"", xkanon("notes"))
        @test occursin("\"presence\": \"defaulted\"", xkanon("signed"))
    end

    @testset "o valor padrão, inclusive o injetado" begin
        @test occursin("\"default\": true", xkanon("signed"))
        @test occursin("\"default\": \"today\"", xkanon("quando"))
        @test occursin("\"default\": \"2026-12-31\"", xkanon("limite"))
    end

    @testset "os formatadores são os USADOS, não os disponíveis" begin
        # o modelo pede `code` e `plain`; `money` também tem `symbol`, que não aparece
        x = xkanon("price")
        @test occursin("\"code\"", x) && occursin("\"plain\"", x)
        @test !occursin("\"symbol\"", x)
        # e um campo sem formatador nomeado não ganha a chave
        @test !occursin("formatters", xkanon("notes"))
    end
end

@testset "cardinalidade nos dois vocabulários" begin
    @testset "o do JSON Schema" begin
        @test occursin("\"minItems\": 2,\n      \"maxItems\": 2", S_C)   # exact(2)
        @test occursin("\"type\": \"array\"", S_C)
    end

    @testset "e o exato, em x-kanon" begin
        @test occursin("\"cardinality\": \"exact(2)\"", xkanon("witnesses"))
        @test occursin("\"cardinality\": \"atleast(1)\"", xkanon("quorum"))
        @test occursin("\"cardinality\": \"range(2,5)\"", xkanon("faixa"))
        @test occursin("\"cardinality\": \"range(0,3)\"", xkanon("teto"))
        @test occursin("\"cardinality\": \"any\"", xkanon("livre"))
        # um campo escalar não ganha a chave
        @test !occursin("cardinality", xkanon("price"))
    end
end

@testset "\$defs" begin
    @testset "todo \$ref tem definição, e nenhuma sobra" begin
        refs = Set(m.captures[1] for m in eachmatch(r"#/\$defs/([a-z]+)", S_C))
        corpo = S_C[findfirst("\"\$defs\": {", S_C)[1]:end]
        defs = Set(m.captures[1] for m in eachmatch(r"^    \"([a-z]+)\": \{$"m, corpo))
        @test refs == defs
    end

    @testset "o composto sai do esquema do tipo, com os obrigatórios" begin
        i = findfirst("\"person\": {", S_C)[1]
        corpo = S_C[i:end]
        corpo = corpo[1:findfirst("\n    }", corpo)[1]]
        @test occursin("\"type\": \"object\"", corpo)
        @test occursin("\"additionalProperties\": false", corpo)
        # `person` declara `spouse` opcional: ele não entra em `required`
        j = findfirst("\"required\": [", corpo)[1]
        req = corpo[j:(j + findfirst("]", corpo[j:end])[1] - 1)]
        @test occursin("name", req)
        @test !occursin("spouse", req)
    end

    @testset "os tipos do núcleo têm forma JSON de verdade" begin
        @test occursin("\"text\": {\n      \"type\": \"string\"\n    }", S_C)
        @test occursin("\"format\": \"date\"", S_C)
        @test occursin("\"currency\"", S_C)      # `money` é objeto com quantia e moeda
    end

    @testset "um escalar de camada vira {} com o nome em x-kanon" begin
        env = Environment(domains = [Science])
        s = contract(load_string(env, RELATORIO; name = "r.kanon"))
        @test occursin("\"measure\": {\n      \"x-kanon\": {\n        \"type\": \"measure\"\n      }\n    }", s)
    end

    @testset "um tipo recursivo não entra em laço" begin
        # `person.spouse : person` resolve pelo `$ref`, não por expansão
        @test count("\"person\": {", S_C) == 1
    end
end

@testset "o emissor de JSON" begin
    @testset "escapa o que precisa ser escapado" begin
        esc(s) = (io = IOBuffer(); Kanon.json_escape(io, s); String(take!(io)))
        @test esc("a\"b") == "\"a\\\"b\""
        @test esc("a\\b") == "\"a\\\\b\""
        @test esc("a\nb") == "\"a\\nb\""
        @test esc("a\tb") == "\"a\\tb\""
        @test esc("a\x01b") == "\"a\\u0001b\""
        @test esc("acentuação") == "\"acentuação\""   # UTF-8 passa intacto
    end

    @testset "o nome do arquivo entra escapado no \$id" begin
        m = load_string(ENVK, MODELO_C; name = "com \"aspas\".kanon")
        @test occursin("\"\$id\": \"kanon:com \\\"aspas\\\".kanon\"", contract(m))
    end

    @testset "objeto e lista vazios não viram linhas em branco" begin
        m = load_string(ENVK, "kanon 1\n\ntext\n\n: b\ntexto\n"; name = "vazio.kanon")
        s = contract(m)
        @test occursin("\"required\": []", s)
        @test occursin("\"properties\": {}", s)
        @test !occursin("\n\n", s)
    end
end

@testset "contract escreve arquivo, para ser versionado ao lado do modelo" begin
    caminho = joinpath(mktempdir(), "c.contract.json")
    @test contract(M_C, caminho) == caminho
    @test read(caminho, String) == S_C
end
