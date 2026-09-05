# O reparo de emenda — a parte mais sujeita a bug do projeto (risco 16.4).
#
# O princípio que a torna testável (D-014): **o reparo é local à emenda**. Depois de
# elidir, o motor não varre o parágrafo normalizando pontuação — ele conhece a posição
# exata de cada remoção e olha só para os caracteres em volta dela.
#
# Um reparo global reescreveria pontuação que o autor digitou de propósito: uma vírgula
# dupla numa citação, reticências, um ponto-e-vírgula estilístico. O motor não tem o
# direito de editar prosa que ele não removeu, e a violação apareceria num documento
# assinado.
#
# Os treze casos normativos de `especificacao.md` §5.3 estão em `test/golden/emenda/`,
# e foram escritos antes deste arquivo.

"Um de `, ; :` — o que separa itens dentro de uma frase."
is_separator(c::Char) = c == ',' || c == ';' || c == ':'

"Um de `. ! ?` — o que termina uma frase. **Nunca é removido, por nenhuma regra.**"
is_terminator(c::Char) = c == '.' || c == '!' || c == '?'

is_blank(c::Char) = c == ' ' || c == '\t'

"""
    repair(chars, seams) -> (texto, emendas)

Aplica o procedimento da §5.2: funde emendas adjacentes, aplica R1–R5 uma vez, da
esquerda para a direita, e limpa as linhas que ficaram vazias por causa de uma emenda.

`seams` são posições no texto **como ele saiu da elisão**: a emenda `p` fica entre
`chars[p-1]` e `chars[p]`. Devolve também as posições **depois** do reparo, porque é
delas que o gancho de idioma precisa: passar as de antes o mandaria olhar para o texto
errado (§5.4).
"""
function repair(chars::Vector{Char}, seams::Vector{Int})
    v = copy(chars)
    ss = merge_seams(v, sort(seams))

    for i in eachindex(ss)
        p = ss[i]
        p = rule1!(v, p, ss, i)
        p = rule2!(v, p, ss, i)
        p = rule3!(v, p, ss, i)
        p = rule4!(v, p, ss, i)
        p = rule5!(v, p, ss, i)
        ss[i] = p
    end

    clean_lines(v, ss)
end

"""
Funde emendas separadas apenas por brancos (§5.2, passo 2): as duas viram uma só, cujo
contexto é o texto à esquerda da primeira e à direita da segunda.

Sem isso, `{a}[, {b}][, {c}], fim` teria duas emendas encostadas e cada regra veria
metade do contexto.
"""
function merge_seams(v::Vector{Char}, seams::Vector{Int})
    isempty(seams) && return Int[]
    out = [seams[1]]
    for p in seams[2:end]
        q = out[end]
        if all(is_blank, @view v[q:(p - 1)])
            # a emenda da direita absorve a da esquerda: o contexto é o de fora das duas
            out[end] = q
            continue
        end
        push!(out, p)
    end
    out
end

# --- utilidades de contexto --------------------------------------------------
#
# Todas trabalham a partir da emenda, e nenhuma percorre o parágrafo inteiro em busca de
# pontuação para consertar. É a diferença entre reparo local e reparo global.

"Índice do primeiro caractere do run de brancos que termina em `p-1`."
function blank_start(v::Vector{Char}, p::Int)
    i = p
    while i > 1 && is_blank(v[i - 1])
        i -= 1
    end
    i
end

"Índice logo após o run de brancos que começa em `p`."
function blank_stop(v::Vector{Char}, p::Int)
    i = p
    while i <= length(v) && is_blank(v[i])
        i += 1
    end
    i
end

"O caractere não-branco imediatamente à esquerda da emenda, e seu índice."
function left_nonblank(v::Vector{Char}, p::Int)
    i = blank_start(v, p) - 1
    i >= 1 ? (v[i], i) : (nothing, 0)
end

"O caractere não-branco imediatamente à direita da emenda, e seu índice."
function right_nonblank(v::Vector{Char}, p::Int)
    i = blank_stop(v, p)
    i <= length(v) ? (v[i], i) : (nothing, 0)
end

"A emenda está no começo de uma linha — só há brancos entre ela e a quebra anterior?"
function at_line_start(v::Vector{Char}, p::Int)
    i = p - 1
    while i >= 1
        v[i] == '\n' && return true
        is_blank(v[i]) || return false
        i -= 1
    end
    return true
end

"A emenda está no fim de uma linha?"
function at_line_end(v::Vector{Char}, p::Int)
    i = p
    while i <= length(v)
        v[i] == '\n' && return true
        is_blank(v[i]) || return false
        i += 1
    end
    return true
end

"Só há brancos entre a emenda e o fim do parágrafo?"
at_paragraph_end(v::Vector{Char}, p::Int) = all(is_blank, @view v[p:end])

