# Plano de dados — o contrato.
#
#   decl_campo    = ident , ":" , tipo , [ cardinalidade ] , [ marca ]
#   cardinalidade = "[" , [ inteiro | inteiro ".." [inteiro] | ".." inteiro ] , "]"
#   marca         = "!" | "=" literal
#
# Três estados e apenas três: obrigatório (`!`), com padrão (`=`), opcional (sem marca).
# Um campo é nulável se e somente se é opcional. Essa correspondência é a base do
# teorema da lacuna e não deve ser afrouxada por nenhuma conveniência futura.

"Resto da cadeia a partir do cursor, sem copiar."
rest(c::Cursor) = SubString(c.s, c.i)

function advance_n!(c::Cursor, n::Integer)
    for _ in 1:n
        advance!(c)
    end
end

"""
Lê um literal: número, texto entre aspas, booleano, data ISO, `null` ou `today`.

O literal de data em ISO nu (`2026-01-01`) é inambíguo **porque a linguagem não tem
aritmética**: `2026-01-01` nunca pode ser lido como subtração. É uma vantagem acidental
da limitação do plano das regras, e vale usá-la.

Compartilhado entre o plano de dados e o plano das regras.
"""
function read_literal!(ctx::ParseCtx, c::Cursor)
    start = here(c, ctx.fileidx)
    r = rest(c)

    m = match(r"^(\d{4})-(\d{2})-(\d{2})", r)
    if m !== nothing
        advance_n!(c, length(m.match))
        sp = merge_span(start, Span(ctx.fileidx, c.line, max(Int32(1), c.col - Int32(1))))
        y, mo, d = parse.(Int, m.captures)
        try
            return Literal(:date, Dates.Date(y, mo, d), sp)
        catch
            err!(ctx, "K1104", sp, "`$(m.match)` não é uma data existente.";
                 hint = "Datas são escritas como `AAAA-MM-DD`.")
            return nothing
        end
    end

    m = match(r"^-?\d+(?:\.\d+)?", r)
    if m !== nothing
        advance_n!(c, length(m.match))
        sp = merge_span(start, Span(ctx.fileidx, c.line, max(Int32(1), c.col - Int32(1))))
        v = occursin('.', m.match) ? parse(Float64, m.match) : parse(Int64, m.match)
        return Literal(:number, v, sp)
    end

    if peek(c) === '"'
        advance!(c)
        io = IOBuffer()
        closed = false
        while !ateof(c)
            ch = advance!(c)
            if ch == '\\'
                nxt = advance!(c)
                nxt === nothing && break
                print(io, nxt)
            elseif ch == '"'
                closed = true
                break
            else
                print(io, ch)
            end
        end
        sp = merge_span(start, Span(ctx.fileidx, c.line, max(Int32(1), c.col - Int32(1))))
        if !closed
            err!(ctx, "K1104", sp, "o texto entre aspas não foi fechado.";
                 hint = "Feche com `\"` na mesma linha.")
            return nothing
        end
        return Literal(:text, String(take!(io)), sp)
    end

    word = read_ident!(c)
    if word !== nothing
        sp = merge_span(start, Span(ctx.fileidx, c.line, max(Int32(1), c.col - Int32(1))))
        k = keyword(ctx.kw, word)
        k === KW_TRUE  && return Literal(:boolean, true, sp)
        k === KW_FALSE && return Literal(:boolean, false, sp)
        k === :null   && return Literal(:null, nothing, sp)
        k === :today  && return Literal(:constant, :today, sp)
        err!(ctx, "K1104", sp, "`$word` não é um valor.";
             hint = "Valores possíveis: um número, um texto entre aspas, uma data `AAAA-MM-DD`, `true`, `false`, `null` ou `today`.")
        return nothing
    end

    err!(ctx, "K1104", start, "esperava um valor aqui.";
         hint = "Depois de `=` vem o valor padrão do campo.")
    return nothing
end

