# Roadmap

> Estado em 4 de setembro de 2026. Escrito para retomar sem depender de memória.

## Onde estamos

| Fase | Estado | O que existe |
|---|---|---|
| **F0** Especificação | ✅ aceita | 6 documentos em `docs/`, 18 decisões registradas |
| **F1** Núcleo mínimo | ✅ concluída | léxico, gramática dos três planos, árvore, 34 códigos de diagnóstico |
| **F2** Validador | ✅ concluída | protocolo de tipo, ambiente, `analyze`, teorema da lacuna, `check` e o checklist |
| **F3** Renderizador | ✅ concluída | elisão, reparo de emenda, numeração, remissões, orçamento e a CLI |
| **F4** `Extenso.jl` | ✅ concluída | flexão por marca, extenso, datas, junção, separadores e as palavras-chave em pt |
| **F5** Numeração e regras | ✅ concluída | `when` remove, `one for each` repete, e a numeração passa a ser dos dados |
| **F6** Domínios | ✅ concluída | `KanonLegal` e `KanonScience`, `@kanon_type`, e o teste de neutralidade |
| **F7** Ingestão e reuso | ✅ concluída | inclusão de fragmentos com contrato unificado; `Tables.jl` e JSON por extensão |
| F8 Saída | ⬜ | — |
| F9 Editor | ⬜ | — |
| F10 Publicação | ⬜ | — |

**F1 a F6 já constituem um produto.** F7 a F9 são projetos por si só.

Suíte: **1.581 testes** ao todo — 1.291 no núcleo (~24 s), 175 em `Extenso`, 74 em
`KanonLegal`, 41 em `KanonScience`.

## Como retomar

```bash
julia --project=. -e 'using Pkg; Pkg.test()'                          # 1.291, ~24 s
for p in Extenso KanonLegal KanonScience; do
  julia --project=lib/$p lib/$p/test/runtests.jl
done
julia --project=. -e 'using Kanon; load_template(Environment(), "modelo.kanon")'
```

Pontos de entrada, na ordem em que o código executa:

| Arquivo | O que faz |
|---|---|
| `src/source.jl` | lê, normaliza NFC, recusa BOM e não-UTF-8 |
| `src/lex.jl` | classes de caractere, `Cursor` com linha/coluna, `KeywordTable` |
| `src/parse.jl` | pragma de versão, divisão em planos, `parse_string` / `parse_file` |
| `src/parse_data.jl` | contrato: campos, cardinalidades, literais |
| `src/parse_text.jl` | blocos, interpolações, grupos, escapes, candidatos a flexão |
| `src/parse_rules.jl` | expressões com precedência |
| `src/ast.jl` | a árvore, com as quatro invariantes comentadas |
| `src/diagnostics.jl` | `CODE_TITLES` — o registro de códigos estáveis |
| `src/types.jl` | as oito funções genéricas; `kanon_formats` por introspecção |
| `src/environment.jl` | `EnvironmentBuilder` → `Environment` congelado; conflitos de nome |
| `src/core_types.jl` | `text`, `number`, `money`, `date`, `boolean`, `list` |
| `src/analysis.jl` | `ResolvedPath`, `Analysis`, `Model` — as tabelas laterais |
| `src/analyze.jl` | caminhos, formatadores, grupos, remissões, regras; `load_string` / `load_template` |
| `src/check.jl` | os dados contra o contrato; `check`, `bind`, `Bound` |
| `src/contract.jl` | o checklist em JSON Schema, com emissor determinístico próprio |
| `src/rules.jl` | avaliação das condições e o **plano**: que blocos existem, quantas vezes, com que número |
| `src/elide.jl` | **o reparo de emenda** — R1 a R5, local à remoção; a peça mais delicada |
| `src/render.jl` | interpolação, grupos, sujeito, numeração, remissões, orçamento |
| `src/cli.jl` | `check`, `render`, `contract`, `preview`; os cinco códigos de saída |
| `lib/Extenso/src/numeros.jl` | extenso, ordinais, dinheiro e datas — tabela, não esperteza |
| `lib/Extenso/src/flexao.jl` | as marcas, o protocolo de sujeito e a recapitalização |
| `src/macro.jl` | `@kanon_type` — o açúcar que a D-019 prometeu, por `GlobalRef` |
| `lib/KanonLegal/` | `pessoa`, `imovel`, `parte`, e o estilo `§` com `CLÁUSULA PRIMEIRA` |
| `lib/KanonScience/` | `measure`, e o estilo `@` que numera teoremas |
| `test/test_neutralidade.jl` | **a espinha dorsal**: o núcleo sem camada nenhuma |
| `src/include.jl` | o carregador com raiz, a unificação de contratos e a composição |
| `ext/` | `Tables.jl` e `JSON3` — extensões, e não dependências |

