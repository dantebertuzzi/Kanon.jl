# Geração da documentação de referência.
#
# Os documentos **normativos** — a especificação, o registro de decisões, a API de
# extensão, a árvore e o roadmap — vivem em `docs/*.md` e não passam por aqui: eles são
# o registro do projeto, escritos para serem lidos no repositório, e uma versão gerada
# deles seria uma segunda cópia a manter em dia.
#
# O que este arquivo gera é a **referência da API**, a partir das docstrings, e a visão
# geral. As duas em inglês (D-083); a visão geral em português fica em `pt.md`.

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
        "Overview" => "index.md",
        "Visão geral (pt)" => "pt.md",
        "Reference" => [
            "Templates and environments" => "referencia/modelo.md",
            "Types and extension" => "referencia/tipos.md",
            "Validation" => "referencia/validacao.md",
            "Rendering" => "referencia/render.md",
            "Tools" => "referencia/ferramentas.md",
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
