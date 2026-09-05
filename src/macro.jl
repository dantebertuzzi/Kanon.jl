# `@kanon_type` — a forma declarativa de definir um tipo.
#
# É o açúcar que a D-019 prometeu: a fachada `register_type!` registra o **nome** e a
# macro gera o **comportamento**. Ela expande em tempo de carga do módulo da camada, e
# por isso pode receber as closures que a fachada não podia (não há `eval` em runtime,
# nem tabela de despacho).
#
# Duas obrigações da F0 (`api-extensao.md` §2.3), ambas com teste:
#
#   1. Tudo que a macro gera é escrevível à mão pelo caminho da §2.
#   2. `@macroexpand` não contém nenhum nome não exportado por `Kanon` — a verificação
#      mecânica de que a macro não é um atalho para dentro do núcleo.

"""
    @kanon_type <nome> <TipoJulia> begin ... end

Define um tipo Kanon por despacho, a partir de uma descrição declarativa.

```julia
@kanon_type person Pessoa begin
    schema     = (FieldSpec(:name, :text), FieldSpec(:spouse, :person; optional = true))
    getfield   = (name = :nome, spouse = :conjuge)
    default    = (v, ctx) -> v.nome
    formats    = (formal = (v, ctx) -> uppercase(v.nome),)
    attributes = (minor = v -> v.idade < 18,)
    validate   = (v, ctx) -> nothing
    decode     = (raw, ctx) -> Pessoa(raw)
    compare    = (a, b) -> cmp(a.nome, b)
    locale     = :pt
end
```

Só `default` é obrigatório; o resto é opcional. `getfield` só precisa listar os campos
cujo nome no esquema difere do nome da propriedade Julia.

**`aliases` não entra aqui.** Nome é local ao ambiente e se registra no `configure!` da
camada, com `register_type!(b, Pessoa; aliases = (pt = :pessoa,))` — é a divisão que a
D-019 estabeleceu e a D-025 confirmou.

`locale`, quando presente, declara que os formatadores nomeados deste tipo pertencem a
um idioma e só são visíveis onde ele está ativo (D-026).
"""
macro kanon_type(nome, T, corpo)
    corpo isa Expr && corpo.head === :block ||
        error("@kanon_type espera um bloco `begin ... end` com as definições do tipo.")

    partes = Dict{Symbol,Any}()
    for linha in corpo.args
        linha isa LineNumberNode && continue
        (linha isa Expr && linha.head === :(=)) ||
            error("cada linha de @kanon_type é uma atribuição `chave = valor`; veio: $linha")
        chave = linha.args[1]
        chave isa Symbol ||
            error("a chave de @kanon_type é um nome simples; veio: $chave")
        chave in CHAVES_KANON_TYPE ||
            error("`$chave` não é uma chave de @kanon_type. As chaves são: " *
                  join(CHAVES_KANON_TYPE, ", ") * ".")
        partes[chave] = linha.args[2]
    end

    haskey(partes, :default) ||
        error("@kanon_type exige `default`: todo tipo tem um formatador padrão (§3.2).")

    # `GlobalRef`, e não `Kanon.nome`: o hygiene da macro qualificaria com o módulo de
    # definição e produziria `Kanon.Kanon.format` e `Kanon.Val`, que funcionam mas
    # tornam a expansão ilegível — e o teste normativo da §2.3 varre exatamente isto.
    K(n::Symbol) = GlobalRef(@__MODULE__, n)
    B(n::Symbol) = GlobalRef(Base, n)
    tipo = esc(T)

    out = Expr(:block)
    push!(out.args, :($(K(:kanon_typename))(::$(B(:Type)){$tipo}) = $(QuoteNode(nome))))
    push!(out.args, :($(K(:format))(v::$tipo, ::$(B(:Val)){:default}, ctx) =
                          $(esc(partes[:default]))(v, ctx)))

    haskey(partes, :schema) &&
        push!(out.args, :($(K(:kanon_schema))(::$(B(:Type)){$tipo}) = $(esc(partes[:schema]))))
    haskey(partes, :validate) &&
        push!(out.args, :($(K(:kanon_validate))(v::$tipo, ctx) =
                              $(esc(partes[:validate]))(v, ctx)))
    haskey(partes, :decode) &&
        push!(out.args, :($(K(:kanon_decode))(::$(B(:Type)){$tipo}, raw, ctx) =
                              $(esc(partes[:decode]))(raw, ctx)))
    haskey(partes, :compare) &&
        push!(out.args, :($(K(:kanon_compare))(a::$tipo, b) = $(esc(partes[:compare]))(a, b)))

    idioma = get(partes, :locale, nothing)

    if haskey(partes, :formats)
        for (f, fn) in nomeados(partes[:formats], "formats")
            push!(out.args, :($(K(:format))(v::$tipo, ::$(B(:Val)){$(QuoteNode(f))}, ctx) =
                                  $(esc(fn))(v, ctx)))
            idioma === nothing ||
                push!(out.args, :($(K(:kanon_format_locale))(::$(B(:Type)){$tipo},
                          ::$(B(:Val)){$(QuoteNode(f))}) = $(esc(idioma))))
        end
    end

    if haskey(partes, :attributes)
        pares = nomeados(partes[:attributes], "attributes")
        nomes = Tuple(sort!([first(p) for p in pares]))
        push!(out.args, :($(K(:kanon_attributes))(::$(B(:Type)){$tipo}) = $nomes))
        for (a, fn) in pares
            push!(out.args, :($(K(:kanon_attribute))(v::$tipo,
                      ::$(B(:Val)){$(QuoteNode(a))}) = $(esc(fn))(v)))
        end
    end

    if haskey(partes, :getfield)
        for (campo, prop) in nomeados(partes[:getfield], "getfield")
            push!(out.args, :($(K(:kanon_getfield))(v::$tipo,
                      ::$(B(:Val)){$(QuoteNode(campo))}) =
                          $(B(:getproperty))(v, $(esc(prop)))))
        end
    end

    push!(out.args, tipo)
    return out
end

"As chaves que `@kanon_type` reconhece. Fechada, para que um erro de digitação erre."
const CHAVES_KANON_TYPE = (:schema, :getfield, :default, :formats, :attributes,
                           :validate, :decode, :compare, :locale)

"""
Lê um `NamedTuple` literal da macro como pares `(nome, expressão)`.

Trabalha sobre a **expressão**, e não sobre o valor: a macro roda antes de existir valor
nenhum, e é isso que permite gerar métodos em vez de guardar funções numa tabela.
"""
function nomeados(expr, chave::AbstractString)
    (expr isa Expr && expr.head === :tuple) ||
        error("`$chave` de @kanon_type é uma tupla nomeada, como `(nome = f,)`.")
    out = Pair{Symbol,Any}[]
    for a in expr.args
        (a isa Expr && a.head === :(=) && a.args[1] isa Symbol) ||
            error("cada entrada de `$chave` é `nome = valor`; veio: $a")
        push!(out, a.args[1] => a.args[2])
    end
    out
end
