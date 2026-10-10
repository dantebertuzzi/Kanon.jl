# Kanon

Kanon is a template language for documents in which each template declares the data it
needs. A template whose data does not satisfy that declaration does not render: a
missing required field stops generation with an error naming the field and the line.

Every example on this page runs when the documentation is built, and uses only the core
package — no language or domain layer.

## A first template

```@example guide
using Kanon

report = load_string(Environment(), """
kanon 1

data
  seller : text  !
  price  : money !
  notes  : text

text

: preamble
{seller} sells for {price}[, noting that {notes}].
"""; name = "report.kanon")

render(report, Dict("seller" => "Ana", "price" => Money("1200.50", :USD),
                    "notes" => "payment in cash"))
```

`!` marks a field as required. `notes` is optional, so the text that depends on it sits
inside brackets, and when `notes` is absent the whole bracketed group is left out,
comma included:

```@example guide
render(report, Dict("seller" => "Ana", "price" => Money("1200.50", :USD)))
```

Interpolating an optional value *outside* a group is rejected when the template is
loaded, before any data exists:

```@example guide
try
    load_string(Environment(), """
    kanon 1

    data
      notes : text

    text

    : a
    Note: {notes}.
    """; name = "bad.kanon")
catch err
    showerror(stdout, err)
end
```

And data that leaves out a required field is rejected by `check`, which returns every
problem at once instead of stopping at the first:

```@example guide
check(report, Dict("seller" => "Ana"))
```

The diagnostic messages are in Portuguese — see [Language](@ref) below. Each one carries
a stable code (`K2012`, `K3001`), so tools and tests can match on the code rather than on
the wording.

## The guarantee

> If `check(tmpl)` passes and `check(tmpl, data)` passes, then `render(tmpl, data)`
> contains no text originating from an absent value, and no text whose reading depends
> on one.

Many template engines can fail on a *missing field*. What Kanon checks is narrower and,
as far as the survey in `docs/estado-da-arte.md` found, not covered elsewhere: that no
sentence of the output depends on a value that was not there. The check is done per node
of the template, and a property test asserts it over a corpus.

Two rules follow from it:

- There is no lenient mode. No option renders with an unsatisfied contract.
- No type has a null of its own: there is no "empty `money`". Blank text is an error in a
  required field and is treated as absent, with a warning, in an optional one.

| System | Where the contract lives | Checked when | Prevents gaps? |
|---|---|---|---|
| Liquid, Mustache | nowhere | — | no |
| Jinja2 `StrictUndefined` | implicit | at render | only the field |
| Askama (Rust) | a Rust struct | compile time | only the field |
| HotDocs | a component file | assembly | only the field |
| docassemble | YAML + Python | interview | asks for it |
| **Kanon** | **the template itself** | **before render, without data** | **yes** |

## Data, text and rules

A template has three parts: `data` declares the contract, `text` is the document in the
order it comes out, and `rules` decide which blocks appear.

```@example guide
sale = load_string(Environment(), """
kanon 1

data
  seller       : text   !
  price        : money  !
  installments : number

text

: preamble
{seller} sells for {price}.

:: payment
Paid in {installments} monthly instalments.

rules
  payment when installments > 1
"""; name = "sale.kanon")

print(render(sale, Dict("seller" => "Ana", "price" => Money("3600", :USD),
                        "installments" => 3)))
```

Rules only remove or repeat blocks. They never insert, replace or reorder text, so
reading the `text` part gives an upper bound on what the document can contain.

## Output formats

`render` produces plain text by default, and also `:markdown` and `:typst`. The author's
markup passes through; markup inside a *value* is escaped, so data cannot change the
structure of the document:

```@example guide
signed = load_string(Environment(), """
kanon 1

data
  name : text !

text

: a
Signed by **{name}**.
"""; name = "signed.kanon")

print(render(signed, Dict("name" => "*Maria* # x"); to = :markdown))
```

For `.docx`, `.odt` or PDF, pipe the Markdown through pandoc.

## Command line

```
kanon check    template.kanon [data.json]
kanon render   template.kanon data.json -o out.md
kanon contract template.kanon              # JSON Schema 2020-12
kanon preview  template.kanon [data.json]  # marked draft, never exported
kanon outline  template.kanon              # every block and the rule that governs it
kanon ask      template.kanon [data.json]  # asks for each missing value
```

The exit codes are listed in the specification.

## Layers

The core package knows no natural language and no domain. It numbers blocks `1`, `2`,
`3.1`, prints `0.42` and `2026-03-12`, and joins lists with `", "`. Everything else is a
layer in `lib/`:

| Package | Adds |
|---|---|
| `Extenso` | Portuguese: inflection, numbers and dates spelled out, separators |
| `KanonLegal` | `pessoa`, `imovel`, `parte`; the `§` marker and `CLÁUSULA PRIMEIRA` |
| `KanonScience` | `measure` (value with uncertainty); the `@` marker and `Theorem 1` |

Layers extend the core by adding methods to its generic functions, not through a
registry:

```julia
format(v, ::Val{name}, ctx) = throw(UnknownFormatter(typeof(v), name))   # core
format(v::Money, ::Val{:extenso}, ctx) = spell_out(v, ctx)               # Extenso
```

The test suite runs the core with no layer loaded and fails if anything language- or
domain-specific is found in it.

## Reuse and ingestion

`include "clauses.kanon"` pulls in a fragment, and the fragment's data declarations are
merged with the host's. The loader only reads below a configured root.

`Tables.jl` and `JSON3` are package extensions. With `Tables` loaded,
`render_each(tmpl, table)` produces one document per row, and a dotted column name such
as `load.value` becomes a field of a composite value.

## Language

The code and this page are in English. The specification, the decision record, the
diagnostic messages and, for now, the docstrings in the API reference are in Portuguese,
the author's language. Generated documents are not affected: the language a template is
written in is chosen by the layers loaded, not by the engine.

The normative documents are in the repository: the
[specification](https://github.com/dantebertuzzi/Kanon.jl/blob/main/docs/especificacao.md),
the [decision record](https://github.com/dantebertuzzi/Kanon.jl/blob/main/docs/decisoes.md),
the [extension protocol](https://github.com/dantebertuzzi/Kanon.jl/blob/main/docs/api-extensao.md)
and the [roadmap](https://github.com/dantebertuzzi/Kanon.jl/blob/main/docs/roadmap.md).

## Status

The syntax of language version 1 is frozen: the golden corpus in §13 of the
specification must render byte-identical on every `kanon 1.x` engine. The Julia API is at
`0.1` and may still change.
