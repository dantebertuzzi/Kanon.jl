# Plano do texto.
#
#   bloco     = cabecalho , { linha }
#   cabecalho = marcador , ws , ident , [ ws , "<-" , ws , path ]
#
# O cabeçalho ocupa a coluna 0 e a linha inteira. Uma linha é cabeçalho se e somente se
# casa integralmente com a forma acima; caso contrário é prosa. Assim
# `: Considerando o exposto` é prosa, e só `: palavra` isolada colidiria.
#
# Um refinamento sobre a regra escrita na especificação: a presença de `<-` denuncia a
# INTENÇÃO de escrever um cabeçalho (prosa não termina em `<-`). Quando ela aparece e o
# resto não casa, o resultado é erro, não prosa silenciosa.

"""
Reconhece a linha de inclusão: `include "caminho"` na coluna 0.

O nome do que entra está escrito no ponto em que entra — é o que faz a leitura linear
continuar sendo um limite superior do documento, e é a razão de a linguagem ter inclusão
e não herança (D-005).
"""
function parse_include(ctx::ParseCtx, s::AbstractString, lineno::Integer)
    (isempty(s) || s[1] == ' ' || s[1] == '\t') && return nothing
    c = Cursor(s, lineno, 1)
    w = read_ident!(c)
    (w !== nothing && keyword(ctx.kw, w) === :include) || return nothing

    sp = Span(ctx.fileidx, Int32(lineno), Int32(1), Int32(lineno), Int32(max(1, length(s))))
    skip_blanks!(c)
    if peek(c) !== '"'
        err!(ctx, "K1214", sp,
             "a inclusão pede o caminho entre aspas.";
             hint = "Escreva `include \"fragmento.kanon\"`.")
        return nothing
    end
    advance!(c)
    io = IOBuffer()
    fechou = false
    while (ch = advance!(c)) !== nothing
        ch == '"' && (fechou = true; break)
        print(io, ch)
    end
    caminho = String(take!(io))
    if !fechou || isempty(caminho)
        err!(ctx, "K1214", sp,
             fechou ? "a inclusão tem o caminho vazio." : "as aspas da inclusão não fecham.";
             hint = "Escreva `include \"fragmento.kanon\"`.")
        return nothing
    end
    skip_blanks!(c)
    if peek(c) !== nothing
        err!(ctx, "K1214", sp,
             "sobra `$(rest(c))` depois do caminho da inclusão.";
             hint = "A linha de inclusão tem só a palavra e o caminho.")
        return nothing
    end
    return caminho
end

"""
Reconhece um cabeçalho de bloco. Devolve `(unit, repeat, name, subject)` ou `nothing`
se a linha for prosa. Emite diagnóstico apenas quando há intenção clara de cabeçalho.
"""
function block_header!(ctx::ParseCtx, s::AbstractString, lineno::Integer)
    isempty(s) && return nothing
    (s[1] == ' ' || s[1] == '\t') && return nothing
    unit = s[1]
    is_marker_unit(unit) || return nothing

    c = Cursor(s, lineno, 1)
    n = 0
    while peek(c) === unit
        advance!(c)
        n += 1
    end

    # `:#` é comentário do plano do texto (D-012), não cabeçalho.
    n == 1 && peek(c) === '#' && return nothing

    (peek(c) === ' ' || peek(c) === '\t') || return nothing
    skip_blanks!(c)
    name = read_ident!(c)
    name === nothing && return nothing

    skip_blanks!(c)
    subject = nothing

    if !ateof(c)
        # Só `<-` denuncia intenção de cabeçalho; qualquer outra coisa é prosa.
        (peek(c) === '<' && peek(c, 1) === '-') || return nothing
        arrow = here(c, ctx.fileidx)
        advance!(c); advance!(c)
        skip_blanks!(c)
        subject = read_path!(ctx, c)
        if subject === nothing
            err!(ctx, "K1201", arrow,
                 "esperava o caminho de um valor depois de `<-`.";
                 hint = "O sujeito liga o bloco a um valor: `: outorgante <- vendedor`.")
            return nothing
        end
        skip_blanks!(c)
        if !ateof(c)
            err!(ctx, "K1201", here(c, ctx.fileidx),
                 "sobra `$(strip(String(rest(c))))` depois do sujeito do bloco `$name`.";
                 hint = "O cabeçalho termina no caminho do sujeito.")
            return nothing
        end
    end

    if n - 1 > MAX_BLOCK_LEVEL
        err!(ctx, "K1212", Span(ctx.fileidx, Int32(lineno), Int32(1)),
             "o bloco `$name` está no nível $(n - 1), e a versão 1 vai até o nível $MAX_BLOCK_LEVEL.";
             hint = "Níveis são dados pela repetição do marcador: `$(unit)$(unit)` é o nível 1.")
    end

    return (unit, n, Symbol(name), subject)
