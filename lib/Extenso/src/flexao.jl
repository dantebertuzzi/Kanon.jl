# Flexão por marca.
#
# O invariante que este arquivo existe para não quebrar (D-013):
#
#   **Só a palavra que carrega a marca muda.** Todo o resto da prosa é imutável.
#
# O núcleo entrega `(palavra, marca, sujeito)` e insere de volta o que este arquivo
# devolver. Não há travessia de texto aqui, não há lista de palavras, não há
# heurística sobre a frase — só a palavra que o autor marcou.
#
# Escrever a marca é o consentimento do autor, palavra a palavra. `residente e
# domiciliado(a)` com sujeito feminino produz `residente e domiciliada`, e não
# `residentes e domiciliadas`: para isso o autor escreve `residente(s) e domiciliado(a)`.

"""
    Marca

O que uma marca faz. `condicao` é o que o sujeito precisa ser para ela valer; `sufixo` é
o que entra; `substitui` diz se ela troca a vogal final da palavra ou se anexa.

A diferença entre substituir e anexar é o que separa `brasileiro(a)` ⟶ `brasileira` de
`legítimo(s)` ⟶ `legítimos`: a marca de gênero ocupa a desinência, a de número vem
depois dela.
"""
struct Marca
    sufixo::String
    genero::Union{Nothing,Symbol}
    plural::Bool
    substitui::Bool
end

"""
As marcas do português, em minúsculas. As formas maiúsculas são derivadas na construção
do ambiente — `VENDEDOR(A)` é a mesma marca de `portador(a)`, escrita na caixa do texto
em que ela vive.
"""
const MARCAS = (
    "a"   => Marca("a",   :f,      false, true),
    "o"   => Marca("o",   :m,      false, true),
    "as"  => Marca("as",  :f,      true,  true),
    "os"  => Marca("os",  :m,      true,  true),
    "s"   => Marca("s",   nothing, true,  false),
    "es"  => Marca("es",  nothing, true,  false),
    "is"  => Marca("is",  nothing, true,  false),
    "ns"  => Marca("ns",  nothing, true,  false),
    "ais" => Marca("ais", nothing, true,  false),
    "m"   => Marca("m",   nothing, true,  false),
    "em"  => Marca("em",  nothing, true,  false),
    "eis" => Marca("eis", nothing, true,  false),
)

"Toda forma escrita de marca que o ambiente registra: `(a)` e `(A)`, `(es)` e `(ES)`."
function formas_de_marca()
    out = String[]
    for (nome, _) in MARCAS
        push!(out, "(" * nome * ")")
        push!(out, "(" * uppercase(nome) * ")")
    end
    out
end

"A marca correspondente a uma forma escrita, ignorando a caixa. `nothing` se não é marca."
function marca_de(forma::AbstractString)
    nucleo = lowercase(strip(forma, ('(', ')')))
    for (nome, m) in MARCAS
        nome == nucleo && return m
    end
    return nothing
end

# --- o protocolo de sujeito --------------------------------------------------
#
# Definido aqui, e não no núcleo: o núcleo não conhece gênero nem número, e é isso que
# o mantém neutro. Uma camada de domínio dá métodos para os tipos dela.

"""
    genero(v) -> :m | :f | nothing

O gênero gramatical de um valor. O padrão é `nothing` — **desconhecido**, e não
masculino: uma marca de gênero sobre sujeito de gênero desconhecido não flexiona, e a
palavra fica na forma que o autor escreveu.

Supor masculino calaria o erro: o documento sairia todo no masculino sem que nada
avisasse que o tipo não declarou gênero.
"""
genero(v) = nothing

"""
    numero(v) -> :singular | :plural

Um valor solto é singular; uma coleção é plural quando tem mais de um.
"""
numero(v) = :singular
numero(v::AbstractVector) = length(v) == 1 ? :singular : :plural

"""
Numa coleção, basta um masculino para o conjunto ser masculino — a regra do português
para grupo misto. Só é feminino o grupo em que todos os elementos são femininos.
"""
function genero(v::AbstractVector)
    isempty(v) && return nothing
    vistos = [genero(x) for x in v]
    any(g -> g === :m, vistos) && return :m
    all(g -> g === :f, vistos) && return :f
    return nothing
end

# --- a aplicação -------------------------------------------------------------

const VOGAIS_DESINENCIA = ('o', 'a', 'O', 'A')

"""
    flexionar(palavra, forma, sujeito) -> String

O que o núcleo chama em cada ponto de flexão. Devolve a **palavra inteira**, já
flexionada — ou a palavra como estava, quando a marca não se aplica ao sujeito.

Nada além desta palavra é tocado, e é isso que D-013 garante.
"""
function flexionar(palavra::AbstractString, forma::AbstractString, sujeito)
    m = marca_de(forma)
    m === nothing && return palavra * forma        # não é marca nossa: prosa literal

    aplica = true
    m.genero === nothing || (aplica &= genero(sujeito) === m.genero)
    m.plural && (aplica &= numero(sujeito) === :plural)
    aplica || return String(palavra)

    sufixo = caixa_de(forma, m.sufixo)
    base = (m.substitui && !isempty(palavra) && last(palavra) in VOGAIS_DESINENCIA) ?
           palavra[1:prevind(palavra, lastindex(palavra))] : palavra
    String(base) * sufixo
end

"O sufixo entra na caixa em que a marca foi escrita: `(A)` produz `A`, `(a)` produz `a`."
caixa_de(forma::AbstractString, sufixo::AbstractString) =
    any(isuppercase, forma) ? uppercase(sufixo) : sufixo

# --- recapitalização depois da elisão ---------------------------------------

"""
    recapitalizar(texto, emendas, ctx) -> String

O gancho de reparo da camada (§5.4): quando o começo de uma frase foi elidido, a palavra
que sobrou no início dela é recapitalizada.

**O núcleo nunca mexe em caixa** — capitalizar é regra de idioma, e por isso mora aqui.

Conservador de propósito: só age quando a emenda deixou a palavra no início do parágrafo
ou logo depois de um terminador de frase. Uma emenda no meio da frase não autoriza
mexer em caixa nenhuma, porque ali a minúscula pode ser o que o autor quis.
"""
function recapitalizar(texto::AbstractString, emendas, ctx)
    isempty(emendas) && return String(texto)
    v = collect(texto)
    for p in emendas
        i = proxima_letra(v, p)
        i === nothing && continue
        inicio_de_frase(v, i) || continue
        v[i] = uppercase(v[i])
    end
    String(v)
end

"Índice da primeira letra a partir de `p`, pulando brancos."
function proxima_letra(v::Vector{Char}, p::Int)
    i = max(p, 1)
    while i <= length(v) && (v[i] == ' ' || v[i] == '\t')
        i += 1
    end
    (i <= length(v) && isletter(v[i])) ? i : nothing
end

"Só há começo de parágrafo, ou um terminador de frase, antes desta posição?"
function inicio_de_frase(v::Vector{Char}, i::Int)
    j = i - 1
    while j >= 1
        c = v[j]
        (c == ' ' || c == '\t' || c == '\n') && (j -= 1; continue)
        return c == '.' || c == '!' || c == '?'
    end
    return true
end
