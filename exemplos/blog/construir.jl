# Transforma `conteudo/` em site.
#
#     julia --project construir.jl           publica: tudo validado, rascunhos de fora
#     julia --project construir.jl servir    pré-visualiza: rascunhos entram, com «marcadores»
#
# O caminho de uma página, e por que cada passo está onde está:
#
#   1. O cabeçalho do redator é **TOML**, lido por `TOML.jl`, e nunca o bloco `+++` do
#      Franklin — que é código Julia avaliado: `data = 2026-05-06` sem aspas vira o
#      número 2015, calado, e um `$` num título executa código.
#   2. O Kanon valida o cabeçalho contra o modelo da página. Campo obrigatório faltando,
#      autor que não existe, data que não é data, campo com nome errado: o site não é
#      construído, e o redator lê o que corrigir.
#   3. O Kanon escreve o cabeçalho e o rodapé em Markdown **CommonMark**, e o CommonMark.jl
#      o converte em HTML. Não vai como Markdown para o Franklin: o dialeto dele não é o
#      CommonMark — `\[` abre matemática e dois `$` no mesmo parágrafo viram fórmula —,
#      e o escape que o Kanon garante é o do CommonMark.
#   4. O corpo, que o redator escreveu, vai intacto para o Franklin, entre os dois blocos
#      de HTML. É Markdown do Franklin, com `$...$` para matemática.

using Dates, TOML
using Kanon, Extenso      # `bind` se escreve `Kanon.bind`: o `Base` também exporta um (D-078)
using CommonMark
import Franklin

include(joinpath(@__DIR__, "modelos", "tipos.jl"))
using .BlogKanon

const RAIZ = @__DIR__
const CONTEUDO = joinpath(RAIZ, "conteudo")
const SITE = RAIZ

"A pasta de conteúdo desta construção — `conteudo/`, ou uma cópia, no teste."
const CONTEUDO_EM_USO = Ref(CONTEUDO)

const ENV_PT = Environment(locale = :pt, domains = [BlogKanon])
const ENV_EN = Environment(domains = [BlogKanon])

"As chaves do cabeçalho que são do site, e não do contrato de nenhum modelo."
const CHAVES_DO_SITE = ("idioma", "rascunho", "ref")

const MARCA_DO_CORPO = "<!-- corpo -->"

# --- o que pode dar errado, dito para quem escreve -----------------------------

struct Problema
    arquivo::String
    mensagem::String
    dica::Union{Nothing,String}
    grave::Bool
end

Problema(arquivo, mensagem; dica = nothing, grave = true) =
    Problema(arquivo, mensagem, dica, grave)

relativo(caminho) = relpath(caminho, dirname(CONTEUDO_EM_USO[]))

function relatar(io::IO, problemas::Vector{Problema})
    for arquivo in unique(p.arquivo for p in problemas)
        println(io, "\n", arquivo)
        for p in problemas
            p.arquivo == arquivo || continue
            println(io, "  ", p.grave ? "✗ " : "! ", p.mensagem)
            p.dica === nothing || println(io, "    ", p.dica)
        end
    end
end

# --- 1. o arquivo do redator ---------------------------------------------------

struct Pagina
    arquivo::String                 # relativo à raiz do blog
    cabecalho::Dict{String,Any}
    corpo::String
    linhas_antes::Int               # para citar a linha do corpo como o editor a vê
end

