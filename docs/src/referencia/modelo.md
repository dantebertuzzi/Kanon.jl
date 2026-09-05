# Modelo e ambiente

O caminho de um documento: um `Environment` diz que camadas existem; `load_template` lê e
analisa; `check` confronta os dados; `render` escreve.

```@docs
Environment
EnvironmentBuilder
load_template
load_string
Model
```

## Registro de nomes

O que uma camada registra no ambiente é **nome**, e nome é local. Comportamento é método,
e método é global e aditivo — a divisão está em D-025.

```@docs
register_type!
register_type_alias!
register_aliases!
register_block_style!
register_inflection!
register_repair_hook!
register_list_joiner!
register_currency!
register_separators!
register_date_pattern!
configure!
configure_locale!
```

## Consulta

```@docs
typefor
typenames
stylefor
hasmark
currency_symbol
FormatContext
```
