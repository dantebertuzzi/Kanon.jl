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
    Kanon.rows(tabela) -> Vector

As linhas de uma tabela, cada uma pronta para `check` e `render`. Uma linha de
`Tables.jl` já responde a `propertynames`/`getproperty`, que é o que
`Kanon.input_field` usa — não há conversão no caminho.
"""
Kanon.rows(tabela) = Tables.istable(tabela) ? collect(Tables.rows(tabela)) :
    throw(ArgumentError("`$(typeof(tabela))` não é uma tabela de `Tables.jl`."))

"""
    Kanon.render_each(modelo, tabela; today, budget) -> Vector{String}

Um documento por linha. É o caso que a ingestão existe para atender: a mesma minuta para
cada linha de uma planilha.

Falha **na primeira linha que não satisfaz o contrato**, com a linha nomeada — e não
depois de gerar metade dos documentos.
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
