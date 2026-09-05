# Renderização

`render` é puro: sem I/O, sem relógio, sem aleatoriedade. `today` é injetado. Se `analyze`
e `check` passaram, a única falha possível é o orçamento.

```@docs
render
preview
Budget
```

## Formatos de saída

O valor interpolado nunca altera a estrutura do documento (D-028): a prosa do autor passa
intacta, o dado é escapado.

```@docs
OutputFormat
PlainText
Markdown
Typst
output_format
Kanon.escape_value
Kanon.heading
```

## Elisão e reparo de emenda

```@docs
Kanon.repair
Kanon.BlockInstance
Kanon.Plan
```
