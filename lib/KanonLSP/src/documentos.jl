# O que o servidor sabe sobre um arquivo aberto.
#
# O texto é o do **buffer**, e não o do disco: o editor tem a versão que o redator está
# digitando, e é sobre ela que os diagnósticos têm de falar. Por isso a análise entra por
# `load_source`, que recebe texto e não lança.

"""
    Document

Um arquivo aberto no editor: o texto, as linhas já partidas (a conversão de posição
precisa delas em cada consulta) e o resultado da última análise.

`loaded.model` é `nothing` enquanto o arquivo não tem árvore — o estado normal de um
arquivo no meio de uma frase. Toda funcionalidade que dependa de estrutura tem de
sobreviver a isso, e é por isso que ele é um campo e não uma exceção.

`last_model` é **a última análise que deu certo**, e nunca é apagada. Existe porque
completar é a funcionalidade que roda exatamente quando o arquivo não analisa: no
instante em que alguém pede uma sugestão, o que ele digitou é `{`, e um servidor que
consultasse só a análise corrente não sugeriria nada nunca.

Isso não é a ferramenta discordando do motor (D-029) — é ela mostrando **a última coisa
que o motor disse** em vez de inventar uma própria. As duas coisas se distinguem por
onde a resposta é calculada, e não por quão recente ela é: diagnóstico, estrutura e
cursor continuam saindo de `loaded`, porque para eles um arquivo quebrado tem uma
resposta certa, que é dizer o que está quebrado.
"""
mutable struct Document
    uri::String
    path::String
    version::Int
    text::String
    lines::Vector{SubString{String}}
    loaded::Kanon.Loaded
    last_model::Union{Nothing,Kanon.Model}
end

Document(uri, path, version, text, lines, loaded) =
    Document(uri, path, version, text, lines, loaded, loaded.model)

"""
    Server

O estado do servidor. `env` decide **quais camadas existem** — e é o cliente que decide
isso, na configuração dele, exatamente como a CLI recebe `--locale`.

Um servidor que carregasse todas as camadas disponíveis por conta própria aceitaria um
modelo que o motor recusaria em produção, e o redator descobriria a diferença no dia da
entrega. O padrão é o núcleo puro, que é o padrão da linguagem.
"""
mutable struct Server
    io_in::IO
    io_out::IO
    env::Kanon.Environment
    docs::Dict{String,Document}
    published::Set{String}          # a quem já mandamos diagnósticos, para poder limpar
    shutdown_requested::Bool
    running::Bool
end

Server(io_in::IO, io_out::IO, env::Kanon.Environment = Kanon.Environment()) =
    Server(io_in, io_out, env, Dict{String,Document}(), Set{String}(), false, true)

# --- URI ---------------------------------------------------------------------
#
# Só `file:`. Um editor pode abrir um buffer sem arquivo, e aí a inclusão de fragmentos
# não tem raiz — o que é o comportamento certo, e não uma limitação: sem arquivo não há
# de onde incluir.

"""
    path_of(uri) -> String

O caminho de um `file:` URI, com os `%XX` desfeitos. Cadeia vazia para qualquer outro
esquema.

No Windows o URI é `file:///D:/a/x.kanon`, e a barra que abre o caminho **não** faz parte
dele: `/D:/a` é `D:\a`. Sem essa distinção o servidor procura um arquivo que não existe,
e o editor recebe diagnóstico de arquivo nenhum.
"""
function path_of(uri::AbstractString)
    startswith(uri, "file://") || return ""
    resto = uri[8:end]
    i = findfirst('/', resto)
    i === nothing && return ""
    caminho = unescape_uri(resto[i:end])
    is_windows_path(caminho) ? replace(caminho[2:end], '/' => '\\') : caminho
end

"`/D:/a/x` — a forma que um URI dá a um caminho com letra de unidade."
is_windows_path(p::AbstractString) =
    length(p) >= 3 && p[1] == '/' && isletter(p[2]) && p[3] == ':'

function unescape_uri(s::AbstractString)
    io = IOBuffer()
    i = firstindex(s)
    while i <= lastindex(s)
        c = s[i]
        if c == '%' && i + 2 <= lastindex(s)
            b = tryparse(UInt8, s[(i + 1):(i + 2)]; base = 16)
            b === nothing ? print(io, c) : write(io, b)
            i = nextind(s, i, 3)
        else
            print(io, c)
            i = nextind(s, i)
        end
    end
    String(take!(io))
end

