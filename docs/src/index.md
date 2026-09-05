# Kanon

Linguagem de modelos de documento e seu motor.

O modelo declara seu contrato de dados; o que não satisfaz o contrato não renderiza.
Campo obrigatório ausente interrompe a geração com um erro que nomeia o campo e aponta a
linha — nunca produz um documento com lacuna silenciosa.

```kanon
kanon 1

data
  seller : person !
  price  : money  !
  notes  : text

text

: preamble
{seller.name} vende pelo preço de {price}[, observado que {notes}].
```

Os colchetes são o ponto. `notes` é opcional, então tudo que depende dele fica dentro de
um grupo — e quando o valor falta, o grupo inteiro sai, vírgula e tudo. Interpolar um
valor opcional **fora** de um grupo é erro de validação, não surpresa em produção.

## O teorema da lacuna

> Se `check(tmpl)` passa e `check(tmpl, dados)` passa, então `render(tmpl, dados)` não
> contém nenhum trecho originado de valor ausente, nem trecho cuja leitura dependa de um.

É a única afirmação do projeto para a qual o levantamento não encontrou precedente, e
tudo o mais serve a ela. Não é slogan: a implicação é verificada nó a nó, e um teste de
propriedade a afirma sobre um corpus.

## Os documentos normativos

Esta referência descreve a API. O que a linguagem **é** está em documentos separados, no
repositório, e eles são normativos:

| Documento | O que contém |
|---|---|
| [`especificacao.md`](https://github.com/dantebertuzzi/Kanon.jl/blob/main/docs/especificacao.md) | léxico, gramática dos três planos, tipos, elisão, erros, o teorema |
| [`decisoes.md`](https://github.com/dantebertuzzi/Kanon.jl/blob/main/docs/decisoes.md) | as decisões de projeto, com alternativas, motivo e data |
| [`api-extensao.md`](https://github.com/dantebertuzzi/Kanon.jl/blob/main/docs/api-extensao.md) | o protocolo de extensão — dez funções genéricas |
| [`ast.md`](https://github.com/dantebertuzzi/Kanon.jl/blob/main/docs/ast.md) | a árvore, as tabelas laterais e as quatro invariantes |
| [`exemplos.md`](https://github.com/dantebertuzzi/Kanon.jl/blob/main/docs/exemplos.md) | dois documentos reais, com a saída exigida byte a byte |
| [`roadmap.md`](https://github.com/dantebertuzzi/Kanon.jl/blob/main/docs/roadmap.md) | o estado de cada fase, e o que cada uma descobriu |

## As camadas

O núcleo não conhece idioma nem domínio. Ele numera `1`, `2`, `3.1`; emite `0.42` e
`2026-03-12`; junta listas com `", "`. Tudo além disso é camada:

| Pacote | O que acrescenta |
|---|---|
| `Extenso` | português: flexão por marca, extenso, datas, separadores |
| `KanonLegal` | `pessoa`, `imovel`, `parte`; o marcador `§` e `CLÁUSULA PRIMEIRA` |
| `KanonScience` | `measure`; o marcador `@` e `Theorem 1` |

Camadas estendem por **despacho múltiplo**, nunca por registro:

```julia
format(v, ::Val{name}, ctx) = throw(UnknownFormatter(typeof(v), name))   # núcleo
format(v::Money, ::Val{:extenso}, ctx) = dinheiro_extenso(v.amount, v.currency)
```
