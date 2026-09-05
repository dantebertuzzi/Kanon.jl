# As funcionalidades. Cada uma sai da `Analysis` ou do `outline`, e nenhuma decide nada
# sobre a linguagem (D-029).

# --- diagnósticos ------------------------------------------------------------

const SEVERITY = Dict(:error => 1, :warning => 2)

"""
Um diagnóstico do Kanon como diagnóstico do LSP.

A dica entra na **mensagem**, depois de uma linha em branco: o LSP não tem campo para
ela, e a dica é metade do valor de um diagnóstico deste motor — `docs/especificacao.md`
§10.4 manda sugerir a correção provável, e engoli-la seria jogar fora o que a mensagem
tem de melhor.
"""
function lsp_diagnostic(d::Document, x::Kanon.Diagnostic)
    msg = x.hint === nothing ? x.message : x.message * "\n\n" * x.hint
    (range = lsp_range(d, x.line, x.col, x.endline, x.endcol),
     severity = get(SEVERITY, x.severity, 1),
     code = x.code,
     source = "kanon",
     message = msg)
end

"""
    publish_diagnostics!(server, doc)

Publica os diagnósticos do documento — e os dos **fragmentos** que ele inclui, cada um
no URI dele.

Um problema dentro de um fragmento pertence ao fragmento, e mandá-lo para o hospedeiro o
poria numa linha que muitas vezes nem existe lá (D-035). É a primeira coisa que esta fase
consome da anterior.
"""
function publish_diagnostics!(s::Server, d::Document)
    # O próprio documento entra sempre, mesmo sem nada a dizer: sem a lista vazia, o
    # editor guarda para sempre o erro que o redator acabou de corrigir.
    por_arquivo = Dict{String,Vector{Any}}(d.uri => Any[])

    for x in d.loaded.diagnostics
        uri = arquivo_para_uri(d, x.file)
        push!(get!(por_arquivo, uri, []), lsp_diagnostic(doc_para_posicao(s, d, uri), x))
    end

    for (uri, ds) in por_arquivo
        notify(s.io_out, "textDocument/publishDiagnostics",
               (uri = uri, diagnostics = ds))
        push!(s.published, uri)
    end

    # o que ficou limpo desde a última vez precisa ser apagado, ou o editor guarda para
    # sempre o erro de um fragmento que já foi corrigido
    for uri in collect(s.published)
        haskey(por_arquivo, uri) && continue
        haskey(s.docs, uri) && continue
        notify(s.io_out, "textDocument/publishDiagnostics", (uri = uri, diagnostics = []))
        delete!(s.published, uri)
    end
    return nothing
end

arquivo_para_uri(d::Document, arquivo::AbstractString) =
    (arquivo == d.path || isempty(arquivo)) ? d.uri : uri_of(arquivo)

"""
O documento cujas linhas convertem a posição de um diagnóstico.

O de um fragmento pode não estar aberto; nesse caso lemos o arquivo, porque a coluna sem
a linha não converte. Falhando a leitura, o próprio documento serve — a coluna sai
aproximada, e aproximada é melhor que ausente.
"""
function doc_para_posicao(s::Server, d::Document, uri::AbstractString)
    uri == d.uri && return d
    haskey(s.docs, uri) && return s.docs[uri]
    p = path_of(uri)
    isfile(p) || return d
    texto = try; read(p, String); catch; return d; end
    Document(uri, p, 0, texto, linhas_de(texto), Kanon.Loaded(nothing, Kanon.DiagnosticSet()))
end

# --- símbolos ----------------------------------------------------------------

const SYM_FIELD = 8         # Field
const SYM_STRING = 15       # String
const SYM_NAMESPACE = 3     # Namespace
const SYM_KEY = 20          # Key

