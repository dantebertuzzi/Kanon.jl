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

Como o texto vira arquivo. `PlainText` é o padrão e não toca em nada; os demais escapam
o que o formato deles trataria como marcação.
"""
abstract type OutputFormat end

"Texto puro: nada é marcação, nada precisa de escape."
struct PlainText <: OutputFormat end

"Markdown. Escapa o que o CommonMark leria como marcação."
struct Markdown <: OutputFormat end

"""
Typst. Candidato a backend de página: o Kanon garante o conteúdo e o Typst compõe a
página — que era a melhor ideia do levantamento (`estado-da-arte.md`).
"""
struct Typst <: OutputFormat end

"""
    escape_value(fmt, texto, inicio_de_linha) -> String

Escapa um valor **vindo dos dados**. Não se aplica à prosa do modelo: o autor que
escreve `**importante**` num modelo Markdown quer negrito, e tirá-lo dele seria editar o
texto que ele digitou — o mesmo erro que o reparo global de emenda seria (D-014).

`inicio_de_linha` diz se o valor está sendo emitido no começo de uma linha, e o render é
quem sabe disso. Sem essa informação, um `12.345` no meio de uma frase teria de ser
escapado como se pudesse abrir uma lista — e nenhum valor sairia legível.
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
Escapa um valor para Markdown.

Rastreia o início de linha porque um valor pode conter quebras: `"X\n\n# Cláusula"`
poria um título no documento se o `#` não fosse escapado **ali**, e escapá-lo em toda
posição encheria o texto de barras sem proteger nada.
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
Escapa um valor para Typst.

A contrabarra vai **antes do dígito**, e não antes do ponto: `1. x` no começo de uma
linha é item de enumeração explícita, e a forma de escrever o parágrafo é `\\1. x` — o
inverso do Markdown, onde o ponto é que leva a barra. Duas linguagens de marcação, duas
regras, e é por isso que o escape é método de formato e não uma função só.
"""
function escape_value(::Typst, s::AbstractString, inicio_de_linha::Bool)
    io = IOBuffer()
    inicio = inicio_de_linha
    for c in s
        if c in TYPST_ESPECIAIS || (inicio && (isdigit(c) || c in TYPST_INICIO))
            print(io, '\\')
        end
        print(io, c)
        inicio = c == '\n' ? true : (inicio && (c == ' ' || c == '\t'))
    end
    String(take!(io))
end

"""
    heading(fmt, nivel, texto) -> String

O rótulo de um bloco cujo estilo declara `layout = :heading`. Em texto puro ele é o
parágrafo que o estilo produziu; num formato com títulos, ele vira título de verdade, e
o nível vem da profundidade da numeração.
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
    document(fmt, paragrafos) -> String

Junta os parágrafos. Todos os formatos que o núcleo conhece separam por linha em branco;
o método existe para que um formato que não separe assim possa dizê-lo.
"""
document(::OutputFormat, paragrafos::Vector{String}) = join(paragrafos, "\n\n")

"O nome do formato para a linha de comando e para a mensagem de erro."
const FORMATOS = (text = PlainText, markdown = Markdown, md = Markdown, typst = Typst)

"""
    output_format(nome) -> OutputFormat

O formato de saída pelo nome. Erra nomeando os que existem — um formato desconhecido
escreveria o documento errado em silêncio, e é a última coisa que este motor deve fazer.
"""
function output_format(nome::Symbol)
    haskey(FORMATOS, nome) && return FORMATOS[nome]()
    throw(ArgumentError("`$nome` não é um formato de saída. Os formatos são: " *
                        join(sort!(collect(String.(keys(FORMATOS)))), ", ") * "."))
end

output_format(f::OutputFormat) = f
