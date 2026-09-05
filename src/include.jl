# Inclusão de fragmentos (D-005, F7).
#
# **Inclusão, e não herança.** Herança inverte o controle: para saber o que sai é
# preciso ler o pai, e o pai não está no arquivo. A inclusão é local e aditiva — no
# ponto em que o fragmento entra está escrito o nome dele, e a leitura linear continua
# sendo um limite superior do documento.
#
# A consequência que decide a questão é o contrato: **inclusão compõe com o contrato e
# herança não**. O fragmento traz o próprio plano `data`, unificado com o do hospedeiro;
# mesmo nome e mesmo tipo funde, tipos diferentes é erro na carga, e a obrigatoriedade é
# o máximo das duas. O checklist do modelo composto é derivado.
#
# O carregador tem raiz configurada e recusa caminho absoluto, travessia e link
# simbólico para fora — um modelo é dado não confiável (§11.2).

"""
    Loader

De onde os fragmentos podem vir. `root` é a raiz configurada, e nada fora dela é
carregável — nem por caminho absoluto, nem por `..`, nem por link simbólico.

Sem raiz, a inclusão é recusada: o padrão é não ler arquivo nenhum, e quem quer incluir
diz de onde.
"""
struct Loader
    root::Union{Nothing,String}
    limit::Int
end

Loader(root = nothing; limit::Int = 32) =
    Loader(root === nothing ? nothing : abspath(String(root)), limit)

"O caminho, resolvido e verificado, ou uma mensagem dizendo por que ele não serve."
function resolve_include(ldr::Loader, caminho::AbstractString)
    ldr.root === nothing &&
        return nothing, ("K2055",
            "este modelo inclui `$caminho`, e a carga não tem raiz configurada.",
            "Passe `root = \"...\"` a `load_template`: sem raiz, o motor não lê arquivo " *
            "nenhum, e é assim de propósito.")

    isabspath(caminho) &&
        return nothing, ("K2050",
            "`$caminho` é um caminho absoluto.",
            "Fragmentos se nomeiam relativos à raiz da carga.")

    alvo = normpath(joinpath(ldr.root, caminho))
    dentro(alvo, ldr.root) ||
        return nothing, ("K2050",
            "`$caminho` sai da raiz `$(ldr.root)`.",
            "Um modelo é dado não confiável: ele não escolhe o que o motor lê (§11.2).")

    isfile(alvo) ||
        return nothing, ("K2052",
            "não há arquivo em `$caminho`.",
            "O caminho é relativo à raiz `$(ldr.root)`.")

    # O link simbólico é resolvido DEPOIS de existir: um link dentro da raiz que aponte
    # para fora dela é a forma mais simples de escapar, e `normpath` sozinho não a vê.
    real = realpath(alvo)
    dentro(real, realpath(ldr.root)) ||
        return nothing, ("K2050",
            "`$caminho` é um link para fora da raiz.",
            "O destino de um link também precisa estar na raiz.")

    return real, nothing
end

"O caminho está dentro da raiz? Compara por componente, e não por prefixo de cadeia."
function dentro(caminho::AbstractString, raiz::AbstractString)
    c = splitpath(normpath(caminho))
    r = splitpath(normpath(raiz))
    length(c) >= length(r) && c[1:length(r)] == r
end

# --- unificação de contratos -------------------------------------------------

"A presença mais forte de duas: obrigatório vence padrão, que vence opcional (D-005)."
function stronger(a::Presence, b::Presence)
    (a === REQUIRED || b === REQUIRED) && return REQUIRED
    (a === DEFAULTED || b === DEFAULTED) && return DEFAULTED
    return OPTIONAL
end

"""
Unifica o plano de dados de um fragmento com o do hospedeiro.

Mesmo nome e mesmo tipo **fundem**, com a obrigatoriedade mais forte das duas; tipos ou
cardinalidades diferentes são erro **na carga**, e não no render. A ideia vem da CUE
(`estado-da-arte.md` §10.4), e é o que herança não teria como fazer: com um bloco
sobrescrito, o contrato fica indeterminado até saber quem sobrescreve o quê.
"""
function unify_data(host::DataPlane, frag::DataPlane, file::AbstractString,
                    diags::Vector{Diagnostic})
    campos = copy(host.fields)
    for f in frag.fields
        i = findfirst(g -> g.name === f.name, campos)
        if i === nothing
            push!(campos, f)
            continue
        end
        g = campos[i]
        if g.type !== f.type
            push!(diags, Diagnostic("K2053", :reference, f.span, file,
                "`$(f.name)` é `$(g.type)` no modelo e `$(f.type)` no fragmento.";
                hint = "Um campo com o mesmo nome tem de ter o mesmo tipo nos dois; " *
                       "renomeie um deles.", path = String(f.name)))
            continue
        end
        if g.card != f.card
            push!(diags, Diagnostic("K2053", :reference, f.span, file,
                "`$(f.name)` tem cardinalidades diferentes no modelo e no fragmento.";
                hint = "A cardinalidade faz parte do tipo do campo.", path = String(f.name)))
            continue
        end
        presenca = stronger(g.presence, f.presence)
        padrao = g.default === nothing ? f.default : g.default
        campos[i] = FieldDecl(g.id, g.name, g.type, g.card, presenca, padrao, g.span)
    end
    DataPlane(campos)