Leituras obrigatórias antes de continuar a F2: `docs/especificacao.md` §3 (sistema de
tipos) e §14 (teorema da lacuna), `docs/api-extensao.md` inteiro, `docs/ast.md` §7–8.

---

## F2 — Validador (concluída em 4 de setembro de 2026)

**Objetivo.** Tudo que é verificável **sem dados** (erros de referência, `K2xxx`) e a
validação dos dados contra o contrato (erros de contrato, `K3xxx`), acumulados e no
formato de `docs/especificacao.md` §10.4.

**Refinamento de fronteira proposto** (não estava na F0, decida ao começar): a F2 fica
com *tudo que é estático*, inclusive a checagem semântica das regras; a F5 fica com o
*comportamento em execução* de numeração e regras. Validar regra sem renderizar é
análise estática pura, e separá-la da F2 só para respeitar a fronteira original criaria
um `analyze` que passa duas vezes na mesma árvore.

### Incrementos, cada um com teste antes de avançar

**F2.1 — Ambiente e protocolo de tipo.** ✅ **concluída em 4 de setembro de 2026.**
`EnvironmentBuilder` mutável → `Environment` imutável e congelado; conflito de nome
entre domínios detectado na construção, com os dois domínios na mensagem. As oito
funções genéricas de `api-extensao.md` §2 e os seis tipos do núcleo.

`kanon_formats(T)` saiu por introspecção da tabela de métodos, ordenada e sem
`:default`, e nenhum `Dict` de formatadores foi preciso. O teste que sustenta a fase
passa: um formatador acrescentado só por despacho aparece na validação e na mensagem de
erro, sem registro nenhum.

Três coisas que a implementação forçou e que a F0 não previa:

- **D-019**, a decisão da fase: a fachada `register_type!` registra o nome; o
  comportamento é sempre despacho. A forma com closures de `api-extensao.md` §2.2 era
  incompatível com a proibição de `eval` e com a obrigação 5-A ao mesmo tempo, e passou
  para `@kanon_type` (macro, F6).
- **`Bool` não é `number`.** Em Julia `Bool <: Integer`; definir `number` sobre `Real`
  faria `{flag:fixed2}` passar na validação. Daí `NumberValue`, que exclui `Bool`.
- **Arredondamento por `Rational{BigInt}`, nunca por `BigFloat`**, cuja precisão é
  estado global (`setprecision`) — o determinismo não pode depender dela. Meio para
  longe do zero, que é a convenção de documento.

**F2.2 — `analyze`: caminhos e tipos.** ✅ **concluída em 4 de setembro de 2026.**
Tabelas `paths` e `formatter`, nove códigos `K20xx`, e `load_string` / `load_template`
devolvendo um `Model` (árvore + análise + ambiente) reutilizável sem reparse. A
resolução em duas etapas do §4.2 tenta **sempre** os dois escopos: resolver nos dois é
ambiguidade, e nenhum caminho tem precedência silenciosa. Nada entrou no nó (I2): o
sujeito do bloco mora em `paths[bloco]`.

O que a fase acrescentou ao previsto:

- **D-020**: a nulabilidade do sujeito atravessa o bloco. Conservador de propósito, e
  com o refinamento que a F2.5 deve fazer já escrito na decisão.
- **Nulabilidade que atravessa composto** já está no `ResolvedPath` — a F2.3 herda isso
  pronto e só precisa da tabela `guarded` e da regra de exigência.
- **Tipo desconhecido é dito uma vez, na declaração**, e os usos não repetem: sem isso
  um `person` faltando produziria um erro por interpolação.
- **Sugestão de nome por distância de Damerau**, com transposição valendo 1 — `nmae` por
  `name` é o erro de digitação mais comum, e com Levenshtein puro ele custa 2 e a
  sugestão não sai.

