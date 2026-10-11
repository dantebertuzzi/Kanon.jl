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
    Kanon.read_json(path) -> Dict{String,Any}

Reads a JSON file as data. Nested objects become `Dict` and arrays become `Vector`, which
is what `kanon_decode` of a composite type receives.

**It decodes nothing.** Converting to the declared type belongs to the contract, and
`check` does it, with messages that name the field. A JSON `"2026-03-12"` in a `date`
field arrives here as a string and leaves `check` as a `Date`, or as an error.
"""
Kanon.read_json(caminho::AbstractString) = Kanon.parse_json(read(caminho, String))

"Like `read_json`, from a string."
Kanon.parse_json(texto::AbstractString) = plano(JSON3.read(texto))

plano(x::JSON3.Object) = Dict{String,Any}(String(k) => plano(v) for (k, v) in pairs(x))
plano(x::JSON3.Array) = Any[plano(v) for v in x]
plano(x) = x

end # module