"""
Separa o cabeçalho TOML do corpo. O cabeçalho abre e fecha com uma linha `+++`, como no
Hugo; o que vem depois é do Franklin.
"""
function ler_pagina(caminho::AbstractString, problemas::Vector{Problema})
    arq = relativo(caminho)
    linhas = split(replace(read(caminho, String), "\r\n" => "\n"), '\n')
    if isempty(linhas) || strip(linhas[1]) != "+++"
        push!(problemas, Problema(arq, "o arquivo não começa pelo cabeçalho.";
            dica = "A primeira linha é `+++`, depois vêm os campos (`titulo = \"...\"`), " *
                   "e outra linha `+++` fecha o cabeçalho."))
        return nothing
    end
    fim = findnext(l -> strip(l) == "+++", linhas, 2)
    if fim === nothing
        push!(problemas, Problema(arq, "o cabeçalho abre com `+++` na linha 1 e não fecha.";
            dica = "Escreva outra linha só com `+++` depois do último campo."))
        return nothing
    end
    lido = TOML.tryparse(join(linhas[2:(fim - 1)], '\n'))
    if lido isa TOML.ParserError
        push!(problemas, Problema(arq,
            "a linha $(lido.line + 1) do arquivo não pôde ser lida ($(explicar_toml(lido))).";
            dica = "Texto vai entre aspas (`titulo = \"Média\"`); data e número, sem aspas " *
                   "(`data = 2026-05-06`); lista entre colchetes (`tags = [\"a\", \"b\"]`)."))
        return nothing
    end
    Pagina(arq, lido, join(linhas[(fim + 1):end], '\n'), fim)
end

"O erro do TOML, em uma frase — o texto dele é inglês e aponta coluna, não o que fazer."
function explicar_toml(e)
    t = string(e.type)
    occursin("UnexpectedStartOfValue", t) && return "um valor sem aspas que não é número, data nem lista"
    occursin("DuplicateKey", t) && return "o mesmo campo aparece duas vezes"
    occursin("ExpectedEqualAfterKey", t) && return "falta o `=` depois do nome do campo"
    occursin("UnterminatedString", t) && return "as aspas abrem e não fecham"
    occursin("InvalidBareKeyCharacter", t) &&
        return "o nome do campo tem acento, espaço ou outro caractere que não vale ali: " *
               "os nomes são sem acento, como `descricao` e `titulo`"
    return lowercase(replace(t, "Err" => ""))
end

# --- 2. o contrato -------------------------------------------------------------

"O que o cabeçalho diz ao site — idioma, rascunho, tradução — conferido aqui mesmo."
function chaves_do_site(p::Pagina, problemas::Vector{Problema})
    idioma = get(p.cabecalho, "idioma", "pt")
    if !(idioma in ("pt", "en"))
        push!(problemas, Problema(p.arquivo, "`idioma = $(repr(idioma))` não é um idioma deste site.";
            dica = "Escreva `idioma = \"pt\"` ou `idioma = \"en\"`, ou tire a linha: o padrão é português."))
        idioma = "pt"
    end
    rascunho = get(p.cabecalho, "rascunho", false)
    if !(rascunho isa Bool)
        push!(problemas, Problema(p.arquivo, "`rascunho` é `true` ou `false`, sem aspas."))
        rascunho = true
    end
    ref = get(p.cabecalho, "ref", nothing)
    if ref !== nothing && !(ref isa String)
        push!(problemas, Problema(p.arquivo, "`ref` é um texto entre aspas, igual nas duas traduções."))
        ref = nothing
    end
    if haskey(p.cabecalho, "traducao")
        push!(problemas, Problema(p.arquivo, "`traducao` não se escreve: o site a encontra pelo `ref`.";
            dica = "Dê o mesmo `ref = \"...\"` a este post e ao outro idioma dele."))
    end
    (; idioma, rascunho, ref)
end

