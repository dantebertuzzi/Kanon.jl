# Formatos de saída (F8).
#
# O render produz **texto**, e o formato decide como esse texto vira arquivo. O núcleo
# conhece três, e uma camada acrescenta o quarto pelo mesmo caminho de sempre: métodos
# de funções genéricas.
#
# A regra que governa este arquivo, e que é a mesma do projeto inteiro dita para outro
# problema:
#
#   **O valor interpolado nunca altera a estrutura do documento.** A prosa que o autor
#   escreveu é dele e passa intacta; o dado que veio de fora é escapado.
#
# Um nome com `*` não vira itálico, um valor com `#` não vira título, e um campo com
# `\\` não escapa nada. É a mesma preocupação de quem escapa HTML, pela mesma razão: o
# dado é do usuário, a estrutura é do autor, e confundir os dois é como se produz um
# documento que ninguém escreveu.

"""
    OutputFormat

How the text becomes a file. `PlainText` is the default and touches nothing; the others
escape what their format would read as markup.
"""
abstract type OutputFormat end

"Plain text: nothing is markup, nothing needs escaping."
struct PlainText <: OutputFormat end

"Markdown. Escapes what CommonMark would read as markup."
struct Markdown <: OutputFormat end

"""
Typst. A candidate page backend: Kanon guarantees the content and Typst lays out the
page (`estado-da-arte.md`).
"""
struct Typst <: OutputFormat end

"""
    escape_value(fmt, text, at_line_start) -> String

Escapes a value **that comes from the data**. It does not apply to the template's prose:
an author who writes `**important**` in a Markdown template wants bold, and removing it
would be editing what they typed, the same mistake a global seam repair would be (D-014).

`at_line_start` says whether the value is being emitted at the start of a line, which
only the renderer knows. Without it, a `12.345` in the middle of a sentence would have to
be escaped as if it could open a list, and no value would come out readable.
"""
escape_value(f::OutputFormat, s::AbstractString) = escape_value(f, s, true)
escape_value(::OutputFormat, s::AbstractString, ::Bool) = String(s)

"""
O que o CommonMark trata como marcação **em qualquer posição**. Ênfase, código, links,
HTML embutido, matemática e atributos.
"""
const MARKDOWN_SEMPRE = raw"\`*_[]<>&$|{}"

"""
O que só é marcação **no início de uma linha**: títulos, citações, itens de lista, e a
linha de sublinhado de um título ATX alternativo.

Escapar estes no meio do texto seria ruído puro: `12.345` viraria `12\\.345` e
`- item` do meio de uma frase não abre lista nenhuma, sem que nada estivesse sendo
protegido.

O cifrão **não** está nesta lista, e é de propósito: ele abre matemática em Pandoc e no
GitHub, e escapado é literal nos dois e no CommonMark. `R\\\$ 42.000,00` no fonte é o
preço de um contrato não virar fórmula, e o modelo real nº 11 é quem o paga.
"""
const MARKDOWN_INICIO = raw"#+->=~"

"""
Escapes a value for Markdown.

Tracks line starts because a value can contain line breaks: `"X\n\n# Cláusula"` would
put a heading in the document if the `#` were not escaped **there**, and escaping it
everywhere would fill the text with backslashes without protecting anything.
"""
function escape_value(::Markdown, s::AbstractString, inicio_de_linha::Bool)
    io = IOBuffer()
    inicio = inicio_de_linha    # estamos no começo de uma linha?
    digitos = false        # viemos de dígitos desde o começo da linha?
    for c in s
        if c in MARKDOWN_SEMPRE
            print(io, '\\', c)
        elseif inicio && c in MARKDOWN_INICIO
            print(io, '\\', c)
        elseif digitos && (c == '.' || c == ')')
            # `1.` e `1)` no começo da linha abrem lista ordenada
            print(io, '\\', c)
        else
            print(io, c)
        end
        if c == '\n'
            inicio = true
            digitos = false
        else
            digitos = (inicio || digitos) && isdigit(c)
            inicio = inicio && (c == ' ' || c == '\t')
        end
    end
    String(take!(io))
end

"No Typst, o que abre construção é `#`, `\$`, `@`, `<`, `[`, `*`, `_` e a contrabarra."
const TYPST_ESPECIAIS = raw"\#$@<>[]*_`"

"""
O que só abre construção no **começo de uma linha**: os itens de lista (`-`, `+`), a
lista de termos (`/`) e o título (`=`). A enumeração explícita entra por outro caminho,
porque ela começa por dígito.
"""
const TYPST_INICIO = raw"-+/="

