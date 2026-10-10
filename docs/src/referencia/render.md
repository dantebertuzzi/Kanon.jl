# Rendering

`render` is pure: no I/O, no clock, no randomness. `today` is injected. If `analyze` and
`check` passed, the only possible failure is the resource budget.

```@docs
render
preview
Budget
```

## Output formats

An interpolated value never changes the structure of the document (D-028): the author's
prose passes through untouched, and the data is escaped.

```@docs
OutputFormat
PlainText
Markdown
Typst
output_format
Kanon.escape_value
Kanon.heading
Kanon.line_breaks
```

## Elision and seam repair

```@docs
Kanon.repair
Kanon.BlockInstance
Kanon.Plan
```