end

"Lê um caminho `a.b.c` a partir do cursor."
function read_path!(ctx::ParseCtx, c::Cursor)
    start = here(c, ctx.fileidx)
    first = read_ident!(c)
    first === nothing && return nothing
    segs = Symbol[Symbol(first)]
    while peek(c) === '.'
        advance!(c)
        seg = read_ident!(c)
        if seg === nothing
            err!(ctx, "K1205", here(c, ctx.fileidx),
                 "esperava um nome depois do ponto no caminho.";
                 hint = "Um caminho tem a forma `campo` ou `campo.subcampo`.")
            return nothing
        end
        push!(segs, Symbol(seg))
    end
    sp = merge_span(start, Span(ctx.fileidx, c.line, max(Int32(1), c.col - Int32(1))))
    return Path(segs, sp)
end

"Lê um caminho a partir de uma cadeia solta (o miolo de uma interpolação)."
function path_from_string(ctx::ParseCtx, s::AbstractString, sp::Span)
    isempty(s) && return nothing
    segs = Symbol[]
    for part in split(s, '.'; keepempty = true)
        (isempty(part) || !is_ident_start(part[1]) || !all(is_ident_char, part)) && return nothing
        push!(segs, Symbol(part))
    end
    return Path(segs, sp)
end

# --- interpolação ------------------------------------------------------------

"""
Lê `{...}` a partir do `{`. Uma interpolação não atravessa quebra de linha.

Duas sintaxes ficam **reservadas** e erram explicitamente em vez de serem aceitas com
outro significado: encadeamento (`{v:a:b}`, D-007) e argumentos (`{v:round(2)}`).
Reservar agora é o que permite adicioná-las numa versão menor, sem quebrar acervo.
"""
function read_interp!(ctx::ParseCtx, c::Cursor)
    open = here(c, ctx.fileidx)
    advance!(c)   # consome '{'

    io = IOBuffer()
    closed = false
    endl, endc = c.line, c.col
    while !ateof(c)
        ch = peek(c)
        ch === '\n' && break
        pl, pc = c.line, c.col
        advance!(c)
        if ch === '}'
            closed = true
            endl, endc = pl, pc
            break
        end
        print(io, ch)
    end
    content = String(take!(io))
    sp = Span(ctx.fileidx, open.line, open.col, endl, endc)

    if !closed
        err!(ctx, "K1203", open, "esta interpolação não foi fechada com `}`.";
             hint = "Uma interpolação começa e termina na mesma linha. Para uma chave literal, escreva `{{`.")
        return nothing
    end

    if isempty(strip(content))
        err!(ctx, "K1204", sp, "interpolação vazia.";
             hint = "Escreva o nome do campo entre as chaves: `{price}`.")
        return nothing
    end

    body = strip(content)

    if startswith(body, "::")
        target = body[3:end]
        if isempty(target) || !is_ident_start(target[1]) || !all(is_ident_char, target)
            err!(ctx, "K1211", sp, "`{$(body)}` não é uma remissão válida.";
                 hint = "Uma remissão tem a forma `{::nome_do_bloco}`.")
            return nothing
        end
        return BlockRef(newid!(ctx), Symbol(target), sp)
    end

    parts = split(body, ':')
    if length(parts) > 2
        err!(ctx, "K1206", sp,
             "encadeamento de formatadores não existe na versão 1: `{$body}` usa $(length(parts) - 1).";
             hint = "Use um formatador por interpolação. Um formatador composto é registrado na camada, com nome próprio (D-007).")
        return nothing
    end

    pathtext = strip(parts[1])
    path = path_from_string(ctx, pathtext, sp)
    if path === nothing
        err!(ctx, "K1205", sp, "`$pathtext` não é um caminho de campo.";
             hint = "Um caminho tem a forma `campo` ou `campo.subcampo`, com letras, dígitos e `_`.")
        return nothing
    end

    formatter = nothing
    if length(parts) == 2
        f = strip(parts[2])
        if occursin('(', f) || occursin(')', f)
            err!(ctx, "K1207", sp,
                 "argumentos de formatador não existem na versão 1: `$f`.";
                 hint = "Registre um formatador com nome próprio na camada, ou espere a versão 1.1.")
            return nothing
        end
        if isempty(f) || !is_ident_start(f[1]) || !all(is_ident_char, f)
            err!(ctx, "K1205", sp, "`$f` não é um nome de formatador.";
                 hint = "Um formatador é um nome: `{price:written}`.")
            return nothing
        end
        formatter = Symbol(f)
    end

    return Interp(newid!(ctx), path, formatter, sp)
