# Plano das regras.
#
#   regra    = ident , ( "when" expr | "one" "for" "each" path )
#   expr     = ou ;  ou = e , { "or" e } ;  e = unaria , { "and" unaria }
#   unaria   = [ "not" ] primaria
#   primaria = "(" expr ")" | comparacao | atributo | path | literal
#
# Sem laços, sem atribuição, sem chamada de função, sem aritmética. A limitação é
# proposital: é o que mantém o modelo analisável estaticamente e seguro.
#
# Precedência, da mais forte para a mais fraca: `is` e comparações, `not`, `and`, `or`.

const COMPARISONS = (("==", :eq), ("!=", :ne), (">=", :ge), ("<=", :le), (">", :gt), ("<", :lt))

"Posição do cursor, para poder voltar atrás sem consumir."
save(c::Cursor) = (c.i, c.line, c.col)

function restore!(c::Cursor, st)
    c.i, c.line, c.col = st
    return c
end

"Lê o próximo identificador sem consumi-lo."
function peek_word(c::Cursor)
    st = save(c)
    skip_blanks!(c)
    w = read_ident!(c)
    restore!(c, st)
    return w
end

"Consome o identificador se ele for a palavra-chave canônica pedida."
function take_keyword!(ctx::ParseCtx, c::Cursor, canon::Symbol)
    st = save(c)
    skip_blanks!(c)
    w = read_ident!(c)
    if w !== nothing && keyword(ctx.kw, w) === canon
        return true
    end
    restore!(c, st)
    return false
end

"Um operando de comparação: caminho ou literal."
function parse_operand!(ctx::ParseCtx, c::Cursor)
    skip_blanks!(c)
    ch = peek(c)
    ch === nothing && return nothing

    if is_ident_start(ch)
        w = peek_word(c)
        if w !== nothing && keyword(ctx.kw, w) in (KW_TRUE, KW_FALSE, :null, :today)
            return read_literal!(ctx, c)
        end
        p = read_path!(ctx, c)
        return p
    end
    return read_literal!(ctx, c)
end

"Envolve um operando num nó de expressão."
function operand_expr(ctx::ParseCtx, op)
    op isa Path && return PathExpr(newid!(ctx), op, op.span)
    op isa Literal && return LitExpr(newid!(ctx), op, op.span)
    return nothing
end

function parse_primary!(ctx::ParseCtx, c::Cursor)
    skip_blanks!(c)
    start = here(c, ctx.fileidx)

    if peek(c) === '('
        advance!(c)
        e = parse_or!(ctx, c)
        e === nothing && return nothing
        skip_blanks!(c)
        if peek(c) !== ')'
            err!(ctx, "K1303", start, "este parêntese não foi fechado.";
                 hint = "Parênteses agrupam condições: `(a and b) or c`.")
            return nothing
        end
        advance!(c)
        return e
    end

    lhs = parse_operand!(ctx, c)
    lhs === nothing && return nothing

    # atributo: `path is [not] nome`
    if lhs isa Path && peek_word(c) !== nothing && keyword(ctx.kw, peek_word(c)) === :is
        take_keyword!(ctx, c, :is)
        negated = take_keyword!(ctx, c, :not)
        skip_blanks!(c)
        attr = read_ident!(c)
        if attr === nothing
            err!(ctx, "K1302", here(c, ctx.fileidx),
                 "esperava o nome de um atributo depois de `is`.";
                 hint = "Atributos do núcleo: `present`, `absent`. Os demais vêm das camadas.")
            return nothing
        end
        # `present` e `absent` são palavras-chave (§9), e em português o autor escreve
        # `presente` e `ausente`. Sem canonicalizar aqui, os dois atributos do núcleo
        # simplesmente não existiriam fora do inglês.
        canonico = keyword(ctx.kw, attr)
        sp = merge_span(lhs.span, Span(ctx.fileidx, c.line, max(Int32(1), c.col - Int32(1))))
        return AttrExpr(newid!(ctx), lhs, canonico === nothing ? Symbol(attr) : canonico,
                        negated, sp)
    end

    # comparação
    skip_blanks!(c)
    r = rest(c)
    for (txt, op) in COMPARISONS
        if startswith(r, txt)
            advance_n!(c, length(txt))
            rhs = parse_operand!(ctx, c)
            rhs === nothing && return nothing
            l = operand_expr(ctx, lhs)
            rr = operand_expr(ctx, rhs)
            sp = merge_span(lhs.span, rhs.span)
            return BinExpr(newid!(ctx), op, l, rr, sp)
        end
    end

    return operand_expr(ctx, lhs)
