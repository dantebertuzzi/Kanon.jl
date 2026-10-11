"""
    KanonTablesExt

Ingestão de tabelas — carregada **só** quando `Tables.jl` está presente.

O roadmap pedia "`Tables.jl`, e não um adaptador por formato": qualquer coisa que
implemente a interface — `DataFrame`, CSV lido, resultado de consulta SQL, vetor de
`NamedTuple` — vira dados sem que o Kanon saiba de onde veio.

É extensão, e não dependência: o núcleo continua com `Dates` e `Unicode`, e o teste de
neutralidade continua verificando isso.
"""
module KanonTablesExt

using Kanon
using Tables

"""
    Kanon.rows(table) -> Vector

The rows of a table, each ready for `check` and `render`. A `Tables.jl` row already
answers `propertynames`/`getproperty`, which is what `Kanon.input_field` uses, so a flat
table needs no conversion.

**A dotted column is a field of a composite** (D-052). A spreadsheet is flat and every
domain type is composite: without this rule, `load : measure` could not come from a CSV,
and `render_each` could not reach any domain layer. The columns `load.value`,
`load.uncertainty` and `load.unit` become the object `load`, which is what the type's
`kanon_decode` receives from JSON; the dot is the same separator the template uses in
`{load.value}`.

An empty cell is an absent key, for the reason in D-046: where the data comes from must
not change what the contract means. A group whose cells are **all** empty is an absent
field, which is the only way a row can say that an optional measurement was not taken.
"""
function Kanon.rows(tabela)
    Tables.istable(tabela) ||
        throw(ArgumentError("`$(typeof(tabela))` não é uma tabela de `Tables.jl`."))
    linhas = collect(Tables.rows(tabela))
    isempty(linhas) && return linhas
    nomes = collect(Tables.columnnames(first(linhas)))
    any(n -> occursin('.', String(n)), nomes) || return linhas
    [aninhar(linha, nomes) for linha in linhas]
end

"Uma linha como objeto: as colunas com ponto viram objetos aninhados, e o vazio sai."
function aninhar(linha, nomes)
    d = Dict{String,Any}()
    for n in nomes
        partes = split(String(n), '.')
        any(isempty, partes) && throw(ArgumentError(
            "a coluna `$n` tem um trecho vazio entre pontos; o ponto separa o campo do " *
            "composto do campo de dentro, como em `carga.value`."))
        alvo = d
        for (k, p) in enumerate(partes[1:(end - 1)])
            prox = get!(() -> Dict{String,Any}(), alvo, String(p))
            prox isa Dict{String,Any} || conflito(join(partes[1:k], "."))
            alvo = prox
        end
        haskey(alvo, String(partes[end])) && conflito(String(n))
        alvo[String(partes[end])] = Tables.getcolumn(linha, n)
    end
    podar!(d)
    d
end

conflito(nome) = throw(ArgumentError(
    "a tabela traz a coluna `$nome` e também colunas `$nome.…`: a mesma linha diria o " *
    "valor duas vezes. Deixe uma forma só — a coluna inteira ou as partes dela."))

"Tira o que veio vazio, e o objeto que ficou sem nada: célula vazia é chave ausente."
function podar!(d::Dict{String,Any})
    for k in collect(keys(d))
        v = d[k]
        v isa Dict{String,Any} && podar!(v)
        (v === missing || v === nothing || (v isa Dict && isempty(v))) && delete!(d, k)
    end
    d
end

"""
    Kanon.render_each(model, table; today, budget) -> Vector{String}

One document per row: the same template filled from each row of a spreadsheet.

Fails **at the first row that does not satisfy the contract**, naming the row, rather
than after generating half of the documents.
"""
function Kanon.render_each(m::Kanon.Model, tabela; today = nothing,
                           budget::Kanon.Budget = Kanon.Budget())
    linhas = Kanon.rows(tabela)
    out = Vector{String}(undef, length(linhas))
    for (i, linha) in enumerate(linhas)
        s = Kanon.check(m, linha; today, budget)
        Kanon.haserrors(s) &&
            throw(Kanon.KanonContractError(Kanon.DiagnosticSet(
                [Kanon.with_row(d, i) for d in s])))
        out[i] = Kanon.render(m, linha; today, budget)
    end
    out
end

end # module