"""
    document_symbols(doc) -> Vector

A estrutura do arquivo: os campos do contrato e os blocos do texto, cada bloco com os
campos que ele usa aninhados dentro.

É a **primeira coluna** do editor de três colunas, e o `detail` de cada bloco é a
**segunda** — a regra que o governa, ao lado dele.
"""
function document_symbols(d::Document)
    m = d.loaded.model
    m === nothing && return []
    arquivo = file_index(m, isempty(d.path) ? d.uri : d.path)
    out = Any[]

    campos = [f for f in m.template.data.fields if f.span.file == arquivo]
    if !isempty(campos)
        filhos = [(name = String(f.name),
                   detail = detalhe_campo(f),
                   kind = SYM_FIELD,
                   range = lsp_range(d, f.span),
                   selectionRange = lsp_range(d, f.span)) for f in campos]
        push!(out, (name = "data", detail = "o contrato", kind = SYM_NAMESPACE,
                    range = envolver(d, [f.span for f in campos]),
                    selectionRange = lsp_range(d, first(campos).span),
                    children = filhos))
    end

    for b in Kanon.outline(m)
        bloco = block_named(m, b.name)
        bloco === nothing && continue
        bloco.span.file == arquivo || continue          # os do fragmento são do fragmento
        push!(out, (name = String(b.name),
                    detail = detalhe_bloco(b),
                    kind = SYM_KEY,
                    range = lsp_range(d, bloco.span),
                    selectionRange = lsp_range(d, bloco.span.line, bloco.span.col,
                                               bloco.span.line, bloco.span.col),
                    children = [(name = u.path,
                                 detail = detalhe_uso(u),
                                 kind = SYM_STRING,
                                 range = lsp_range(d, u.line, 1, u.line, 1),
                                 selectionRange = lsp_range(d, u.line, 1, u.line, 1))
                                for u in b.fields]))
    end
    out
end

function envolver(d::Document, spans)
    isempty(spans) && return lsp_range(d, 1, 1, 1, 1)
    lsp_range(d, first(spans).line, first(spans).col,
              maximum(sp.endline for sp in spans), maximum(sp.endcol for sp in spans))
end

function detalhe_campo(f::Kanon.FieldDecl)
    marca = f.presence === Kanon.REQUIRED ? "!" :
            f.presence === Kanon.DEFAULTED ? "= padrão" : "opcional"
    card = Kanon.islist(f.card) ? "[]" : ""
    string(f.type, card, " ", marca)
end

function detalhe_bloco(b::Kanon.BlockOutline)
    partes = String[]
    b.label === nothing || push!(partes, b.label)
    b.subject === nothing || push!(partes, "<- " * b.subject)
    b.foreach === nothing || push!(partes, "um por " * b.foreach)
    b.rule === nothing || push!(partes, "quando " * b.rule)
    join(partes, " · ")
end

function detalhe_uso(u::Kanon.FieldUse)
    s = string(u.typename)
    u.formatter === :default || (s *= ":" * String(u.formatter))
    u.nullable && (s *= u.guarded ? " · pode faltar, protegido" : " · PODE FALTAR, sem grupo")
    s
end

# --- hover -------------------------------------------------------------------

markup(texto) = (kind = "markdown", value = String(texto))

"""
    hover(doc, linha, coluna) -> resposta | nothing

O que está sob o cursor, dito com o vocabulário do redator.

Cada resposta é lida de uma tabela da `Analysis` — o tipo resolvido, o formatador
efetivo, se o valor pode faltar, se está protegido por grupo, o número que o bloco
consome. Nada é recalculado aqui: o editor mostra o que o motor sabe, ou não mostra nada.
"""
function hover(d::Document, l::Integer, c::Integer)
    m = d.loaded.model
    m === nothing && return nothing
    arquivo = file_index(m, isempty(d.path) ? d.uri : d.path)
    arquivo == 0 && return nothing
    h = at(m, arquivo, l, c)
    h === nothing && return nothing

    texto = descrever(m, h)
    texto === nothing && return nothing
    (contents = markup(texto), range = lsp_range(d, span_de(h.node)))
end

span_de(n) = n.span

function descrever(m::Kanon.Model, h::Hit)
    n = h.node
    n isa Kanon.FieldDecl && return descrever_campo(m, n)
    n isa Kanon.Interp && return descrever_interp(m, n)
    n isa Kanon.BlockRef && return descrever_remissao(m, n)
    n isa Kanon.Block && return descrever_bloco(m, n)
    n isa Kanon.Group && return "**grupo opcional** — sai inteiro se algum valor direto dele faltar."
    n isa Kanon.FlexPoint &&
        return "**ponto de flexão** `$(n.word)$(n.mark)`\n\n" *
               (Kanon.hasmark(m.env, n.mark) ?
                "A marca `$(n.mark)` está registrada: a palavra flexiona pelo sujeito do bloco." :
                "A marca `$(n.mark)` **não** está registrada neste ambiente, e sai como prosa literal.")
    n isa Kanon.PathExpr && return descrever_caminho_regra(m, n)
    n isa Kanon.AttrExpr &&
        return "**atributo** `$(n.attr)` sobre `$(n.subject)`" *
               (n.negated ? " (negado)" : "")
    return nothing
end