end

# --- composição --------------------------------------------------------------

"""
    compose(template, loader, keywords) -> Template

Resolve as inclusões e devolve o modelo composto: um `Template` só, em que nada indica
que houve fragmento — quem analisa e renderiza não sabe da inclusão.

Os identificadores de nó continuam únicos porque todos os arquivos são analisados com o
**mesmo** contador; é o que evita reconstruir a árvore para renumerá-la.
"""
function compose(t::Template, ldr::Loader, kw::KeywordTable)
    isempty(t.text.includes) && return t

    ctx = ParseCtx(source_from_text("", t.sources[1]), kw)
    ctx.nextid = t.nnodes
    sources = copy(t.sources)
    diags = Diagnostic[]
    visitados = Set{String}()
    raiz = ldr.root === nothing ? nothing : realpath(ldr.root)
    raiz === nothing || push!(visitados, raiz)

    data, blocos, regras = expand!(t, ldr, kw, ctx, sources, diags, visitados,
                                   t.sources[1], 0)

    set = sorted(DiagnosticSet(diags))
    haserrors(set) && throw(KanonReferenceError(set))
    Template(t.version, t.language, sources, data, TextPlane(blocos), regras, ctx.nextid)
end

"""
Expande um modelo: os blocos dele, com os dos fragmentos inseridos no ponto de cada
inclusão. Recursiva, com teto de profundidade e detecção de ciclo — um fragmento que se
inclua, direta ou indiretamente, para aqui (§11.5).
"""
function expand!(t::Template, ldr::Loader, kw::KeywordTable, ctx::ParseCtx,
                 sources::Vector{String}, diags::Vector{Diagnostic},
                 visitados::Set{String}, arquivo::AbstractString, nivel::Int)
    data = t.data
    blocos = Block[]
    regras = copy(t.rules.rules)
    nomes = Set{Symbol}(b.name for b in t.text.blocks)

    if nivel > ldr.limit
        push!(diags, Diagnostic("K2051", :reference, Span(1, 0, 0), arquivo,
            "a inclusão passou de $(ldr.limit) níveis.";
            hint = "Provavelmente há um ciclo que a detecção não alcançou."))
        return data, t.text.blocks, RulesPlane(regras)
    end

    proximo = 1
    for inc in sort(t.text.includes; by = i -> i.before)
        for k in proximo:(inc.before - 1)
            push!(blocos, t.text.blocks[k])
        end
        proximo = inc.before

        alvo, falha = resolve_include(ldr, inc.path)
        if alvo === nothing
            codigo, msg, hint = falha
            push!(diags, Diagnostic(codigo, :reference, inc.span, arquivo, msg; hint,
                                    path = inc.path))
            continue
        end
        if alvo in visitados
            push!(diags, Diagnostic("K2051", :reference, inc.span, arquivo,
                "`$(inc.path)` já está sendo incluído: a inclusão fecha um ciclo.";
                hint = "Um fragmento não pode incluir a si mesmo, nem quem o inclui.",
                path = inc.path))
            continue
        end

        push!(visitados, alvo)
        frag = parse_into!(ctx, read_source(alvo), sources)
        fdata, fblocos, fregras = expand!(frag, ldr, kw, ctx, sources, diags, visitados,
                                          alvo, nivel + 1)
        delete!(visitados, alvo)

        data = unify_data(data, fdata, arquivo, diags)
        for b in fblocos
            if b.name in nomes
                push!(diags, Diagnostic("K2054", :reference, inc.span, arquivo,
                    "o fragmento `$(inc.path)` traz o bloco `$(b.name)`, que já existe " *
                    "no modelo.";
                    hint = "Nomes de bloco são únicos no modelo composto: é por eles " *
                           "que as regras e as remissões apontam.", path = String(b.name)))
                continue
            end
            push!(nomes, b.name)
            push!(blocos, b)
        end
        append!(regras, fregras.rules)
    end

    for k in proximo:length(t.text.blocks)
        push!(blocos, t.text.blocks[k])
    end
    return data, blocos, RulesPlane(regras)
end
