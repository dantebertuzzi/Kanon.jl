# Kanon

Linguagem de modelos de documento e seu motor, em Julia.

O modelo declara seu contrato de dados; o que não satisfaz o contrato não renderiza.
Campo obrigatório ausente interrompe a geração com um erro que nomeia o campo e aponta
a linha — nunca produz um documento com lacuna silenciosa.

```
kanon 1

data
  seller : person !
  price  : money  !
  notes  : text

text

: preamble
{seller.name} vende pelo preço de {price}[, observado que {notes}].
```

## Estado

**Fase 1 concluída.** O que existe: léxico, gramática dos três planos, árvore sintática
e erros de sintaxe com linha, coluna e código estável.

```julia
using Kanon
tmpl = parse_file("escritura.kanon")   # ou parse_string(texto)
```

Ainda não existe: validação de contrato e referências (F2) nem renderização (F3).

A especificação normativa está em [`docs/`](docs/README.md); o registro das decisões de
projeto, em [`docs/decisoes.md`](docs/decisoes.md).

Licença: MIT.