function descrever_campo(m::Kanon.Model, f::Kanon.FieldDecl)
    io = IOBuffer()
    println(io, "**`", f.name, "`** — campo do contrato")
    println(io)
    println(io, "- tipo: `", f.type, "`")
    println(io, "- ", f.presence === Kanon.REQUIRED ? "**obrigatório** (`!`)" :
                     f.presence === Kanon.DEFAULTED ? "tem **valor padrão**" :
                     "**opcional** — toda interpolação dele exige `[...]`")
    Kanon.islist(f.card) && println(io, "- coleção: ", Kanon.card_text(f.card), " valores")
    T = Kanon.typefor(m.env, f.type)
    if T !== nothing
        fs = Kanon.kanon_formats(T)
        isempty(fs) || println(io, "- formatadores: ", join(("`" .* String.(fs) .* "`"), ", "))
    end
    String(take!(io))
end

function descrever_interp(m::Kanon.Model, n::Kanon.Interp)
    rp = Kanon.resolved(m.analysis, n)
    rp === nothing && return "**`{$(n.path)}`** — este caminho não resolveu."
    io = IOBuffer()
    fmt = Kanon.formatter(m.analysis, n)
    println(io, "**`{", n.path, fmt === :default ? "" : ":" * String(fmt), "}`**")
    println(io)
    println(io, "- tipo: `", rp.typename, "`")
    rp.kind === :subject_field && println(io, "- lido pelo **sujeito do bloco**")
    rp.kind === :constant && println(io, "- constante de ambiente")
    if rp.nullable
        println(io, "- **pode faltar** — ",
                m.analysis.guarded[Kanon.id(n)] ?
                "está dentro de um grupo, e o trecho sai junto quando ele falta." :
                "e **não** está dentro de nenhum grupo.")
    else
        println(io, "- o contrato garante que ele está presente")
    end
    String(take!(io))
end

function descrever_remissao(m::Kanon.Model, n::Kanon.BlockRef)
    b = block_named(m, n.target)
    b === nothing && return "**`{::$(n.target)}`** — não há bloco com esse nome."
    pos = blockpos(m, b)
    num = (pos == 0 || isempty(m.analysis.numbering)) ? Int32[] : m.analysis.numbering[pos]
    io = IOBuffer()
    println(io, "**remissão a `", n.target, "`**")
    println(io)
    isempty(num) || println(io, "- rende hoje o número `", join(num, '.'), "`")
    println(io, "- renumera sozinha se um bloco entrar antes dele")
    String(take!(io))
end

function descrever_bloco(m::Kanon.Model, b::Kanon.Block)
    o = findfirst(x -> x.name === b.name, Kanon.outline(m))
    o === nothing && return nothing
    ob = Kanon.outline(m)[o]
    io = IOBuffer()
    println(io, "**bloco `", b.name, "`**", ob.label === nothing ? "" : " — " * ob.label)
    println(io)
    ob.subject === nothing || println(io, "- sujeito: `", ob.subject, "`")
    ob.foreach === nothing || println(io, "- **repete**: um por `", ob.foreach, "`")
    ob.rule === nothing ? println(io, "- sem regra: sai sempre") :
                          println(io, "- **condicional**: `quando ", ob.rule, "`")
    println(io, "- ", ob.paragraphs, ob.paragraphs == 1 ? " parágrafo, " : " parágrafos, ",
            length(ob.fields), length(ob.fields) == 1 ? " campo usado" : " campos usados")
    origem = Kanon.source_of(m.template, b.span)
    println(io, "- vem de `", basename(origem), "`")
    String(take!(io))
end

function descrever_caminho_regra(m::Kanon.Model, e::Kanon.PathExpr)
    rp = Kanon.resolved(m.analysis, e)
    rp === nothing && return "**`$(e.path)`** — este caminho não resolveu."
    "**`$(e.path)`** — tipo `$(rp.typename)`" *
    (rp.nullable ? ", pode faltar" : ", garantido pelo contrato")
end

# --- ir para a definição -----------------------------------------------------

"""
    definition(server, doc, linha, coluna) -> Location | nothing

De uma interpolação para a declaração do campo; de uma remissão para o cabeçalho do
bloco; do sujeito de um bloco para o campo que ele nomeia.

O destino pode estar **em outro arquivo** — um bloco vindo de fragmento —, e é por isso
que a `Location` carrega o URI resolvido pelo índice do trecho, e não o do documento
atual.
"""
function definition(s::Server, d::Document, l::Integer, c::Integer)
    m = d.loaded.model
    m === nothing && return nothing
    arquivo = file_index(m, isempty(d.path) ? d.uri : d.path)
    arquivo == 0 && return nothing
    h = at(m, arquivo, l, c)
    h === nothing && return nothing

    alvo = alvo_de(m, h)
    alvo === nothing && return nothing
    localizacao(s, d, m, alvo)
end

