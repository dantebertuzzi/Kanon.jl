# O gerador de minutas, sem HTTP: as quatro operações que a página pede ao servidor.
#
#   contrato(id)            o JSON Schema do modelo, como `contract` o escreve — e é só dele
#                           que a página monta o formulário
#   previa(id, dados)       a minuta com «marcadores» no que falta, e os problemas campo a campo
#   documento(id, dados, f) a minuta final, em Markdown, texto, Typst ou .docx — ou a recusa
#   exemplo(id)             os dados reais do modelo, para preencher o formulário de uma vez
#
# Nenhuma regra da linguagem mora aqui nem na página (D-029): o formulário sai do checklist,
# a validação é `Kanon.bind`, e a prévia é `preview`. Se a página precisasse decidir que um
# campo é obrigatório por conta própria, a decisão estaria no arquivo errado.

module Minutas

using Dates, TOML
using JSON3                       # carrega a extensão de JSON do Kanon: `parse_json`
using CommonMark
using Kanon, Extenso, KanonLegal, KanonScience

export catalogo, contrato, previa, documento, exemplo, ler_dados

const RAIZ = @__DIR__
const EXEMPLOS = normpath(joinpath(RAIZ, "..", "..", "test", "golden", "exemplos"))
const AMBIENTE = Environment(locale = :pt, domains = [KanonLegal, KanonScience])
const LEITOR = CommonMark.Parser()

struct Entrada
    id::String
    titulo::String
    descricao::String
    modelo::Model
    exemplo::String               # caminho do JSON de exemplo
end

const CATALOGO = Ref{Vector{Entrada}}()

"Os modelos do catálogo, carregados uma vez. Um modelo que não analisa limpo derruba a partida."
function catalogo()
    isassigned(CATALOGO) && return CATALOGO[]
    lido = TOML.parsefile(joinpath(RAIZ, "catalogo.toml"))
    entradas = Entrada[]
    for id in sort!(collect(keys(lido)))
        e = lido[id]
        caminho = joinpath(EXEMPLOS, e["modelo"])
        push!(entradas, Entrada(id, e["titulo"], e["descricao"],
                                load_template(AMBIENTE, caminho), joinpath(EXEMPLOS, e["exemplo"])))
    end
    CATALOGO[] = entradas
end

function entrada(id::AbstractString)
    i = findfirst(e -> e.id == id, catalogo())
    i === nothing ? nothing : catalogo()[i]
end

contrato(e::Entrada) = contract(e.modelo)
exemplo(e::Entrada) = read(e.exemplo, String)

"O corpo de uma requisição, lido pelo mesmo leitor de JSON que a linha de comando usa."
function ler_dados(texto::AbstractString)
    isempty(strip(texto)) && return Dict{String,Any}()
    Kanon.parse_json(texto)
end

"""
Os diagnósticos como a página os consome: o `caminho` do campo (`outorgante[2].nome`),
a mensagem e a dica. A linha do modelo não vai — para quem preenche um formulário, o lugar
do problema é o campo, e não o arquivo que ele não vê.
"""
problemas(set) = [(; caminho = something(d.path, ""), codigo = d.code,
                     mensagem = d.message, dica = something(d.hint, ""),
                     grave = d.severity === :error) for d in Kanon.sorted(set)]

"""
A prévia: o documento com «marcadores» no que ainda falta, e a lista do que falta.

`hoje` é injetado, como em todo o motor: um modelo com `emissao : data = hoje` sai com a
data do servidor, e o teste passa a sua.
"""
function previa(e::Entrada, dados::AbstractDict; hoje::Date = today())
    b = Kanon.bind(e.modelo, dados; today = hoje)
    md = preview(e.modelo, dados; today = hoje, to = Kanon.Markdown())
    (; html = CommonMark.html(LEITOR(md)),
       completo = !Kanon.haserrors(b),
       problemas = problemas(diagnostics(b)))
end

const FORMATOS = Dict("md" => ("text/markdown; charset=utf-8", "md"),
                      "txt" => ("text/plain; charset=utf-8", "txt"),
                      "typ" => ("text/plain; charset=utf-8", "typ"),
                      "docx" => ("application/vnd.openxmlformats-officedocument.wordprocessingml.document", "docx"))

"O pandoc, se houver: `KANON_PANDOC`, ou o do `PATH`. Sem ele, não há `.docx`."
function pandoc()
    p = get(ENV, "KANON_PANDOC", "")
    isempty(p) || return p
    Sys.which("pandoc")
end

"""
A minuta final. Recusa, com os mesmos problemas da prévia, quando o contrato não fecha —
não existe download de documento incompleto, nem como opção (§14).
"""
function documento(e::Entrada, dados::AbstractDict, formato::AbstractString; hoje::Date = today())
    haskey(FORMATOS, formato) || return (; ok = false, problemas = [(; caminho = "", codigo = "",
        mensagem = "o formato `$formato` não existe; os formatos são md, txt, typ e docx.", dica = "", grave = true)])
    b = Kanon.bind(e.modelo, dados; today = hoje)
    Kanon.haserrors(b) && return (; ok = false, problemas = problemas(diagnostics(b)))

    tipo, extensao = FORMATOS[formato]
    nome = "$(e.id).$extensao"
    formato == "txt" && return (; ok = true, tipo, nome, bytes = Vector{UInt8}(render(b)))
    formato == "typ" && return (; ok = true, tipo, nome, bytes = Vector{UInt8}(render(b; to = Kanon.Typst())))
    md = render(b; to = Kanon.Markdown())
    formato == "md" && return (; ok = true, tipo, nome, bytes = Vector{UInt8}(md))

    exe = pandoc()
    exe === nothing && return (; ok = false, problemas = [(; caminho = "", codigo = "",
        mensagem = "o servidor não tem pandoc, e o .docx sai por ele.",
        dica = "Instale o pandoc, ou aponte KANON_PANDOC para ele. O Markdown baixa sem pandoc.", grave = true)])
    mktempdir() do dir
        entrada_md, saida = joinpath(dir, "minuta.md"), joinpath(dir, nome)
        write(entrada_md, md)
        run(`$exe $entrada_md -f commonmark -o $saida`)
        (; ok = true, tipo, nome, bytes = read(saida))
    end
end

end # module
