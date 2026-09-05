@testset "diagnósticos" begin
    @testset "todo código emitido está registrado" begin
        # A construção de `Diagnostic` já afirma isso; aqui garantimos que o registro
        # não tem entrada órfã com título vazio.
        @test all(!isempty, values(CODE_TITLES))
        @test all(c -> occursin(r"^K[0-9]{4}$", c), keys(CODE_TITLES))
    end

    @testset "todo código registrado é emitido em algum lugar" begin
        # A recíproca do teste acima, e a que ninguém escreve: o construtor de
        # `Diagnostic` garante que nada saia sem registro, e **nada garantia que o
        # registro não tivesse peso morto**.
        #
        # Um código que nunca erra é pior que inútil. Ele engorda a tabela, dá a impressão
        # de que o motor distingue um caso que ele não distingue, e a primeira pessoa a
        # escrever uma ferramenta contra ele descobre que a condição nunca acontece. Pior:
        # o `K4003` estava registrado, era o código certo para o teto de profundidade de
        # inclusão, e o sítio emitia o do vizinho — o registro estava certo e o código
        # estava errado, que é a forma de defeito que só esta direção do teste encontra.
        #
        # Vale mais que cobertura de linha aqui: nenhum dos defeitos que os cinco modelos
        # reais acharam era linha descoberta. Este é.
        raiz = normpath(joinpath(@__DIR__, ".."))
        registro = joinpath(raiz, "src", "diagnostics.jl")

        fontes = String[]
        for sub in ("src", "lib", "ext")
            dir = joinpath(raiz, sub)
            isdir(dir) || continue
            for (d, _, arquivos) in walkdir(dir), a in arquivos
                endswith(a, ".jl") || continue
                caminho = joinpath(d, a)
                caminho == registro && continue          # o registro não conta como uso
                push!(fontes, read(caminho, String))
            end
        end
        todo = join(fontes, "\n")

        orfaos = sort([c for c in keys(CODE_TITLES) if !occursin("\"" * c * "\"", todo)])
        isempty(orfaos) ||
            error("códigos registrados que nenhuma linha de `src/` ou `lib/` emite: " *
                  join(orfaos, ", ") *
                  ".\nOu dê uso a eles, ou tire-os do registro — um código que nunca " *
                  "erra é um código a menos.")
        @test isempty(orfaos)
    end

    @testset "acumula todos os problemas, não só o primeiro" begin
        cs = codes("""
kanon 1

data
  a text !
  b : person[x]
  c : text ! = "x"

text

: bloco
{price
{v:round:written}
""")
        @test "K1101" in cs
        @test "K1102" in cs
        @test "K1103" in cs
        @test "K1203" in cs
        @test "K1206" in cs
        @test length(cs) >= 5
    end

    @testset "ordem determinística: arquivo, linha, coluna, código" begin
        d = diags("""
kanon 1

text

: b
{v:round:written}
{price
""")
        ls = [x.line for x in d]
        @test issorted(ls)
    end

    @testset "toda mensagem nomeia linha e coluna" begin
        d = diags(withtext("{v:round:written}"))
        @test all(x -> x.line > 0 && x.col > 0, d)
    end

    @testset "o formato é o da especificação §10.4" begin
        out = format_diagnostics(diags(withtext("{v:round(2)}")))
        @test occursin("1 problema encontrado", out)
        @test occursin("[K1207]", out)
        @test occursin("sintaxe,", out)
        @test occursin("linha 6", out)
    end

    @testset "vocabulário de redator, não de implementação" begin
        out = format_diagnostics(diags(withtext("{price")))
        for banido in ("AST", "token", "MethodError", "Val{", "nothing", "Symbol")
            @test !occursin(banido, out)
        end
    end
end