function alvo_de(m::Kanon.Model, h::Hit)
    n = h.node
    if n isa Kanon.Interp
        rp = Kanon.resolved(m.analysis, n)
        rp === nothing && return nothing
        return decl_of(m, rp.decl)
    elseif n isa Kanon.BlockRef
        return block_named(m, n.target)
    elseif n isa Kanon.Block && n.subject !== nothing
        i = findfirst(f -> f.name === first(n.subject.segments), m.template.data.fields)
        return i === nothing ? nothing : m.template.data.fields[i]
    elseif n isa Kanon.PathExpr || n isa Kanon.AttrExpr
        # No plano das regras o salto é o mesmo do plano do texto: do uso para a
        # declaração. `analyze` guarda o caminho resolvido de uma expressão pelo mesmo
        # `NodeId`, e é dele que sai o destino — não de uma segunda resolução aqui.
        rp = Kanon.resolved(m.analysis, n)
        rp === nothing && return nothing
        return decl_of(m, rp.decl)
    end
    return nothing
end

function localizacao(s::Server, d::Document, m::Kanon.Model, alvo)
    sp = alvo.span
    origem = Kanon.source_of(m.template, sp)
    uri = (origem == d.path || isempty(origem)) ? d.uri : uri_of(origem)
    (uri = uri, range = lsp_range(doc_para_posicao(s, d, uri), sp))
end

# --- completar ---------------------------------------------------------------
#
# Completar trabalha sobre o **texto**, e não sobre a árvore, e isso não é preguiça: no
# instante em que alguém pede uma sugestão, o que ele digitou é `{nom` — que não analisa.
# Uma completação que exigisse árvore só funcionaria depois de o redator terminar de
# escrever o que ele queria que ela escrevesse por ele.
#
# O que ela oferece, porém, sai do modelo da **última análise que deu certo**, e não de
# uma varredura própria do texto. É a diferença entre não ter árvore agora e não usar o
# motor nunca.

const KIND_FIELD = 5
const KIND_CLASS = 7
const KIND_KEYWORD = 14
const KIND_VALUE = 12
const KIND_REFERENCE = 18

item(rotulo, kind, detalhe) =
    (label = String(rotulo), kind = kind, detail = String(detalhe))

"""
    completion(doc, linha, coluna) -> Vector

O que cabe na posição. O contexto sai da linha à esquerda do cursor:

| onde o cursor está | o que se oferece |
|---|---|
| `{` … | campos do contrato, campos do sujeito, e `::` para remissão |
| `{caminho:` … | os formatadores **daquele tipo**, e só eles |
| `{::` … | os blocos numerados |
| no plano de dados, depois de `nome :` | os tipos que este ambiente conhece |
| no plano das regras, coluna 1 | os blocos que ainda não têm regra |
"""
function completion(d::Document, l::Integer, c::Integer)
    linha = String(line_at(d, l))
    antes = prefixo(linha, c)

    ctx = contexto_interpolacao(antes)
    ctx === nothing || return completar_interpolacao(d, l, ctx)

    plano = plano_em(d, l)
    plano === :data && ocorre_dois_pontos(antes) && return completar_tipos(d)
    plano === :rules && isempty(strip(antes)) && return completar_blocos_sem_regra(d)
    plano === :rules && return completar_palavras(d)
    return []
end

"O texto da linha antes do cursor, contado em pontos de código."
prefixo(linha::AbstractString, c::Integer) =
    c <= 1 ? "" : String(first(linha, min(Int(c) - 1, length(linha))))

"""
O contexto de interpolação aberto à esquerda do cursor, ou `nothing`.

Devolve `(:path, prefixo)`, `(:formatter, caminho)` ou `(:ref, prefixo)`. Procura de trás
para frente e para no primeiro `{` sem `}` — `{{` é chave literal e não abre nada.
"""
function contexto_interpolacao(antes::AbstractString)
    cs = collect(antes)
    i = length(cs)
    while i >= 1
        c = cs[i]
        c == '}' && return nothing
        if c == '{'
            i > 1 && cs[i - 1] == '{' && return nothing         # `{{`
            corpo = String(cs[(i + 1):end])
            startswith(corpo, "::") && return (:ref, corpo[3:end])
            j = findfirst(':', corpo)
            j === nothing && return (:path, corpo)
            return (:formatter, corpo[1:(j - 1)])
        end
        i -= 1
    end
    return nothing
end

