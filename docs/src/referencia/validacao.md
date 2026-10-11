# Validation

Three steps, three categories of error. Each has what the previous one lacked: `parse`
has no environment, `analyze` has no data, `render` has both.

```@docs
analyze
Analysis
ResolvedPath
check
Kanon.bind
Bound
contract
```

## Diagnostics

Errors are user interface here, not an implementation detail. Every diagnostic has a
**stable code**: the test suite asserts on the code, so the wording of a message can
improve without breaking a test. The messages themselves are in Portuguese.

```@docs
Diagnostic
DiagnosticSet
Kanon.CODE_TITLES
format_diagnostics
KanonError
KanonSyntaxError
KanonReferenceError
KanonContractError
KanonEnvironmentError
KanonResourceError
```
