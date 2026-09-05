# A conversão de posição, que é o primeiro lugar onde os dois mundos discordam.
#
#   Kanon   linha 1-based, coluna 1-based, contada em PONTOS DE CÓDIGO
#   LSP     linha 0-based, coluna 0-based, contada em UNIDADES UTF-16
#
# Três diferenças numa coisa só, e a terceira é a que morde: `§`, `ã` e `±` valem 1 nas
# duas contagens, mas ocupam 2 e 3 bytes — de modo que uma implementação que usasse
# índice de byte funcionaria em inglês e erraria em português, calada. E um emoji vale 1
# ponto de código e 2 unidades UTF-16, de modo que uma que usasse ponto de código
# funcionaria em português e erraria com emoji, também calada.
#
# Por isso a conversão é explícita, tem nome, e é testada com um caractere de cada
# espécie.

"O número de unidades UTF-16 de um caractere: 1, ou 2 fora do plano básico."
utf16_units(c::AbstractChar) = codepoint(c) <= 0xFFFF ? 1 : 2

"""
    to_lsp(linha_texto, col) -> Int

A coluna Kanon (1-based, em pontos de código) como coluna LSP (0-based, em unidades
UTF-16), dada a linha em que ela está.
"""
function to_lsp(linha::AbstractString, col::Integer)
    col <= 1 && return 0
    n = 0
    for (i, c) in enumerate(linha)
        i >= col && break
        n += utf16_units(c)
    end
    n
end

"""
    to_kanon(linha_texto, character) -> Int

O inverso: a coluna LSP como coluna Kanon. Uma posição que caia **no meio** de um par
substituto arredonda para o caractere que o contém — é o que um editor entende por
"o cursor está nele".
"""
function to_kanon(linha::AbstractString, character::Integer)
    character <= 0 && return 1
    n = 0
    for (i, c) in enumerate(linha)
        # Compara com o FIM do caractere, e não com o começo: uma posição que caia no
        # meio de um par substituto pertence ao caractere que a contém, e comparar com o
        # começo devolveria o caractere seguinte.
        n + utf16_units(c) > character && return i
        n += utf16_units(c)
    end
    length(linha) + 1
end

"""
As linhas de um texto, **sem** o terminador, preservando a última linha vazia.

`split(s, '\\n')` já faz isso; a função existe para que o motivo esteja escrito: o LSP
conta linhas de 0 a n-1 e uma posição no fim do arquivo aponta a linha n-1, que só
existe se a linha vazia depois do último `\\n` for contada.
"""
linhas_de(texto::AbstractString) = split(texto, '\n')
