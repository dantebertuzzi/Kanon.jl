# Templates and environments

The path of a document: an `Environment` says which layers exist; `load_template` reads
and analyses; `check` confronts the data; `render` writes.

```@docs
Environment
EnvironmentBuilder
load_template
load_string
Model
```

## Registering names

What a layer registers in the environment is a **name**, and names are local. Behaviour
is methods, and methods are global and additive; the split is in D-025.

```@docs
register_type!
register_type_alias!
register_attribute_alias!
register_formatter_alias!
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

## Lookup

```@docs
typefor
typenames
stylefor
hasmark
currency_symbol
FormatContext
```
