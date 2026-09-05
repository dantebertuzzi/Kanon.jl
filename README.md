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

**Fases 1 a 4 concluídas.** O que existe: léxico, gramática dos três planos,
árvore sintática, o protocolo de tipo com os seis tipos do núcleo, o ambiente, e a
análise completa do modelo sem dados — caminhos, tipos, formatadores, grupos opcionais,
remissões e regras — e a validação dos dados contra o contrato, tudo com erros que
trazem linha, coluna, código estável e sugestão de correção.

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

Os dados também já são verificados contra o contrato:

```julia
check(tmpl, dados)          # DiagnosticSet; vazio quer dizer que passou
```

```
report.kanon: 1 problema encontrado

  contrato, campo obrigatório ausente                             [K3001]
    linha 4, coluna 3: `effect` é exigido pelo modelo (linha 4) e não foi informado.
```

E o contrato vira checklist, em JSON Schema draft 2020-12 — determinístico, para ser
versionado ao lado do modelo:

```julia
contract(tmpl, "escritura.contract.json")
```

E o documento é escrito:

```julia
render(tmpl, dados; today = Date(2026, 3, 12))
```

```
$ kanon render escritura.kanon dados.kdata --today 2026-03-12

1. Constitui objeto desta escritura o imóvel Rua X, 100.

2. O preço ajustado é de BRL 450000.00, pago neste ato.

Ana Silva vende a Bruno Costa o imóvel descrito na 1, pelo preço da 2, em 2026-03-12.
```

O trecho `[, casado sob o regime da {regime},]` saiu inteiro porque `regime` não veio —
com a vírgula que o separava, e sem deixar buraco nem pontuação órfã.

`kanon preview` mostra o rascunho com «marcadores» no lugar do que falta. Não é um modo
leniente: é um comando à parte, a saída é sempre visivelmente marcada, e `kanon render`
continua recusando exatamente os mesmos dados.

## Português

`lib/Extenso` é a camada de idioma, publicável sozinha:

```julia
using Kanon, Extenso
env = Environment(locale = :pt)
```

```
Maria Alves, brasileira, casada, residente e domiciliada, doravante denominada
OUTORGANTE VENDEDORA;

1. O preço certo e ajustado é de R$ 1.234,57 (mil, duzentos e trinta e quatro reais
   e cinquenta e sete centavos), pago neste ato.
```

O modelo que produziu isso escreve `brasileiro(a)`, `domiciliado(a)`, `denominado(a)` e
`VENDEDOR(A)`. **Só a palavra que carrega a marca muda** — `residente`, sem marca, fica
como está mesmo com sujeito plural. Escrever a marca é o consentimento do autor, palavra
a palavra.

Ainda não existem as regras em execução (F5) nem os domínios (F6).

A especificação normativa está em [`docs/`](docs/README.md); o registro das decisões de
projeto, em [`docs/decisoes.md`](docs/decisoes.md).

Licença: MIT.
