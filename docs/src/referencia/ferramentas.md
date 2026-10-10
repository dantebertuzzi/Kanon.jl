# Tools

## Ingestion

Package extensions, loaded when `Tables.jl` or `JSON3.jl` is present. The core depends on
neither.

```@docs
rows
render_each
read_json
parse_json
```

## Including fragments

```@docs
Loader
Kanon.compose
```

## Inspection

What an editing tool consumes: the template's structure, already resolved, without
reimplementing the analysis (D-029).

```@docs
outline
BlockOutline
FieldUse
format_outline
```

## Command line

The CLI logic is in `Kanon.main`, which takes the streams as arguments and returns the
exit code instead of ending the process, so the five exit codes can be tested without a
child process.

What that does **not** test is loading: inside a test suite that has already loaded the
layer and `JSON3`, `--domain` and reading `.json` have nothing to load. The flow with a
layer is tested through `bin/kanon`, in a separate process (D-059, D-060).

    kanon check    template.kanon [data.json]
    kanon render   template.kanon data.json [-o out.md] [--to markdown|typst]
    kanon contract template.kanon
    kanon preview  template.kanon [data.json]
    kanon outline  template.kanon
    kanon ask      template.kanon [data] [-o data.json]

With a domain layer: `--locale pt --domain KanonLegal`. For Portuguese with no domain
layer, the language package is loaded the same way: `--locale pt --domain Extenso`
(D-068). `ask` asks for every missing scalar field, checks each answer with `check`, and
writes the data back in the shape it came in: JSON if the input was JSON or if `-o` ends
in `.json` (D-061). A number written the way the document prints it is refused, showing
the expected form, and an ambiguous one (`1.320`, in a language where the dot separates
thousands) is refused with both readings (D-069).

Exit codes: `0` success, `1` contract, `2` template, `3` usage, `4` resources.
