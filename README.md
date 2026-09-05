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

**Fases 1 a 7 concluídas.** O que existe: léxico, gramática dos três planos,
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

## Regras

Regras só **removem** ou **repetem** blocos — nunca inserem, substituem ou reordenam.
Ler o plano do texto é um limite superior confiável do documento gerado.

```
regras
  outorgante um para cada vendedor
  itbi       quando preco > 0
```

Um bloco por vendedor; a cláusula do imposto só quando há preço. Blocos removidos não
consomem número, e as remissões renumeram junto.

## Domínios

Dois, no mesmo repositório, escritos **só com a API pública**:

| Pacote | O que traz |
|---|---|
| `lib/Extenso` | português: flexão por marca, extenso, datas, separadores |
| `lib/KanonLegal` | `pessoa`, `imovel`, `parte`; o marcador `§` e `CLÁUSULA PRIMEIRA` |
| `lib/KanonScience` | `measure` — valor com incerteza —; o marcador `@` e `Theorem 1` |

`KanonScience` não conhece `Extenso` nem `KanonLegal`, escreve em inglês canônico, e
produz relatórios com o mesmo núcleo que produz a escritura. É a prova, em forma de
pacote, de que a linguagem não é jurídica nem portuguesa — e há um
[teste de neutralidade](test/test_neutralidade.jl) que roda o núcleo **sem camada
nenhuma** e falha se algo tiver vazado.

```julia
env = Environment(locale = :pt, domains = [KanonLegal])
tmpl = load_template(env, "escritura.kanon")
render(tmpl, dados; today = Date(2026, 3, 12))
```

```
João Alves de Souza, brasileiro, casado, portador do CPF 123.456.789-00, residente e
domiciliado na Rua das Acácias, 120, Petrolina/PE, sob o regime da comunhão parcial de
bens, doravante denominado OUTORGANTE VENDEDOR;

Maria Alves de Souza, brasileira, casada, portadora do CPF 987.654.321-00, residente e
domiciliada na Rua das Acácias, 120, Petrolina/PE, doravante denominada OUTORGANTE
VENDEDORA;

CLÁUSULA SEGUNDA. O preço certo e ajustado da presente transação é de R$ 250.000,00
(duzentos e cinquenta mil reais), pago neste ato.

Conforme o disposto na cláusula segunda, as partes se obrigam por si e por seus
sucessores.
```

## Reuso e ingestão

Um modelo inclui fragmentos, e o contrato do fragmento é **unificado** com o do
hospedeiro:

```
texto

: abertura
Contrato de {nome}.

include "clausulas.kanon"
```

Inclusão, e não herança: no ponto em que o fragmento entra está escrito o nome dele, e
ler o modelo continua sendo um limite superior do documento. O carregador tem raiz
configurada e recusa caminho absoluto, travessia e link para fora — um modelo é dado não
confiável.

`Tables.jl` e `JSON3` são **extensões**: quem só quer o motor não carrega nenhum dos
dois.

```julia
using Tables, Kanon
render_each(tmpl, tabela)     # um documento por linha
```

Falta a F8 em diante: saída em Markdown e `.docx`, o editor, e o registro no General.

A especificação normativa está em [`docs/`](docs/README.md); o registro das decisões de
projeto, em [`docs/decisoes.md`](docs/decisoes.md).

Licença: MIT.
