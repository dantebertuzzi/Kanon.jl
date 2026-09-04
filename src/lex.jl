# Léxico compartilhado: classes de caractere, cursor e a tabela de palavras-chave.
#
# `parse` não consulta o `Environment` (docs/ast.md §8). A tabela de palavras-chave é
# escolhida ANTES do lex, a partir do pragma, e chega aqui como dado. É o que permite
# que um modelo em inglês tenha uma única árvore possível, independente das camadas
# carregadas.

# --- classes de caractere ----------------------------------------------------

is_ident_start(c::Char) = isletter(c)
is_ident_char(c::Char)  = isletter(c) || isdigit(c) || c == '_'

"""
Conjunto fechado de unidades de marcador de bloco na versão 1.

Fechado de propósito: o marcador precisa ser reconhecível sem consultar o ambiente
(uma camada de domínio registra `§`, mas o parser não a conhece), e um conjunto aberto
transformaria qualquer linha de prosa iniciada por pontuação em candidata a cabeçalho.
O núcleo usa `:`; as demais ficam para as camadas.
"""
const MARKER_UNITS = Set{Char}([':', '§', '¶', '@', '%', '&', '*', '+', '~', '^', '†', '‡'])

is_marker_unit(c::Char) = c in MARKER_UNITS

"Teto de níveis numerados na versão 1 (D-001)."
const MAX_BLOCK_LEVEL = 3

# --- palavras-chave ----------------------------------------------------------

"""
    KeywordTable

Mapeia a forma escrita no arquivo para a palavra canônica. O arquivo canônico é o
inglês: um motor sem nenhuma camada instalada lê qualquer modelo em inglês.

Mistura é erro (D-003): a tabela é uma só por arquivo, escolhida pelo pragma.
"""
struct KeywordTable
    lang::Union{Nothing,Symbol}
    forms::Dict{String,Symbol}
end

const CANONICAL_KEYWORDS = ("data", "text", "rules", "when", "one", "for", "each",
                            "and", "or", "not", "is", "present", "absent",
                            "true", "false", "null", "today")

# `:true` e `:false`, escritos assim em Julia, são os *booleanos* `true` e `false`, não
# símbolos. Comparar o resultado de `keyword` com `:true` seria sempre falso — e o bug
# passaria despercebido até alguém escrever `= true` num valor padrão.
const KW_TRUE = Symbol("true")
const KW_FALSE = Symbol("false")

"Tabela do inglês canônico, a única que o núcleo conhece sozinho."
function canonical_keywords()
    forms = Dict{String,Symbol}()
    for w in CANONICAL_KEYWORDS
        forms[w] = Symbol(w)
    end
    KeywordTable(nothing, forms)
end

"Palavra canônica correspondente à forma escrita, ou `nothing` se não for palavra-chave."
keyword(kt::KeywordTable, s::AbstractString) = get(kt.forms, s, nothing)

iskeyword(kt::KeywordTable, s::AbstractString, canon::Symbol) = keyword(kt, s) === canon

"Formas escritas conhecidas, ordenadas — para a sugestão na mensagem de erro (I4)."
known_forms(kt::KeywordTable) = sort!(collect(keys(kt.forms)))

# --- cursor ------------------------------------------------------------------

"""
    Cursor

Percorre uma cadeia mantendo linha e coluna em caracteres. Existe porque a posição é
parte do produto: um erro sem linha e coluna não serve ao redator.
"""
mutable struct Cursor
    s::String
    i::Int          # índice de byte
    line::Int32
    col::Int32
end

Cursor(s::AbstractString, line::Integer, col::Integer) = Cursor(String(s), 1, Int32(line), Int32(col))

ateof(c::Cursor) = c.i > ncodeunits(c.s)

function peek(c::Cursor, ahead::Int = 0)
    i = c.i
    for _ in 1:ahead
        i > ncodeunits(c.s) && return nothing
        i = nextind(c.s, i)
    end
    i > ncodeunits(c.s) && return nothing
    return c.s[i]
end

function advance!(c::Cursor)
    ateof(c) && return nothing
    ch = c.s[c.i]
    c.i = nextind(c.s, c.i)
    if ch == '\n'
        c.line += 1
        c.col = 1
    else
        c.col += 1
    end
    return ch
end

here(c::Cursor, file::Integer = 1) = Span(file, c.line, c.col)

"Consome espaços e tabulações. Não atravessa quebra de linha."
function skip_blanks!(c::Cursor)
    while true
        ch = peek(c)
        (ch === ' ' || ch === '\t') || break
        advance!(c)
    end
end

"Lê um identificador a partir da posição atual, ou `nothing`."
function read_ident!(c::Cursor)
    ch = peek(c)
    (ch !== nothing && is_ident_start(ch)) || return nothing
    io = IOBuffer()
    while true
        ch = peek(c)
        (ch !== nothing && is_ident_char(ch)) || break
        print(io, advance!(c))
    end
    return String(take!(io))
end

# --- utilidades de linha -----------------------------------------------------

"""
Remove o comentário `#` de uma linha dos planos `data` e `rules`, respeitando aspas.

No plano do texto isto **não** se aplica: lá `#` é prosa e comentário é uma linha
inteira iniciada por `:#` na coluna 0 (D-012).
"""
function strip_comment(s::AbstractString)
    inquote = false
    for i in eachindex(s)
        ch = s[i]
        if ch == '"'
            inquote = !inquote
        elseif ch == '#' && !inquote
            return rstrip(s[1:prevind(s, i)])
        end
    end
    return rstrip(s)
end

isblankline(s::AbstractString) = all(c -> c == ' ' || c == '\t', s)
