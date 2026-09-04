# Estrutura do arquivo: pragma de versão e divisão em planos.
#
#   arquivo = pragma , [ plano_dados ] , plano_texto , [ plano_regras ] , EOF
#
# Ordem fixa, cada plano no máximo uma vez, `text` obrigatório. Dois modelos com a
# mesma informação devem ter a mesma forma: a leitura de um acervo de duzentos
# arquivos depende disso mais do que a conveniência de quem escreve o primeiro.

"Versão da linguagem que este motor implementa."
const LANGUAGE_VERSION = LangVersion(1, 0)

"""
    ParseCtx

Estado do parser. É mutável — mas nenhum **nó** é (I1): o que muda aqui é o contador de
identificadores e a lista de diagnósticos, nunca a árvore.
"""
mutable struct ParseCtx
    src::SourceFile
    fileidx::Int32
    kw::KeywordTable
    diags::Vector{Diagnostic}
    nextid::NodeId
end

ParseCtx(src::SourceFile, kw::KeywordTable) = ParseCtx(src, Int32(1), kw, Diagnostic[], NodeId(0))

function newid!(ctx::ParseCtx)
    ctx.nextid += NodeId(1)
    return ctx.nextid
end

function err!(ctx::ParseCtx, code::AbstractString, sp::Span, msg::AbstractString; hint = nothing)
    push!(ctx.diags, Diagnostic(code, :syntax, sp, ctx.src.name, msg; hint))
    return nothing
end

"Trecho que cobre uma linha inteira."
function linespan(ctx::ParseCtx, i::Integer)
    n = length(line(ctx.src, i))
    Span(ctx.fileidx, Int32(i), Int32(1), Int32(i), Int32(max(1, n)))
end

# --- pragma ------------------------------------------------------------------

"""
Lê a linha de versão. Devolve `(versão, idioma, linha em que continuar)`.

O motor recusa modelo cuja versão maior ele não conhece, e também versão menor acima da
sua: `kanon 1.2` num motor 1.1 é erro, porque o modelo declara usar recurso que o motor
não tem. Isso existe porque modelos viram acervo.
"""
function parse_pragma!(ctx::ParseCtx)
    i = 1
    while i <= nlines(ctx.src)
        s = line(ctx.src, i)
        (isblankline(s) || startswith(lstrip(s), '#')) || break
        i += 1
    end

    if i > nlines(ctx.src)
        err!(ctx, "K1002", Span(ctx.fileidx, 1, 1),
             "o arquivo não tem a linha de versão.";
             hint = "Todo modelo começa com `kanon 1` na primeira linha significativa.")
        return LANGUAGE_VERSION, nothing, i
    end

    s = rstrip(line(ctx.src, i))
    sp = linespan(ctx, i)
    parts = split(strip(s))

    if isempty(parts) || parts[1] != "kanon"
        err!(ctx, "K1002", sp,
             "a primeira linha significativa deveria ser a linha de versão, e é `$(strip(s))`.";
             hint = "Escreva `kanon 1` antes de qualquer outra coisa.")
        return LANGUAGE_VERSION, nothing, i
    end

    if length(parts) < 2 || length(parts) > 3
        err!(ctx, "K1003", sp,
             "a linha de versão aceita `kanon <versão>` ou `kanon <versão> <idioma>`, e tem $(length(parts) - 1) argumento(s).";
             hint = "Exemplos: `kanon 1`, `kanon 1.2`, `kanon 1 pt`.")
        return LANGUAGE_VERSION, nothing, i
    end

    vs = parts[2]
    m = match(r"^([0-9]+)(?:\.([0-9]+))?$", vs)
    if m === nothing
        err!(ctx, "K1003", sp,
             "`$vs` não é uma versão de linguagem.";
             hint = "A versão é um inteiro, opcionalmente com uma versão menor: `1` ou `1.2`.")
        return LANGUAGE_VERSION, nothing, i
    end
    major = parse(Int, m.captures[1])
    minor = m.captures[2] === nothing ? 0 : parse(Int, m.captures[2])
    version = LangVersion(major, minor)

    if major != LANGUAGE_VERSION.major
        err!(ctx, "K1004", sp,
             "este modelo pede a versão $major da linguagem; este motor implementa a versão $(LANGUAGE_VERSION.major).";
             hint = "Instale uma versão do Kanon que implemente a linguagem $major.")
    elseif minor > LANGUAGE_VERSION.minor
        err!(ctx, "K1005", sp,
             "este modelo pede a versão $major.$minor da linguagem; este motor implementa a $(LANGUAGE_VERSION).";
             hint = "Atualize o Kanon, ou remova do modelo o que exige a versão $major.$minor.")
    end

    lang = nothing
    if length(parts) == 3
        lang = Symbol(parts[3])
        if ctx.kw.lang !== lang
            available = ctx.kw.lang === nothing ? "apenas o inglês canônico" : "`$(ctx.kw.lang)`"
            err!(ctx, "K1006", sp,
                 "o modelo declara o idioma `$(parts[3])`, e o ambiente tem $available.";
                 hint = "Carregue a camada de idioma correspondente, ou escreva o modelo em inglês canônico.")
        end
    end

    return version, lang, i + 1
