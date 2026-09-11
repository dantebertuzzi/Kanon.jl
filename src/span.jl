# Posição e identidade — as duas peças que a árvore e o diagnóstico compartilham.
#
# Moram num arquivo próprio porque a dependência entre os dois é de mão dupla desde a
# D-055: o diagnóstico nasce de um `Span`, e o `Template` passou a guardar diagnósticos.
# Em Julia um campo, e o tipo de um argumento, precisam do tipo já definido — e um
# arquivo com o que os dois usam é mais barato que uma ordem que não existe.

"Índice denso de nó. Denso para que as tabelas laterais sejam `Vector`, não `Dict` (I4)."
const NodeId = Int32

"""
    Span

Posição de um trecho no arquivo. Colunas são contadas em **caracteres**, 1-based —
é o que o redator vê no editor, não o que o byte diz.
"""
struct Span
    file::Int32
    line::Int32
    col::Int32
    endline::Int32
    endcol::Int32
end

Span(file::Integer, line::Integer, col::Integer) = Span(file, line, col, line, col)

"Junta dois trechos no menor que cobre os dois."
merge_span(a::Span, b::Span) = Span(a.file, a.line, a.col, b.endline, b.endcol)