function completar_interpolacao(d::Document, l::Integer, ctx)
    m = d.last_model
    m === nothing && return []
    tipo, arg = ctx

    tipo === :ref && return [item("::" * String(b.name), KIND_REFERENCE, rotulo_de(m, b))
                             for b in m.template.text.blocks if numerado(m, b)]

    if tipo === :formatter
        T = tipo_do_caminho(m, arg)
        T === nothing && return []
        return [item(String(f), KIND_VALUE, "formatador de `" * String(Kanon.kanon_typename(T)) * "`")
                for f in Kanon.kanon_formats(T)]
    end

    out = Any[]
    for f in m.template.data.fields
        push!(out, item(f.name, KIND_FIELD, detalhe_campo(f)))
    end
    b = bloco_da_linha(m, l)
    if b !== nothing && b.subject !== nothing
        rp = caminho_resolvido(m, b.subject)
        T = rp === nothing ? nothing : Kanon.typefor(m.env, rp.typename)
        if T !== nothing
            for spec in Kanon.kanon_schema(T)
                push!(out, item(spec.name, KIND_FIELD,
                                string(spec.type, spec.optional ? " · opcional no sujeito" :
                                                                  " · do sujeito")))
            end
        end
    end
    push!(out, item("::", KIND_REFERENCE, "remissão a um bloco numerado"))
    out
end

"O tipo Julia do caminho escrito, ou `nothing`. Sai da declaração, não de adivinhação."
function tipo_do_caminho(m::Kanon.Model, caminho::AbstractString)
    segs = split(strip(caminho), '.')
    isempty(segs) && return nothing
    i = findfirst(f -> String(f.name) == segs[1], m.template.data.fields)
    i === nothing && return nothing
    T = Kanon.typefor(m.env, m.template.data.fields[i].type)
    for s in segs[2:end]
        T === nothing && return nothing
        esquema = Kanon.kanon_schema(T)
        j = findfirst(spec -> String(spec.name) == s, esquema)
        j === nothing && return nothing
        T = Kanon.typefor(m.env, esquema[j].type)
    end
    T
end

function caminho_resolvido(m::Kanon.Model, p::Kanon.Path)
    i = findfirst(f -> f.name === first(p.segments), m.template.data.fields)
    i === nothing && return nothing
    Kanon.ResolvedPath(:field, m.template.data.fields[i].type, false,
                       m.template.data.fields[i].card, Kanon.id(m.template.data.fields[i]))
end

numerado(m::Kanon.Model, b::Kanon.Block) = b.repeat > 1

function rotulo_de(m::Kanon.Model, b::Kanon.Block)
    pos = blockpos(m, b)
    (pos == 0 || isempty(m.analysis.numbering)) && return "bloco"
    num = m.analysis.numbering[pos]
    isempty(num) ? "bloco" : "hoje é " * join(num, '.')
end

"O bloco cujo trecho cobre a linha, ou `nothing`."
function bloco_da_linha(m::Kanon.Model, l::Integer)
    i = findfirst(b -> b.span.line <= l <= b.span.endline, m.template.text.blocks)
    i === nothing ? nothing : m.template.text.blocks[i]
end

completar_tipos(d::Document) =
    d.last_model === nothing ? [] :
    [item(String(n), KIND_CLASS, "tipo") for n in Kanon.typenames(d.last_model.env)]

function completar_blocos_sem_regra(d::Document)
    m = d.last_model
    m === nothing && return []
    [item(String(b.name), KIND_FIELD, "bloco sem regra")
     for (i, b) in enumerate(m.template.text.blocks)
     if isempty(m.analysis.block_rule) || m.analysis.block_rule[i] == 0]
end

"As palavras-chave do plano das regras, na forma escrita deste arquivo."
function completar_palavras(d::Document)
    m = d.last_model
    m === nothing && return []
    quero = (:when, :one, Symbol("for"), :each, :and, :or, :not, :is, :present, :absent)
    formas = String[]
    for (forma, canon) in m.env.keywords.forms
        canon in quero && push!(formas, forma)
    end
    [item(f, KIND_KEYWORD, "palavra-chave") for f in sort!(formas)]
end

"Há um `:` de declaração de campo à esquerda do cursor?"
ocorre_dois_pontos(antes::AbstractString) = occursin(':', antes)

"""
Em que plano está a linha. Procura para trás o cabeçalho mais próximo na coluna 0,
usando as **formas escritas deste arquivo** — num modelo `pt` o cabeçalho é `dados`.
"""
function plano_em(d::Document, l::Integer)
    kw = d.last_model === nothing ? Kanon.canonical_keywords() : d.last_model.env.keywords
    for i in min(Int(l), length(d.lines)):-1:1
        s = String(d.lines[i])
        s == strip(s) || continue
        k = Kanon.keyword(kw, s)
        k in (:data, :text, :rules) && return k
    end
    return nothing
end
