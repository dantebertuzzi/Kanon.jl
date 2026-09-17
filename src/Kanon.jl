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
#
# A exceção é este primeiro trio, e é de definição: `Template` guarda os avisos da
# leitura (D-055) e `Diagnostic` nasce de um `Span`. `span.jl` carrega o que os dois
# precisam antes de qualquer um deles existir.
include("span.jl")
include("diagnostics.jl")
include("ast.jl")
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
include("include.jl")
include("analyze.jl")
include("rules.jl")
include("check.jl")
include("contract.jl")
include("output.jl")
include("elide.jl")
include("render.jl")
include("outline.jl")
include("cli.jl")
include("macro.jl")

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
export kanon_getfield, kanon_format_locale, kanon_json_schema
export format
export Money, NumberValue
export fixed_number, plain_number, decimal_separator, group_separator

# --- ambiente ---
export Environment, EnvironmentBuilder, FormatContext, BlockStyle
export register_type!, register_aliases!, register_block_style!
export register_inflection!, register_repair_hook!, register_currency!
export register_separators!, register_date_pattern!
export register_type_alias!, register_list_joiner!
export register_attribute_alias!, register_formatter_alias!
export register_term!, term
export configure!, configure_locale!
export @kanon_type
export typefor, typenames, stylefor, hasmark, currency_symbol
export KanonEnvironmentError, KanonProtocolError
export UnregisteredType, UnknownFormatter, UnknownAttribute
export UndecodableValue, UnwritableValue, IncomparableValues

# --- análise ---
export Analysis, ResolvedPath, Model
export analyze, load_string, load_template, load_source, Loaded
export Loader
# `bind` não é exportado: o `Base` exporta um `bind`, e os dois juntos não resolvem — quem
# fizesse `using Kanon` e chamasse `bind(modelo, dados)` recebia `UndefVarError`. Escreve-se
# `Kanon.bind`, e `diagnostics` é o que lê o resultado (D-078).
export Bound, check, value, diagnostics
export rows, render_each, read_json, parse_json
export Plan, BlockInstance
export contract
export outline, format_outline, BlockOutline, FieldUse
export render, preview, Budget, KanonResourceError
export OutputFormat, PlainText, Markdown, Typst, output_format

# --- linha de comando ---
export main
export resolved, formatter

# --- entrada ---
export parse_string, parse_file
export KeywordTable, canonical_keywords
export LANGUAGE_VERSION

end # module
