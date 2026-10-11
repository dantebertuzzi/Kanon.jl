# Os exemplos do README rodam.
#
# O README é a primeira coisa que alguém executa, e um exemplo que falha ali custa mais
# que qualquer defeito escondido no motor. Este teste extrai os blocos cercados do
# README, grava-os numa pasta descartável e os executa no núcleo, sem camada nenhuma.
#
# A convenção é pequena:
#
# - um bloco ```kanon precisa carregar num `Environment()` vazio. Se a linha logo acima
#   for `<!-- file: nome.kanon -->`, ele também é gravado com esse nome na pasta;
# - os blocos ```julia rodam em ordem, num mesmo módulo, com a pasta como diretório
#   corrente — o segundo enxerga o que o primeiro definiu;
# - `<!-- no-test -->` logo acima de um bloco o deixa de fora. Serve para trechos que
#   mostram a forma de uma coisa e não são programa, como a assinatura de um método.
#
# Blocos sem linguagem (saída de terminal, linhas de comando) não são executados.

"Os blocos cercados de `md`, com a linguagem e a linha de marcação logo acima."
function fenced_blocks(md::AbstractString)
    linhas = split(md, '\n')
    blocos = NamedTuple{(:lang, :code, :mark, :line),Tuple{String,String,String,Int}}[]
    i = 1
    while i <= length(linhas)
        m = match(r"^```(\w*)\s*$", linhas[i])
        if m === nothing
            i += 1
            continue
        end
        inicio = i
        marca = ""
        for j in i-1:-1:1
            isempty(strip(linhas[j])) && continue
            startswith(strip(linhas[j]), "<!--") && (marca = strip(linhas[j]))
            break
        end
        j = i + 1
        while j <= length(linhas) && !startswith(linhas[j], "```")
            j += 1
        end
        push!(blocos, (lang = String(m.captures[1]), code = join(linhas[i+1:j-1], "\n") * "\n",
                       mark = String(marca), line = inicio))
        i = j + 1
    end
    blocos
end

@testset "README: os exemplos rodam" begin
    readme = read(joinpath(@__DIR__, "..", "README.md"), String)
    blocos = filter(b -> b.mark != "<!-- no-test -->", fenced_blocks(readme))
    dir = mktempdir()

    @testset "há o que testar" begin
        @test any(b -> b.lang == "kanon", blocos)
        @test any(b -> b.lang == "julia", blocos)
    end

    for b in filter(b -> b.lang == "kanon", blocos)
        @testset "bloco kanon da linha $(b.line) carrega no núcleo" begin
            @test load_string(Environment(), b.code; name = "README:$(b.line)") isa Model
        end
        arquivo = match(r"^<!-- file: (\S+) -->$", b.mark)
        arquivo === nothing || write(joinpath(dir, arquivo.captures[1]), b.code)
    end

    sandbox = Module(:ReadmeSandbox)
    Core.eval(sandbox, :(using Kanon, Dates))
    cd(dir) do
        for b in filter(b -> b.lang == "julia", blocos)
            @testset "bloco julia da linha $(b.line) roda" begin
                @test (include_string(sandbox, b.code, "README.md:$(b.line)"); true)
            end
        end
    end
end