**F2.3 — A tabela `guarded` e o teorema da lacuna.** ✅ **concluída em 4 de setembro de 2026.**
Cinco códigos `K2010`–`K2014`. A implicação do §14 é verificada nó a nó, e há um teste
de propriedade que a afirma sobre um corpus: se `analyze` não acusou nada, então toda
interpolação nulável está dentro de algum grupo.

O que a fase acrescentou ao previsto:

- **D-021**: grupo cujas diretas são todas garantidas também é erro. A §4.4 tinha
  enunciado o caso extremo (`nenhuma` direta) de uma regra mais geral e parado nele; o
  grupo garantido *mente* para quem lê o modelo, prometendo um trecho dispensável que
  nunca sai.
- **A mensagem nomeia o segmento culpado.** `{seller.spouse.name}` não é nulável por
  causa de `seller`, que é obrigatório — é por causa de `spouse`, opcional em `person`.
  Dizer "o contrato o declara opcional" mandaria o redator corrigir o campo errado.
- **A contagem de pontuação atravessa grupos aninhados**, e o parêntese escrito `((`
  conta como qualquer outro: o problema não é a origem do caractere, é o par ter ficado
  do lado de fora.

**F2.4 — Referências.** ✅ **concluída em 4 de setembro de 2026.**
Nove códigos `K2030`–`K2038`. Remissão a bloco inexistente, repetido ou não numerado é
erro; a bloco que uma regra pode remover, aviso — que não impede carregar, porque o
autor pode saber que as duas condições coincidem e o motor não tem como provar que ele
está errado.

O que a fase absorveu de outras, e por quê:

- **D-002 veio da F2.5 para cá.** É aqui que o conflito aparece fisicamente: duas
  regras da mesma espécie disputam a mesma casa de `block_rule`, e guardar uma delas em
  silêncio seria escolher por conta própria qual das duas o redator quis dizer.
- **A sequência de níveis da §6.2 veio da F5.** Nível 2 sem nível 1 antes é erro *sem
  dados*, e a fronteira aceita é "a F2 fica com tudo que é estático". Os contadores
  continuam na F5.
- **A semântica do elemento no bloco iterado (§8.3) teve de vir junto.** Dentro de
  `cada one for each witnesses`, o caminho `{witnesses}` denota **uma** testemunha, não
  a lista. Sem isso a lista inteira sairia por iteração, em silêncio; e um `one for each`
  sobre lista de escalares seria impossível, porque o sujeito sem campos era recusado.
  A concordância entre `<- C` e `one for each C` continua sendo F2.5.

O núcleo passou a registrar o estilo `:section` — `unit = ':'`, `layout = :prefix`,
`separator = ". "`, numerando `1`, `2`, `3.1` (§6.3 e §6.4).

**F2.5 — Semântica das regras.** ✅ **concluída em 4 de setembro de 2026.**
Sete códigos `K2040`–`K2047`. Sem veracidade implícita, `one for each` com a redundância
`<- C` verificada, comparação só quando o tipo declara `kanon_compare`, e atributos
resolvidos contra o tipo com `present`/`absent` valendo para todo campo.

- **`can_compare` é `which`, não `hasmethod`.** O padrão de `kanon_compare` casa com
  tudo, e `hasmethod` seria sempre verdadeiro; a pergunta certa é se o método escolhido
  é o recuso genérico. Mesma técnica de `kanon_formats`, e pelo mesmo motivo.
- **D-020 revisto**, como estava previsto: `one for each` e `when C is present` tornam o
  sujeito presente por construção. O reconhecimento é conservador de propósito.
- **`K2047` é aviso**, não erro: `is present` sobre campo garantido é tautologia e a
  regra é decoração — mas um modelo em edição passa legitimamente por esse estado.

**O critério de aceite da F2 já passa na metade que não precisa de dados**: o modelo
científico de `exemplos.md` §2.1 analisa limpo, e sem a camada `Science` é recusado
nomeando o tipo `measure` e o marcador `@` que faltam (`test/test_acceptance.jl`).

**F2.6 — `check(tmpl, dados)`.** ✅ **concluída em 4 de setembro de 2026.**
Dez códigos `K3001`–`K3030`, e um `Bound` que guarda os valores já decodificados para
que o render não redecodifique nada. As quatro formas de entrada — `Dict` de string,
`Dict` de símbolo, `NamedTuple` e `struct` — atravessam sem adaptador por formato.

