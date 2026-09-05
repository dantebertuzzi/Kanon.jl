# Kanon — Especificação da linguagem, versão 1 (rascunho F0)

> Estado: **rascunho para aceite**. Nada aqui está congelado; a sintaxe só congela
> depois de quinze modelos reais reescritos (seção 13 do documento de projeto).
>
> Este documento é normativo e deve ser legível sem o código Julia. Onde ele diverge
> da especificação inicial, a divergência está marcada com **[revisão]** e justificada.

## 1. Léxico e estrutura do arquivo

### 1.1 Codificação e normalização

Arquivo `.kanon`, UTF-8 obrigatório, sem BOM (BOM é erro de sintaxe, não é ignorado
silenciosamente). O conteúdo é normalizado para **NFC** na leitura, e identificadores
são comparados após a normalização.

*Por quê:* `José` pode ser escrito com `é` (U+00E9) ou `e`+U+0301. Sem normalização,
dois campos visualmente idênticos são campos diferentes, e o erro resultante é
indepurável. **[revisão]** — a especificação inicial não trata disso.

Fim de linha `\n`; `\r\n` é normalizado para `\n` na leitura. A saída usa `\n`.

### 1.2 Identificadores

```
ident      = letra , { letra | digito | "_" } ;
letra      = ? qualquer ponto de código Unicode das categorias L* ? ;
digito     = ? categoria Nd ? ;
```

Sensíveis a caixa. `seller` e `Seller` são campos distintos — mas dois identificadores
que diferem apenas por caixa no mesmo escopo são **erro de validação**, porque a
distinção é invisível na revisão humana do documento.

### 1.3 Caminhos

```
path = ident , { "." , ident } ;
```

### 1.4 Literais

```
literal     = numero | texto_lit | booleano | data_lit | "null" ;
numero      = [ "-" ] , digito , { digito } , [ "." , digito , { digito } ] ;
texto_lit   = '"' , { caractere - '"' | '\"' | '\\' } , '"' ;
booleano    = "true" | "false" ;
data_lit    = digito*4 , "-" , digito*2 , "-" , digito*2 ;
```

O literal de data em ISO 8601 nu (`2026-01-01`) é inambíguo **porque a linguagem não
tem aritmética**: `2026-01-01` nunca pode ser lido como subtração. É uma vantagem
acidental da limitação do plano das regras, e vale usá-la.

### 1.5 Comentários **[revisão]**

- Nos planos `data` e `rules`: `#` até o fim da linha.
- No plano `text`: **linha inteira** iniciada por `:#` na coluna 0.

*Por quê a divergência:* a especificação inicial diz "comentários com `#` nos três
planos". Isso é incompatível com o alvo de saída Markdown da F8 — `# Título` e
`## Seção` são conteúdo, não comentário, e o conflito seria descoberto tarde e
custaria uma versão maior. No plano do texto, `#` é sempre prosa. A forma `:#` reusa
o sigilo estrutural do plano do texto (a coluna 0 com dois-pontos), portanto não
acrescenta conceito novo.

Comentários não têm efeito algum sobre a saída e não participam do reparo de emenda.

### 1.6 Pragma de versão

Primeira linha significativa (linhas em branco e comentários `#` podem precedê-la):

```
pragma  = "kanon" , ws , versao , [ ws , idioma ] , fim_linha ;
versao  = numero_maior , [ "." , numero_menor ] ;
idioma  = ident ;     (* etiqueta curta de idioma: pt, en, es *)
```

Exemplos: `kanon 1`, `kanon 1.2`, `kanon 1 pt`.

Semântica:

- **Maior desconhecido ⇒ recusa**, com a mensagem dizendo qual versão do motor seria
  necessária. Nunca tenta interpretar.
- **Menor maior que o suportado ⇒ recusa.** `kanon 1.2` num motor 1.1 é erro: o modelo
  declara que usa recurso introduzido em 1.2.
- Menor omitido significa `.0`.
- `idioma` fixa o conjunto de palavras-chave aceito no arquivo (seção 9). Omitido =
  inglês canônico. **[revisão]** — a especificação inicial deixava o idioma implícito;
  declará-lo elimina inferência e melhora a mensagem de erro.

### 1.7 Planos

```
arquivo = pragma , [ plano_dados ] , plano_texto , [ plano_regras ] , EOF ;
```

Ordem **fixa**, cada plano no máximo uma vez, `text` obrigatório. Os cabeçalhos
`data`, `text` e `rules` ocupam a coluna 0 e uma linha inteira.

*Por quê ordem fixa:* dois modelos com a mesma informação devem ter a mesma forma;
a leitura de um acervo de duzentos arquivos depende disso mais do que da conveniência
de quem escreve o primeiro.

Um modelo sem `data` é um documento constante — legítimo, e o menor programa válido.

---

## 2. Plano de dados — o contrato

```ebnf
plano_dados = "data" , fim_linha , { decl_campo | linha_vazia | comentario } ;

decl_campo  = ident , ":" , tipo , [ cardinalidade ] , [ marca ] , fim_linha ;
tipo        = ident ;
cardinalidade = "[" , [ card_corpo ] , "]" ;
card_corpo  = inteiro                        (* exata: [2]      *)
            | inteiro , ".."                 (* mínimo: [1..]   *)
            | inteiro , ".." , inteiro       (* faixa:  [2..5]  *)
            | ".." , inteiro ;               (* máximo: [..5]   *)
marca       = "!" | ( "=" , literal ) | ( "=" , constante ) ;
constante   = "today" ;
```

