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
árvore sintática, o protocolo de tipo com os seis tipos do núcleo, o ambiente, e a
análise de caminhos, tipos, formatadores, grupos opcionais, remissões e regras — tudo
com erros que trazem linha, coluna, código estável e sugestão de correção.

```julia
using Kanon

env  = Environment()                    # o núcleo puro, sem idioma nem domínio
tmpl = load_template(env, "escritura.kanon")
```

```
escritura.kanon: 2 problemas encontrados

  referência, campo não existe no tipo                            [K2003]
    linha 10, coluna 1: `person` não tem o campo `nmae`.
    Você quis dizer `name`? Campos de `person`: name, spouse.

  referência, formatador desconhecido                             [K2020]
    linha 10, coluna 25: `writen` não existe para o tipo `money`.
    Formatadores de `money`: code, plain, symbol.
```

O teorema da lacuna já é verificado, e não enunciado: um valor que pode faltar fora de
um grupo opcional é erro, e a ausência que vem de dentro de um tipo composto conta
igual.

```
  referência, valor que pode faltar, fora de grupo opcional       [K2012]
    linha 12, coluna 27: `seller.spouse.name` pode faltar, porque `spouse` é opcional
    em `person`, e está fora de qualquer grupo opcional.
```

Ainda não existe: a semântica das expressões de regra (F2.5), a validação dos dados
contra o contrato (F2.6) nem a renderização (F3).

A especificação normativa está em [`docs/`](docs/README.md); o registro das decisões de
projeto, em [`docs/decisoes.md`](docs/decisoes.md).

Licença: MIT.