Duas decisões, e a segunda era um furo:

- **D-022**: campo a mais nos dados é aviso. Ele nunca esconde um erro sozinho — o campo
  declarado aparece como ausente e o erro sai por `K3001` —, e recusar tornaria
  impossível alimentar vários modelos com a mesma tabela.
- **D-023 — `kanon_getfield`, a nona função do protocolo.** A API listava oito e
  **nenhuma lia um campo**. Sem ela, `{seller.name}` é não-nulável porque o esquema
  declara `name` obrigatório, e nada verificava que o `person` recebido cumpre a própria
  declaração: um `Pessoa("", …)` atravessaria tudo para abrir no texto o buraco que a
  §14 supõe impossível. A verificação existe agora, desce nos aninhados e nas coleções,
  e tem teto de profundidade porque nada impede um ciclo nos dados.

**Critério de aceite da F2: cumprido.** O modelo científico de `exemplos.md` §2.1
analisa sem dados, e `check` recusa o JSON sem `effect` nomeando o campo e apontando a
linha 4 (`test/test_check.jl`, último bloco).

**F2.7 — `contract(tmpl)`.** ✅ **concluída em 4 de setembro de 2026.**
JSON Schema draft 2020-12 com `x-kanon`, e um emissor de JSON escrito à mão — nenhuma
biblioteca garante ordem de chaves, e sem ordem não há `diff`. `properties` na ordem de
declaração, `required` na ordem do arquivo, `$defs` em ordem alfabética, indentação fixa.

O checklist do modelo de aceite está versionado em `test/golden/report.contract.json` e
é comparado byte a byte (regenerável com `KANON_REGEN_GOLDEN=1`). É o primeiro artefato
do corpus golden, e resolve metade da dívida que a F3 herdaria.

Os `$defs` dos seis tipos do núcleo têm forma JSON de verdade; um composto de camada sai
de `kanon_schema`, com `required` e `additionalProperties: false`. **Um escalar de camada
vira `{}` com o nome em `x-kanon`**: o protocolo não revela a forma JSON de um `measure`,
e afirmar uma inventada seria pior que não afirmar nenhuma.

Os formatadores listados são os que o modelo **usa**, não os que o tipo oferece — é isso
que interessa a quem lê o checklist para saber o que precisa funcionar.

---

## O que a F2 entregou

`load_template` → `check` → `contract`, as três funções da API de alto nível que não
dependem de renderizar. Um modelo é recusado sem dados por caminho, tipo, formatador,
grupo, remissão, nível, regra ou lacuna; e com dados por ausência, tipo, cardinalidade,
branco ou esquema descumprido.

Cinco decisões saíram da implementação, e três delas fecharam buracos que a F0 não via:

| | O que estava errado |
|---|---|
| **D-019** | a fachada com closures era incompatível com a proibição de `eval` **e** com a obrigação 5-A ao mesmo tempo |
| **D-021** | a §4.4 enunciou o caso extremo de uma regra mais geral e parou nele |
| **D-023** | a API listava oito funções do protocolo e **nenhuma lia um campo** — o teorema tinha um furo do tamanho de um tipo composto |

As outras duas — D-020 (revista no mesmo dia) e D-022 — são escolhas de calibragem, e
ambas erram para o lado apertado, que é o único reversível enquanto não há acervo.

**Critério de aceite da F2:** o modelo científico de `docs/exemplos.md` §2.1 valida sem
dados e `check` recusa, com mensagens nomeando campo e linha, um JSON a que falte
`effect`.

---

## F3 — Renderizador (concluída em 4 de setembro de 2026)

Os treze casos normativos foram escritos como arquivos golden **antes** do renderizador,
em `test/golden/emenda/`, começando pelos casos 11 e 12 — e passaram todos na primeira
execução do algoritmo.

**O documento sai byte a byte igual ao de `exemplos.md` §2.3**, que foi escrito na F0,
antes de qualquer código, como a saída que a linguagem deveria produzir. Está fixado em
`test/golden/report.output.txt`. É o teste mais duro da fase: nada nele foi ajustado
depois.

O que a fase entregou, além do previsto:

