# `contract(modelo)` — o checklist, em JSON Schema draft 2020-12 (D-009).
#
# Por que JSON Schema e não um formato próprio: qualquer gerador de formulário,
# validador ou ferramenta de documentação do mercado consome o checklist sem adaptador,
# e a chave de extensão `x-kanon` carrega o que o JSON Schema não expressa — o tipo
# Kanon de origem, a linha da declaração, a cardinalidade exata, os formatadores usados.
#
# A saída é **determinística e comparável em `diff`**: chaves de `properties` na ordem
# de declaração, `required` na ordem do arquivo, `$defs` em ordem alfabética, indentação
# fixa. É o que permite versionar o checklist ao lado do modelo e ver, no `diff` de um
# commit, exatamente o que o contrato passou a exigir.

# --- um emissor de JSON pequeno e ordenado -----------------------------------
#
# Escrito à mão, e não com uma dependência, por uma razão só: nenhuma biblioteca
# garante ordem de chaves, e sem ordem não há `diff`.

"Objeto JSON com ordem de chaves explícita — a razão de este arquivo não usar `Dict` (I4)."
struct JObj
    entries::Vector{Pair{String,Any}}
end

JObj() = JObj(Pair{String,Any}[])
Base.isempty(o::JObj) = isempty(o.entries)
Base.push!(o::JObj, p::Pair) = (push!(o.entries, String(first(p)) => last(p)); o)

function json_escape(io::IO, s::AbstractString)
    print(io, '"')
    for c in s
        if c == '"'
            print(io, "\\\"")
        elseif c == '\\'
            print(io, "\\\\")
        elseif c == '\n'
            print(io, "\\n")
        elseif c == '\r'
            print(io, "\\r")
        elseif c == '\t'
            print(io, "\\t")
        elseif c < ' '
            print(io, "\\u", lpad(string(UInt16(c); base = 16), 4, '0'))
        else
            print(io, c)
        end
    end
    print(io, '"')
end

const INDENT = "  "

function write_json(io::IO, x, depth::Int = 0)
    pad = repeat(INDENT, depth)
    inner = repeat(INDENT, depth + 1)

    if x isa JObj
        isempty(x) && return print(io, "{}")
        println(io, '{')
        for (i, (k, v)) in enumerate(x.entries)
            print(io, inner)
            json_escape(io, k)
            print(io, ": ")
            write_json(io, v, depth + 1)
            println(io, i == length(x.entries) ? "" : ",")
        end
        print(io, pad, '}')
    elseif x isa AbstractVector
        isempty(x) && return print(io, "[]")
        println(io, '[')
        for (i, v) in enumerate(x)
            print(io, inner)
            write_json(io, v, depth + 1)
            println(io, i == length(x) ? "" : ",")
        end
        print(io, pad, ']')
    elseif x isa AbstractString
        json_escape(io, x)
    elseif x isa Bool
        print(io, x ? "true" : "false")
    elseif x isa Integer
        print(io, x)
    elseif x isa AbstractFloat
        print(io, isinteger(x) ? string(Integer(x)) : string(x))
    elseif x === nothing
        print(io, "null")
    else
        json_escape(io, string(x))
    end
    return nothing
end

# --- o esquema de um tipo ----------------------------------------------------

"""
A forma JSON dos seis tipos do núcleo. O núcleo pode conhecê-los porque são dele; o de
uma camada é descrito abaixo, pelo que o protocolo já revela.
"""
function core_json_type(name::Symbol)
    name === :text && return JObj(["type" => "string"])
    name === :number && return JObj(["type" => "number"])
    name === :boolean && return JObj(["type" => "boolean"])
    name === :date && return JObj(["type" => "string", "format" => "date"])
    name === :money && return JObj([
        "type" => "object",
        "properties" => JObj([
            "amount" => JObj(["type" => ["string", "number"]]),
            "currency" => JObj(["type" => "string"]),
        ]),
        "required" => ["amount", "currency"],
        "additionalProperties" => false,
    ])
    return nothing
end

"""
O `\$defs` de um tipo.

Um composto vira `object` a partir de `kanon_schema` — o esquema é público, e é
exatamente a descrição de que o JSON Schema precisa.

Um **escalar de camada** vira `{}` com o `x-kanon` dizendo o nome do tipo: o protocolo
não tem como revelar a forma JSON de um `measure`, e afirmar uma forma inventada seria
pior do que não afirmar nenhuma. Uma ferramenta que conheça Kanon lê o nome em
`x-kanon`; um validador genérico aceita o valor sem restringi-lo. Descrever esses tipos
é candidato a uma versão menor, e é aditivo (dívida registrada no roadmap).
"""
function type_schema(env::Environment, name::Symbol)
    # Pelo canônico: `data` é `date`, e sem isto o checklist de um modelo em português
    # sairia sem `type` nenhum — validando qualquer coisa (§2.4).
    base = core_json_type(canonical_typename(env, name))
    base === nothing || return base

    T = typefor(env, name)
    T === nothing && return JObj(["x-kanon" => JObj(["type" => String(name)])])

    schema = kanon_schema(T)
    isempty(schema) && return JObj(["x-kanon" => JObj(["type" => String(name)])])

    props = JObj()
    required = String[]
    for spec in schema
        push!(props, String(spec.name) => field_schema(spec.type, spec.card))
        spec.optional || push!(required, String(spec.name))
    end
    o = JObj(["type" => "object", "properties" => props])
    isempty(required) || push!(o, "required" => required)
    push!(o, "additionalProperties" => false)
    return o
