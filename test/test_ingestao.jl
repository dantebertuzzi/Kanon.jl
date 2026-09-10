# Ingestão (F7): tabelas e JSON, por extensão.
#
# O roadmap pedia "`Tables.jl`, e não um adaptador por formato". A consequência é que
# `DataFrame`, CSV lido, resultado de consulta e vetor de `NamedTuple` entram pelo mesmo
# caminho, e o Kanon não sabe de onde os dados vieram.
#
# São **extensões**, e não dependências: o núcleo continua com `Dates` e `Unicode`, e o
# teste de neutralidade continua verificando isso.

using Tables
using JSON3

const M_ING = load_string(Environment(), """
kanon 1

data
  nome  : text !
  preco : money !
  nota  : text

text

: b
{nome} paga {preco}[, com a nota {nota}].
"""; name = "i.kanon")

@testset "ingestão de tabela" begin
    tabela = [(nome = "Ana", preco = Money("10.00", :BRL), nota = nothing),
              (nome = "Bo", preco = Money("20.00", :BRL), nota = "urgente")]

    @testset "um documento por linha" begin
        docs = render_each(M_ING, tabela)
        @test docs == ["Ana paga BRL 10.00.", "Bo paga BRL 20.00, com a nota urgente."]
    end

    @testset "`rows` aceita o que implementa a interface, e recusa o resto" begin
        @test length(rows(tabela)) == 2
        @test rows(Tables.columntable(tabela)) |> length == 2   # orientado a coluna
        @test_throws ArgumentError rows("não é tabela")
    end

    @testset "uma linha de tabela é dados como qualquer outro" begin
        # nenhuma conversão no caminho: a linha responde a `propertynames`, e é o que basta
        @test isempty(check(M_ING, first(rows(tabela))))
        @test render(M_ING, first(rows(tabela))) == "Ana paga BRL 10.00."
    end

    @testset "falha na primeira linha ruim, nomeando qual" begin
        ruim = [(nome = "Ana", preco = Money("1", :BRL), nota = nothing),
                (nome = "Bo", preco = nothing, nota = nothing)]
        e = try; render_each(M_ING, ruim); catch err; err; end
        @test e isa KanonContractError
        d = first(collect(e.diagnostics))
        @test occursin("2º registro da tabela", d.message)
        @test d.code == "K3001"
    end

    @testset "coluna com ponto é o campo do composto (D-052)" begin
        # Uma planilha é plana, e um tipo composto não cabe numa célula. Sem esta regra,
        # nenhuma planilha alcançava tipo composto — e todo tipo de domínio é composto.
        # O ponto é o mesmo separador que o modelo usa em `{preco.amount}`.
        cols = (:nome, Symbol("preco.amount"), Symbol("preco.currency"), :nota)
        plana = [NamedTuple{cols}(("Ana", "10.00", "BRL", missing)),
                 NamedTuple{cols}(("Bo", "20.00", "BRL", "urgente"))]
        @test first(rows(plana))["preco"] == Dict("amount" => "10.00", "currency" => "BRL")
        @test render_each(M_ING, plana) ==
              ["Ana paga BRL 10.00.", "Bo paga BRL 20.00, com a nota urgente."]
        # célula vazia é chave ausente, e não um `missing` que o decodificador recusaria
        @test !haskey(first(rows(plana)), "nota")
    end

    @testset "o grupo todo vazio é o campo ausente; pela metade, a chave que falta" begin
        cols = (:nome, Symbol("preco.amount"), Symbol("preco.currency"))
        vazio = [NamedTuple{cols}(("Ana", missing, missing))]
        e = try; render_each(M_ING, vazio); catch err; err; end
        @test only(collect(e.diagnostics)).code == "K3001"     # `preco` não veio

        metade = [NamedTuple{cols}(("Ana", "10.00", missing))]
        e = try; render_each(M_ING, metade); catch err; err; end
        @test only(collect(e.diagnostics)).code == "K3010"     # veio, e sem moeda
    end

    @testset "a tabela plana passa intacta" begin
        # sem coluna com ponto não há o que aninhar, e a linha segue sendo a da tabela
        @test first(rows(tabela)) === first(tabela)
    end

    @testset "e não devolve metade dos documentos" begin
        # o erro vem antes de qualquer saída: um lote ou sai inteiro, ou não sai
        ruim = [(nome = "Ana", preco = nothing, nota = nothing)]
        @test_throws KanonContractError render_each(M_ING, ruim)
    end
end

@testset "ingestão de JSON" begin
    @testset "o JSON vira dados, e quem decodifica é o contrato" begin
        d = parse_json("""{"nome": "Ana", "preco": {"amount": "10.00", "currency": "BRL"}}""")
        @test d isa Dict{String,Any}
        @test d["preco"] isa Dict          # objeto aninhado vira Dict, não Money
        @test isempty(check(M_ING, d))     # é `check` quem converte, com o tipo declarado
        @test render(M_ING, d) == "Ana paga BRL 10.00."
    end

    @testset "`null` no JSON é o mesmo nulo de sempre (§2.3)" begin
        d = parse_json("""{"nome":"Ana","preco":{"amount":1,"currency":"BRL"},"nota":null}""")
        @test render(M_ING, d) == "Ana paga BRL 1.00."
    end

    @testset "lista no JSON vira vetor" begin
        m = load_string(Environment(), """
kanon 1

data
  xs : number[1..] !

text

: b
São {xs:count}: {xs}.
"""; name = "l.kanon")
        d = parse_json("""{"xs": [1, 2, 3]}""")
        @test d["xs"] isa Vector
        @test render(m, d) == "São 3: 1, 2, 3."
    end

    @testset "o que o JSON traz errado, o contrato recusa nomeando" begin
        d = parse_json("""{"nome": "Ana", "preco": 10}""")
        s = check(M_ING, d)
        @test [x.code for x in s] == ["K3010"]
        @test occursin("currency", s[1].message)
    end

    @testset "read_json lê do disco" begin
        p = tempname()
        write(p, """{"nome":"Ana","preco":{"amount":"5.50","currency":"BRL"}}""")
        @test render(M_ING, read_json(p)) == "Ana paga BRL 5.50."
    end
end

@testset "as extensões não entram no núcleo" begin
    projeto = read(joinpath(@__DIR__, "..", "Project.toml"), String)
    deps = projeto[findfirst("[deps]", projeto)[1]:(findfirst("[weakdeps]", projeto)[1] - 1)]

    @testset "Tables e JSON3 são weakdeps, e não deps" begin
        @test !occursin("Tables", deps) && !occursin("JSON3", deps)
        @test occursin("[weakdeps]", projeto)
        @test occursin("KanonTablesExt = \"Tables\"", projeto)
        @test occursin("KanonJSON3Ext = \"JSON3\"", projeto)
    end

    @testset "e os pontos de extensão existem no núcleo, sem implementação própria" begin
        for f in (rows, render_each, read_json, parse_json)
            @test f isa Function
        end
        # o núcleo declara as funções; quem as implementa é a extensão, quando existe
        @test parentmodule(rows) === Kanon
    end
end