"""
Escapes a value for Typst.

The backslash goes **before the digit**, not before the dot: `1. x` at the start of a
line is an explicitly numbered list item, and the way to write it as a paragraph is
`\\1. x`, the opposite of Markdown, where the dot takes the backslash. Two markup
languages, two rules, which is why escaping is a method per format and not one function.

Three constructs **do not open anything visible; they delete**, checked against Typst
0.15.1 while compiling the golden output of real template no. 12 (D-062):

- `//` starts a comment anywhere on a line: `processo 123//2026, vara` comes out as
  `processo 123`, and the rest of the line disappears without any error;
- `~` is a non-breaking space: `~200 m²` loses its tilde;
- `-?` is a soft hyphen, and disappears entirely.

These are the worst kind of defect a format can have: the document compiles and says less
than the data did. The slash is escaped only where it forms a comment: next to another
slash, or at the edge of the value, where the neighbour is prose the escaper cannot see.

Three more of the same family were found by taking that check to its end, sweeping the
whole alphabet against the compiler rather than following a suspicion (D-080). These do
not delete, they **replace**, which is why D-062 missed them:

- `--` is an en dash and `---` an em dash: `SEI 0001--2026` comes out as `SEI 0001–2026`;
- `...` is an ellipsis: `disse que ... não sabia` comes out with `…`.

A case number that changes a character in a document going to be signed is the same
failure as `//`, made worse by being readable: nobody checks what looks right. The hyphen
is escaped by the slash rule, which is the rule for every **two**-character shortcut:
next to another hyphen, or at the edge. The dot is not: an ellipsis needs **three**, and
only a sequence inside the value itself can form one. A single dot at the edge would need
the prose to supply the other two, and then the ellipsis is the author's.
"""
function escape_value(::Typst, s::AbstractString, inicio_de_linha::Bool)
    io = IOBuffer()
    inicio = inicio_de_linha
    cs = collect(s)
    n = length(cs)
    for (i, c) in enumerate(cs)
        anterior = i > 1 ? cs[i - 1] : nothing
        seguinte = i < n ? cs[i + 1] : nothing
        if c in TYPST_ESPECIAIS || (inicio && (isdigit(c) || c in TYPST_INICIO)) ||
           c == '~' ||
           (c == '/' && (i == 1 || i == n || anterior == '/' || seguinte == '/')) ||
           (c == '?' && (i == 1 || anterior == '-')) ||
           (c == '-' && (i == 1 || i == n || anterior == '-' || seguinte == '-')) ||
           (c == '.' && (anterior == '.' || seguinte == '.'))
            print(io, '\\')
        end
        print(io, c)
        inicio = c == '\n' ? true : (inicio && (c == ' ' || c == '\t'))
    end
    String(take!(io))
end

"""
    heading(fmt, level, text) -> String

The label of a block whose style declares `layout = :heading`. In plain text it is the
paragraph the style produced; in a format with headings it becomes a real heading, with
the level taken from the depth of the numbering.
"""
heading(::OutputFormat, ::Int, texto::AbstractString) = String(texto)
heading(::Markdown, nivel::Int, texto::AbstractString) = repeat('#', min(nivel, 6)) * " " * texto
heading(::Typst, nivel::Int, texto::AbstractString) = repeat('=', min(nivel, 6)) * " " * texto

"""
    label(fmt, texto) -> String

O rótulo de um bloco `layout = :prefix` **com o separador do estilo**, que prefixa o
primeiro parágrafo (§6.4). Os dois vêm juntos porque a estrutura que eles abrem por
acidente é a soma deles: o `1` é do rótulo e o `. ` que faz dele um marcador de lista é
do separador.

Ele não é prosa do autor nem valor dos dados: é a **única parte do documento que o motor
calcula**, e por isso a única que precisa sair intacta em todo formato. Num documento
numerado por `1.`, `1.1.`, `2.` — o estilo do núcleo —, o rótulo cai no começo da linha
exatamente na forma que o Markdown lê como marcador de lista, e o número que o motor
apurou passa a ser um número que o renderizador redefine, enquanto as remissões da prosa
continuam texto literal apontando para o número antigo (D-044).
"""
label(::OutputFormat, texto::AbstractString) = String(texto)
label(f::Markdown, texto::AbstractString) = escape_value(f, texto, true)
label(f::Typst, texto::AbstractString) = escape_value(f, texto, true)

