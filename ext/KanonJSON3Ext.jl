"""
    KanonJSON3Ext

Leitura de dados em JSON — carregada **só** quando `JSON3.jl` está presente.

O núcleo não precisa de JSON para funcionar: `check` e `render` aceitam qualquer coisa
que responda por nome (`Dict`, `NamedTuple`, `struct`, linha de tabela). O que esta
extensão dá é a conveniência de ler o arquivo — e o exemplo de `docs/exemplos.md` §1.2
está em JSON justamente porque é assim que os dados chegam na prática.
"""
module KanonJSON3Ext

using Kanon
using JSON3

"""
    Kanon.read_json(caminho) -> Dict{String,Any}

Lê um JSON como dados. Objetos aninhados viram `Dict`, e listas viram `Vector` — que é
exatamente o que `kanon_decode` de um tipo composto recebe.

**Não decodifica nada**: converter para o tipo declarado é do contrato, e é `check` quem
faz, com as mensagens que nomeiam o campo. Um JSON com `"2026-03-12"` num campo `date`
chega aqui como cadeia e sai de `check` como `Date`, ou como erro.
"""
Kanon.read_json(caminho::AbstractString) = Kanon.parse_json(read(caminho, String))

"Como `read_json`, a partir do texto."
Kanon.parse_json(texto::AbstractString) = plano(JSON3.read(texto))

plano(x::JSON3.Object) = Dict{String,Any}(String(k) => plano(v) for (k, v) in pairs(x))
plano(x::JSON3.Array) = Any[plano(v) for v in x]
plano(x) = x

end # module
