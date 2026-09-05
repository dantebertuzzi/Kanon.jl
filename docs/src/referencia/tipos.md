# Tipos e extensão

Um tipo Kanon é um conjunto de métodos de funções genéricas do núcleo. Não há tabela de
despacho mantida à mão, não há registro mutável, não há `eval`.

```@docs
kanon_typename
kanon_schema
kanon_validate
format
kanon_formats
kanon_format_locale
kanon_attribute
kanon_attributes
Kanon.UNIVERSAL_ATTRIBUTES
kanon_getfield
kanon_decode
kanon_compare
FieldSpec
```

## A forma declarativa

```@docs
@kanon_type
```

## Os tipos do núcleo

```@docs
Money
Kanon.NumberValue
```

## Falhas do protocolo

São exceções, e não diagnósticos: acontecem fora de um arquivo de modelo, e portanto não
têm linha nem coluna. `check` e `analyze` as convertem em diagnóstico onde há uma posição
a que atribuí-las.

```@docs
Kanon.KanonProtocolError
UnregisteredType
UnknownFormatter
UnknownAttribute
UndecodableValue
IncomparableValues
```