Exemplo:

```kanon
data
  seller    : person   !
  buyer     : person   !
  property  : property !
  price     : money    !
  date      : date     = today
  witnesses : person[2]
  notes     : text
```

### 2.1 Obrigatoriedade, padrão e nulo

Três estados e apenas três:

| Marca | Estado | Pode ser nulo? | Interpolação exige `[...]`? |
|---|---|---|---|
| `!` | obrigatório | não | não |
| `= lit` | padrão | não (o padrão preenche) | não |
| (nenhuma) | opcional | sim | **sim** |

Um campo é **nulável** se e somente se é opcional. Essa correspondência é a base do
teorema da seção 3 e não deve ser afrouxada por nenhuma conveniência futura.

`[..n]` e `[]` admitem lista vazia; `[]` sem marca continua opcional (ausente ≠ vazia).

### 2.2 Constantes de ambiente

`today` é o único nome reservado de constante na versão 1. Não é lido do relógio: é
**injetado** em `render`. Um modelo que usa `today` e um `render` que não recebe `today`
produzem erro de contrato. Isso torna o princípio do determinismo verificável em vez
de aspiracional.

### 2.3 Nulo, ausência e vazio **[revisão — resposta à questão 15.8]**

Existe **um** conceito de ausência. Na entrada:

| Entrada | Interpretação |
|---|---|
| chave ausente no JSON | nulo |
| `null` no JSON | nulo |
| `nothing` / `missing` em Julia | nulo |
| `""` ou só espaços em campo `text` **obrigatório** | **erro de contrato** |
| `""` ou só espaços em campo `text` **opcional** | normalizado para nulo, com aviso listado por `check` |
| `[]` em campo de lista | lista vazia (não é nulo) |
| chave nos dados que o contrato não declara | **aviso**, e o campo é ignorado (D-022) |

*Por quê:* "chave ausente" e `null` como conceitos distintos seriam um segundo tipo de
ausência, o que a seção 6.3 do documento de projeto proíbe — e a distinção é ruído em
JSON produzido por ferramenta. Já texto em branco é o buraco pelo qual a lacuna
silenciosa voltaria: `[, sob o regime da {regime}]` com `regime = ""` renderiza
`", sob o regime da "` e nenhum princípio teria sido violado formalmente. Tratar branco
como ausência fecha o buraco; tratá-lo como erro quando o campo é obrigatório o fecha
alto. O aviso no caso opcional existe para que a normalização nunca seja silenciosa.

### 2.4 Checklist derivado

`contract(tmpl)` emite **JSON Schema draft 2020-12** descrevendo o objeto de dados,
com as informações que o JSON Schema não expressa sob a chave de extensão `x-kanon`
(formatadores usados, cardinalidade exata, tipo Kanon de origem, linha da declaração).
Ver `api-extensao.md`, seção 7.

---

## 3. Sistema de tipos

### 3.1 A definição da especificação inicial é insuficiente **[revisão]**

A seção 6.3 do documento de projeto define um tipo como "um nome, uma função de
validação, um formatador padrão e um conjunto nomeado de formatadores adicionais.
Nada mais" — e pede explicitamente que se verifique se isso basta para `money`,
`measure` e `person`. **Não basta.** Faltam cinco coisas, cada uma exigida por um
requisito já escrito:

1. **Esquema de campos.** `{seller.name}` precisa saber que `person` tem um campo
   `name` de tipo `text`. Uma função `validate` que devolve `Bool` não informa isso, e
   sem isso `{seller.nmae}` só falha com dados — violando "o modelo deve ser
   verificável sem dados" (6.3) e o erro de referência da seção 7.
2. **Nulabilidade por campo do tipo composto.** Se `person.spouse` é opcional, então
   `{seller.spouse.name}` é nulável e precisa de `[...]`. Sem isso o teorema da lacuna
   vale só para campos de primeiro nível, o que é o mesmo que não valer.
3. **Atributos.** `when property is rural` exige um conjunto de predicados nomeados,
   enumerável para a mensagem de erro.
4. **Decodificador da entrada externa.** Uma `date` vindo de JSON chega como string
   `"2026-03-12"`. Sem coerção implícita, alguém tem de converter, e esse alguém tem de
   ser declarado — senão a proibição de coerção torna JSON inutilizável e a regra é
   burlada na prática.
5. **Comparação.** `price > 0` e `date > 2026-01-01` no plano das regras exigem uma
   ordem definida.

Gênero e número **não** entram aqui: são protocolo da camada de idioma sobre o valor
(`gender(v)`, `number(v)`), não propriedade do tipo. Manter fora é o que preserva a
neutralidade do núcleo.

### 3.2 Definição normativa

Um **tipo** é uma tupla:

```
(nome, esquema, validar, atributos, formatador_padrão, formatadores, decodificar, comparar)
```

| Componente | Obrigatório | Descrição |
|---|---|---|
| `nome` | sim | identificador único no ambiente |
| `esquema` | sim | `()` para escalar, ou lista de `(campo, tipo, opcional?)` |
| `validar` | sim | valor ⟶ `nothing` ou lista de diagnósticos |
| `atributos` | não | conjunto de predicados nomeados |
| `formatador_padrão` | sim | valor × contexto ⟶ texto |
| `formatadores` | não | mapa nome ⟶ (valor × contexto ⟶ texto) |
| `decodificar` | não | valor externo ⟶ valor do tipo, ou erro |
| `comparar` | não | ordem total parcial para o plano das regras |