end

"A referência a um tipo, com o invólucro de array quando a cardinalidade é de lista."
function field_schema(tn::Symbol, card::Cardinality)
    ref = JObj(["\$ref" => "#/\$defs/" * String(tn)])
    islist(card) || return ref

    o = JObj(["type" => "array", "items" => ref])
    card.kind === EXACT && (push!(o, "minItems" => Int(card.lo)); push!(o, "maxItems" => Int(card.lo)))
    card.kind === ATLEAST && push!(o, "minItems" => Int(card.lo))
    if card.kind === RANGE
        card.lo == 0 || push!(o, "minItems" => Int(card.lo))
        push!(o, "maxItems" => Int(card.hi))
    end
    return o
end

"A cardinalidade como `x-kanon` a escreve — a forma exata, que o JSON Schema perde."
function card_string(c::Cardinality)
    c.kind === EXACT && return "exact($(c.lo))"
    c.kind === ATLEAST && return "atleast($(c.lo))"
    c.kind === RANGE && return "range($(c.lo),$(c.hi))"
    return "any"
end

const PRESENCE_NAME = Dict(REQUIRED => "required", OPTIONAL => "optional",
                           DEFAULTED => "defaulted")

"O literal de valor padrão, na forma que o JSON carrega."
function default_json(lit::Literal)
    lit.kind === :constant && return String(lit.value)     # hoje só `today`
    lit.kind === :date && return Dates.format(lit.value, dateformat"yyyy-mm-dd")
    lit.kind === :null && return nothing
    return lit.value
end

"""
Os formatadores que o modelo de fato usa em cada campo de primeiro nível, ordenados.

Não são os formatadores *disponíveis* — esses o tipo enumera. São os que este documento
pede, e é isso que interessa a quem lê o checklist para saber o que precisa funcionar.
"""
function used_formatters(m::Model)
    out = Dict{Symbol,Set{Symbol}}()
    for b in m.template.text.blocks, p in b.children
        collect_formatters!(out, m, p.children)
    end
    out
end

function collect_formatters!(out, m::Model, nodes)
    for n in nodes
        if n isa Interp
            f = m.analysis.formatter[id(n)]
            (f === :default || f === NO_FORMATTER) && continue
            rp = m.analysis.paths[id(n)]
            rp === nothing && continue
            # só o campo de primeiro nível: o checklist descreve o objeto de dados
            campo = n.path.segments[1]
            push!(get!(out, campo, Set{Symbol}()), f)
        elseif n isa Group
            collect_formatters!(out, m, n.children)
        end
    end
end

# --- o checklist -------------------------------------------------------------

"Todo tipo que o checklist precisa definir, incluindo os alcançados por dentro dos compostos."
function reachable_types(env::Environment, fields)
    vistos = Set{Symbol}()
    fila = Symbol[f.type for f in fields]
    while !isempty(fila)
        tn = popfirst!(fila)
        tn in vistos && continue
        push!(vistos, tn)
        T = typefor(env, tn)
        T === nothing && continue
        for spec in kanon_schema(T)
            spec.type in vistos || push!(fila, spec.type)
        end
    end
    sort!(collect(vistos))
end

"""
    contract(model) -> String

O checklist de dados do modelo, em JSON Schema draft 2020-12 com a extensão `x-kanon`
(`docs/api-extensao.md` §7).

Determinístico: duas chamadas sobre o mesmo modelo dão a mesma cadeia, byte a byte.
"""
function contract(m::Model)
    campos = m.template.data.fields
    fmts = used_formatters(m)

    props = JObj()
    required = String[]
    for f in campos
        x = JObj([
            "type" => String(f.type),
            "line" => Int(f.span.line),
            "presence" => PRESENCE_NAME[f.presence],
        ])
        islist(f.card) && push!(x, "cardinality" => card_string(f.card))
        f.default === nothing || push!(x, "default" => default_json(f.default))
        haskey(fmts, f.name) && push!(x, "formatters" => sort!(String.(collect(fmts[f.name]))))

        entry = field_schema(f.type, f.card)
        push!(entry, "x-kanon" => x)
        push!(props, String(f.name) => entry)

        f.presence === REQUIRED && push!(required, String(f.name))
    end

    defs = JObj()
    for tn in reachable_types(m.env, campos)
        push!(defs, String(tn) => type_schema(m.env, tn))
    end

    nome = isempty(m.template.sources) ? "<string>" : m.template.sources[1]
    doc = JObj([
        "\$schema" => "https://json-schema.org/draft/2020-12/schema",
        "\$id" => "kanon:" * nome,
        "type" => "object",
        "required" => required,
        "additionalProperties" => false,
        "properties" => props,
        "\$defs" => defs,
    ])

    io = IOBuffer()
    write_json(io, doc)
    println(io)
    String(take!(io))
end

"Escreve o checklist num arquivo. Feito para ser versionado ao lado do modelo."
function contract(m::Model, path::AbstractString)
    open(io -> print(io, contract(m)), path, "w")
    return path
end