"Lê `[2]`, `[1..]`, `[2..5]`, `[..5]` ou `[]`."
function read_cardinality!(ctx::ParseCtx, c::Cursor)
    peek(c) === '[' || return Cardinality()
    start = here(c, ctx.fileidx)
    r = rest(c)

    for (re, build) in (
        (r"^\[\s*\]",                     _ -> Cardinality(ANY, Int32(0), typemax(Int32))),
        (r"^\[\s*(\d+)\s*\]",             m -> Cardinality(EXACT, parse(Int32, m.captures[1]), parse(Int32, m.captures[1]))),
        (r"^\[\s*(\d+)\s*\.\.\s*\]",      m -> Cardinality(ATLEAST, parse(Int32, m.captures[1]), typemax(Int32))),
        (r"^\[\s*(\d+)\s*\.\.\s*(\d+)\s*\]", m -> Cardinality(RANGE, parse(Int32, m.captures[1]), parse(Int32, m.captures[2]))),
        (r"^\[\s*\.\.\s*(\d+)\s*\]",      m -> Cardinality(RANGE, Int32(0), parse(Int32, m.captures[1]))),
    )
        m = match(re, r)
        if m !== nothing
            advance_n!(c, length(m.match))
            card = build(m)
            if card.kind === RANGE && card.lo > card.hi
                err!(ctx, "K1102", start,
                     "a cardinalidade `$(m.match)` tem mínimo maior que o máximo.")
            end
            return card
        end
    end

    err!(ctx, "K1102", start, "cardinalidade malformada.";
         hint = "Formas aceitas: `[]` livre, `[2]` exata, `[1..]` ao menos um, `[2..5]` faixa, `[..5]` no máximo.")
    # Consome até o `]` para não cascatear erro no resto da linha.
    while !ateof(c) && peek(c) !== ']'
        advance!(c)
    end
    ateof(c) || advance!(c)
    return Cardinality()
end

function parse_field_decl!(ctx::ParseCtx, s::AbstractString, lineno::Integer)
    c = Cursor(s, lineno, 1)
    skip_blanks!(c)
    start = here(c, ctx.fileidx)

    name = read_ident!(c)
    if name === nothing
        err!(ctx, "K1101", start, "esperava o nome de um campo no início da linha.";
             hint = "Uma declaração tem a forma `nome : tipo`.")
        return nothing
    end

    skip_blanks!(c)
    if peek(c) !== ':'
        err!(ctx, "K1101", here(c, ctx.fileidx), "esperava `:` depois do nome `$name`.";
             hint = "Uma declaração tem a forma `nome : tipo`.")
        return nothing
    end
    advance!(c)

    skip_blanks!(c)
    tname = read_ident!(c)
    if tname === nothing
        err!(ctx, "K1101", here(c, ctx.fileidx), "esperava o nome de um tipo depois de `:`.";
             hint = "Tipos do núcleo: text, number, money, date, boolean, list.")
        return nothing
    end

    card = read_cardinality!(ctx, c)

    skip_blanks!(c)
    presence = OPTIONAL
    default = nothing

    if peek(c) === '|'
        err!(ctx, "K1106", here(c, ctx.fileidx),
             "tipos-soma não existem na versão 1 da linguagem.";
             hint = "Modele as duas possibilidades como um único tipo composto com um atributo que as distinga (D-006).")
        return nothing
    elseif peek(c) === '!'
        advance!(c)
        presence = REQUIRED
    elseif peek(c) === '='
        advance!(c)
        skip_blanks!(c)
        default = read_literal!(ctx, c)
        default === nothing && return nothing
        presence = DEFAULTED
    end

    skip_blanks!(c)
    if !ateof(c)
        sp = here(c, ctx.fileidx)
        junk = strip(String(rest(c)))
        if peek(c) === '!' || peek(c) === '='
            err!(ctx, "K1103", sp, "o campo `$name` já tem uma marca; `$junk` sobra.";
                 hint = "Um campo é obrigatório (`!`) ou tem padrão (`=`), nunca os dois.")
        else
            err!(ctx, "K1101", sp, "sobra `$junk` no fim da declaração de `$name`.";
                 hint = "Depois do tipo vem, no máximo, a cardinalidade e uma marca.")
        end
        return nothing
    end

    sp = merge_span(start, Span(ctx.fileidx, Int32(lineno), Int32(max(1, length(s)))))
    return FieldDecl(newid!(ctx), Symbol(name), Symbol(tname), card, presence, default, sp)
end

function parse_data_plane!(ctx::ParseCtx, range)
    fields = FieldDecl[]
    seen = Dict{Symbol,Int}()

    for i in range
        s = strip_comment(line(ctx.src, i))
        isblankline(s) && continue
        f = parse_field_decl!(ctx, s, i)
        f === nothing && continue
        if haskey(seen, f.name)
            err!(ctx, "K1105", f.span,
                 "o campo `$(f.name)` já foi declarado na linha $(seen[f.name]).";
                 hint = "Cada campo aparece uma vez no contrato.")
            continue
        end
        seen[f.name] = i
        push!(fields, f)
    end

    return DataPlane(fields)
end