"""
Remove `v[a:b]` e desloca as emendas **posteriores** — as anteriores já foram tratadas e
não se movem. Devolve a nova posição da emenda corrente.
"""
function cut!(v::Vector{Char}, a::Int, b::Int, ss::Vector{Int}, i::Int, p::Int)
    b < a && return p
    n = b - a + 1
    deleteat!(v, a:b)
    for j in (i + 1):length(ss)
        ss[j] > b ? (ss[j] -= n) : (ss[j] = a)
    end
    p > b ? p - n : a
end

"Insere `c` em `v[a]`, deslocando as emendas posteriores."
function put!(v::Vector{Char}, a::Int, c::Char, ss::Vector{Int}, i::Int, p::Int)
    insert!(v, a, c)
    for j in (i + 1):length(ss)
        ss[j] >= a && (ss[j] += 1)
    end
    p >= a ? p + 1 : p
end

# --- as cinco regras ---------------------------------------------------------

"""
**R1 — espaço.** Brancos que atravessam a emenda colapsam num único espaço; no começo
ou no fim da linha, colapsam para nada.
"""
function rule1!(v::Vector{Char}, p::Int, ss::Vector{Int}, i::Int)
    a = blank_start(v, p)
    b = blank_stop(v, p) - 1
    b < a && return p                       # não há branco de nenhum lado

    if at_line_start(v, p) || at_line_end(v, p)
        return cut!(v, a, b, ss, i, p)
    end
    # colapsa para um só: corta tudo e repõe um espaço
    q = cut!(v, a, b, ss, i, p)
    put!(v, a, ' ', ss, i, q)
end

"""
**R2 — separador duplicado.** `sep₁ ws* sep₂` ⟶ `sep₁`: mantém o da esquerda e descarta
o resto até o da direita, inclusive.
"""
function rule2!(v::Vector{Char}, p::Int, ss::Vector{Int}, i::Int)
    l, li = left_nonblank(v, p)
    r, ri = right_nonblank(v, p)
    (l === nothing || r === nothing) && return p
    (is_separator(l) && is_separator(r)) || return p
    cut!(v, li + 1, ri, ss, i, p)
end

"""
**R3 — separador antes de terminador.** `sep ws* term` ⟶ `term`. O terminador fica; quem
sai é o separador e os brancos entre eles.
"""
function rule3!(v::Vector{Char}, p::Int, ss::Vector{Int}, i::Int)
    l, li = left_nonblank(v, p)
    r, ri = right_nonblank(v, p)
    (l === nothing || r === nothing) && return p
    (is_separator(l) && is_terminator(r)) || return p
    cut!(v, li, ri - 1, ss, i, p)
end

"""
**R4 — separador no fim do parágrafo.** Um separador que a emenda deixou como último
caractere não-branco do parágrafo é removido.
"""
function rule4!(v::Vector{Char}, p::Int, ss::Vector{Int}, i::Int)
    l, li = left_nonblank(v, p)
    l === nothing && return p
    is_separator(l) || return p
    at_paragraph_end(v, p) || return p
    cut!(v, li, li, ss, i, p)
end

"""
**R5 — separador no início.** Um separador que a emenda deixou como primeiro caractere
não-branco de uma linha é removido, e R1 se aplica de novo.
"""
function rule5!(v::Vector{Char}, p::Int, ss::Vector{Int}, i::Int)
    r, ri = right_nonblank(v, p)
    r === nothing && return p
    is_separator(r) || return p
    at_line_start(v, p) || return p
    q = cut!(v, ri, ri, ss, i, p)
    rule1!(v, q, ss, i)
end

# --- limpeza -----------------------------------------------------------------

"""
§5.2, passo 5: uma linha que ficou só com brancos **por causa de uma emenda** é
removida. Linha em branco que o autor escreveu não é tocada — e a diferença entre as
duas é exatamente a lista de emendas.
"""
function clean_lines(v::Vector{Char}, seams::Vector{Int})
    isempty(seams) && return (String(v), seams)

    linhas = String[]
    finais = Int[]
    inicio = 1
    n = length(v)
    escrito = 0
    for i in 1:(n + 1)
        (i > n || v[i] == '\n') || continue
        fim = i - 1
        trecho = String(@view v[inicio:fim])
        # a linha só cai se ficou vazia E alguma emenda caiu dentro dela
        vazia = all(isspace, trecho)
        tocada = any(s -> inicio <= s <= i, seams)
        if vazia && tocada
            inicio = i + 1
            continue
        end
        push!(linhas, trecho)
        for s in seams
            inicio <= s <= i && push!(finais, escrito + (s - inicio) + 1)
        end
        escrito += length(trecho) + 1      # +1 pela quebra que `join` repõe
        inicio = i + 1
    end
    (join(linhas, "\n"), sort!(finais))
end
