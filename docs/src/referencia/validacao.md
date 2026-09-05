# Validação

Três passos, três categorias de erro. Cada um tem o que o anterior não tinha: `parse` não
tem ambiente, `analyze` não tem dados, `render` tem os dois.

```@docs
analyze
Analysis
ResolvedPath
check
Kanon.bind
Bound
contract
```

## Diagnósticos

Erro é interface de usuário aqui, não detalhe de implementação. Todo diagnóstico tem
**código estável**: a suíte afirma sobre o código, e a redação da mensagem pode melhorar
sem quebrar teste.

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
