# Types and extension

A Kanon type is a set of methods of the core's generic functions. There is no hand-kept
dispatch table, no mutable registry, and no `eval`.

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
kanon_json_schema
kanon_compare
FieldSpec
```

## The declarative form

```@docs
@kanon_type
```

## Core types

```@docs
Money
Kanon.NumberValue
```

## Protocol failures

These are exceptions, not diagnostics: they happen outside a template file, so they have
no line or column. `check` and `analyze` turn them into diagnostics where there is a
position to attribute them to.

```@docs
Kanon.KanonProtocolError
UnregisteredType
UnknownFormatter
UnknownAttribute
UndecodableValue
IncomparableValues
```