- **A numeração estática entrou aqui**, não na F5. Sem regras aplicadas, os contadores
  por estilo são determinísticos, e sem eles `{::x}` não teria o que render. A F5
  recalcula quando as regras removerem e repetirem blocos — aí a numeração passa a ser
  do render, que tem os dados, e `Analysis.numbering` fica sendo a estática.
- **D-024**: o marcador do rascunho vive no texto, não nos dados. A implementação ingênua
  injetava `"«preco»"` como valor e falhava no primeiro modelo real, porque `«preco»` não
  é um `money` — e a §3.4 garante que nunca será.
- **A CLI**, com os cinco códigos de saída da §12 e `Kanon.main` recebendo os fluxos como
  argumento, o que a torna testável sem processo filho.

Armadilha de Julia registrada: `resize!` para cima **não inicializa memória**. O contador
de numeração começava em lixo, e o primeiro bloco saía como `7`.

---

## F4 — `Extenso.jl` (concluída em 4 de setembro de 2026)

Mora em `lib/Extenso/`, com `Project.toml` e suíte próprios, e depende de `Kanon` — nunca
o contrário. Publicável sozinho: `inteiro_extenso`, `ordinal_extenso`,
`dinheiro_extenso` e `data_extenso` servem a qualquer programa Julia que gere texto
formal em português.

D-013 está garantido por assinatura, e não por disciplina: `flexionar` recebe uma palavra
e devolve uma palavra. **Não há por onde a prosa em volta entrar.**

O que a fase acrescentou ao previsto:

- **D-025**, a decisão da fase: o que a camada substitui é gancho de ambiente, nunca
  método global. Um `format(::AbstractVector, ::Val{:default}, ctx)` em `Extenso` seria
  global e aditivo — bastaria carregar o pacote para o núcleo puro passar a juntar com
  `e`, e a neutralidade cairia sem que nada avisasse.
- **Dois defeitos do núcleo que só a camada revelaria**, os dois corrigidos:
  o parser não canonicalizava o atributo (`presente` não virava `present`, e os dois
  atributos do núcleo simplesmente não existiam fora do inglês); e `register_aliases!`
  só aceitava `NamedTuple`, o que impedia traduzir `for`, `and`, `is`, `true` e `false`
  — todas reservadas em Julia.
- **O gancho de reparo recebia emendas desatualizadas.** `repair` agora devolve as
  posições depois do reparo, que são as que o gancho precisa olhar.
- **O render passou a recusar bloco com regra.** Ele renderizava um `one for each` uma
  vez, com a coleção inteira no lugar do elemento — a saída errada em silêncio que a
  linguagem existe para impedir, produzida pelo motor que promete não produzi-la.
  Recusar é o honesto até a F5.

**D-026, achada respondendo a uma pergunta.** "O Extenso só é em português?" levou a
testar um `Environment()` neutro com `Extenso` carregado no processo — e ele renderizava
`mil e duzentos reais`. Método em Julia é global, e a D-025 tinha fechado o vazamento
para a junção de listas e os apelidos de tipo sem ver que os **formatadores** têm o mesmo
problema. `kanon_format_locale` é a décima função do protocolo, e a diferença entre
`kanon_formats(T)` e `kanon_formats(T, env)` é onde ela age.

Exceções do português que estão na tabela porque nenhuma regra as deriva: `cem` sozinho
mas `cento` composto; `mil e duzentos` mas `mil duzentos e trinta`; o dia 1 por ordinal
(`ao primeiro dia`, nunca `um dia`); e grupo misto no masculino.

---

## F5 — Numeração e regras em execução (concluída em 4 de setembro de 2026)

`when` remove, `one for each` repete, e o `when` de um bloco repetido é avaliado por
iteração — `grantor one for each seller` mais `grantor when seller is not minor` lê-se
"um bloco por vendedor, exceto os menores", e é assim que funciona.

**O plano mora no `Bound`, não na `Analysis`.** Blocos removidos não consomem número e
repetidos consomem um por iteração, então a numeração final depende dos dados.
`Analysis.numbering` continua sendo a estática — a do editor da F9, que mostra o modelo
sem dados.

Duas coisas que a fase forçou:

- **Uma remissão a bloco que as regras removeram é erro de contrato** (`K3040`), e é
  reportada em `check`, não no render — que não emite diagnóstico. Por isso o plano é
  montado em `bind`: é lá que há dados para saber se o bloco existe. `analyze` continua
  avisando (`K2035`) que isso *pode* acontecer, porque o autor pode saber que as duas
  condições coincidem.
