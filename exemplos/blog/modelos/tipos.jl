# Os dois tipos que o blog acrescenta ao Kanon, escritos como uma camada de terceiro
# escreveria: só com a API pública, por `@kanon_type`.
#
# `autor` é o `site.data.authors[page.author]` do Liquid. Lá, uma chave que não existe
# devolve nada, o `{% if author %}` é falso, e o post sai sem assinatura — em silêncio.
# Aqui a chave passa por `kanon_decode`, que é a única porta de entrada de um valor
# (§3.4): chave desconhecida é erro de contrato, com a lista das que existem.
#
# `chamada` é um post citado por outro — na lista da página inicial e no link da
# tradução. Ela nunca vem do redator: quem a monta é `construir.jl`, e por isso não
# decodifica nada além dela mesma.

module BlogKanon

using Kanon
using Dates: Date

export Autor, Chamada, AUTORES

struct Autor
    chave::String
    nome::String
    iniciais::String
end

"""
Os autores de `conteudo/autores.toml`, carregados por `construir.jl` antes de qualquer
post ser validado. É estado de módulo, e não do ambiente, porque o ambiente guarda
**nomes** e isto é **dado** — o mesmo lugar em que uma camada de domínio guardaria uma
tabela de municípios.
"""
const AUTORES = Dict{String,Autor}()

function autor_de(raw, ctx)
    raw isa Autor && return raw
    raw isa AbstractString ||
        throw(UndecodableValue(Autor, raw, "o autor se escreve pela chave, entre aspas."))
    a = get(AUTORES, strip(raw), nothing)
    a === nothing || return a
    conhecidos = join(("`$(k)`" for k in sort!(collect(keys(AUTORES)))), ", ")
    throw(UndecodableValue(Autor, raw,
        "não há autor `$(raw)` em `conteudo/autores.toml`. Os autores são: $conhecidos."))
end

@kanon_type autor Autor begin
    schema   = (FieldSpec(:nome, :text), FieldSpec(:iniciais, :text))
    default  = (v, ctx) -> v.nome
    decode   = (raw, ctx) -> autor_de(raw, ctx)
end

struct Chamada
    titulo::String
    url::String
    data::Date
    descricao::Union{Nothing,String}
end

@kanon_type chamada Chamada begin
    schema  = (FieldSpec(:titulo, :text), FieldSpec(:url, :text), FieldSpec(:data, :date),
               FieldSpec(:descricao, :text; optional = true))
    default = (v, ctx) -> v.titulo
end

function configure!(b::Kanon.EnvironmentBuilder)
    register_type!(b, Autor)
    register_type!(b, Chamada)
    return b
end

end # module
