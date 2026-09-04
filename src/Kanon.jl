"""
    Kanon

Linguagem de modelos de documento e seu motor.

O modelo declara seu contrato; o que não satisfaz o contrato não renderiza. Tudo mais
no desenho serve a isso.

Esta é a **fase 1**: léxico, gramática dos três planos, árvore sintática e erros de
sintaxe com linha e coluna. Ainda não há validação (F2) nem renderização (F3).

A especificação normativa está em `docs/`; o registro das decisões, em
`docs/decisoes.md`.
"""
module Kanon

using Dates
using Unicode

# A ordem dos `include` segue a dependência conceitual, não a de definição: em Julia,
# funções podem ser definidas em qualquer ordem desde que existam antes da chamada.
include("ast.jl")
include("diagnostics.jl")
include("source.jl")
include("lex.jl")
include("parse.jl")
include("parse_data.jl")
include("parse_text.jl")
include("parse_rules.jl")

# --- árvore ---
export Template, LangVersion
export DataPlane, FieldDecl, Cardinality, CardKind, Presence
export SCALAR, EXACT, ATLEAST, RANGE, ANY
export REQUIRED, OPTIONAL, DEFAULTED
export TextPlane, Block, Paragraph, Group, TextLit, Interp, BlockRef, FlexPoint
export RulesPlane, Rule, RuleExpr, PathExpr, LitExpr, NotExpr, BinExpr, AttrExpr
export Node, Path, Literal, Span, NodeId

# --- diagnóstico ---
export Diagnostic, DiagnosticSet, format_diagnostics
export KanonError, KanonSyntaxError, KanonReferenceError, KanonContractError

# --- entrada ---
export parse_string, parse_file
export KeywordTable, canonical_keywords
export LANGUAGE_VERSION

end # module