end

# --- varredura de um parágrafo ----------------------------------------------

"""
Varre o conteúdo de um parágrafo produzindo nós.

**Escapes.** Chaves e parênteses escapam por duplicação (`{{`, `}}`, `((`, `))`), porque
nem interpolação nem marca de flexão aninham: `}}` nunca é produzido pela própria
linguagem. Colchetes **não** podem escapar por duplicação, porque grupos aninham e
`[{a}[{b}]]` termina em `]]` legítimo. Colchete literal é `\\[` e `\\]`, e a contrabarra
literal é `\\\\` (D-004, revista na F1).

Um grupo opcional pode atravessar quebra de linha, mas **não** fronteira de parágrafo:
cada parágrafo é varrido isoladamente, e um `[` não fechado até o fim dele é erro. É o
que mantém a árvore em `Bloco → Parágrafo → nós` sem que um grupo fique a cavaleiro de
dois parágrafos. O caso de elidir um parágrafo inteiro continua possível: o grupo abre
e fecha dentro dele.
"""
function scan_run!(ctx::ParseCtx, c::Cursor, stop_at_bracket::Bool)
    children = Node[]
    buf = Char[]
    bline, bcol = c.line, c.col
    lastl, lastc = c.line, c.col
    closed = false

    push_char! = function (ch::Char, l, col)
        if isempty(buf)
            bline, bcol = l, col
        end
        push!(buf, ch)
        lastl, lastc = l, col
    end

    flush! = function ()
        isempty(buf) && return
        push!(children, TextLit(newid!(ctx), String(buf),
                                Span(ctx.fileidx, bline, bcol, lastl, lastc)))
        empty!(buf)
    end

    while !ateof(c)
        ch = peek(c)
        nx = peek(c, 1)
        pl, pc = c.line, c.col

        if ch === '{' && nx === '{'
            advance!(c); advance!(c); push_char!('{', pl, pc)
        elseif ch === '}' && nx === '}'
            advance!(c); advance!(c); push_char!('}', pl, pc)
        elseif ch === '(' && nx === '('
            advance!(c); advance!(c); push_char!('(', pl, pc)
        elseif ch === ')' && nx === ')'
            advance!(c); advance!(c); push_char!(')', pl, pc)
        elseif ch === '\\' && (nx === '[' || nx === ']' || nx === '\\')
            advance!(c); advance!(c); push_char!(nx, pl, pc)

        elseif ch === '{'
            flush!()
            node = read_interp!(ctx, c)
            node === nothing || push!(children, node)

        elseif ch === '['
            flush!()
            advance!(c)
            inner, inner_closed, el, ec = scan_run!(ctx, c, true)
            if !inner_closed
                err!(ctx, "K1208", Span(ctx.fileidx, pl, pc),
                     "este grupo opcional não foi fechado antes do fim do parágrafo.";
                     hint = "Feche com `]`. Para um colchete literal, escreva `[[`.")
            end
            push!(children, Group(newid!(ctx), inner, Span(ctx.fileidx, pl, pc, el, ec)))

        elseif ch === ']'
            if stop_at_bracket
                advance!(c)
                closed = true
                lastl, lastc = pl, pc
                break
            end
            err!(ctx, "K1209", Span(ctx.fileidx, pl, pc),
                 "este `]` fecha um grupo que nunca foi aberto.";
                 hint = "Para um colchete literal, escreva `]]`.")
            advance!(c)

        elseif ch === '('
            m = match(r"^\(([\p{L}]{1,4})\)", rest(c))
            if m !== nothing && !isempty(buf) && isletter(buf[end])
                k = length(buf)
                while k >= 1 && isletter(buf[k])
                    k -= 1
                end
                word = String(buf[(k + 1):end])
                resize!(buf, k)
                wcol = pc - Int32(length(word))
                if !isempty(buf)
                    push!(children, TextLit(newid!(ctx), String(buf),
                                            Span(ctx.fileidx, bline, bcol, pl, wcol - Int32(1))))
                    empty!(buf)
                end
                mark = String(m.match)
                advance_n!(c, length(mark))
                push!(children, FlexPoint(newid!(ctx), word, mark,
                                          Span(ctx.fileidx, pl, wcol, pl, pc + Int32(length(mark)) - Int32(1))))
            else
                advance!(c)
                push_char!('(', pl, pc)
            end

        else
            advance!(c)
            push_char!(ch, pl, pc)
        end
    end

    flush!()
    return children, closed, lastl, lastc