- **D-020 revista pela segunda vez.** A garantia passou a valer para todo caminho que o
  `when` afirme presente, e não só para o sujeito: `b when notes is present` com
  `{notes}` no texto era o padrão mais natural da linguagem e exigia colchetes
  redundantes. A interação com D-021 é intencional e a mensagem a distingue: um grupo
  que a regra torna redundante manda tirar os colchetes, não mexer no plano de dados.

E o defeito que a F4 tinha exposto está resolvido: o `refuse_unimplemented_rule` saiu, e
a escritura com `um para cada vendedor` sai com um bloco por vendedor.

---

## F6 — Domínios (concluída em 5 de setembro de 2026)

`KanonLegal` e `KanonScience`, ambos escritos **só com a API pública**, e os dois
exemplos de `docs/exemplos.md` renderizando byte a byte.

Os três testes que o roadmap pedia, e o que cada um mostrou:

- **`@macroexpand` sem nome não exportado.** Passou, mas só depois de a macro trocar a
  qualificação por `GlobalRef`: o *hygiene* do Julia produzia `Kanon.Kanon.format` e
  `Kanon.Val`, que funcionam e tornam a expansão ilegível. Com `GlobalRef` a varredura é
  exata, e o teste afirma o conjunto **completo** dos métodos gerados.
- **`parte` no lugar de tipo-soma (D-006).** Passou: um composto com atributo `empresa`
  faz o que `pessoa | empresa` faria, e o núcleo continua recusando a sintaxe de soma.
  A separação núcleo/domínio aguentou.
- **O teste de neutralidade.** Passou — mas um dos mecanismos que o roadmap propunha teve
  de ser trocado, e a troca virou **D-027**.

O que a fase encontrou:

- **D-027**: "proibir literal não-ASCII no núcleo" foi escrito supondo mensagens em
  inglês, e as do Kanon estão em português. O mecanismo mediria acentos onde deveria
  medir comportamento — e teria dado falsa sensação de rigor enquanto a D-026 passava
  despercebida por duas fases.
- **O exemplo da F0 contradizia a D-013.** A saída exigida trazia `OUTORGADA` de um
  `OUTORGADO` sem marca. O exemplo foi escrito antes da decisão que estabeleceu que só a
  palavra marcada muda; corrigido para `OUTORGADO(A)`, e a nota está em `exemplos.md`.
- **A localização traduz palavras, não ordem sintática.** `is not` vira `é não`, que é
  agramatical; a forma natural em português é o `não (...)` prefixo, que a gramática já
  tem. Fica documentado, porque nenhuma tradução de palavras resolve.
- **Um atributo não pode depender do relógio.** `kanon_attribute(v, ::Val{name})` recebe
  o valor e mais nada, então a maioridade não é atributo de `pessoa` — pergunta-se
  comparando a data de nascimento, que é injetada.

---

## F7 — Ingestão e reuso (concluída em 5 de setembro de 2026)

`include "fragmento.kanon"` no plano do texto, com o carregador que a D-005 exige: raiz
configurada, sem caminho absoluto, sem travessia, sem link para fora, e com detecção de
ciclo. O contrato do fragmento é **unificado** com o do hospedeiro — mesmo nome e mesmo
tipo fundem, tipos diferentes é erro na carga, e a obrigatoriedade é a mais forte das
duas.

Depois de composto, **nada indica que houve inclusão**: quem analisa e renderiza vê um
`Template` só. Os identificadores de nó continuam únicos porque todos os arquivos são
analisados com o mesmo contador — o que evitou reconstruir a árvore inteira para
renumerá-la.

`Tables.jl` e `JSON3` entraram como **extensões**, e não dependências. Quem só quer o
motor não carrega nenhum dos dois, e o teste de neutralidade passou a verificar também
que nenhuma `weakdep` é camada. `render_each` gera um documento por linha e falha na
primeira que não satisfaz o contrato, com a linha nomeada — um lote ou sai inteiro, ou
não sai.

O link simbólico foi o caso que exigiu cuidado: um link **dentro** da raiz apontando para
fora dela é a forma mais simples de escapar, e `normpath` sozinho não a vê. O carregador
resolve `realpath` depois de confirmar que o arquivo existe, e compara por componente de
caminho — nunca por prefixo de cadeia, que `"/raiz"` e `"/raizoutra"` enganariam.

