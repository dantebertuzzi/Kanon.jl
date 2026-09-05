# Geração da documentação de referência.
#
# Os documentos **normativos** — a especificação, o registro de decisões, a API de
# extensão, a árvore e o roadmap — vivem em `docs/*.md` e não passam por aqui: eles são
# o registro do projeto, escritos para serem lidos no repositório, e uma versão gerada
# deles seria uma segunda cópia a manter em dia.
#
# O que este arquivo gera é a **referência da API**, a partir das docstrings.

using Documenter
using Kanon

makedocs(
    sitename = "Kanon.jl",
    modules = [Kanon],
    authors = "Dante Bertuzzi",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://dantebertuzzi.github.io/Kanon.jl",
    ),
    pages = [
        "Início" => "index.md",
        "Referência" => [
            "Modelo e ambiente" => "referencia/modelo.md",
            "Tipos e extensão" => "referencia/tipos.md",
            "Validação" => "referencia/validacao.md",
            "Renderização" => "referencia/render.md",
            "Ferramentas" => "referencia/ferramentas.md",
        ],
    ],
    checkdocs = :exports,
    warnonly = [:missing_docs],
)

deploydocs(
    repo = "github.com/dantebertuzzi/Kanon.jl.git",
    devbranch = "main",
    push_preview = true,
)
