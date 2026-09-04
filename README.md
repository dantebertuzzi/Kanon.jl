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

**Fase 1 concluída; fase 2 em curso.** O que existe: léxico, gramática dos três planos,
árvore sintática, erros de sintaxe com linha, coluna e código estável — e, da F2, o
protocolo de tipo, os seis tipos do núcleo e o ambiente.

```julia
using Kanon
tmpl = parse_file("escritura.kanon")   # ou parse_string(texto)

env = Environment()                    # o núcleo puro, sem idioma nem domínio
ctx = FormatContext(env)
format(Money("1234.57", :BRL), Val(:code), ctx)   # "BRL 1234.57"
```

Ainda não existe: análise de referências, validação de contrato (F2.2 em diante) nem
renderização (F3).

A especificação normativa está em [`docs/`](docs/README.md); o registro das decisões de
projeto, em [`docs/decisoes.md`](docs/decisoes.md).

Licença: MIT.