end

function parse_not!(ctx::ParseCtx, c::Cursor)
    skip_blanks!(c)
    start = here(c, ctx.fileidx)
    if take_keyword!(ctx, c, :not)
        inner = parse_not!(ctx, c)
        inner === nothing && return nothing
        return NotExpr(newid!(ctx), inner, merge_span(start, inner.span))
    end
    return parse_primary!(ctx, c)
end

function parse_and!(ctx::ParseCtx, c::Cursor)
    lhs = parse_not!(ctx, c)
    lhs === nothing && return nothing
    while true
        w = peek_word(c)
        (w !== nothing && keyword(ctx.kw, w) === :and) || break
        take_keyword!(ctx, c, :and)
        rhs = parse_not!(ctx, c)
        rhs === nothing && return nothing
        lhs = BinExpr(newid!(ctx), :and, lhs, rhs, merge_span(lhs.span, rhs.span))
    end
    return lhs
end

function parse_or!(ctx::ParseCtx, c::Cursor)
    lhs = parse_and!(ctx, c)
    lhs === nothing && return nothing
    while true
        w = peek_word(c)
        (w !== nothing && keyword(ctx.kw, w) === :or) || break
        take_keyword!(ctx, c, :or)
        rhs = parse_and!(ctx, c)
        rhs === nothing && return nothing
        lhs = BinExpr(newid!(ctx), :or, lhs, rhs, merge_span(lhs.span, rhs.span))
    end
    return lhs
end

function parse_rule!(ctx::ParseCtx, s::AbstractString, lineno::Integer)
    c = Cursor(s, lineno, 1)
    skip_blanks!(c)
    start = here(c, ctx.fileidx)

    block = read_ident!(c)
    if block === nothing
        err!(ctx, "K1301", start, "esperava o nome de um bloco no início da regra.";
             hint = "Uma regra tem a forma `bloco when <condição>` ou `bloco one for each <lista>`.")
        return nothing
    end

    skip_blanks!(c)
    kwpos = here(c, ctx.fileidx)
    word = read_ident!(c)
    if word === nothing
        err!(ctx, "K1301", kwpos, "esperava `when` ou `one for each` depois de `$block`.";
             hint = "Bloco sem regra é sempre incluído; não escreva o nome sozinho.")
        return nothing
    end

    canon = keyword(ctx.kw, word)

    if canon === :when
        e = parse_or!(ctx, c)
        e === nothing && return nothing
        skip_blanks!(c)
        if !ateof(c)
            err!(ctx, "K1302", here(c, ctx.fileidx),
                 "sobra `$(strip(String(rest(c))))` no fim da condição de `$block`.";
                 hint = "Combine condições com `and`, `or` e parênteses.")
            return nothing
        end
        sp = merge_span(start, e.span)
        return Rule(newid!(ctx), Symbol(block), e, nothing, sp)

    elseif canon === :one
        if !take_keyword!(ctx, c, :for) || !take_keyword!(ctx, c, :each)
            err!(ctx, "K1301", kwpos, "depois de `one` vem `for each`.";
                 hint = "A forma completa é `bloco one for each lista`.")
            return nothing
        end
        skip_blanks!(c)
        p = read_path!(ctx, c)
        if p === nothing
            err!(ctx, "K1301", here(c, ctx.fileidx),
                 "esperava o caminho da lista depois de `one for each`.")
            return nothing
        end
        skip_blanks!(c)
        if !ateof(c)
            err!(ctx, "K1301", here(c, ctx.fileidx),
                 "sobra `$(strip(String(rest(c))))` no fim da regra de `$block`.")
            return nothing
        end
        sp = merge_span(start, p.span)
        return Rule(newid!(ctx), Symbol(block), nothing, p, sp)
    end

    err!(ctx, "K1301", kwpos, "`$word` não abre uma regra.";
         hint = "As duas espécies de regra são `when <condição>` e `one for each <lista>`.")
    return nothing
end

function parse_rules_plane!(ctx::ParseCtx, range)
    rules = Rule[]
    for i in range
        s = strip_comment(line(ctx.src, i))
        isblankline(s) && continue
        r = parse_rule!(ctx, s, i)
        r === nothing || push!(rules, r)
    end
    return RulesPlane(rules)
end