"""
O cifrão de dinheiro no corpo. No Markdown do Franklin, `\$` abre matemática: `R\$ 3.000 e
R\$ 4.000` no mesmo parágrafo vira uma fórmula, sem erro nenhum, e um cifrão sozinho
derruba a página inteira. O que o redator quer quase sempre é dinheiro, e a correção é
uma contrabarra.
"""
function conferir_cifrao!(problemas::Vector{Problema}, p::Pagina)
    for (i, linha) in enumerate(split(p.corpo, '\n'))
        # As alternativas vão inteiras, e não como prefixo de um `$` que vem depois:
        # `(R|US|U\$S)?\$` nunca casava `U$S`, porque o cifrão dele é o do meio.
        for m in eachmatch(r"(?<![\\\w])(?:(?:R|US)?\$|U\$S)(?=\s?\d)", linha)
            push!(problemas, Problema(p.arquivo,
                "o corpo tem `$(m.match)` seguido de número na linha $(i + p.linhas_antes): " *
                "no Franklin, `\$` abre uma fórmula.";
                dica = "Para dinheiro, escreva com contrabarra: `R\\\$ 3.000`. Para matemática, " *
                       "a fórmula não começa por número — `\$x = 3\$`."))
            break
        end
    end
end

dados_do_contrato(p::Pagina) =
    Dict{String,Any}(k => v for (k, v) in p.cabecalho if !(k in CHAVES_DO_SITE))

"""
Os diagnósticos do Kanon, ditos pelo arquivo do redator.

A linha que o Kanon cita num erro de contrato é a do **modelo** (D-050) — certo para quem
escreve modelos, e ruído para quem escreveu o post. O que serve aqui é a mensagem e a dica.

E um campo que o contrato não declara (`K3021`) é aviso no Kanon e **erro** neste site: o
Kanon ignora o campo, e `descricão`, com til, é justamente a `descricao` que o redator
queria escrever — publicar assim é publicar sem a descrição, em silêncio, que é o que o
Liquid faria.
"""
function do_kanon!(problemas::Vector{Problema}, arquivo::String, set; rascunho::Bool = false)
    for d in Kanon.sorted(set)
        rascunho && d.code in AUSENCIA && continue
        grave = !rascunho && (d.severity === :error || d.code == "K3021")
        push!(problemas, Problema(arquivo, d.message; dica = d.hint, grave))
    end
end

"""
O que, num rascunho, é o normal: o campo que **ainda não foi escrito**. É para isso que o
rascunho serve, e dizê-lo a cada construção seria ruído.

O que está **errado** é outra coisa, e ficava calado: um `data = "ontem"` saía na
pré-visualização como «data», idêntico ao campo que ninguém escreveu ainda, e o redator
lia "falta preencher" onde havia um valor recusado — só descobria ao tirar o `rascunho`.
Agora sai como aviso, que não impede o site.
"""
const AUSENCIA = ("K3001", "K3004")

# --- 3. o HTML que o Kanon escreve ---------------------------------------------

const LEITOR = CommonMark.Parser()

"O documento do Kanon, em HTML, cortado onde o corpo do redator entra."
function em_volta_do_corpo(markdown::AbstractString, modelo::AbstractString)
    html = CommonMark.html(LEITOR(markdown))
    partes = split(html, MARCA_DO_CORPO)
    length(partes) == 2 ||
        error("o modelo `$modelo` precisa ter exatamente um `$MARCA_DO_CORPO`; tem $(length(partes) - 1).")
    (strip(partes[1]), strip(partes[2]))
end

"""
A página que o Franklin lê. O `+++` dele é código Julia, e por isso nada do redator entra
ali sem `repr`: o título vira um literal de texto, com `\$` escapado.
"""
function pagina_franklin(; titulo, idioma, antes, corpo, depois, classe)
    """
    +++
    title = $(repr(String(titulo)))
    lang = $(repr(idioma))
    classe = $(repr(classe))
    +++

    ~~~
    <header class="cabecalho">
    $antes
    </header>
    <div class="corpo">
    ~~~

    $corpo

    ~~~
    </div>
    <footer class="fecho">
    $depois
    </footer>
    ~~~
    """
end

# --- os posts ------------------------------------------------------------------

const PADRAO_DE_POST = r"^(\d{4})-(\d{2})-(\d{2})-([a-z0-9]+(?:-[a-z0-9]+)*)\.md$"

