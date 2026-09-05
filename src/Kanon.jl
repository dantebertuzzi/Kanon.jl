"""
    Kanon

Linguagem de modelos de documento e seu motor.

O modelo declara seu contrato; o que não satisfaz o contrato não renderiza. Tudo mais
no desenho serve a isso.

Esta é a **fase 2, em andamento**: sobre o léxico e a gramática da F1, o protocolo de
tipo e o ambiente. Ainda não há análise de referência (F2.2 em diante) nem renderização
(F3).

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
include("types.jl")
include("environment.jl")
include("core_types.jl")
include("analysis.jl")
include("analyze.jl")
include("check.jl")
include("contract.jl")
include("elide.jl")
include("render.jl")
include("cli.jl")

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

# --- protocolo de tipo ---
export FieldSpec
export kanon_typename, kanon_schema, kanon_validate, kanon_formats
export kanon_attribute, kanon_attributes, kanon_decode, kanon_compare
export kanon_getfield, kanon_format_locale
export format
export Money, NumberValue

# --- ambiente ---
export Environment, EnvironmentBuilder, FormatContext, BlockStyle
export register_type!, register_aliases!, register_block_style!
export register_inflection!, register_repair_hook!, register_currency!
export register_separators!, register_date_pattern!
export register_type_alias!, register_list_joiner!
export configure!, configure_locale!
export typefor, typenames, stylefor, hasmark, currency_symbol
export KanonEnvironmentError, KanonProtocolError
export UnregisteredType, UnknownFormatter, UnknownAttribute
export UndecodableValue, IncomparableValues

# --- análise ---
export Analysis, ResolvedPath, Model
export analyze, load_string, load_template
export Bound, check, bind, value
export contract
export render, preview, Budget, KanonResourceError

# --- linha de comando ---
export main
export resolved, formatter

# --- entrada ---
export parse_string, parse_file
export KeywordTable, canonical_keywords
export LANGUAGE_VERSION

end # module