---

## F8 a F10 (as próximas)

- **F8** — Markdown primeiro. Preferir pandoc a escrever gerador de `.docx`. **Typst
  como candidato a backend** foi a melhor ideia do levantamento: Kanon garante o
  conteúdo, Typst compõe a página.
- **F9** — editor de três colunas com a regra ao lado de cada bloco e pré-visualização
  sempre visível. Não é extra: sem ele a linguagem fica pior na prática que um motor
  convencional (risco 16.2). Candidato herdado do docassemble: `kanon ask`, que pergunta
  os campos faltantes um a um — atende à necessidade por trás do "modo leniente" sem
  relaxar nada.
- **F10** — Documenter, CI, Aqua, registro no General. **Lembrete:** `Kanon` e `Extenso`
  reprovam na checagem automática de similaridade de nome e vão exigir o rótulo
  `Override AutoMerge: name similarity is okay` e revisão humana.

---

## Dívidas conhecidas

| Dívida | Onde | Quando resolver |
|---|---|---|
| Coluna deslocada em um caractere na linha escapada com `\:` | `parse_text.jl` | quando incomodar; é o preço de ter uma contrabarra na coluna 0 |
| O exemplo jurídico de `docs/exemplos.md` renderiza com tipos de mentira; falta `KanonLegal` | tipos `pessoa`/`imovel`, estilo `§`, `CLÁUSULA PRIMEIRA` | F6 |
| As mensagens de erro listam os atributos em inglês mesmo num modelo `pt` | `analyze.jl` | quando a tradução de diagnóstico entrar (não planejada) |
| Texto em branco só é normalizado no campo de primeiro nível, não dentro de composto | `check.jl` | quando um tipo composto de verdade tiver campo `text` (F6) |
| Escalar de camada vira `{}` no checklist; falta um `kanon_json_type` para a camada descrevê-lo | `contract.jl` | aditivo, cabe numa versão menor |
| Sem CI, sem Aqua, sem Documenter | — | F10 |
| `is not` em português vira `é não`: a localização troca palavras, não ordem sintática | `parse_rules.jl` | escrever `não (x é y)` resolve; mudar a gramática seria versão maior |
| Os quatro pacotes vivem num repo só, com `Project.toml` cada | `lib/` | extrair na F10, se o registro exigir |
| O orçamento não é configurável pela CLI | `cli.jl` | quando alguém precisar |
| `K1213` está no registro e nunca é emitido: a unidade fora do conjunto fechado nunca vira cabeçalho | `diagnostics.jl` | remover ou dar uso na F3 |
| A mensagem de palavra-chave errada não diz "`rules` é a forma inglesa de `regras`" | `lex.jl`, `parse.jl` | quando a primeira camada de idioma existir (F4) |
| `money` emite duas casas para toda moeda; JPY não tem centavos | `core_types.jl` | quando alguém precisar — exige casas por moeda no ambiente |

## Invariantes que nenhuma fase pode quebrar

Cheque contra esta lista antes de aceitar qualquer incremento:

1. **Falhar alto.** Nenhum modo, opção ou flag permite renderizar com contrato
   insatisfeito. Modo leniente não existe, nem como conveniência.
2. **Teorema da lacuna.** Toda construção nova que introduza nulabilidade preserva a
   exigência de grupo, ou é versão maior.
3. **Neutralidade.** Nada de idioma nem de domínio dentro de `Kanon.jl`.
4. **Sem execução arbitrária.** Renderizar não executa código, não lê arquivo, não
   acessa rede, não expõe campo não declarado.
5. **Determinismo.** Mesma entrada, mesma saída byte a byte. Nada de relógio, de
   aleatoriedade, nem de ordem de iteração de `Dict` alcançando o texto.
6. **I2.** Nenhum resultado de análise dentro do nó. A tentação virá na F5, com a
   numeração.
7. **Anti-XSLT.** Regras só removem ou repetem.
8. **`parse` não consulta o `Environment`.**

## O portão para a 1.0

**A sintaxe só congela depois de quinze modelos reais reescritos na linguagem.** Depois
disso haverá acervo e cada erro de design vira permanente — e o corpus golden da versão 1
passa a ter de renderizar byte a byte idêntico em todo motor `1.x`.