struct Post
    pagina::Pagina
    slug::String
    idioma::String
    rascunho::Bool
    ref::Union{Nothing,String}
end

url_de(post::Post) = "/posts/$(post.slug)/"

function ler_posts(problemas::Vector{Problema})
    posts = Post[]
    dir = joinpath(CONTEUDO_EM_USO[], "posts")
    for nome in sort(readdir(dir))
        endswith(nome, ".md") || continue
        caminho = joinpath(dir, nome)
        m = match(PADRAO_DE_POST, nome)
        if m === nothing
            push!(problemas, Problema(relativo(caminho), "o nome do arquivo não segue o padrão dos posts.";
                dica = "Escreva `AAAA-MM-DD-titulo-curto.md`, só com minúsculas, números e hífen: " *
                       "`2026-05-06-desvio-padrao.md`."))
            continue
        end
        p = ler_pagina(caminho, problemas)
        p === nothing && continue
        conferir_cifrao!(problemas, p)
        conferir_imagem!(problemas, p)
        s = chaves_do_site(p, problemas)

        # a data do nome do arquivo e a do cabeçalho dizem a mesma coisa
        data = get(p.cabecalho, "data", nothing)
        do_nome = tryparse(Date, "$(m[1])-$(m[2])-$(m[3])")
        if data isa Date && do_nome !== nothing && data != do_nome
            push!(problemas, Problema(p.arquivo,
                "o nome do arquivo diz $(do_nome) e o cabeçalho diz `data = $(data)`.";
                dica = "As duas datas são a data de publicação: corrija a que está errada."))
        end
        push!(posts, Post(p, m[4], s.idioma, s.rascunho, s.ref))
    end

    # dois posts não publicam no mesmo endereço
    for slug in unique(p.slug for p in posts)
        iguais = filter(p -> p.slug == slug, posts)
        length(iguais) > 1 || continue
        for p in iguais
            push!(problemas, Problema(p.pagina.arquivo,
                "outro post também publica em `/posts/$slug/`: " *
                join((q.pagina.arquivo for q in iguais if q !== p), ", ") * "."))
        end
    end
    posts
end

modelo_do_post(idioma) = idioma == "en" ?
    load_template(ENV_EN, joinpath(RAIZ, "modelos", "post-en.kanon")) :
    load_template(ENV_PT, joinpath(RAIZ, "modelos", "post.kanon"))

texto_ou_nada(x) = x isa AbstractString && !isempty(strip(x)) ? String(x) : nothing

chamada_de(post::Post) = Chamada(post.pagina.cabecalho["titulo"], url_de(post),
                                 post.pagina.cabecalho["data"],
                                 texto_ou_nada(get(post.pagina.cabecalho, "descricao", nothing)))

# --- a página inicial: os cards ------------------------------------------------

"Quantos cards aparecem antes do botão, e quantos cada clique mostra."
const CARDS_VISIVEIS = 3

"""
O resumo do card: a `descricao`, se o post tem uma; senão, as primeiras 20 palavras do
primeiro parágrafo do corpo, sem a marcação. É o `strip_html | truncatewords: 20` do
Liquid — e mora aqui porque o Kanon não encadeia formatadores (D-007) nem calcula nada.
"""
function resumo_de(post::Post)
    d = texto_ou_nada(get(post.pagina.cabecalho, "descricao", nothing))
    d === nothing || return d
    paragrafo = something(findfirst(p -> !isempty(strip(p)) && !startswith(strip(p), r"[#|$<!-]"),
                                    split(post.pagina.corpo, r"\n\s*\n")), 0)
    paragrafo == 0 && return "(sem resumo)"
    texto = split(post.pagina.corpo, r"\n\s*\n")[paragrafo]
    texto = replace(texto, r"\$\$?[^$]*\$\$?" => "…", r"[*_`]" => "", r"\[([^\]]*)\]\([^)]*\)" => s"\1",
                    r"\\\$" => "\$", r"\s+" => " ")
    palavras = split(strip(texto))
    length(palavras) <= 20 ? join(palavras, " ") : join(palavras[1:20], " ") * "…"