end

# --- montagem do plano -------------------------------------------------------

"""
Aplica o escape de coluna 0: `\\:` produz uma linha de prosa iniciada por dois-pontos,
que de outro modo colidiria com o cabeçalho de bloco. Uma linha iniciada por contrabarra
literal se escreve `\\\\`, e quem cuida disso é o varredor, não esta função.

Consequência conhecida: a linha escapada fica com as colunas deslocadas em um caractere
nos diagnósticos. É o preço de ter exatamente uma contrabarra na linguagem.
"""
function unescape_column0(s::AbstractString)
    startswith(s, "\\:") ? s[2:end] : s
end

function parse_text_plane!(ctx::ParseCtx, range)
    blocks = Block[]
    includes = IncludePoint[]
    seen = Dict{Symbol,Int}()

    # (unit, repeat, name, subject, linha do cabeçalho, linhas de conteúdo)
    current = nothing
    content = Tuple{Int,String}[]

    function close_block!()
        current === nothing && return
        unit, n, name, subject, hl = current
        paras = build_paragraphs!(ctx, content)
        sp = Span(ctx.fileidx, Int32(hl), Int32(1),
                  Int32(isempty(content) ? hl : content[end][1]),
                  Int32(max(1, isempty(content) ? 1 : length(content[end][2]))))
        push!(blocks, Block(newid!(ctx), name, unit, Int8(n), subject, paras, sp))
        current = nothing
        empty!(content)
    end

    for i in range
        s = line(ctx.src, i)

        caminho = parse_include(ctx, s, i)
        if caminho !== nothing
            close_block!()
            push!(includes, IncludePoint(caminho, Int32(length(blocks) + 1),
                                         linespan(ctx, i)))
            continue
        end

        hdr = block_header!(ctx, s, i)
        if hdr !== nothing
            close_block!()
            unit, n, name, subject = hdr
            if haskey(seen, name)
                err!(ctx, "K1202", Span(ctx.fileidx, Int32(i), Int32(1)),
                     "o bloco `$name` já foi declarado na linha $(seen[name]).";
                     hint = "Nomes de bloco são únicos: é por eles que as regras e as remissões apontam.")
            else
                seen[name] = i
            end
            current = (unit, n, name, subject, i)
            continue
        end

        # Comentário do plano do texto: linha inteira iniciada por `:#`.
        startswith(s, ":#") && continue

        if current === nothing
            isblankline(s) && continue
            err!(ctx, "K1210", linespan(ctx, i),
                 "este texto está fora de qualquer bloco.";
                 hint = "Abra um bloco antes: `: nome` na coluna 0.")
            continue
        end

        push!(content, (i, unescape_column0(s)))
    end
    close_block!()

    return TextPlane(blocks, includes)
end

"Agrupa as linhas de um bloco em parágrafos, separados por linha em branco."
function build_paragraphs!(ctx::ParseCtx, content::Vector{Tuple{Int,String}})
    paras = Paragraph[]
    run = Tuple{Int,String}[]

    function close_run!()
        isempty(run) && return
        text = join((t for (_, t) in run), '\n')
        first_line = run[1][1]
        c = Cursor(text, first_line, 1)
        children, _, el, ec = scan_run!(ctx, c, false)
        sp = Span(ctx.fileidx, Int32(first_line), Int32(1), Int32(el), Int32(ec))
        push!(paras, Paragraph(newid!(ctx), children, sp))
        empty!(run)
    end

    for (i, s) in content
        if isblankline(s)
            close_run!()
        else
            push!(run, (i, s))
        end
    end
    close_run!()
    return paras
end