Em Julia, cada componente é um método de uma função genérica do núcleo
(`api-extensao.md`); a fachada `register_type!` é açúcar.

### 3.3 Tipos do núcleo

| Tipo | Representação Julia | Formatadores do núcleo |
|---|---|---|
| `text` | `AbstractString` | `upper`, `lower`, `title` |
| `number` | `Real` | `integer`, `fixed2` |
| `money` | `Money` (`Rational{Int128}` + moeda) | `symbol`, `code`, `plain` |
| `date` | `Dates.Date` | `iso`, `numeric` |
| `boolean` | `Bool` | — |
| `list` | vetor homogêneo | `count` |

Nenhum deles conhece idioma. `money:symbol` usa o símbolo declarado no ambiente, não
uma convenção nacional embutida; `date:numeric` emite conforme o padrão de data do
ambiente, cujo valor de fábrica é ISO. **Separador decimal e separador de milhar são
do idioma, não do tipo**: o núcleo emite `0.42` e `1200`, e a camada de idioma
substitui por `0,42` e `1.200`. Um tipo composto que formate números (como `measure`)
obtém os separadores do contexto, nunca os embute. Por extenso, ordinal, mês por nome e junção de
lista com conjunção são **da camada de idioma** — o núcleo não os tem.

O formatador padrão de `list` junta os elementos formatados por `", "`. É a única
convenção tipográfica no núcleo, está declarada aqui como tal, e é substituível pela
camada de idioma.

> **Questão aberta (D-033, F10).** O tipo `list` **não é declarável no plano de dados**:
> um campo `x : list` com uma lista de verdade viola a cardinalidade da §2.1. A forma que
> funciona é a cardinalidade sobre o tipo do elemento — `x : text[]` —, que faz tudo o que
> `list` promete e ainda diz de que são os elementos. A decisão entre remover o tipo
> (versão maior) e torná-lo alcançável está aberta até o fim do portão da 1.0.

### 3.4 Coerção

Não há coerção implícita entre tipos, em lugar nenhum. A conversão da entrada externa
(JSON, DataFrame, planilha) para o tipo declarado é feita por `decodificar`, é
explícita, e falha alto. Valor já do tipo correto atravessa a fronteira intacto — um
`Measure` construído em Julia entra no documento como `Measure`, nunca como string.

### 3.5 Resolução de formatador

`{price}` usa o formatador padrão de `money`. `{price:written}` procura `written` entre
os formatadores de `money`. **A resolução acontece na validação do modelo, sem dados.**
Formatador inexistente é erro de referência, com a lista dos disponíveis na mensagem.

---

## 4. Plano do texto

```ebnf
plano_texto = "text" , fim_linha , { bloco } ;

bloco       = cabecalho , { linha_texto | linha_vazia | comentario_texto } ;
cabecalho   = marcador , ws , ident , [ ws , "<-" , ws , path ] , fim_linha ;
marcador    = ":" | "::" { ":" } | marcador_registrado ;
```

O cabeçalho ocupa a coluna 0 e a linha inteira. Uma linha do plano do texto é
cabeçalho **se e somente se** casa integralmente com `cabecalho`; caso contrário é
prosa. Assim `: Considerando o exposto` (que tem texto após o identificador) é prosa,
e apenas `: palavra` isolada colide.

Um refinamento acrescentado na F1: a presença de `<-` denuncia a **intenção** de escrever
um cabeçalho, porque prosa não termina em seta. Quando `<-` aparece e o resto da linha
não casa, o resultado é erro (`K1201`), não prosa silenciosa — que seria a categoria de
defeito que a linguagem existe para impedir. Para escrever uma linha de prosa que começa por
`:` na coluna 0, escreva `\:`; `\\` na coluna 0 produz uma contrabarra literal. Fora
da coluna 0, a contrabarra escapa `[`, `]` e ela mesma (§4.4), e é literal diante de
qualquer outro caractere.

Blocos não aninham no plano do texto. Hierarquia existe apenas para numeração
(seção 6) e é dada pela repetição do marcador.

### 4.1 Parágrafos

O conteúdo de um bloco é uma sequência de **parágrafos**, separados por uma ou mais
linhas em branco. Quebras de linha dentro de um parágrafo são preservadas na saída
verbatim; a camada de saída (F8) decide se são quebras rígidas.

### 4.2 Sujeito

`: grantor <- seller` liga o bloco ao valor de `seller`. Dentro do bloco:

1. um caminho resolve primeiro contra os campos do sujeito;
2. se não resolver, contra os campos de primeiro nível do contrato;
3. se resolver **nos dois**, é **erro de validação por ambiguidade** — nunca uma
   precedência silenciosa.

O sujeito é também o argumento passado à camada de idioma nos pontos de flexão
(seção 7).

### 4.3 Interpolação

```ebnf
interp     = "{" , ( path | ref_bloco ) , [ ":" , ident ] , "}" ;
ref_bloco  = "::" , ident ;
```

- `{caminho}` — formatador padrão do tipo do caminho.
- `{caminho:nome}` — formatador nomeado.
- `{::bloco}` — remissão a bloco numerado (seção 6).
- `{{` e `}}` produzem `{` e `}` literais.