end

"""
Os cards, cada um um documento de `cartao.kanon`. O que o Liquid decidia com `forloop` —
qual é o mais novo, quais começam escondidos — é decidido aqui, e chega ao modelo como
dado (`novo`) ou à moldura como classe (`post-oculto`).

A moldura é HTML da casca, e não tem valor nenhum dentro: o que vem do redator passou
pelo Kanon e pelo CommonMark, que escapam o texto e o `alt` da imagem.
"""
function cards(publicados::Vector{Post}, modelo)
    io = IOBuffer()
    println(io, """<div class="cards" data-por-clique="$CARDS_VISIVEIS">""")
    for (i, post) in enumerate(publicados)
        c = post.pagina.cabecalho
        dados = Dict{String,Any}("titulo" => c["titulo"], "url" => url_de(post), "data" => c["data"],
                                 "resumo" => resumo_de(post), "novo" => i == 1)
        imagem = texto_ou_nada(get(c, "imagem", nothing))
        imagem === nothing || (dados["imagem"] = imagem)
        html = CommonMark.html(LEITOR(render(modelo, dados; to = Kanon.Markdown())))
        oculto = i > CARDS_VISIVEIS ? " post-oculto" : ""
        println(io, """<article class="card$oculto">""", html, "</article>")
    end
    println(io, "</div>")
    if length(publicados) > CARDS_VISIVEIS
        # escondido até o script existir: sem JavaScript, todos os cards ficam à vista
        println(io, """<p class="mais"><button type="button" id="mostrar-mais" hidden>Mostrar mais</button></p>""")
    end
    String(take!(io))
end

"""
A imagem de um post é um arquivo de `_assets/`, escrito como `/assets/...`. Conferido
aqui porque o Kanon valida o tipo — é texto — e não o que o texto aponta: um nome de
arquivo digitado errado publicaria a imagem quebrada, e `javascript:...` passaria inteiro.
"""
function conferir_imagem!(problemas::Vector{Problema}, p::Pagina)
    img = get(p.cabecalho, "imagem", nothing)
    img isa AbstractString || return nothing
    if !startswith(img, "/assets/")
        push!(problemas, Problema(p.arquivo, "`imagem = $(repr(img))` não é uma imagem deste site.";
            dica = "Ponha o arquivo em `_assets/imagens/` e escreva `imagem = \"/assets/imagens/nome.svg\"`."))
    elseif !isfile(joinpath(SITE, "_assets", img[length("/assets/") + 1:end]))
        push!(problemas, Problema(p.arquivo, "a imagem `$img` não existe.";
            dica = "O arquivo fica em `_assets/$(img[length("/assets/") + 1:end])`. Confira o nome, com a extensão."))
    end
    nothing
end

# --- a construção --------------------------------------------------------------

