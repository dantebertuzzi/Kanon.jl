# Kanon

[![CI](https://github.com/dantebertuzzi/Kanon.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/dantebertuzzi/Kanon.jl/actions/workflows/CI.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Julia](https://img.shields.io/badge/Julia-1.10%2B-9558B2.svg)](https://julialang.org)
[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://dantebertuzzi.github.io/Kanon.jl/dev/)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![Tests](https://img.shields.io/badge/tests-1701-brightgreen.svg)](test/)

**A document template language whose templates declare their own data contract.**
What does not satisfy the contract does not render.

A missing required field stops generation with an error that names the field and points
at the line. It never produces a document with a silent gap.

```
kanon 1

data
  seller : person !
  price  : money  !
  notes  : text

text

: preamble
{seller.name} sells for {price}[, noting that {notes}].
```

The brackets are the point. `notes` is optional, so anything depending on it must sit
inside a group — and when the value is absent the whole group is elided, comma and all.
A template that interpolates an optional value *outside* a group is a **compile-time
error**, not a runtime surprise.

---

## The gap theorem

This is the one claim the project could not find prior art for, and everything else
serves it.

> If `check(tmpl)` passes and `check(tmpl, data)` passes, then `render(tmpl, data)`
> contains no text originating from an absent value, and no text whose reading depends
> on one.

Askama proves the *field* exists. Kanon proves the *gap* never appears — and proves it
before seeing any data. The theorem is not a slogan: it is checked node by node, and a
property test asserts it over a corpus.

Two obligations follow, and they hold for every future version of the language:

- **No mode, option or flag** ever renders with an unsatisfied contract. There is no
  lenient mode, not even as a convenience.
- **No type has a null of its own.** There is no "empty `money`", no "invalid `date`".

Blank text is the hole the gap would crawl back through, and it is closed explicitly:
`""` is an error in a required field and normalized to null — with a listed warning — in
an optional one.

## Where the contract lives

The survey behind this project looked hard for counterexamples, and found plenty of
systems that declare *something*. The defensible claim is narrower than "nobody does
this":

| System | Where the contract lives | Checked when | Prevents gaps? | Readable by a non-programmer |
|---|---|---|---|---|
| Liquid, Mustache | nowhere | — | no | yes |
| Jinja2 `StrictUndefined` | implicit | render, in production | only the field | yes |
| Askama (Rust) | a Rust struct | compile time | only the field | no |
| HotDocs | a component file | assembly | only the field | partly |
| docassemble | YAML + Python | interview | turns it into a question | no |
| CUE / Dhall | the file itself | evaluation | yes, but produces no prose | no |
| **Kanon** | **the template itself** | **before render, without data** | **yes** | **it is the requirement** |

Nobody puts the contract in the same file the non-technical writer edits, and nobody
guarantees statically that an absent value cannot reach the text.

## Three planes, one file

```
kanon 1

data                              # the contract
  witnesses : person[2] !

text                              # what comes out, in the order it comes out
:: payment
Paid in {installments} monthly instalments.

rules                             # rules only remove or repeat blocks
  payment when price > 0
```

The **anti-XSLT invariant**: rules never insert, never substitute, never reorder. Reading
the text plane is therefore a reliable upper bound on the generated document — which is
exactly what XSLT lost by making control flow implicit.

## Getting started

```julia
using Kanon

env  = Environment()                       # the bare core: no language, no domain
tmpl = load_template(env, "report.kanon")

check(tmpl, data)                          # DiagnosticSet; empty means it passed
render(tmpl, data; today = Date(2026, 3, 12))
contract(tmpl, "report.contract.json")     # JSON Schema 2020-12, deterministic
```

Errors are the product, so they carry a stable code, a line, a column, and a fix:

```
report.kanon: 2 problems found

  reference, field does not exist on type                         [K2003]
    line 10, column 1: `person` has no field `nmae`.
    Did you mean `name`? Fields of `person`: name, spouse.

  contract, required field missing                                [K3001]
    line 4, column 3: `effect` is required by the template (line 4) and was not supplied.
```

There is a thin CLI, with the exit codes documented in the spec:

```
kanon check    template.kanon [data.json]
kanon render   template.kanon data.json -o out.md
kanon contract template.kanon
kanon preview  template.kanon [data.json]   # draft with «markers», never exports
```

```
kanon outline  template.kanon              # every block, and the rule that governs it
kanon ask      template.kanon              # asks for what is missing, one at a time
```

`preview` is the only command that produces incomplete output, and it is always visibly
marked. It is not a lenient mode: `render` still refuses exactly the same data.

Neither is `ask`. Whoever asks for a lenient mode almost always wants to see the document
while still gathering the data — so `ask` gathers the data and `preview` shows the draft.
The need was real; the proposed solution was what was wrong.

## The core knows no language and no domain

`Kanon.jl` depends on `Dates` and `Unicode`, and on nothing else. It numbers `1`, `2`,
`3.1`; it emits `0.42` and `2026-03-12`; it joins lists with `", "`. Everything beyond
that is a layer:

| Package | What it adds |
|---|---|
| [`lib/Extenso`](lib/Extenso) | Portuguese: inflection by mark, numbers and dates spelled out, separators |
| [`lib/KanonLegal`](lib/KanonLegal) | `pessoa`, `imovel`, `parte`; the `§` marker and `CLÁUSULA PRIMEIRA` |
| [`lib/KanonScience`](lib/KanonScience) | `measure` — value with uncertainty; the `@` marker and `Theorem 1` |

Layers extend by **multiple dispatch**, never by a registry. The core defines the generic
function and calls it; a layer adds methods.

```julia
format(v, ::Val{name}, ctx) = throw(UnknownFormatter(typeof(v), name))   # core
format(v::Money, ::Val{:extenso}, ctx) = spell_out(v, ctx)               # Extenso
```

`KanonScience` has never heard of `KanonLegal`, writes in canonical English, and produces
reports with the same core that produces a Brazilian deed. That is the proof, in package
form, that the language is neither legal nor Portuguese — and
[`test/test_neutralidade.jl`](test/test_neutralidade.jl) runs the core **with no layer
loaded at all** and fails if anything leaked. CI runs it as a separate job, in an
environment where the layers do not exist.

## Output

```julia
render(tmpl, data; to = :markdown)
```

Three formats — `text`, `markdown`, `typst` — and a rule that matters:

> **An interpolated value never alters the structure of the document.**

The author's prose passes through untouched: `**important**` written in the template
stays bold. A value carrying `*Maria*` comes out as five characters and two asterisks. A
name containing `# Clause` cannot open a heading. It is the concern behind HTML escaping,
for the same reason — with the added weight that the document may be signed.

For `.docx`, `.odt` or PDF the answer is pandoc. Kanon guarantees the content; page
composition belongs to something that knows how to do it:

```
kanon render deed.kanon data.json --to markdown | pandoc -o deed.docx
```

## Reuse and ingestion

A template includes fragments, and the fragment's contract is **unified** with the host's
— same name and same type merge, different types are a load-time error, and the stronger
obligation wins:

```
include "clauses.kanon"
```

Inclusion, not inheritance. The name of what goes in is written at the point where it
goes in. The loader has a configured root and refuses absolute paths, traversal, and
symlinks pointing outside — a template is untrusted data.

`Tables.jl` and `JSON3` are **package extensions**, not dependencies:

```julia
using Tables, Kanon
render_each(tmpl, table)     # one document per row
```

## Status

Phases 1 through 8 are done, and F9 in part. The language is usable end to end: parse, validate, render,
and a CLI.

| Phase | State |
|---|---|
| F0 Specification · F1 Parser · F2 Validator | done |
| F3 Renderer · F4 `Extenso` · F5 Rules · F6 Domains · F7 Ingestion · F8 Output | done |
| F9 Editor | partial — `outline` and `ask` shipped; the GUI is an application |
| F10 Publishing | CI, Aqua and Documenter done; General registration pending |

**Syntax is not frozen.** The gate to 1.0 is fifteen real templates rewritten in the
language — after that there is a corpus, every design mistake becomes permanent, and the
golden suite must render byte-identical on every `1.x` engine.

## A note on language

The code, the tests and this README are in English. **The specification, the decision
record and the engine's diagnostic messages are in Portuguese** — the project is written
in the author's language, and the neutrality invariant is about the *language and the
generated document*, not about which language the engine speaks to its operator
(decision D-027). Translating every message to English would not change a single byte of
any generated document.

The normative documents live in [`docs/`](docs/):

| Document | What it holds |
|---|---|
| [`especificacao.md`](docs/especificacao.md) | the normative spec: lexis, grammar, types, elision, errors, the theorem |
| [`decisoes.md`](docs/decisoes.md) | 27 decisions, each with alternatives, reasoning and date |
| [`api-extensao.md`](docs/api-extensao.md) | the extension protocol — ten generic functions |
| [`ast.md`](docs/ast.md) | the tree, the side tables, and the four invariants |
| [`roadmap.md`](docs/roadmap.md) | where things stand, and what each phase found |

## License

MIT.