**Um formatador por interpolação na versão 1** (questão 15.7, decisão D-007). A sintaxe
`{v:a:b}` e a sintaxe `{v:round(2)}` são **reservadas**: o lexer as reconhece e emite
erro "encadeamento de formatadores não existe na versão 1", em vez de aceitá-las com
outro significado. Reservar agora é o que permite adicioná-las em 1.x sem versão maior.

### 4.4 Grupos opcionais

```ebnf
grupo = "[" , { conteudo } , "]" ;
```

Aninháveis, mas **nunca atravessam fronteira de parágrafo** (D-016): um `[` não fechado
até a linha em branco seguinte é erro.

`\[` e `\]` produzem `[` e `]` literais, e `\\` produz a contrabarra (D-004, revista na
F1). Colchete é o único delimitador que **não** escapa por duplicação, e o motivo é
estrutural: grupos aninham, então `[{a}[{b}]]` termina em `]]` legítimo, e nenhuma regra
distinguiria esse `]]` de um colchete literal. Chaves e parênteses não têm o problema —
interpolação e marca de flexão não aninham — e continuam escapando por duplicação.

**Resumo dos escapes do plano do texto** (D-018):

| Para escrever | Escreva | Fora daí |
|---|---|---|
| `{` `}` | `{{` `}}` | — |
| `(` `)` | `((` `))` | — |
| `[` `]` | `\[` `\]` | a contrabarra **não** é especial: `\alpha` e `C:\Users` passam intactos |
| `\` | `\\` | |
| `:` na coluna 0 | `\:` | §4 |

A regra em uma frase: **dobre o caractere; o colchete é a exceção, porque grupo cabe
dentro de grupo.** Unificar tudo na contrabarra foi considerado e descartado: `\(` e
`\)` são matemática em linha no LaTeX, e a unificação alteraria em silêncio o texto de
quem escreve relatório científico (D-018).

Colisão conhecida e assumida: `\[` e `\]` também são matemática em bloco no LaTeX. Num
modelo Kanon produzem colchetes literais — não há saída, porque `[` é estrutural aqui.

Uma **interpolação direta** de um grupo é uma interpolação de campo que está
lexicalmente dentro dele e fora de qualquer grupo aninhado nele. Remissões `{::x}` não
contam (nunca são nulas).

**Regra de elisão.** O grupo é elidido se, e somente se, alguma de suas interpolações
diretas resolve para nulo. Grupos aninhados elidem por conta própria e não afetam o
grupo externo.

**Erro de validação.** Um grupo que **não pode elidir** é erro. Há duas formas disso, e
a razão é a mesma nas duas:

- nenhuma interpolação direta (`K2010`, "grupo opcional que nunca elide");
- interpolações diretas todas garantidas pelo contrato — obrigatórias ou com padrão
  (`K2011`). **[acrescentado na F2.3 — D-021]**: a regra de elisão exige que *alguma*
  direta possa ser nula, e uma direta garantida nunca é.

Um grupo com parênteses ou aspas desbalanceados no seu conteúdo é erro (`K2013`,
`K2014`): a elisão deixaria pontuação órfã que o reparo de emenda não conserta. A
contagem atravessa os grupos aninhados, e um parêntese escrito `((` conta como
qualquer outro — o problema não é de onde o caractere veio, e sim que o par dele ficou
do lado de fora. Apóstrofo não é contado como aspa (`d'água` seria falso positivo); as
aspas contadas são as retas.

**Exigência do teorema da lacuna.** Toda interpolação de caminho nulável tem de estar
lexicalmente dentro de pelo menos um grupo (`K2012`). É a verificação que a
demonstração da §14 supõe, e a nulabilidade que ela consulta é a que atravessa o tipo
composto (§3.1): `{seller.spouse.name}` exige grupo mesmo com `seller` obrigatório.

---

## 5. Elisão e reparo de emenda

O algoritmo mais sujeito a bug do projeto (risco 16.4). Especificado aqui como
procedimento determinístico e testável.

### 5.1 Princípio: o reparo é **local à emenda**

Depois de elidir, o motor **não** varre o parágrafo normalizando pontuação. Ele
registra a posição exata de cada remoção — a **emenda** — e aplica as regras abaixo
somente ali.

*Por quê:* um reparo global reescreveria pontuação que o autor digitou de propósito
(uma vírgula dupla numa citação, reticências, um ponto-e-vírgula estilístico). O motor
não tem o direito de editar prosa que ele não removeu. Essa restrição também torna o
algoritmo testável: cada teste tem uma emenda e um resultado.

### 5.2 Procedimento

Para cada parágrafo, na ordem:

1. **Elidir.** Avaliar os grupos de dentro para fora; remover o texto dos elididos;
   registrar cada remoção como uma emenda (posição no texto resultante).
2. **Fundir emendas adjacentes.** Duas emendas separadas apenas por espaços em branco
   viram uma só, cujo contexto é o texto à esquerda da primeira e à direita da segunda.
3. **Aplicar as regras R1–R5**, uma vez, da esquerda para a direita.
4. **Aplicar o gancho da camada de idioma**, se houver (seção 5.4).
5. **Limpar parágrafos.** Linha que ficou só com espaços por causa de uma emenda é
   removida; parágrafo que ficou vazio é removido junto com uma das linhas em branco
   que o cercavam.

Sejam `E` o texto imediatamente à esquerda da emenda e `D` o imediatamente à direita.
Chame **separador** um de `, ; :` e **terminador** um de `. ! ?`.

- **R1 — espaço.** Espaços e tabulações que atravessam a emenda colapsam em um único
  espaço. Se a emenda está no início da linha, colapsam para nada; se está no fim da
  linha, colapsam para nada.
- **R2 — separador duplicado.** Se a emenda produz `sep₁ ws* sep₂` com ambos
  separadores, mantém-se `sep₁` e descarta-se o resto até `sep₂` inclusive.
- **R3 — separador antes de terminador.** `sep ws* term` ⟶ `term`.
- **R4 — separador no fim do parágrafo.** Separador que, por causa da emenda, ficou
  como último caractere não-branco do parágrafo é removido.
- **R5 — separador no início.** Separador que ficou como primeiro caractere não-branco
  de uma linha por causa da emenda é removido, e aplica-se R1.

**Terminador nunca é removido**, por nenhuma regra.

### 5.3 Os casos normativos

Todos viram arquivo em `test/golden/emenda/` **antes** da implementação (risco 16.4).

| # | Modelo | Dados | Saída exigida |
|---|---|---|---|
| 1 | `na {address}[, sob o regime da {regime}], doravante` | `regime` nulo | `na Rua X, doravante` |
| 2 | `{a}[, {b}][, {c}], fim` | `b`,`c` nulos | `A, fim` |
| 3 | `Valor de {v}[ ({obs})].` | `obs` nulo | `Valor de 10.` |
| 4 | `[{titulo} ]{nome}` | `titulo` nulo | `Fulano` |
| 5 | `{a}, [{b}], {c}` | `b` nulo | `A, C` (R2) |
| 6 | `lista: {a}, [{b}].` | `b` nulo | `lista: A.` (R3) |
| 7 | `{a}[, {b}]` | `b` nulo | `A` |
| 8 | `{a}[ e {b}], {c}` | `b` nulo | `A, C` |
| 9 | `[{a}, ]{b}` | `a` nulo | `B` (R5) |
| 10 | `Comprou [{q} de ]{item}[ por {p}].` | `q`,`p` nulos | `Comprou casa.` |
| 11 | `{a}[, {b}[ e {c}]], fim` | `c` nulo, `b` presente | `A, B, fim` |
| 12 | `{a}[, {b}[ e {c}]], fim` | `b` nulo | `A, fim` |
| 13 | parágrafo inteiro dentro de `[...]` elidido | — | parágrafo e uma linha em branco removidos |

Os casos 11 e 12 são os que fixam a regra de aninhamento e devem ser escritos primeiro.

### 5.4 Gancho de idioma

O núcleo repara pontuação latina. Uma camada de idioma pode registrar
`repair_hook(idioma)` para (a) recapitalizar a primeira palavra de uma frase cujo
início foi elidido e (b) tratar pontuação não-latina. **O núcleo nunca mexe em caixa**
— capitalizar é regra de idioma.

---

## 6. Blocos numerados e remissões

### 6.1 Sintaxe

```
:: payment
O preço será pago em {installments:written} parcelas mensais.

::: payment_late
Em caso de atraso, ...
```

`::` é nível 1, `:::` nível 2, `::::` nível 3.

Um estilo registra uma **unidade de marcador** de um caractere, tirada de um conjunto
fechado pela versão da linguagem — na versão 1: `:` `§` `¶` `@` `%` `&` `*` `+` `~` `^`
`†` `‡`. O conjunto é fechado porque o marcador precisa ser reconhecível **sem consultar
o ambiente** (uma camada registra `§`, mas o parser não a conhece), e um conjunto aberto
transformaria qualquer linha de prosa iniciada por pontuação em candidata a cabeçalho.

O nível *n* é a unidade repetida *n*+1 vezes. O núcleo registra a unidade `:`, cuja forma simples (`:`) é o bloco
não numerado. Um estilo de camada registra, por exemplo, a unidade `§`: `§§` é nível 1,
`§§§` é nível 2, e `§` sozinho é erro — só o núcleo tem forma não numerada. Cada estilo
tem seu próprio contador.

**Numeração aninhada entra na versão 1** (questão 15.1, decisão D-001).

### 6.2 Semântica

- Cada **estilo** (marcador) tem sua própria família de contadores.
- Um bloco de nível *n* incrementa o contador de nível *n* e zera os de nível > *n*.
- Um bloco de nível *n* > 1 sem bloco de nível *n*−1 antes dele, no mesmo estilo, é erro.
- A numeração é calculada num passo de análise e vive numa **tabela lateral**, nunca
  dentro do nó da árvore (ver `ast.md`).
- Blocos removidos por regra **não** consomem número. Blocos repetidos por
  `one for each` consomem um número por iteração.

### 6.3 Remissão

`{::nome}` rende o texto de remissão do estilo. Remissão a bloco inexistente é erro de
referência (`K2033`, sem dados). Remissão a bloco **repetido** por `one for each` é erro
(`K2034`): não há como nomear uma instância. Remissão a bloco que uma regra pode remover
é **aviso** (`K2035`) — não erro, porque o autor pode saber que as duas condições
coincidem, mas ele precisa ser avisado.

**[acrescentado na F2.3/F2.4]** Remissão a bloco **não numerado** é erro (`K2038`): a
remissão rende um número, e o bloco de forma simples não tem nenhum. E os marcadores
são resolvidos contra o ambiente aqui: uma unidade sem estilo registrado é `K2030`, e a
forma simples de uma unidade que não seja `:` é `K2032` — só o núcleo tem forma não
numerada (§6.1).

A checagem de sequência de níveis da §6.2 é **estática** — nível 2 sem nível 1 antes é
erro sem dados (`K2031`) — e por isso acontece na validação do modelo, e não com os
contadores.

**[acrescentado na F10 — D-032]** O plano das regras pode produzir em execução o estado
que essa checagem proíbe no texto: um bloco de nível 1 condicional, seguido de um bloco
de nível 2 que não está preso à mesma condição. Removido o primeiro, o segundo fica sem o
nível anterior, e o contador do nível 1 nunca incrementado o rotula `0.1` — um número que
não existe. É **aviso** (`K2039`), pela mesma razão do `K2035`: as duas condições podem
coincidir de propósito. O reconhecimento é conservador — só a igualdade estrutural das
duas condições dispensa o aviso.

Formato do número e da remissão vêm das camadas (`register_block_style!`). O núcleo,
sozinho, numera `1`, `2`, `3.1` e remete como `3.1`.

### 6.4 Onde o rótulo aparece **[revisão]**

A especificação inicial não dizia se o número vira parágrafo próprio ou prefixo. O
estilo declara:

- `layout = :prefix` — o rótulo prefixa o primeiro parágrafo do bloco, seguido do
  `separator` declarado. Padrão do núcleo, com `separator = ". "`, produzindo `1. Texto`.
- `layout = :heading` — o rótulo ocupa um parágrafo próprio antes do conteúdo.

`KanonLegal` usa `:prefix` com `". "` e número `CLÁUSULA PRIMEIRA`, produzindo
`CLÁUSULA PRIMEIRA. Constitui objeto…`.

---

## 7. Pontos de flexão

### 7.1 O que o núcleo enxerga

O núcleo **não conhece flexão**. Ele conhece um conjunto de **marcas** registrado pela
camada de idioma. Uma marca é uma cadeia curta entre parênteses, e um **ponto de
flexão** é a ocorrência de uma marca registrada imediatamente colada (sem espaço) ao
fim de uma palavra:

```
portador(a)      →  ponto de flexão: palavra="portador", marca="(a)"
domiciliado(a)   →  ponto de flexão: palavra="domiciliado", marca="(a)"
item (a)         →  não é ponto de flexão (há espaço)
((a))            →  literal "(a)"
```

O núcleo entrega `(palavra, marca, sujeito)` à camada de idioma e insere no lugar o
texto devolvido. Não interpreta a marca, não conhece gênero, não conhece número.

**Quem decide o quê, e quando** (precisado na F1). O parser não pode consultar o ambiente
(`ast.md` §8), logo não sabe quais marcas estão registradas. Então o léxico reconhece
apenas a **forma** — uma a quatro letras entre parênteses, coladas ao fim de uma palavra —
e produz um nó candidato. É `analyze`, que tem o ambiente, quem decide: marca registrada
vira ponto de flexão; marca não registrada vira prosa literal `palavra + marca`. Um
`casa(s)` num modelo sem camada de idioma sai exatamente como `casa(s)`.

### 7.2 Invariante: só a marca muda **[revisão]**

A especificação inicial diz "com sujeito plural, o bloco pluraliza". Lido em sentido
amplo — o motor pluralizando palavras arbitrárias da prosa — isso é inaceitável:
seria reescrita automática de texto que o autor digitou, sem controle e com erros
impossíveis de prever.

**Invariante normativo:** apenas a palavra portadora de uma marca é alterada. Todo o
resto da prosa é imutável. `portador(a)` com sujeito feminino plural vira `portadoras`
porque a camada de idioma recebe a palavra inteira e a marca; `residente e
domiciliado(a)` vira `residentes e domiciliadas` **apenas se** ambas as palavras
tiverem marca — `residente(s) e domiciliado(a)`. Escrever a marca é o consentimento do
autor.

### 7.3 Escape

`((a))` produz `(a)` literal. Como o ponto de flexão exige colagem à palavra e a marca
tem de estar no conjunto registrado, a taxa de falso positivo é baixa; onde ela ocorrer
(nome próprio, sigla — risco 16.3), o escape é por marca e é suficiente, porque o
invariante 7.2 garante que nada além da marca é tocado.

---

## 8. Plano das regras

```ebnf
plano_regras = "rules" , fim_linha , { regra | linha_vazia | comentario } ;
regra        = ident , ws , ( "when" , ws , expr | "one" , ws , "for" , ws , "each" , ws , path ) , fim_linha ;

expr      = ou ;
ou        = e , { "or" , e } ;
e         = unaria , { "and" , unaria } ;
unaria    = [ "not" ] , primaria ;
primaria  = "(" , expr , ")" | comparacao | atributo | path ;
comparacao = operando , op_comp , operando ;
op_comp   = "==" | "!=" | ">" | "<" | ">=" | "<=" ;
operando  = path | literal ;
atributo  = path , "is" , [ "not" ] , ident ;
```

Precedência, da mais forte para a mais fraca: `is` / comparações → `not` → `and` → `or`.
Parênteses permitidos e recomendados. Sem laços, sem atribuição, sem chamada de função,
sem aritmética.

### 8.1 Tipagem das expressões

Não há veracidade implícita. Um `path` isolado só é expressão booleana se o seu tipo
for `boolean`. `when notes` é erro; escreva `when notes is present`.

`present` e `absent` são atributos do núcleo, aplicáveis a qualquer campo. Todos os
demais atributos vêm das camadas.

Comparação entre valor tipado e literal só é válida se o tipo declarar `comparar` para
aquele literal. `price > 0` funciona porque `money` compara com número; `date >
2026-01-01` funciona porque `date` compara com literal de data; `name > 3` é erro de
validação (`K2043`).

**[precisões da F2.5]**

- A exigência vale para os **seis** operadores, `==` e `!=` inclusive. Igualdade não é
  um caso à parte: um tipo que não sabe se ordenar com outro também não sabe se comparar
  com ele, e abrir exceção para `==` faria o redator descobrir a diferença por acidente.
- A ordem dos operandos não importa: `0 < price` vale tanto quanto `price > 0`.
- Comparar com `null` é erro (`K2044`), e não uma forma de testar ausência: ausência não
  é valor. A mensagem manda escrever `is absent`.
- `is present` sobre um campo que o contrato garante é **aviso** (`K2047`): a condição é
  uma tautologia e a regra que depende dela nunca remove nada. Aviso, e não erro, porque
  um modelo em edição passa legitimamente por esse estado.

### 8.2 Uma regra de cada espécie por bloco **[resposta à questão 15.2]**

Um bloco admite **no máximo um `when`** e **no máximo um `one for each`**. Duas linhas
`when` para o mesmo bloco são **erro**, não conjunção implícita. Para combinar, escreva
uma expressão com `and`/`or`.

*Por quê:* "como duas regras se combinam" é precisamente a pergunta que um leitor não
deveria ter de fazer. Um `and` implícito seria adivinhado errado por metade dos
leitores, e a metade que adivinhasse certo estaria confiando numa convenção invisível.

### 8.3 Iteração

`bloco one for each C` exige que `C` seja de tipo lista e que o cabeçalho do bloco
declare `<- C` — o mesmo caminho. A redundância é deliberada: o plano do texto precisa
ser legível sozinho, e `<- seller` é o que diz ao leitor do texto o que `{name}`
significa.

Dentro do bloco iterado, o identificador do caminho denota o **elemento corrente**,
tanto no texto quanto no `when` do próprio bloco. Assim:

```kanon
rules
  grantor        one for each seller
  grantor        when seller is not minor
```

lê-se "um bloco `grantor` para cada vendedor, exceto os menores", e o `when` é avaliado
por iteração. O bloco não tem acesso à coleção inteira; se precisar, use outro bloco.

### 8.4 Invariante anti-XSLT

> **Regras só removem ou repetem blocos. Nunca inserem, nunca substituem, nunca
> reordenam.**

Consequência: a ordem dos blocos na saída é sempre a ordem do plano do texto, e a
leitura linear do plano do texto é um limite superior confiável do documento. É o que
distingue este plano de um stylesheet XSLT (ver `estado-da-arte.md`, seção 6), e é o
que torna o risco 16.2 tratável por ferramenta.

Bloco sem regra é sempre incluído. Regra referenciando bloco inexistente é erro.

---

## 9. Localização

A camada de idioma registra apelidos para as palavras-chave. Com `Extenso.jl` carregado
e `kanon 1 pt` no cabeçalho:

| Canônico | pt |
|---|---|
| `data` | `dados` |
| `text` | `texto` |
| `rules` | `regras` |
| `when` | `quando` |
| `one for each` | `um para cada` |
| `and` / `or` / `not` | `e` / `ou` / `não` |
| `is` / `present` / `absent` | `é` / `presente` / `ausente` |
| `today` | `hoje` |

O arquivo canônico é o inglês: um motor sem nenhuma camada instalada lê qualquer
modelo em inglês.

**Mistura é erro** (questão 15.3, decisão D-003). O idioma é o declarado no pragma, ou
inglês se omitido; qualquer palavra-chave fora desse conjunto é erro de sintaxe com a
sugestão do termo correto. Marcadores de bloco registrados (`§§`) e o operador `<-` são
símbolos, não palavras-chave, e não participam da restrição.

---

## 10. Modelo de erros

### 10.1 Categorias

| Categoria | Tipo Julia | Quando | Precisa de dados? |
|---|---|---|---|
| Sintaxe | `KanonSyntaxError` | leitura | não |
| Referência | `KanonReferenceError` | validação do modelo | não |
| Contrato | `KanonContractError` | validação dos dados | sim |

Todas descendem de `KanonError`. Renderização, depois de modelo e dados validados, não
tem categoria de erro própria — exceto os limites de recurso da seção 11.

### 10.2 Diagnóstico

Um diagnóstico carrega: **código estável** (`K1042`), severidade (`error` | `warning`),
arquivo, linha, coluna, extensão, caminho do campo quando aplicável, mensagem e
sugestão. Códigos estáveis são exigência de teste (a suíte afirma sobre o código, não
sobre a redação) e de ferramenta (o editor da F9 mapeia código a ação).

**[revisão]** — a especificação inicial não previa códigos; sem eles, todo ajuste de
redação quebra a suíte, e a suíte passa a desencorajar melhorar mensagens.

### 10.3 Acumulação e ordem

Todos os erros de uma categoria são acumulados e reportados juntos. A ordem é
determinística: por arquivo, linha, coluna, código. Um erro de sintaxe suprime as fases
seguintes (não há árvore para validar); erros de referência e de contrato são
reportados juntos quando ambos são possíveis.

### 10.4 Formato

```
escritura.kanon: 3 problemas encontrados

  contrato, campo obrigatório ausente                              [K3001]
    'price' é exigido pelo modelo (linha 6) e não foi informado.

  contrato, tipo incompatível                                      [K3010]
    'date' espera uma data; foi recebido o texto "12/03/2026".
    Se for uma data, informe-a como data, não como texto.

  referência, formatador desconhecido                              [K2020]
    linha 24: 'written' não existe para o tipo 'text'.
    Formatadores disponíveis para 'text': upper, lower, title.
```

Regras de redação, normativas: nomear o campo; apontar linha; dizer o que se esperava e
o que veio; sugerir a correção provável quando houver uma; nunca usar vocabulário de
implementação (`AST`, `token`, `Val{:written}`, `MethodError`).

---

## 11. Modelo de segurança

Um modelo é dado não confiável. Garantias exigidas, cada uma com teste adversarial
próprio:

1. Renderizar **não executa código Julia** do modelo. Não há `eval`, não há chamada de
   função a partir do modelo.
2. Renderizar **não lê nem escreve arquivo**. A inclusão de blocos (F7) passa por um
   carregador explícito com raiz configurada; caminho que escape da raiz, link
   simbólico que aponte para fora e caminho absoluto são erro.
3. Renderizar **não acessa rede**.
4. **Só campos declarados** são acessíveis. Um objeto com campos extras não os expõe.
   Não há acesso reflexivo.
5. **Sem recursão infinita**: inclusão cíclica é detectada e erra.
6. **Orçamento determinístico** de recursos **[revisão]**: máximo de nós visitados,
   de bytes de saída, de profundidade de inclusão e de iterações. Excedido, erra.

*Por quê orçamento e não tempo:* um limite de tempo de parede torna **não determinístico
se o render erra ou não** — a mesma entrada erra numa máquina lenta e passa numa
rápida —, o que contradiz o princípio do determinismo. Limite de tempo continua
existindo, mas no processo da CLI, não na semântica da linguagem.

---

## 12. Interface de linha de comando

```
kanon check    modelo.kanon                 # valida só o modelo
kanon check    modelo.kanon dados.json      # valida modelo e dados
kanon render   modelo.kanon dados.json -o saida.md
kanon contract modelo.kanon                 # JSON Schema 2020-12 + x-kanon
kanon preview  modelo.kanon dados.json      # rascunho com «marcadores», nunca exporta
```

Códigos de saída: `0` sucesso; `1` erro de contrato (dados); `2` erro de modelo
(sintaxe ou referência); `3` erro de uso da CLI; `4` limite de recurso excedido.
`kanon preview` sai com `0` e escreve o aviso no *stderr* mesmo com campos faltando —
é o único comando que produz saída incompleta, e ela é sempre visivelmente marcada.

Candidato para a F9, herdado do docassemble: `kanon ask modelo.kanon dados.json`
pergunta os campos faltantes um a um e emite o JSON completo. Atende à necessidade real
por trás do pedido de "modo leniente" sem relaxar nada.

---

## 13. Política de compatibilidade

**SemVer estrito** para o pacote; versão da **linguagem** independente, declarada no
arquivo.

Pode mudar em **versão menor da linguagem** (aditivo):

- novas palavras-chave e apelidos, **apenas em posições onde antes havia erro**;
- novos tipos, formatadores e atributos do núcleo;
- afrouxamento que torna válido um modelo antes inválido;
- novas mensagens e novos códigos de diagnóstico (códigos existentes não mudam de
  significado).

Exige **versão maior da linguagem**:

- qualquer alteração de semântica existente, inclusive de espaçamento e pontuação;
- remoção ou renomeação de palavra-chave, tipo, formatador ou atributo;
- mudança no algoritmo de elisão ou no reparo de emenda.

**Definição operacional, e é a que vale em disputa:**

> O corpus golden da versão 1 deve renderizar **byte a byte idêntico** em todo motor
> `1.x`. Uma mudança que altere um byte do corpus é versão maior, qualquer que seja a
> justificativa.

O corpus golden é versionado junto com a especificação e nunca é editado para
acomodar uma mudança de motor. Depreciação: uma versão menor inteira emitindo aviso
antes da remoção na maior seguinte.

---

## 14. Teorema da lacuna

**Enunciado.** Se `check(tmpl)` passa e `check(tmpl, dados)` passa, então
`render(tmpl, dados)` não contém nenhum trecho originado de valor ausente, nem trecho
de texto cuja leitura dependa de um valor ausente.

**Demonstração.** Um valor pode ser nulo apenas se o campo for opcional (2.1) ou se um
campo de tipo composto for opcional (3.1, item 2). A validação do modelo exige que toda
interpolação de caminho nulável esteja lexicalmente dentro de pelo menos um grupo (4.4).
Todo grupo cuja interpolação direta seja nula é elidido (4.4). Portanto nenhuma
interpolação nulável chega ao texto com valor nulo. As interpolações não-nuláveis
correspondem a campos obrigatórios ou com padrão, cuja presença o contrato garante
(2.1) e cuja ausência é erro de contrato antes do render. Texto em branco não é nulo
por acidente: é erro no campo obrigatório e nulo no opcional (2.3). ∎

**Consequências que devem ser mantidas em toda evolução da linguagem:**

- Nenhum modo, opção ou flag pode permitir renderizar com contrato insatisfeito.
- Nenhum tipo pode ter valor nulo próprio ("`money` vazio", "`date` inválida").
- Toda construção nova que introduza nulabilidade (tipos-soma, campos calculados)
  precisa ou preservar a exigência de grupo, ou versão maior.

Este teorema é o produto. Se ele cair, Kanon vira mais um motor de template.