"""
    construir(; servir = false, conteudo = CONTEUDO, escrever = true, io = stdout)

Valida `conteudo` e gera as páginas do Franklin. Devolve `(; ok, paginas, problemas)`:
`teste.jl` constrói cópias de `conteudo/` com defeitos plantados e confere o que o
redator leria, sem escrever nada (`escrever = false`).
"""
function construir(; servir::Bool = false, conteudo::AbstractString = CONTEUDO,
                   escrever::Bool = true, io::IO = stdout)
    CONTEUDO_EM_USO[] = conteudo
    problemas = Problema[]

    autores = TOML.tryparse(read(joinpath(CONTEUDO_EM_USO[], "autores.toml"), String))
    if autores isa TOML.ParserError
        push!(problemas, Problema("conteudo/autores.toml",
            "a linha $(autores.line) não pôde ser lida ($(explicar_toml(autores)))."))
        relatar(io, problemas)
        return (; ok = false, paginas = Dict{String,String}(), problemas)
    end
    empty!(AUTORES)
    for (chave, a) in autores
        if !(a isa AbstractDict && get(a, "nome", nothing) isa String && get(a, "iniciais", nothing) isa String)
            push!(problemas, Problema("conteudo/autores.toml",
                "o autor `$chave` precisa de `nome` e `iniciais`, os dois entre aspas."))
            continue
        end
        AUTORES[chave] = Autor(chave, a["nome"], a["iniciais"])
    end

    modelos = Dict("pt" => modelo_do_post("pt"), "en" => modelo_do_post("en"))
    posts = ler_posts(problemas)

    # Primeira passada: o contrato de cada post, sem a tradução, que depende dos outros.
    # Publicar deixa os rascunhos de fora; servir os valida como pré-visualização.
    validos = Post[]
    for post in posts
        post.rascunho && !servir && continue
        b = Kanon.bind(modelos[post.idioma], dados_do_contrato(post.pagina))
        if post.rascunho
            do_kanon!(problemas, post.pagina.arquivo, diagnostics(b); rascunho = true)
            push!(validos, post)
            continue
        end
        antes = length(problemas)
        do_kanon!(problemas, post.pagina.arquivo, diagnostics(b))
        any(p -> p.grave, problemas[(antes + 1):end]) || push!(validos, post)
    end

    # Segunda passada: a tradução é o post de mesmo `ref` no outro idioma.
    paginas = Dict{String,String}()
    for post in validos
        dados = dados_do_contrato(post.pagina)
        if post.ref !== nothing
            outros = filter(q -> q.ref == post.ref && q.idioma != post.idioma && !q.rascunho, validos)
            length(outros) == 1 && (dados["traducao"] = chamada_de(outros[1]))
            if length(outros) > 1
                push!(problemas, Problema(post.pagina.arquivo,
                    "o `ref = $(repr(post.ref))` aparece em mais de um post no outro idioma."))
            end
        end
        modelo = modelos[post.idioma]
        md = post.rascunho ? preview(modelo, dados; to = Kanon.Markdown()) :
                             render(modelo, dados; to = Kanon.Markdown())
        antes, depois = em_volta_do_corpo(md, "post")
        titulo = get(post.pagina.cabecalho, "titulo", "(sem título)")
        paginas["posts/$(post.slug).md"] = pagina_franklin(; titulo, idioma = post.idioma,
            antes, corpo = post.pagina.corpo, depois, classe = "post")
    end

    # As páginas simples: tudo o que está na raiz de `conteudo/`, menos a inicial.
    modelo_pagina = load_template(ENV_PT, joinpath(RAIZ, "modelos", "pagina.kanon"))
    for nome in sort(readdir(CONTEUDO_EM_USO[]))
        (endswith(nome, ".md") && nome != "inicio.md") || continue
        p = ler_pagina(joinpath(CONTEUDO_EM_USO[], nome), problemas)
        p === nothing && continue
        conferir_cifrao!(problemas, p)
        b = Kanon.bind(modelo_pagina, p.cabecalho)
        n = length(problemas)
        do_kanon!(problemas, p.arquivo, diagnostics(b))
        any(q -> q.grave, problemas[(n + 1):end]) && continue
        antes, depois = em_volta_do_corpo(render(b; to = Kanon.Markdown()), "pagina")
        paginas[nome] = pagina_franklin(; titulo = p.cabecalho["titulo"], idioma = "pt",
            antes, corpo = p.corpo, depois, classe = "pagina")
    end

    # A inicial: a apresentação do redator e os posts em português, do mais novo ao mais antigo.
    inicio = ler_pagina(joinpath(CONTEUDO_EM_USO[], "inicio.md"), problemas)
    if inicio !== nothing
        conferir_cifrao!(problemas, inicio)
        publicados = sort(filter(p -> p.idioma == "pt" && !p.rascunho, validos);
                          by = p -> p.pagina.cabecalho["data"], rev = true)
        dados = merge(inicio.cabecalho, Dict{String,Any}("posts" => chamada_de.(publicados)))
        modelo_inicio = load_template(ENV_PT, joinpath(RAIZ, "modelos", "inicio.kanon"))
        b = Kanon.bind(modelo_inicio, dados)
        n = length(problemas)
        do_kanon!(problemas, inicio.arquivo, diagnostics(b))
        if !any(q -> q.grave, problemas[(n + 1):end])
            antes, depois = em_volta_do_corpo(render(b; to = Kanon.Markdown()), "inicio")
            modelo_cartao = load_template(ENV_PT, joinpath(RAIZ, "modelos", "cartao.kanon"))
            partes = split(depois, "<!-- cartoes -->")
            length(partes) == 2 || error("o modelo `inicio` precisa ter exatamente um `<!-- cartoes -->`.")
            depois = partes[1] * cards(publicados, modelo_cartao) * partes[2]
            paginas["index.md"] = pagina_franklin(; titulo = inicio.cabecalho["titulo"],
                idioma = "pt", antes, corpo = inicio.corpo, depois, classe = "inicio")
        end
    end

    relatar(io, problemas)
    graves = count(p -> p.grave, problemas)
    if graves > 0
        println(io, "\nO site não foi construído: ", graves == 1 ? "1 problema" : "$graves problemas",
                " para corrigir.")
        return (; ok = false, paginas, problemas)
    end

    escrever && escrever_paginas(paginas)
    rascunhos = count(p -> p.rascunho, validos)
    println(io, "\n", length(paginas), " páginas geradas",
            rascunhos > 0 ? " (com $rascunhos rascunho(s) em pré-visualização)" : "", ".")
    return (; ok = true, paginas, problemas)