"""
    line_breaks(fmt, paragraph) -> String

Line breaks **inside** a paragraph, which §4.1 preserves and leaves to the format to make
hard or not. In plain text the break is already the line the author wrote. In Markdown
and Typst a single newline is a **space**, so a format that decided nothing was in effect
joining lines: `Nestes termos,` and `pede deferimento.` came out on one line in the
`.docx`, and the signature block became `PAULO HENRIQUE LINS OAB/PE 12.345`, with no
warning, while the plain-text output of the same template was right (D-070, real template
no. 15).

A hard break is a backslash at the end of the line, which CommonMark, pandoc's default
reader and Typst all read the same way, and which is visible in the file, unlike the two
trailing spaces every editor strips. It is added only where the break would otherwise be a
space: in runs of consecutive lines where **none** opens a block construct. A list, table
or heading written by the author is their markup and passes through untouched (D-028);
a backslash there would break the table and appear literally at the end of the item.

The question is asked of the **already escaped** text: a value that starts a line with
`#` or `1.` arrives here as `\\#` and `1\\.` and opens nothing, which is what makes the
rule safe against the data.
"""
line_breaks(::OutputFormat, s::AbstractString) = String(s)
line_breaks(f::Markdown, s::AbstractString) = hard_breaks(f, s)
line_breaks(f::Typst, s::AbstractString) = hard_breaks(f, s)

"""
O que abre bloco no começo de uma linha de Markdown, no CommonMark **ou** no leitor padrão
do pandoc — que é o que lê o `| pandoc -o saida.docx` da ajuda da CLI: título, citação,
item de lista (inclusive `a)`, `(1)` e `iv.`, que só o pandoc lê), tabela, cerca de código,
bloco de HTML, definição, nota de rodapé e linha horizontal. Errar para o lado de achar
bloco onde não há só deixa a quebra como estava.
"""
const MARKDOWN_BLOCO = r"^ {0,3}(?:#{1,6}(?:\s|$)|>|[-*+](?:\s|$)|\d{1,9}[.)](?:\s|$)|[A-Za-z][.)](?:\s|$)|[ivxlcdmIVXLCDM]+[.)](?:\s|$)|\([0-9A-Za-z#@]+\)(?:\s|$)|#\.(?:\s|$)|\||```|~~~|:::|[:~](?:\s|$)|<|\[|=+\s*$|_{3,}\s*$)"

"O mesmo no Typst: título, lista, enumeração, termo, código, matemática, rótulo e comentário."
const TYPST_BLOCO = r"^\s*(?:=+(?:\s|$)|[-+](?:\s|$)|/\s|\d+\.(?:\s|$)|```|#|\$|<|//)"

opens_block(::Markdown, linha::AbstractString) =
    startswith(linha, "    ") || startswith(linha, '\t') || occursin(MARKDOWN_BLOCO, linha)
opens_block(::Typst, linha::AbstractString) = occursin(TYPST_BLOCO, linha)

function hard_breaks(f::OutputFormat, s::AbstractString)
    occursin('\n', s) || return String(s)
    linhas = split(s, '\n')
    saida = String.(linhas)
    n = length(linhas)
    i = 1
    while i <= n
        if all(isspace, linhas[i])
            i += 1
            continue
        end
        j = i
        while j < n && !all(isspace, linhas[j + 1])
            j += 1
        end
        if j > i && !any(l -> opens_block(f, l), view(linhas, i:j))
            for k in i:(j - 1)
                # uma barra ímpar no fim já é quebra rígida; par é contrabarra escapada
                barras = length(linhas[k]) - length(rstrip(==('\\'), linhas[k]))
                iseven(barras) && (saida[k] *= "\\")
            end
        end
        i = j + 1
    end
    join(saida, '\n')
end

"""
    document(fmt, paragrafos) -> String

Junta os parágrafos. Todos os formatos que o núcleo conhece separam por linha em branco;
o método existe para que um formato que não separe assim possa dizê-lo.
"""
document(::OutputFormat, paragrafos::Vector{String}) = join(paragrafos, "\n\n")

"O nome do formato para a linha de comando e para a mensagem de erro."
const FORMATOS = (text = PlainText, markdown = Markdown, md = Markdown, typst = Typst)

"""
    output_format(name) -> OutputFormat

The output format by name. Fails naming the formats that exist: an unknown format would
silently write the wrong document, the last thing this engine should do.
"""
function output_format(nome::Symbol)
    haskey(FORMATOS, nome) && return FORMATOS[nome]()
    throw(ArgumentError("`$nome` não é um formato de saída. Os formatos são: " *
                        join(sort!(collect(String.(keys(FORMATOS)))), ", ") * "."))
end

output_format(f::OutputFormat) = f
