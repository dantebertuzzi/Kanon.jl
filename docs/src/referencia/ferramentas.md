# Ferramentas

## Ingestão

Extensões: carregadas quando `Tables.jl` ou `JSON3.jl` estão presentes. O núcleo não
depende de nenhum dos dois.

```@docs
rows
render_each
read_json
parse_json
```

## Inclusão de fragmentos

```@docs
Loader
Kanon.compose
```

## Inspeção

O que uma ferramenta de edição consome — a estrutura do modelo já resolvida, sem
reimplementar a análise (D-029).

```@docs
outline
BlockOutline
FieldUse
format_outline
```

## Linha de comando

A lógica da CLI está em `Kanon.main`, que recebe os fluxos como argumento e devolve o
código de saída em vez de encerrar o processo — é o que permite testar os cinco códigos
sem processo filho.

    kanon check    modelo.kanon [dados.json]
    kanon render   modelo.kanon dados.json [-o saida.md] [--to markdown]
    kanon contract modelo.kanon
    kanon preview  modelo.kanon [dados.json]
    kanon outline  modelo.kanon
    kanon ask      modelo.kanon [dados]

Códigos de saída: `0` sucesso, `1` contrato, `2` modelo, `3` uso, `4` recurso.
