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
`Kanon.input_field` usa — numa tabela plana não há conversão no caminho.

**Coluna com ponto é campo de composto** (D-052). Uma planilha é plana, e todo tipo de
domínio é composto: sem esta regra, `carga : measure` não tinha como vir de um CSV, e
`render_each` — que existe para planilhas — não alcançava camada de domínio nenhuma. As
colunas `carga.value`, `carga.uncertainty` e `carga.unit` viram o objeto `carga`, que é o
que `kanon_decode` do tipo recebe de um JSON; o ponto é o mesmo separador que o modelo usa
em `{carga.value}`.

Célula vazia vale chave ausente, pela razão da D-046: a origem dos dados não pode mudar o
significado do contrato. E um grupo com **todas** as células vazias vale campo ausente —
é a única forma de uma linha dizer que a medição opcional não foi feita.
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
