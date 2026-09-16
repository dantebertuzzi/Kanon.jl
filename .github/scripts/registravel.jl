# O que o General vai conferir num `Project.toml`, conferido antes dele — e no arquivo
# commitado, antes de qualquer `Pkg.develop` da suíte.
#
# Existe por um vazamento: o CI desenvolve as camadas dentro do projeto de cada uma para
# rodar a suíte, o `Pkg.develop` as escreve em `[deps]`, e uma cópia assim foi commitada.
# A `KanonScience`, que se anuncia sem idioma, passou a depender do `Extenso`; a
# `KanonLegal`, da `KanonScience`. Nenhum código usava nenhuma das duas, e a ordem de
# registro que o roadmap escreveu a partir delas estava errada.
#
# Três regras por pacote:
#   1. toda dependência fora da biblioteca padrão tem `[compat]` — deps, weakdeps e extras;
#   2. toda dependência de `[deps]` é usada pelo código em `src/`;
#   3. todo pacote que `src/` usa está em `[deps]`.
#
# Roda com `julia .github/scripts/registravel.jl`, sem ambiente nenhum: só `TOML`.

using TOML

const PACOTES = [".", "lib/Extenso", "lib/KanonScience", "lib/KanonLegal", "lib/KanonLSP"]
const RAIZ = normpath(joinpath(@__DIR__, "..", ".."))

eh_stdlib(nome) = isdir(joinpath(Sys.STDLIB, nome))

"""
Os pacotes que os arquivos de `dir` carregam com `using`/`import`. O que está dentro de uma
docstring não conta: o exemplo `using Kanon, Extenso, KanonLegal, KanonLSP` do servidor de
linguagem é o que o usuário escreve, e não o que o pacote carrega.
"""
function usados(dir)
    out = Set{String}()
    isdir(dir) || return out
    for (raiz, _, arquivos) in walkdir(dir), a in arquivos
        endswith(a, ".jl") || continue
        em_docstring = false
        for linha in eachline(joinpath(raiz, a))
            isodd(count("\"\"\"", linha)) && (em_docstring = !em_docstring; continue)
            em_docstring && continue
            m = match(r"^\s*(?:using|import)\s+([^\.:\s][^:]*)", linha)
            m === nothing && continue
            for parte in split(m.captures[1], ',')
                nome = first(split(strip(parte), '.'))
                isempty(nome) || push!(out, nome)
            end
        end
    end
    out
end

falhas = String[]
for p in PACOTES
    t = TOML.parsefile(joinpath(RAIZ, p, "Project.toml"))
    nome = t["name"]
    compat = keys(get(t, "compat", Dict()))
    deps = Set(keys(get(t, "deps", Dict())))

    for secao in ("deps", "weakdeps", "extras"), d in keys(get(t, secao, Dict()))
        eh_stdlib(d) || d in compat ||
            push!(falhas, "$nome: `$d` está em [$secao] sem [compat]")
    end

    uso = setdiff(usados(joinpath(RAIZ, p, "src")), ("Base", "Core", nome))
    for d in sort!(collect(setdiff(deps, uso)))
        push!(falhas, "$nome: `$d` está em [deps] e nenhum arquivo de src/ o usa — dependência só de teste vai em [extras]")
    end
    for d in sort!(collect(setdiff(uso, deps)))
        push!(falhas, "$nome: src/ usa `$d`, que não está em [deps]")
    end
end

if isempty(falhas)
    println("os cinco Project.toml estão prontos para o registro")
else
    foreach(f -> println(stderr, "✗ ", f), falhas)
    exit(1)
end