end

"""
Troca as páginas geradas pelas novas. São só estas — `index.md`, as páginas simples e
`posts/` —, e nenhuma é editada à mão: o que o redator escreve está em `conteudo/`.
"""
function escrever_paginas(paginas::Dict{String,String})
    rm(joinpath(SITE, "posts"); force = true, recursive = true)
    for nome in readdir(SITE)
        endswith(nome, ".md") && !(nome in ("config.md", "404.md", "LEIA-ME.md")) &&
            rm(joinpath(SITE, nome))
    end
    for (destino, texto) in paginas
        caminho = joinpath(SITE, destino)
        mkpath(dirname(caminho))
        write(caminho, texto)
    end
end

"""
Reconstrói quando algo em `conteudo/` muda. O Franklin vigia a pasta dele, e não esta: sem
isto, o redator salvaria o post e continuaria vendo a versão velha. A comparação é pela data
de modificação, a cada segundo — portátil, e barata para algumas dezenas de arquivos.
"""
function vigiar_conteudo()
    marca() = maximum((mtime(joinpath(r, a)) for (r, _, as) in walkdir(CONTEUDO) for a in as); init = 0.0)
    ultima = marca()
    @async while true
        sleep(1)
        agora = marca()
        agora == ultima && continue
        ultima = agora
        println("\n", Dates.format(now(), "HH:MM:SS"), " — conteudo/ mudou; construindo de novo.")
        construir(; servir = true)
    end
end

function main(args)
    servir = "servir" in args
    construir(; servir).ok || exit(1)
    cd(SITE) do
        if servir
            vigiar_conteudo()
            Franklin.serve(; clear = true)
        else
            prepath = get(ENV, "PREPATH", "")
            ok = Franklin.optimize(; prerender = false, minify = false, clear = true,
                                   suppress_errors = false, prepath)
            ok === false && exit(1)
            println("Site em __site/.")
        end
    end
end

abspath(PROGRAM_FILE) == @__FILE__() && main(ARGS)