"""
    uri_of(path) -> String

O `file:` URI de um caminho. Só os caracteres que a RFC 3986 exige são escapados.

**Resolve o link simbólico quando o arquivo existe**, e não é detalhe: o carregador de
fragmentos guarda `realpath` (§11.2, o link que aponta para fora da raiz), e num macOS
`mktempdir()` devolve `/var/folders/…` enquanto o `realpath` é `/private/var/folders/…`.
Sem a normalização, o diagnóstico de um fragmento seria publicado num URI que o editor
não reconhece, e o problema simplesmente não apareceria.
"""
function uri_of(path::AbstractString)
    p = abspath(String(path))
    p = try; realpath(p); catch; p; end
    uri_from_abspath(p)
end

"""
    uri_from_abspath(p) -> String

A conversão pura, separada de `uri_of` para poder ser testada com um caminho do Windows
numa máquina que não é Windows — que é onde ela quebrou, e onde nenhum teste a olhava.

`D:\\a\\x.kanon` vira `file:///D:/a/x.kanon`: barras invertidas viram barras, e a letra
de unidade ganha a terceira barra. Os dois-pontos da unidade ficam literais, que é a
forma que todo cliente aceita.
"""
function uri_from_abspath(p::AbstractString)
    unidade = length(p) >= 2 && isletter(p[1]) && p[2] == ':'
    corpo = replace(String(p), '\\' => '/')
    unidade && (corpo = "/" * corpo)

    io = IOBuffer()
    print(io, "file://")
    for (i, b) in enumerate(codeunits(corpo))
        c = Char(b)
        if c == '/' || 'a' <= c <= 'z' || 'A' <= c <= 'Z' || '0' <= c <= '9' ||
           c in ('-', '.', '_', '~') || (unidade && c == ':' && i == 3)
            print(io, c)
        else
            print(io, '%', uppercase(string(b; base = 16, pad = 2)))
        end
    end
    String(take!(io))
end

# --- análise -----------------------------------------------------------------

"""
    reanalyze(server, doc)

Refaz a análise do buffer. A raiz de inclusão é o diretório do próprio arquivo, como em
`load_template`; um buffer sem arquivo não inclui nada.
"""
function reanalyze!(s::Server, d::Document)
    raiz = isempty(d.path) ? nothing : dirname(d.path)
    nome = isempty(d.path) ? d.uri : d.path
    d.loaded = Kanon.load_source(s.env, d.text; name = nome, root = raiz)
    d.loaded.model === nothing || (d.last_model = d.loaded.model)
    return d
end

function set_text!(s::Server, d::Document, texto::AbstractString, version::Integer)
    d.text = String(texto)
    d.lines = linhas_de(d.text)
    d.version = Int(version)
    reanalyze!(s, d)
end

"""
O caminho de um documento, normalizado como o carregador normaliza — `realpath` quando o
arquivo existe. É o que faz o nome que os diagnósticos usam bater com o que a tabela de
fontes guarda para os fragmentos.
"""
function doc_path(uri::AbstractString)
    p = path_of(uri)
    isempty(p) && return p
    try; realpath(p); catch; p; end
end

function open_document!(s::Server, uri::AbstractString, texto::AbstractString,
                        version::Integer)
    d = Document(String(uri), doc_path(uri), Int(version), String(texto),
                 linhas_de(String(texto)),
                 Kanon.Loaded(nothing, Kanon.DiagnosticSet()))
    d.text = String(texto)
    reanalyze!(s, d)
    s.docs[d.uri] = d
end

# --- posições, agora com o documento em mãos ---------------------------------

"A linha `n` (1-based, como o Kanon conta), ou cadeia vazia se ela não existe."
line_at(d::Document, n::Integer) = 1 <= n <= length(d.lines) ? d.lines[n] : SubString("")

"Uma posição Kanon (linha e coluna 1-based) como posição LSP."
lsp_position(d::Document, line::Integer, col::Integer) =
    (line = max(Int(line) - 1, 0), character = to_lsp(line_at(d, line), col))

"O `Range` LSP de um trecho Kanon."
function lsp_range(d::Document, line, col, endline, endcol)
    (start = lsp_position(d, line, col),
     var"end" = lsp_position(d, endline, endcol))
end

lsp_range(d::Document, sp::Kanon.Span) =
    lsp_range(d, sp.line, sp.col, sp.endline, sp.endcol)

"Uma posição LSP como posição Kanon: `(linha, coluna)`, ambas 1-based."
function kanon_position(d::Document, pos)
    linha = Int(pos.line) + 1
    (linha, to_kanon(line_at(d, linha), Int(pos.character)))
end
