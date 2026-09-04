# F0 — Os dois exemplos, escritos na sintaxe proposta

> Escritos agora, na F0, porque escrever um modelo real é o único jeito honesto de
> descobrir se a gramática funciona. Os dois viram os primeiros *golden tests* e devem
> renderizar exatamente como abaixo ao fim da F6.
>
> Três problemas de especificação foram descobertos ao escrever estes exemplos e estão
> anotados no fim do documento.

---

## 1. Domínio jurídico — `Kanon + Extenso + KanonLegal`

### 1.1 O modelo `escritura.kanon`

```kanon
kanon 1 pt

dados
  vendedor  : pessoa[1..] !
  comprador : pessoa      !
  imovel    : imovel      !
  preco     : dinheiro    !
  data      : data        = hoje

texto

: preambulo
Saibam quantos este público instrumento virem que, aos {data:extenso}, nesta cidade de
Petrolina, Estado de Pernambuco, perante mim, Tabelião, compareceram as partes entre si
justas e contratadas, a saber:

: outorgante <- vendedor
{nome}, brasileiro(a), {estado_civil}, portador(a) do CPF {cpf}, residente e
domiciliado(a) na {endereco}[, sob o regime da {regime}], doravante denominado(a)
OUTORGANTE VENDEDOR(A);

: outorgado <- comprador
{nome}, brasileiro(a), {estado_civil}, portador(a) do CPF {cpf}, residente e
domiciliado(a) na {endereco}, doravante denominado(a) OUTORGADO COMPRADOR(A).

: declaracao <- vendedor
O(s) OUTORGANTE(S) VENDEDOR(ES) declara(m), sob as penas da lei, ser(em) legítimo(s)
proprietário(s) do imóvel ora transacionado, livre e desembaraçado de quaisquer ônus.

§§ objeto
Constitui objeto desta escritura o imóvel {imovel:descricao}, matriculado sob o nº
{imovel.matricula} no Cartório de Registro de Imóveis desta comarca.

§§ preco
O preço certo e ajustado da presente transação é de {preco} ({preco:extenso}), pago
neste ato, em moeda corrente nacional, pelo OUTORGADO ao OUTORGANTE, que lhe dá plena
e geral quitação.

§§ itbi
O imposto de transmissão inter vivos foi recolhido na forma da lei, conforme guia
apresentada e arquivada nestas notas.

: fecho
Conforme o disposto na {::preco}, as partes se obrigam por si e por seus sucessores.

regras
  outorgante  um para cada vendedor
  itbi        quando preco > 0
```

### 1.2 Os dados `escritura.json`

```json
{
  "vendedor": [
    { "nome": "João Alves de Souza", "genero": "m", "estado_civil": "casado",
      "cpf": "123.456.789-00",
      "endereco": "Rua das Acácias, 120, Centro, Petrolina/PE",
      "regime": "comunhão parcial de bens" },
    { "nome": "Maria Alves de Souza", "genero": "f", "estado_civil": "casada",
      "cpf": "987.654.321-00",
      "endereco": "Rua das Acácias, 120, Centro, Petrolina/PE" }
  ],
  "comprador": { "nome": "Ana Beatriz Lima", "genero": "f", "estado_civil": "solteira",
                 "cpf": "111.222.333-44",
                 "endereco": "Avenida Cardoso de Sá, 45, Petrolina/PE" },
  "imovel": { "matricula": "12.345", "tipo": "urbano",
              "descricao": "casa residencial situada na Rua do Sol, nº 300, Petrolina/PE" },
  "preco": { "valor": "250000.00", "moeda": "BRL" },
  "data": "2026-03-12"
}
```

Note dois pontos de propósito: a **segunda vendedora não tem `regime`** (grupo opcional
elide, caso normativo nº 1 da seção 5.3 da especificação) e o **conjunto de vendedores é
misto** (um masculino, uma feminina), exercitando a regra do plural masculino em grupo
misto no bloco `declaracao`.

### 1.3 Saída exigida, byte a byte

```
Saibam quantos este público instrumento virem que, aos doze dias do mês de março do ano
de dois mil e vinte e seis, nesta cidade de Petrolina, Estado de Pernambuco, perante
mim, Tabelião, compareceram as partes entre si justas e contratadas, a saber:

João Alves de Souza, brasileiro, casado, portador do CPF 123.456.789-00, residente e
domiciliado na Rua das Acácias, 120, Centro, Petrolina/PE, sob o regime da comunhão
parcial de bens, doravante denominado OUTORGANTE VENDEDOR;

Maria Alves de Souza, brasileira, casada, portadora do CPF 987.654.321-00, residente e
domiciliada na Rua das Acácias, 120, Centro, Petrolina/PE, doravante denominada
OUTORGANTE VENDEDORA;

Ana Beatriz Lima, brasileira, solteira, portadora do CPF 111.222.333-44, residente e
domiciliada na Avenida Cardoso de Sá, 45, Petrolina/PE, doravante denominada OUTORGADA
COMPRADORA.

Os OUTORGANTES VENDEDORES declaram, sob as penas da lei, serem legítimos proprietários
do imóvel ora transacionado, livre e desembaraçado de quaisquer ônus.

CLÁUSULA PRIMEIRA. Constitui objeto desta escritura o imóvel casa residencial situada
na Rua do Sol, nº 300, Petrolina/PE, matriculado sob o nº 12.345 no Cartório de Registro
de Imóveis desta comarca.

CLÁUSULA SEGUNDA. O preço certo e ajustado da presente transação é de R$ 250.000,00
(duzentos e cinquenta mil reais), pago neste ato, em moeda corrente nacional, pelo
OUTORGADO ao OUTORGANTE, que lhe dá plena e geral quitação.

CLÁUSULA TERCEIRA. O imposto de transmissão inter vivos foi recolhido na forma da lei,
conforme guia apresentada e arquivada nestas notas.

Conforme o disposto na cláusula segunda, as partes se obrigam por si e por seus
sucessores.
```