end

# --- divisão em planos -------------------------------------------------------

"Reconhece uma linha que é exatamente um cabeçalho de plano na coluna 0."
function plane_header(ctx::ParseCtx, s::AbstractString)
    (isempty(s) || s[1] == ' ' || s[1] == '\t') && return nothing
    word = rstrip(s)
    k = keyword(ctx.kw, word)
    (k === :data || k === :text || k === :rules) ? k : nothing
end

"""
Divide o arquivo em planos. Devolve `Vector{Tuple{Symbol,UnitRange{Int}}}` na ordem em
que aparecem, com o intervalo de linhas **de conteúdo** (sem o cabeçalho).
"""
function split_planes!(ctx::ParseCtx, from::Integer)
    found = Tuple{Symbol,Int,UnitRange{Int}}[]   # (plano, linha do cabeçalho, conteúdo)
    current = nothing
    header_line = 0
    start = 0

    for i in from:nlines(ctx.src)
        s = line(ctx.src, i)
        k = plane_header(ctx, s)
        if k !== nothing
            current === nothing || push!(found, (current, header_line, start:(i - 1)))
            current = k
            header_line = i
            start = i + 1
        elseif current === nothing && !isblankline(s) && !startswith(lstrip(s), '#')
            err!(ctx, "K1010", linespan(ctx, i),
                 "esta linha está fora de qualquer plano.";
                 hint = "O conteúdo de um modelo vive sob `data`, `text` ou `rules`.")
        end
    end
    current === nothing || push!(found, (current, header_line, start:nlines(ctx.src)))

    # Duplicidade e ordem.
    seen = Symbol[]
    for (k, hl, _) in found
        if k in seen
            err!(ctx, "K1011", linespan(ctx, hl),
                 "o plano `$k` já foi declarado antes neste arquivo.";
                 hint = "Cada plano aparece no máximo uma vez; junte as duas partes.")
        else
            push!(seen, k)
        end
    end

    order = Dict(:data => 1, :text => 2, :rules => 3)
    for j in 2:length(found)
        prev, _, _ = found[j - 1]
        k, hl, _ = found[j]
        if order[k] < order[prev]
            err!(ctx, "K1012", linespan(ctx, hl),
                 "o plano `$k` aparece depois de `$prev`.";
                 hint = "A ordem é fixa: `data`, depois `text`, depois `rules`.")
        end
    end

    if !(:text in seen)
        err!(ctx, "K1013", Span(ctx.fileidx, 1, 1),
             "o modelo não tem plano de texto.";
             hint = "Todo modelo precisa de um plano `text`; `data` e `rules` são opcionais.")
    end

    return found
end

# --- entrada -----------------------------------------------------------------

"""
    parse_string(text; name = "<string>", keywords = canonical_keywords()) -> Template

Analisa sintaticamente um modelo. Lança [`KanonSyntaxError`](@ref) com **todos** os
problemas encontrados, não apenas o primeiro — o redator não deve descobrir os
problemas um por rodada.

Esta função **não** consulta um `Environment`: a tabela de palavras-chave chega como
argumento. Um modelo em inglês tem uma única árvore possível, independente das camadas.
"""
function parse_string(text::AbstractString; name::AbstractString = "<string>",
                      keywords::KeywordTable = canonical_keywords())
    src = source_from_text(text, name)
    parse_source(src, keywords)
end

"""
    parse_file(path; keywords = canonical_keywords()) -> Template
"""
function parse_file(path::AbstractString; keywords::KeywordTable = canonical_keywords())
    src = read_source(path)
    parse_source(src, keywords)
end

function parse_source(src::SourceFile, kw::KeywordTable)
    ctx = ParseCtx(src, kw)
    version, lang, next_line = parse_pragma!(ctx)

    # Problema no pragma é fatal. Continuar a analisar um arquivo cuja versão, idioma ou
    # natureza são desconhecidos produz uma cascata de erros que não ajuda ninguém: o
    # redator precisa ver um problema, não vinte consequências dele.
    if !isempty(ctx.diags)
        throw(KanonSyntaxError(sorted(DiagnosticSet(ctx.diags))))
    end

    planes = split_planes!(ctx, next_line)

    data = DataPlane()
    text = TextPlane()
    rules = RulesPlane()
    for (k, _, range) in planes
        if k === :data
            data = parse_data_plane!(ctx, range)
        elseif k === :text
            text = parse_text_plane!(ctx, range)
        elseif k === :rules
            rules = parse_rules_plane!(ctx, range)
        end
    end

    set = sorted(DiagnosticSet(ctx.diags))
    haserrors(set) && throw(KanonSyntaxError(set))

    return Template(version, lang, [src.name], data, text, rules, ctx.nextid)
end