O que cada detalhe da saída prova:

| Detalhe | Prova |
|---|---|
| `doze dias do mês de março…` | camada de idioma; o núcleo emitiria `2026-03-12` |
| `brasileiro` / `brasileira` | flexão por marca com sujeito singular de gêneros distintos |
| `Petrolina/PE, doravante` na 2ª vendedora | elisão + emenda sem vírgula dupla (caso 1) |
| `Os OUTORGANTES VENDEDORES declaram` | plural misto ⇒ masculino plural |
| `serem`, `legítimos`, `proprietários` | uma marca por palavra; nada além das marcas mudou |
| `CLÁUSULA PRIMEIRA.` | estilo `§` de `KanonLegal`, ordinal por extenso de `Extenso` |
| `cláusula segunda` no fecho | remissão que renumera sozinha |
| `R$ 250.000,00` | formatador padrão de `dinheiro` com locale `pt` |

Sem `Extenso.jl` e sem `KanonLegal.jl` carregados, este mesmo modelo **não carrega**: as
palavras-chave em português, os tipos `pessoa`/`imovel`/`dinheiro`, o marcador `§` e os
formatadores `extenso`/`descricao` são todos desconhecidos, e o erro os nomeia um a um.
Esse é o teste de neutralidade em forma de exemplo.

---

## 2. Domínio científico — `Kanon + KanonScience`, sem camada de idioma

Escrito em inglês canônico e sem nenhuma camada de idioma, de propósito: é a prova de
que a linguagem não é jurídica nem portuguesa.

### 2.1 O modelo `report.kanon`

```kanon
kanon 1

data
  effect  : measure !
  sample  : number  !
  method  : text    !
  caveat  : text

text

: abstract
We estimated the treatment effect over {sample} subjects using {method}.
The estimated effect was {effect}[, with the caveat that {caveat}].

@@ unbiasedness
For any sample of size at least {sample}, the estimator defined above is unbiased.

@@ consistency
The estimator converges in probability to the true effect as the sample grows.

: discussion
By {::unbiasedness}, the value {effect} is reported without further correction.
```

### 2.2 Os dados

```julia
using Kanon, KanonScience, Dates

env  = Environment(domains = [Science])
tmpl = load_template(env, "report.kanon")

dados = (
    effect = Measure(0.42, 0.07, u"mm"),   # valor, incerteza, unidade — tipo Julia real
    sample = 1200,
    method = "ordinary least squares",
    caveat = nothing,
)

render(tmpl, dados)
```

O `Measure` atravessa a fronteira **como `Measure`**. Não há serialização para string no
caminho, e é por isso que o arredondamento de `0.42` e o de `0.07` são coerentes entre si:
quem decide os algarismos significativos é o formatador do tipo, com os dois números em
mãos. Em Quarto ou R Markdown esse acoplamento se perde na fronteira
(`estado-da-arte.md`, seção 8).

### 2.3 Saída exigida

```
We estimated the treatment effect over 1200 subjects using ordinary least squares.
The estimated effect was 0.42 ± 0.07 mm.

Theorem 1. For any sample of size at least 1200, the estimator defined above is
unbiased.

Theorem 2. The estimator converges in probability to the true effect as the sample
grows.

By Theorem 1, the value 0.42 ± 0.07 mm is reported without further correction.
```

Com `Extenso.jl` carregado e `locale = :pt`, **o mesmo modelo em inglês** produziria
`0,42 ± 0,07 mm` e `1.200`: o separador decimal é do idioma, não do tipo. É o menor teste
possível da fronteira entre as camadas, e vale mantê-lo na suíte.

---

## 3. O que estes exemplos descobriram

Escrever os dois modelos revelou três lacunas na especificação inicial. As três já estão
corrigidas em `especificacao.md`; ficam registradas aqui porque o motivo de cada correção
é este exercício.

**3.1 — Onde o número do bloco aparece na saída não estava definido.** A especificação
dizia que `::` numera e que a camada formata o número, mas não dizia se o rótulo vira
parágrafo próprio, prefixo do primeiro parágrafo, ou nada. Resolvido: o estilo declara
`layout` (`:prefix` ou `:heading`) e um separador. O padrão do núcleo é `:prefix` com
`". "`, produzindo `1. Texto`; `KanonLegal` usa `:prefix` com `". "` e o número
`CLÁUSULA PRIMEIRA`.

**3.2 — Marcador de estilo é uma unidade repetida, não uma cadeia fixa.** A seção 9 do
projeto escreve `marker = "§§"`. Mas o nível vem da repetição (D-001), então o que a
camada registra é a **unidade** (`"§"`), e a forma de nível 1 é a unidade duplicada
(`§§`), de nível 2 triplicada (`§§§`). Registrar a cadeia já duplicada tornaria
impossível derivar os níveis. Consequência: a unidade sozinha (`§`) é erro para estilos
numerados — só o núcleo tem forma não-numerada (`:`).

**3.3 — Nomes de tipo precisam de apelido por idioma.** O modelo jurídico em português
escreve `pessoa`, não `person`. Apelido de palavra-chave (seção 9 da especificação) não
cobre isso, porque nome de tipo não é palavra-chave: é um identificador registrado por
uma camada de domínio. Resolvido acrescentando `aliases` a `register_type!`
(`api-extensao.md`, seção 2.2). Sem isso, um modelo em português teria metade do
vocabulário em inglês e o critério 1 cairia na primeira linha do plano de dados.
