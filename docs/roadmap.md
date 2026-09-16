# Roadmap

> Estado em 16 de setembro de 2026. O portão está **fechado** (15 de 15), as cinco
> decisões da seção 1a estão tomadas, **a sintaxe da versão 1 está congelada** (D-077) e o
> **site está no ar**. Escrito para retomar sem depender de memória.

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
| **F8** Saída | ✅ concluída | `text`, `markdown` e `typst`; o valor é escapado, a prosa não, e o rótulo sai intacto |
| **F9** Editor | ✅ concluída | `outline`, `kanon ask`, e o **servidor de linguagem** — diagnóstico, estrutura, cursor, salto e completação |
| **F10** Publicação | 🔨 quase | CI, Aqua, Documenter e o **site no ar**; falta o registro no General, que é ação sua |

**O produto existe.** `load_template` → `check` → `render`, mais a CLI, os três formatos
de saída e três camadas. Um modelo real renderiza byte a byte igual ao que a F0 exigiu
dele, e o que não satisfaz o contrato não renderiza — que era a frase inteira do projeto.

Suíte: **2.747 testes** ao todo — 1.681 no núcleo (~50 s com Aqua), 357 em `Extenso`,
308 em `KanonLegal`, 215 em `KanonScience`, 186 em `KanonLSP`. CI em Linux, macOS e
Windows, com cobertura no Codecov.

---

## O que resta

As dez fases estão feitas ou entregues em parte. **O que resta não é código de motor** — é
**uma decisão**, o congelamento, e o que vier depois dele.

### 1. Quinze modelos reais — o portão, fechado

Existem **quinze** modelos reais no repositório, em `test/golden/exemplos/`:
`escritura.kanon`, `locacao.kanon`, `relatorio.kanon` (com fragmento incluído),
`certificado.kanon` (um por linha de planilha), `laudo.kanon` (dois domínios ao mesmo
tempo), `edital.kanon` (três níveis de numeração, e a primeira saída Typst),
`doacao.kanon` (comparações nas regras, e os dados vindos de um JSON), `ensaio.kanon`
(a camada científica em português, com as medições vindas de um JSON),
`verificacao.kanon` (um certificado por registro de um CSV de verdade, com as medições em
colunas), `aula.kanon` (fragmento incluído em português), `servicos.kanon` (o contrato em
minuta, pelo rascunho e pela CLI), `procuracao.kanon` (as partes de um JSON, o resto
digitado no `kanon ask`, e a saída em Typst, pelo `bin/kanon` num processo novo),
`notificacao.kanon` (escrita no editor pelo `kanon-lsp`, com um fragmento que a procuração
também inclui), `atestado.kanon` (português sem camada de domínio pelo `bin/kanon`, com os
quantitativos digitados no `kanon ask`) e `reclamacao.kanon` (a petição entregue em
`.docx`, pelo `bin/kanon` encadeado ao pandoc, com o documento lido de volta). O portão
para a 1.0 pedia quinze, e **está fechado**.

**Onde está cada um.** Os quinze estão na `main`: o nº 15 pelo PR #10, depois de o PR #9
consertar o CI no Julia 1.10. Cada modelo abriu o PR **contra a `main`** — PR empilhado não
se reaponta sozinho quando o de baixo é mergeado, e foi assim que o nº 13 foi parar no
branch do nº 12.

**O CI agora instala o pandoc** (3.11, o binário da release de cada sistema), antes da
suíte do `KanonLegal`: o teste do nº 15 roda a cadeia `bin/kanon | pandoc` de verdade, e no
CI ele **recusa rodar** sem o pandoc em vez de se pular. Fora do CI, aponte `KANON_PANDOC`
para um pandoc, ou o teste avisa e fica marcado como pulado.

**Ao retomar, nesta ordem:**

1. **A seção 1a está fechada.** As cinco: o tipo `list` (**D-071**), a marca que nomeia o
   sujeito (**D-072**), a série de trechos opcionais (**D-073**) — as duas reservadas com
   erro, e o reparo de emenda intocado —, o ponto final duplicado (**D-075**), resolvido
   por uma **costura da interpolação** que não é reparo de emenda, e os **apelidos de
   idioma para atributos e formatadores** (**D-076**), aditivos e registrados pela camada
   de idioma.
2. **A sintaxe está congelada** (D-077): a especificação é a versão 1 aceita, e o corpus
   golden listado na §13 é contrato. Os cinco pacotes estão em `0.1.0`; o que resta é o
   **registro no General** (item 2), que é ação sua.
3. E, se quiser público antes disso, o **simulador na página** (item 5), que é o único item
   novo desta lista.

Isto não foi burocracia. Uma linguagem de modelos é julgada por escrever modelos, e cada
um dos quinze cobrou alguma coisa. **Nenhuma outra atividade teve a mesma taxa de
descoberta por hora**, e os catorze últimos mediram isso: escritos com o motor pronto e a
suíte verde, produziram **trinta e seis defeitos**,
dois limites do idioma, um da gramática e as decisões que a seção 1a reúne para antes do
congelamento.

| | O que apareceu | Modelo |
|---|---|---|
| **D-031** | `quando flag` era recusado em português e aceito em inglês. Mesma causa em quatro lugares — e num deles o checklist de um modelo `pt` saía **sem `type` nenhum**, validando qualquer coisa | locação |
| **D-032** | uma regra que remove a cláusula deixava o parágrafo dela órfão, rotulado `0.1` — um número que não existe. Virou o aviso `K2039` | locação |
| **D-033** | o tipo `list` do núcleo **não é declarável** no plano de dados, e a mensagem mandava o autor para `list[]`, que é uma lista de listas. Fechada pela **D-071** com o portão: nenhum dos quinze o declarou, e o nome saiu do plano de dados | locação |
| **D-034** | uma incerteza cujo primeiro algarismo é 3 ganhava **uma casa decimal a mais do que a medição sustenta** — `21.40 ± 0.30` no lugar de `21.4 ± 0.3` —, porque `0.3 / 10.0^-1` vale `2.9999999999999996` | relatório |
| — | **e um limite do idioma, que não é defeito**: a marca só sufixa, e o plural de um verbo em português muda o radical. `concluiu(ram)` não existe; a frase se escreve com particípios | certificado |
| **D-035** | todo diagnóstico sobre algo vindo de fragmento nomeava o **hospedeiro**, com a linha do **fragmento**: um ponteiro para uma linha que muitas vezes nem existe no arquivo apontado | relatório |
| **D-040** | `K2007` recusava sujeito sem campos, e com isso a **flexão de número era inalcançável** para qualquer modelo sem camada de domínio — metade do que `Extenso` faz, e ele se anuncia como publicável sozinho | certificado |
| **D-041** | o mesmo número saía `41.250` como `number` e `41250,0` como `measure`, **duas linhas depois, no mesmo laudo**: a API mandava a camada pegar os separadores do contexto e não dava função para aplicá-los | laudo |
| **D-042** | tipo desconhecido despejava quinze nomes e não dizia que a causa provável é uma camada não carregada | laudo |
| **D-043** | dentro de um bloco repetido, `{lotes}` rendia a **coleção inteira** em cada iteração, contra a §8.3 que a F0 escreveu; e o campo do elemento escrito pelo caminho iterado estourava um `FieldError` de Julia sobre `Array`, sem diagnóstico nenhum | edital |
| **D-044** | o **rótulo** — a única parte do documento que o motor calcula — era a única que o formato de saída não protegia: em Markdown as cláusulas viravam quatro listas renumeradas pelo renderizador, com as remissões da prosa apontando para os números antigos | edital |
| **D-045** | a garantia de presença que a regra do bloco dá era colhida na grafia do contrato e consultada na do sujeito — duas escritas do mesmo valor —, e comparação nenhuma a produzia; o autor era obrigado a escrever um grupo opcional para um caso que o plano das regras já tinha eliminado | doação |
| **D-046** | **nenhum JSON alcançava documento jurídico nenhum**: as camadas não implementavam `kanon_decode`, e `pessoa` só existia se alguém a construísse em Julia | doação |
| **D-047** | e nenhum arquivo alcançava a camada **científica**, que é a única cujos valores um instrumento produz sozinho: a D-046 fechou a porta do domínio jurídico e parou ali | ensaio |
| **D-048** | a ressalva de um ponto medido, escrita como bloco **filho** do bloco repetido, saía numerada `3.4.1` — pendurada no quarto ponto, falando do primeiro. **Sem um único diagnóstico**: a numeração é mecanicamente correta e só o sentido é falso | ensaio |
| **D-049** | `{padrao.unit}` não elidia quando a medição não traz unidade: `check` lia o campo em branco como ausente desde a F2 e o render o lia como presente e vazio — a mesma forma da D-041, com o grupo aberto pela outra porta | ensaio |
| **D-050** | o diagnóstico de um elemento defeituoso não dizia **qual** elemento: quatro medições, uma chave faltando numa delas, e a mesma frase quatro vezes | ensaio |
| **D-052** | **nenhuma planilha alcançava tipo composto**, e todo tipo de domínio é composto: `render_each`, que existe para planilhas, não alcançava camada de domínio nenhuma. A mensagem dizia que `carga` "não foi informado" de um CSV que o trazia em três colunas | verificação |
| **D-053** | a incerteza relativa tinha uma casa fixa: uma balança com incerteza de 5 kg saía com `0,0%` — incerteza nula —, e o padrão do certificado nº 8, já publicado, saía com o dobro da dele | verificação |
| **D-054** | `include` era a **única palavra-chave sem apelido de idioma**, e num modelo `pt` a linha `incluir "x.kanon"` não era inclusão nenhuma: virava prosa, e o caminho do arquivo saía impresso no documento. O modelo carregava limpo e o `check` passava | aula |
| **D-055** | e o parser **não tinha como avisar**: todo `K1xxx` era erro, erro viaja por exceção, e um aviso era descartado entre a leitura e a análise porque o `Template` não tinha onde guardá-lo | aula |
| **D-056** | `Theorem 1` em qualquer idioma — e as três saídas óbvias quebravam uma declaração cada: o domínio não tem idioma, o idioma não conhece domínio, e o núcleo não tem nem uma coisa nem outra | aula |
| **D-057** | o **rascunho** de uma minuta saía sem a cláusula que o contrato promete: um bloco repetido sobre coleção garantida ausente vinha com zero cópias, escondendo justamente a parte em aberto que o redator abriu o rascunho para ver | serviços |
| **D-058** | a **CLI não tinha como carregar uma camada de domínio**, e por isso não alcançava nove dos dez modelos reais já escritos — a linha de comando que a §12 documenta desde a F0 servia só ao que não usa camada | serviços |
| **D-059** | e a correção da D-058 **não funcionava fora da suíte**: o `--domain` carregava a camada num mundo que o resto da execução não enxergava, e pelo `bin/kanon` de verdade `--locale pt --domain KanonLegal` dizia que o idioma não tinha camada. O teste passava porque o `runtests.jl` já tinha feito `using KanonLegal` | procuração |
| **D-060** | e o `bin/kanon` não lia `.json` nenhum: o `JSON3` é extensão, ninguém o carregava, e a recusa saía como **pilha de Julia**. O JSON é o único formato que carrega uma `pessoa` — somadas, a D-059 e a D-060 deixavam a CLI sem documento jurídico nenhum | procuração |
| **D-061** | o `ask` emitia `outorgado = Dict{String, Any}(...)`, que o `render` recusava; nunca perguntava o opcional — o réu, o processo, onde a procuração varia —; e só conferia a resposta depois da última pergunta, sem dizer que a data se escreve `aaaa-mm-dd` | procuração |
| **D-062** | no Typst, `//` num valor começa um comentário e **apaga o resto da linha**; `~` e `-?` também somem. Compila sem erro. Achado ao compilar o golden, que foi o primeiro `.typ` do acervo a passar pelo Typst | procuração |
| **D-063** | `R$ 18.750,00` saía `dezoito mil, setecentos e cinquenta reais`. A docstring e o comentário do teste diziam `mil duzentos e trinta`, sem vírgula, e as asserções logo abaixo exigiam a vírgula — e o laudo nº 5 já publicado a tinha no golden escrito à mão. A lição da D-053, pela terceira vez | notificação |
| **D-064** | com a qualificação do advogado num fragmento, o `ask` perguntava `oab — texto, linha 17` — a linha 17 do fragmento, dita como se fosse da procuração | notificação |
| **D-065** | o `kanon-lsp --locale pt --domain KanonLegal` **morria ao iniciar** — a D-059 no outro lançador —; e, corrigido isso, **subia e mentia**: todo campo de sujeito da notificação saía como `o contrato não declara \`nome\``, num modelo que o motor aceita limpo. A suíte do servidor nunca tinha executado o lançador | notificação |
| **D-066** | o fragmento de dois documentos abertos recebia a lista de diagnósticos de quem falou por último: **abrir a procuração apagava o erro que a notificação ainda tinha**. E salvar o fragmento não mudava hospedeiro nenhum | notificação |
| **D-067** | a completação resolvia o caminho por conta própria: `{notificado.` oferecia os campos de `pessoa`, `{nome:` no bloco do sujeito não oferecia nada, `{especiais:` oferecia os formatadores de `texto` para uma lista, e num ambiente sem idioma `{preco:` oferecia `extenso` | notificação |
| — | **e um limite do idioma, que não é defeito**: a flexão tem um sujeito por bloco, e a frase central de uma procuração concorda com dois — o verbo com os outorgantes, o substantivo com o advogado. `nomeia(m)` flexiona; `procurador(a)` teria de flexionar por outro sujeito na mesma frase. O modelo nomeia o OUTORGADO pelo papel, como a locação já fazia com o LOCATÁRIO — e a locação nº 2 escreve `ao LOCATÁRIO` para a Helena sem que ninguém tivesse registrado por quê. **D-072**: a forma `procurador(a:advogado)` fica reservada, com erro | procuração |
| **D-068** | **nenhum modelo em português sem camada de domínio passava pelo `bin/kanon`**: `--locale pt` dizia que o idioma não tinha camada, com o `Extenso` instalado, e mandava "carregar o pacote" — que não é coisa que se digite. E o `--domain Extenso` tentado em seguida **acusava a camada** de registrar `text` de novo: o construtor chamava o `configure!` do núcleo, que ela importa com `using Kanon` | atestado |
| **D-069** | o fiscal digitou `1.320` metros de drenagem, o `ask` leu `1.32`, e o atestado saiu com **`1,32 m`** — sem aviso nenhum, num documento que prova experiência numa licitação pelos quantitativos. E `12.480,50` era recusado com "esperava um numero", sem a forma a escrever | atestado |
| — | **e um limite da gramática, que não é defeito**: a enumeração de trechos opcionais. `{a}[, {b}][ e {c}]` sai `a, b` quando `c` falta — sem o `e` antes do último presente, porque a conjunção depende de qual trecho é o último, e a gramática não tem como dizê-lo. **D-073**: a série `[[…][…]]` fica reservada, e o reparo de emenda não muda | atestado |
| **D-070** | o fecho `Nestes termos,` / `pede deferimento.` e o bloco de assinatura saíam **numa linha só** no `.docx`, sem aviso nenhum. No Markdown e no Typst a quebra simples é espaço, e a §4.1 deixava ao formato decidir se ela é rígida — o formato não decidia nada. O texto puro do mesmo modelo estava certo, e o Markdown era byte a byte o escrito à mão | reclamação |

**O padrão vale mais que os defeitos um a um: o buraco estava sempre na interseção de duas
coisas testadas separadamente.** Toda a suíte em português usava tipos de domínio, cujos
nomes já são canônicos; toda a suíte de regras, contrato e `ask` estava em inglês. O tipo
`list` era testado chamando `format` sobre um vetor, nunca declarando um campo. A regra do
PDG era testada com incertezas que a potência de dez divide exato. A suíte da inclusão
verificava que o fragmento **compõe**, e nenhum teste tinha um fragmento com um erro
dentro. `Extenso.numero` sobre um vetor era testado direto, e nenhum modelo podia
alcançá-lo. A suíte do `measure` roda sem idioma, onde não há separador a aplicar, e a
suíte em português nunca tinha usado um `measure`. Todo bloco repetido do acervo lia o
elemento por um campo do sujeito, que resolve pela outra porta — e ler o elemento pelo
caminho iterado só tem razão de existir quando ele **não tem campos**, o que a D-040
destravou três dias antes. E nenhum documento numerado por dígitos tinha sido emitido em
formato de marcação: a numeração do `KanonLegal` é `CLÁUSULA PRIMEIRA`, a do
`KanonScience` é `Theorem 1`, e nenhuma das duas começa por dígito. A suíte do `measure`
constrói `Measure` em Julia, e a da ingestão lê arquivos com os tipos do núcleo, que
decodificam. E todo bloco repetido do acervo, sem exceção, era o **último nível** do
estilo dele — o nível de baixo de um bloco que se repete nunca tinha sido escrito, e é a
única construção que o motor aceitava produzindo um documento falso. E a única
"planilha" do acervo era um `NamedTuple` montado em Julia, com listas dentro das células:
nenhum teste tinha lido um CSV, e por isso ninguém tinha perguntado como uma célula guarda
um composto. E a inclusão de fragmentos, que existe desde a F7, tinha **um**
documento: escrito em inglês, sem camada de idioma, com um fragmento do mesmo estilo do
hospedeiro e que o hospedeiro não cita — e por isso ninguém tinha perguntado como se
escreve `include` em português. E a suíte da CLI exercita os cinco códigos de saída
com modelos-brinquedo, em inglês canônico e sem camada, porque a suíte do núcleo não pode
depender de camada; a de cada camada chama o motor de dentro de Julia, onde
`Environment(domains = [...])` sempre esteve à mão. As duas juntas cobriam tudo, e
deixavam de fora a única pergunta que importa ao redator: **e pela linha de comando?** E
a resposta que a D-058 deu a essa pergunta foi conferida **dentro** de Julia, num processo
que já tinha carregado a camada e o `JSON3` — o único lugar onde os dois defeitos seguintes
não existiam. O teste que confirma uma correção roda onde o defeito foi visto, ou não
confirma nada. E a suíte do servidor de linguagem tinha a mesma forma, com um agravante:
para ficar independente das camadas, usava um **domínio de mentira** — um `PessoaTeste`
que se passa por `pessoa` —, e por isso nunca teve um processo com `Extenso` carregado nem
executou o `kanon-lsp`. Independência da suíte e realismo do processo são coisas
diferentes, e só a segunda é a que o redator tem. E a suíte do `ask` no núcleo é em
inglês canônico, sem idioma, onde não há separador de milhar e `1.320` só tem uma
leitura; o único modelo em português que tinha passado pelo `ask`, a procuração, não tinha
número nenhum a digitar. E o único Markdown do acervo, o dos serviços, tinha sido conferido
como **texto** — nunca pelo leitor que faz dele o documento —, enquanto o único parágrafo de
duas linhas do acervo, a assinatura do atestado, saía em texto puro: cada formato estava
certo sozinho, e o `.docx` errado na interseção dos dois.

Um documento atravessa essas interseções porque **não escolhe qual parte da linguagem
usar**. É por isso que escrever um vale mais que acrescentar cem testes de unidade — e o
modelo nº 3 foi escolhido justamente por atravessar três interseções vazias de uma vez:
um modelo em arquivo, com fragmento incluído, na camada científica, emitido também em
Markdown.

O que procurar no que falta:

- Uma construção que a gramática não expressa, ou expressa mal.
- Uma mensagem de erro que não diz o que fazer.
- Um lugar onde os colchetes ficaram no lugar errado, ou onde faltou uma marca de flexão.
- Um formatador que a camada devia ter e não tem.
- **Um documento que sai errado sem que nada avise** — o que a D-048 acrescentou à lista,
  e o mais caro dos seis: os outros se veem lendo a saída uma vez.
- **Uma porta testada fora do lugar em que o redator a usa** — o que os nº 12 e nº 13
  acrescentaram: a CLI conferida dentro de Julia, o servidor com um domínio de mentira.
  Todo modelo passa pelo lançador de verdade, num processo novo. E o nº 15 estendeu a
  regra ao que vem **depois** do motor: o formato intermediário se confere pelo leitor que
  faz dele o documento, e não como texto.

### 1a. Antes de congelar — as decisões que o portão deixou

O portão existe para que estas perguntas sejam respondidas **antes** da 1.0: depois dela,
cada resposta muda a saída de documento publicado ou a gramática, e vira versão maior.
Com o portão fechado, **são o próximo trabalho**: todas precisam de resposta antes do
congelamento. **Estão todas respondidas.** Quatro saíram em 15 de setembro de 2026 — o tipo
`list` (D-071), que a evidência dos quinze modelos decidiu; as duas de sintaxe reservada
(D-072 e D-073), decididas juntas porque pediam a mesma coisa; e o ponto final duplicado
(D-075). A quinta saiu em 16 de setembro.

**Decidida em 16 de setembro de 2026**: os apelidos de idioma para atributos e formatadores
(D-076). `quando pontos é preciso` e `{nome:maiusculo}` num modelo `pt`, **ao lado** do
canônico, que continua valendo. Quem registra é a camada de idioma, e a análise resolve pelo
tipo. A tabela do `Extenso` só traz os nomes que o português dá sem escolha — um nome que
entra convive para sempre com o inglês —, e `title`, `fixed2`, `plain`, `count` e `bare`
esperam o modelo que os peça. O formatador tem o nome na forma de dicionário, como o
`KanonLegal` já fazia, e com isso `{nome:maiusculo}` vale em `texto` e em `pessoa` — a
dívida da procuração nº 12 fechou junto, e a das mensagens com os atributos em inglês também. Os modelos nº 8, nº 9, nº 10 e nº 15 e o fragmento do
procurador passaram a escrever os apelidos, com a saída intacta.

**Decididas em 15 de setembro de 2026**: o tipo `list` (D-071); a marca
que nomeia o sujeito, `procurador(a:advogado)`, **reservada** com o erro `K1216` (D-072); a
série de trechos opcionais, `[[, {b}][ e {c}]]`, **reservada** com o erro `K2015`, com o
reparo de emenda intocado (D-073); e o ponto final duplicado, resolvido pela **costura da
interpolação** da §5.4 — o terminador que o valor traz e o do autor viram um, e o reparo de
emenda continua local à emenda (D-075). As duas reservas custam um erro cada e compram a adição
aditiva: hoje a primeira seria prosa impressa no documento, e a segunda já era erro por
outro nome.

E um limite, registrado e não dívida: **o fragmento fixa os nomes dos campos**. A
qualificação do advogado só serve à procuração e à notificação porque as duas chamam o
advogado de `advogado`; a inclusão não tem parâmetro, e é assim de propósito (D-005).

**A sintaxe está congelada desde 16 de setembro de 2026 (D-077).** Cada erro de design
achado daqui em diante é `kanon 2` — e as construções que alguém vai querer estão
reservadas com erro, para que entrem como versão menor.

### 2. O registro no General — decisão sua, não minha

Os cinco pacotes estão em `0.1.0` desde o congelamento (D-077), e a versão é registrável.
A `0.1.0` promete o que pode cumprir: a **linguagem** `kanon 1` não muda de sentido, e a
**API Julia** ainda pode mudar em `0.2`. O que o registro vai cobrar — a revisão humana de
`Kanon` e `Extenso` pelo nome, e a ordem entre os pacotes — está na seção da F10.

### 3. A pré-visualização sempre visível

**Feito o servidor de linguagem** (`lib/KanonLSP`), que era este item: diagnóstico
enquanto se digita, a estrutura do arquivo com a regra ao lado de cada bloco, o que está
sob o cursor, o salto para a declaração e a completação que conhece os tipos. Um LSP
serve a todos os editores; um editor gráfico serviria a um.

**Com camada de domínio, só passou a funcionar com o modelo nº 13** (D-065): até ali o
`kanon-lsp --locale pt --domain KanonLegal` morria ao iniciar e, corrigido isso, marcava
como erro todo campo de sujeito. No editor, aponte o cliente para
`julia --project=AMBIENTE lib/KanonLSP/bin/kanon-lsp --locale pt --domain KanonLegal`.

**Falta a terceira coluna propriamente dita** — a pré-visualização do documento ao lado
do modelo, atualizada a cada tecla. O motor já a entrega (`preview` rende com
«marcadores» e nunca exporta); o que falta é o caminho até a tela. Como pedido do LSP
seria uma extensão fora do protocolo, e a alternativa é uma janela de editor comum
alimentada pelo mesmo servidor.

O roadmap original dizia que sem a interface *"a linguagem fica pior na prática que um
motor convencional"*. Com o LSP isso deixou de valer para o essencial — o redator agora
vê o erro onde ele está, e vê que um campo pode faltar antes de gerar o documento.

### 4. As dívidas

Nenhuma bloqueia nada. Estão na tabela do fim, com o gatilho de cada uma — a maioria é
"quando alguém precisar", e algumas dependem de um dos três itens acima.

### 5. O simulador na página — proposto, não começado

O site (item 6) mostra o motor em três cenas **gravadas**. O passo seguinte é o visitante
escrever o próprio modelo e ver o que o motor responde. O desenho, decidido em 15 de
setembro de 2026 e ainda não implementado:

- **O motor de verdade, atrás de uma API mínima** — `POST /check`, `POST /render`,
  `POST /contract` num serviço em Julia com as camadas carregadas, imagem feita com
  `PackageCompiler` para a partida não custar segundos.
- **Não um gêmeo em JavaScript.** Reimplementar a linguagem no navegador é o que a D-029 e
  a D-039 recusaram para o servidor de linguagem: uma ferramenta que discorde do motor é
  pior que nenhuma, porque o redator confia nela justamente onde não consegue conferir. Se
  algum dia existir, o preço de entrada é rodar o corpus golden inteiro contra ele no CI e
  quebrar a build em qualquer divergência de um byte.
- **Exposto é seguro, e não por sorte:** a §11 já proíbe execução de código, I/O, rede e
  campo não declarado, e o orçamento é contado em nós, bytes, profundidade e iterações, não
  em tempo de parede (D-010). O que o serviço acrescenta é teto de corpo da requisição,
  limite por IP e timeout duro.
- **Rede de segurança:** a página traz exemplos com a saída **pré-computada pelo motor no
  CI**. Se a API não responde, o visitante ainda edita entre as variações prontas e vê
  resultado verdadeiro, com o commit que o gerou ao lado. A página nunca inventa uma saída.
- **WebAssembly fica para depois.** Seria o ideal — motor de verdade sem servidor —, mas o
  `WebAssemblyCompiler.jl` compila só um subconjunto estático de Julia, e o Kanon depende de
  despacho múltiplo e de introspecção da tabela de métodos (é assim que `kanon_formats`
  enumera formatadores). Gatilho para reavaliar: a história de WASM em Julia amadurecer.

### 6. O site — feito em 15 de setembro de 2026

`https://dantebertuzzi.github.io/Kanon.jl/` é a landing page, e
`https://dantebertuzzi.github.io/Kanon.jl/dev/` a documentação, no mesmo Pages.

A página é um arquivo só em `web/index.html`, sem framework, com a fonte servida pelo
próprio site. Ela mostra a demo do motor em três cenas com **as mensagens que o motor
imprime**, o teorema da lacuna, os três planos, a tabela de onde mora o contrato em cada
sistema, as duas portas e as camadas.

**Duas coisas a saber antes de mexer nela.** O Pages estava configurado no `gh-pages` e
**nunca tinha sido construído** — era por isso que os links da documentação não abriam. E o
Documenter reescreve o `index.html` da raiz a cada deploy: por isso o job `docs` do CI
republica `web/` na raiz **depois** do deploy da documentação. Tirar esse passo faz a
landing durar até o próximo build de docs.

---

## Como retomar

```bash
julia --project=. -e 'using Pkg; Pkg.test()'                          # 1.681, ~50 s
# o KanonLSP roda o modelo real nº 13 com a camada de verdade: desenvolva as camadas nele
# antes, como o CI faz (`Pkg.develop` de `.`, `lib/Extenso`, `lib/KanonScience` e
# `lib/KanonLegal` no projeto `lib/KanonLSP`); e o KanonLegal roda o modelo nº 15 pelo pandoc:
# `KANON_PANDOC=/caminho/do/pandoc`, ou o pandoc no PATH
for p in Extenso KanonLegal KanonScience KanonLSP; do
  julia --project=lib/$p lib/$p/test/runtests.jl
done
julia --project=. -e 'using Kanon; load_template(Environment(), "modelo.kanon")'
```

Pontos de entrada, na ordem em que o código executa:

| Arquivo | O que faz |
|---|---|
| `src/span.jl` | `Span` e `NodeId` — o que a árvore e o diagnóstico compartilham |
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
| `lib/KanonLSP/` | o servidor de linguagem: JSON-RPC, posições, e as cinco funcionalidades |
| `lib/Extenso/src/numeros.jl` | extenso, ordinais, dinheiro e datas — tabela, não esperteza |
| `lib/Extenso/src/flexao.jl` | as marcas, o protocolo de sujeito e a recapitalização |
| `src/macro.jl` | `@kanon_type` — o açúcar que a D-019 prometeu, por `GlobalRef` |
| `lib/KanonLegal/` | `pessoa`, `imovel`, `parte`, e o estilo `§` com `CLÁUSULA PRIMEIRA` |
| `lib/KanonScience/` | `measure`, e o estilo `@` que numera teoremas |
| `test/test_neutralidade.jl` | **a espinha dorsal**: o núcleo sem camada nenhuma |
| `test/golden/exemplos/` | **os modelos reais**: `escritura`, `locacao`, `relatorio` (com fragmento), `certificado` (por linha de planilha), `laudo` (dois domínios), `edital` (três níveis, com a saída também em Typst), `doacao` (regras com comparação, dados em JSON ao lado), `ensaio` (a camada científica em português, medições vindas de JSON) `verificacao` (um por registro de um CSV, medições em colunas com ponto) `aula` (um roteiro por turma, com fragmento incluído em português e duas famílias de numeração) `servicos` (um contrato em minuta, com o rascunho, o documento pronto e o Markdown) `procuracao` (as partes em JSON, as respostas do `ask`, os dados que ele emite, e o documento em texto e em Typst) e `notificacao` (escrita pelo servidor de linguagem; a qualificação do advogado vem de `fragmentos/procurador.kanon`, que a procuração também inclui), `atestado` (português sem camada, pelo `bin/kanon` e pelo `ask`) e `reclamacao` (entregue em `.docx`: o Markdown, e o `.docx` lido de volta pelo pandoc em `reclamacao.docx.txt`), cada um com a saída exigida |
| `src/include.jl` | o carregador com raiz, a unificação de contratos e a composição |
| `ext/` | `Tables.jl` e `JSON3` — extensões, e não dependências |
| `src/output.jl` | os formatos de saída, o escape do valor interpolado e o do rótulo |
| `src/outline.jl` | o esqueleto do modelo, para o editor e para ferramentas |

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

**[D-045, ao escrever o modelo real nº 7]** A garantia de presença que uma regra dá ao seu
bloco (D-020) tinha dois furos, e o primeiro não é sobre regras: ela era colhida na grafia
do contrato — `quando p.nascimento é presente` — e consultada na do sujeito —
`{nascimento}` —, que são duas escritas do mesmo valor (§4.2). O segundo é que **comparação
também afirma presença**: ausência não se compara, e o `return false` de `eval_comparison`
prova a implicação. Sob `not` e sob `or` a garantia não vale, pela mesma razão que já valia
para `is present`.

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

**[D-046, ao escrever o modelo real nº 7]** A ingestão lia o arquivo e parava na porta do
domínio: nenhuma camada implementava `kanon_decode`, e por isso **nenhum JSON alcançava um
documento jurídico** — `pessoa` só existia se alguém a construísse em Julia. A suíte de
ingestão testava os tipos do núcleo, que decodificam; a das camadas construía os valores em
Julia, que é o que um teste de unidade faz; e a pergunta do meio não era de ninguém.

---

## F8 — Saída (concluída em 5 de setembro de 2026)

Três formatos — `text`, `markdown`, `typst` —, por despacho, como tudo o mais: uma camada
acrescenta o quarto definindo três métodos.

**D-028** é a decisão da fase, e é o princípio do projeto dito para outro problema: o
valor interpolado nunca altera a estrutura. A prosa do modelo passa intacta — o autor que
escreve `**importante**` quer negrito, e tirá-lo dele seria o mesmo erro que o reparo
global de emenda seria (D-014).

A precisão que a implementação exigiu: em Markdown há **duas classes** de caractere
especial, e tratá-las igual torna o motor inútil. `12.345` viraria `12\.345` se o ponto
fosse escapado no meio de uma frase; e o `#` de `"X\n\n# Cláusula falsa"` precisa ser
escapado, porque um valor com quebras de linha alcança o começo de uma. Quem sabe a
posição é o render, e `escape_value` passou a recebê-la.

`.docx` e PDF continuam fora do motor, como o roadmap pedia: `--to markdown | pandoc -o
saida.docx` põe a composição de página em quem sabe fazê-la.

---

**[D-044, ao escrever o modelo real nº 6]** A frase acima protegia metade do documento.
A outra metade é o **rótulo**: `1. ` no começo da linha é marcador de lista em Markdown e
enumeração explícita em Typst, e o número que o motor apurou virava um número que o
renderizador redefine — com a remissão da prosa apontando para o antigo. O rótulo sai por
`label(fmt, texto)`, junto com o separador do estilo, e as duas linguagens escapam em
lugares diferentes: `1\.` no Markdown, `\1.` no Typst. Veio junto o escape de valor do
Typst passar a olhar o início de linha, que ele recebia e ignorava.

---

## F9 — Editor (parcial, 5 de setembro de 2026)

**D-029** separou o que a fase misturava. O editor de três colunas é uma aplicação — com
ciclo de vida, dependências de interface e público próprios —, e embutir uma numa
biblioteca de motor amarraria as duas. O que só o motor pode dar é a estrutura já
resolvida, e é o que ele passou a dar:

- `outline(model)` — por bloco: a regra que o governa, o número que ele consome, o
  sujeito, os campos que usa e quais deles podem faltar sem estar em grupo.
- `kanon outline` — as duas primeiras colunas do editor, no terminal.
- `kanon ask` — pergunta o que falta, um a um, e emite os dados que `kanon render` lê de
  volta. **Só passou a ser verdade na D-061**, com o modelo nº 12: até ali um composto
  vindo de JSON saía como `Dict` de Julia, e o opcional nunca era perguntado.

A restrição que isso impõe é o ponto: `outline` sai inteiro da `Analysis`, sem regras
próprias. Uma ferramenta que discordasse do motor seria pior que nenhuma.

**O servidor de linguagem** (`lib/KanonLSP`, 5 de setembro de 2026) é a outra metade, e
`outline` era mesmo o que ele consumia. Cinco funcionalidades, todas lidas da `Analysis`:

| pedido | o que o redator ganha |
|---|---|
| diagnósticos | o erro sublinhado onde ele está, com a dica junto — e o do fragmento vai para o fragmento (D-035) |
| estrutura | a primeira coluna do editor, e a regra de cada bloco no `detail`, que é a segunda |
| cursor | tipo, formatador, se o valor pode faltar, se está protegido por grupo, que número a remissão rende |
| salto | do uso para a declaração, da remissão para o bloco, atravessando fronteira de fragmento |
| completar | campos, campos do sujeito, formatadores **daquele tipo**, blocos numerados, tipos e palavras-chave |

Escrevê-lo cobrou quatro coisas, e duas eram do motor:

- **D-036** — todas as portas do motor lançavam, e uma ferramenta interativa precisa da
  estrutura do arquivo **e** da lista de erros ao mesmo tempo. `load_source` é a porta
  que devolve as duas.
- **D-037** — o trecho de um parágrafo terminava no último **caractere**, e não no último
  nó: `{a}` sozinho produzia um pai menor que o filho. Nada no motor consultava trecho de
  parágrafo, e por isso ninguém tinha topado nele.
- **D-038** — completar roda exatamente quando o arquivo não analisa. A primeira versão
  lia a análise corrente e não sugeria nada, nunca.
- **D-039** — o servidor não escolhe as camadas. Um que carregasse todas mostraria limpo
  um modelo que a CLI recusa.

**O que falta**: a pré-visualização ao lado do modelo. O motor já a entrega — `preview`
rende com «marcadores» e nunca exporta —, e o que falta é o caminho até a tela.

---

## F10 — Publicação (quase, 5 de setembro de 2026)

**Feito:** CI (entrou junto com o README em inglês), Aqua na suíte, Documenter gerando a
referência da API a partir das docstrings — publicada pelo próprio CI —, cobertura no
Codecov e, em 15 de setembro de 2026, o **site no ar**: a landing em `web/` na raiz do
`gh-pages` e a documentação em `/dev/` (item 6 de "o que resta", com as duas armadilhas do
Pages registradas lá).

**Sobre a cobertura, e por que ela é sinal fraco aqui.** Nenhum dos defeitos que os
modelos reais acharam — trinta e seis até o nº 15, contando os do servidor de linguagem —
era linha descoberta: todos estavam na **interseção de duas coisas cobertas
separadamente**, que é uma coisa que percentual de linha não mede e não pode medir. O `codecov.yml` põe as duas
checagens em `informational` de propósito — uma equipe que persegue o número escreve
testes que cobrem linhas sem afirmar nada.

O que ela pega, e que vale, é código que teste nenhum alcança. E há uma trava melhor que
ela para este projeto, na suíte: **todo código de diagnóstico registrado tem de ser
emitido em algum lugar de `src/` ou `lib/`**. Ela achou três de imediato — `K1213` e
`K1304`, que saíram do registro, e `K4003`, que era o código **certo** para o teto de
profundidade de inclusão num sítio que emitia o do vizinho, com a mensagem chutando
"provavelmente há um ciclo" sobre um caso em que não havia ciclo nenhum.

O Documenter mora em `docs/src/`, e os documentos **normativos** continuam em `docs/*.md`
sem passar por ele: eles são o registro do projeto, escritos para serem lidos no
repositório, e uma versão gerada seria uma segunda cópia a manter em dia.

**D-030**, observada ao rodar o Aqua: a extensão por `Val{nome}` **não é pirataria de
tipo**, e a ferramenta padrão do ecossistema concorda. O `Val{:extenso}` é um tipo da
camada porque o símbolo é dela. A escolha foi feita na F0 por outra razão — enumerar
formatadores por introspecção —, e essa propriedade veio junto.

**Falta, e é ação sua:** o registro no General. Os pacotes estão em `0.1.0` desde o
congelamento da sintaxe (D-077).

### O que o registro vai cobrar

- **`Kanon` e `Extenso` reprovam na checagem automática de similaridade de nome.** Medido
  contra a `Registry.toml`: `Kanon` tem distância de Damerau 2 de `Kaimon` e de `Kanones`;
  `Extenso`, 2 de `Extents`. O mínimo do AutoMerge é 3. Os dois vão exigir o rótulo
  `Override AutoMerge: name similarity is okay` e revisão humana. `KanonLegal` e
  `KanonScience` passam.
- **Os quatro pacotes vivem num repositório só.** O General aceita subdiretórios
  (`subdir=`), então não é impedimento — mas cada um precisa da sua própria tag.
- **Ordem obrigatória:** `Kanon` primeiro; `Extenso` depois dele; `KanonLegal` depois dos
  dois. Enquanto `Kanon` não estiver registrado, `Pkg.develop` local é a única forma de
  as camadas resolverem — que é como o CI faz hoje.

O CI entrou fora de fase, junto com o README em inglês: um badge de build sem CI afirma
o que não se verifica, e é a categoria de coisa que este projeto existe para não fazer.
Ele roda o núcleo em três versões de Julia e três sistemas, as três camadas cada uma no
ambiente dela, e **o teste de neutralidade num job separado**, onde nenhuma camada
existe — um teste que precisasse de `Extenso` para provar que `Extenso` não vazou não
provaria nada, e agora é a máquina quem garante essa condição.

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

Nenhuma bloqueia nada. Estão em ordem de quanto incomodariam se aparecessem.

| Dívida | Onde | Gatilho |
|---|---|---|
| `is not` em português vira `é não`, que é agramatical | `parse_rules.jl` | escrever `não (x é y)` resolve hoje; mudar a **ordem** da gramática por idioma seria versão maior |
| Texto em branco só é normalizado no campo de primeiro nível, não dentro de composto | `check.jl` | um `pessoa` com `nome = " "` passa pelo D-008. Fecha o mesmo buraco um nível abaixo |
| Escalar de camada vira `{}` no checklist | `contract.jl` | um gerador de formulário precisar da forma de `measure`. Um `kanon_json_type` é aditivo e cabe numa versão menor |
| `money` emite duas casas para toda moeda; JPY não tem centavos | `core_types.jl` | alguém escrever em iene. Exige casas por moeda no ambiente |
| O orçamento não é configurável pela CLI | `cli.jl` | um documento legítimo estourar o padrão |
| Coluna deslocada em um caractere na linha escapada com `\:` | `parse_text.jl` | quando incomodar; é o preço de ter uma contrabarra na coluna 0 |
| A mensagem de palavra-chave errada não diz "`rules` é a forma inglesa de `regras`" | `lex.jl`, `parse.jl` | a `KeywordTable` precisaria guardar o mapa reverso. Melhoria pura de mensagem |
| O arquivo `chave = valor` escrito à mão lê `drenagem = 1.320` como `1.32` | `cli.jl` | o `ask` recusa a resposta ambígua desde a D-069, e o arquivo digitado não passa por ele: `parse_data_value` não conhece o ambiente. O JSON não tem o problema, porque lá o número é da gramática do JSON. Gatilho: o primeiro modelo com dados digitados à mão em `chave = valor` com número agrupado |
| O escape do Markdown é o do CommonMark, e o leitor padrão do pandoc lê mais: `a)`, `(1)` e `iv.` no começo da linha abrem lista; `H~2~O` e `10^3^` são subscrito e sobrescrito no meio dela; `--` vira travessão e a aspa reta vira curva | `output.jl` | um valor com uma dessas formas chegar a um `.docx`. Registrado na D-070, conferido no pandoc 3.11: a reclamação nº 15 não tem nenhuma, e escapar `(` e `^` em todo Markdown encheria de barras o fonte de quem o lê no CommonMark |
| Os cinco pacotes vivem num repo só | `lib/` | o General aceita `subdir=`; extrair só se o registro exigir |
| A cobertura mede só o núcleo; as quatro camadas não sobem `lcov` | `CI.yml` | quando uma camada crescer a ponto de a leitura do número dela dizer algo. Hoje diria pouco: o sinal deste projeto está nas invariantes, não no percentual |

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

Contagem: **15 de 15 — o portão está fechado.** O que foi escrito cobrou o suficiente para dar razão ao portão —
o exemplo jurídico revelou três lacunas ao ser escrito na F0, e voltou a cobrar na F6 ao
contradizer a D-013 que veio depois dele. A locação, o relatório, o certificado, o laudo, o
edital, a doação, o ensaio, a verificação, a aula, os serviços, a procuração, a
notificação, o atestado e a reclamação, escritos com o motor já pronto e a suíte verde,
cobraram mais trinta e seis (D-031 a D-035 e D-040 a D-070) — **a taxa de descoberta não caiu quando o
código ficou bom; o décimo primeiro achou o motor inalcançável pela porta por onde o
redator entra, o décimo segundo achou a porta ainda fechada atrás de uma correção dada
como feita, o décimo terceiro achou a mesma porta fechada no editor, e o décimo quarto a
achou fechada para o idioma — e, aberta, um documento errado sem aviso atrás dela. O
décimo quinto passou por todas as portas do motor, e achou o documento errado depois da
última: no leitor que transforma a saída no arquivo que o redator abre.**

### O que a implementação já mudou na especificação

Cinquenta e sete decisões saíram de escrever o código e os documentos, e vinte e seis delas fecharam buracos
que nenhuma releitura teria encontrado — o texto era internamente coerente em todos os
casos:

| | O que estava errado |
|---|---|
| **D-019** | a fachada com closures era incompatível com a proibição de `eval` **e** com a obrigação 5-A ao mesmo tempo |
| **D-021** | a §4.4 enunciou o caso extremo de uma regra mais geral e parou nele |
| **D-023** | a API listava oito funções do protocolo e **nenhuma lia um campo** — o teorema tinha um furo do tamanho de um tipo composto |
| **D-026** | um formatador de camada valia em ambiente neutro, e o teste de neutralidade não o veria |
| **D-031** | a §9 prometia que o idioma só renomeia palavras-chave, e o mesmo modelo valia numa língua e não na outra |
| **D-032** | a §6.2 verificava a sequência de níveis só no texto; as regras produziam em execução o estado que ela proíbe |
| **D-033** | a §3.3 descreve um tipo do núcleo que a §2.1 torna indeclarável, e nenhuma das duas está errada sozinha |
| **D-034** | a regra do PDG estava certa e o modo de descobrir o algarismo estava errado, num caso em cada dez |
| **D-035** | a §10.2 promete arquivo, linha e coluna, e o arquivo estava errado sempre que havia mais de um |
| **D-037** | o trecho de um nó devia conter o dos filhos, e não continha — óbvio demais para estar escrito |
| **D-040** | a §4.2 e a §7.1 davam dois ofícios ao sujeito, e a checagem foi escrita para um só |
| **D-041** | a §3.3 mandava a camada obter os separadores do contexto, e a API não dava função para aplicá-los |
| **D-044** | a §6.4 dizia onde o rótulo aparece e a §11 dizia que o valor não altera a estrutura; nenhuma das duas percebeu que o **rótulo** alcança o começo da linha num formato de marcação |
| **D-045** | a §4.2 diz que o sujeito e o contrato são duas resoluções do mesmo escopo, e a garantia da D-020 foi escrita como se fossem dois escopos diferentes |
| **D-046** | a `api-extensao.md` listava `kanon_decode` entre oito funções sem dizer que, para um tipo composto, ela é a diferença entre existir e não existir |
| **D-048** | a §8.4 promete que a ordem dos **blocos** é a do arquivo, e o autor lê nela uma promessa sobre a ordem dos **elementos**, que ninguém fez — e nada impedia o nível de baixo de se pendurar na cópia errada |
| **D-049** | a §2.3 normalizava o branco no primeiro nível e a §3.1 estendia a nulabilidade ao composto; nenhuma das duas percebeu que a normalização também tinha de descer |
| **D-051** | a §9 dizia que a camada de idioma renomeia as palavras-chave, e a tabela sabia lê-las sem saber escrevê-las de volta |
| **D-052** | a F7 prometeu `Tables.jl` como a via das planilhas, e a §3.1 fez todo tipo de domínio composto; nenhuma das duas percebeu que uma célula não guarda um composto |
| **D-054** | a §9 promete que o idioma renomeia as palavras-chave, e a tabela foi escrita antes de a linguagem ter `include` — uma palavra-chave sem apelido não dá erro: vira prosa |
| **D-055** | o próprio parser já tinha escrito que a intenção denunciada não vira prosa em silêncio, e tinha escrito isso só para o cabeçalho de bloco |
| **D-056** | três documentos — o do núcleo, o do domínio e o do idioma — declaram cada um o que não têm, e nenhum dos três disse quem escreve a palavra que falta aos outros dois |
| **D-057** | a D-024 decidiu o que o rascunho faz com o **valor** que falta, e a §8.3 decidiu o que o plano faz com a **coleção** que falta; nenhuma das duas percebeu que o rascunho também monta plano |
| **D-058** | a §12 descreve a linha de comando desde a F0 e a §5 descreve as camadas desde a F0, e nenhuma das duas disse como se carrega uma camada pela linha de comando |
| **D-061** | a §12 dizia desde a F0 que o `ask` emite o JSON completo, a F9 o escreveu emitindo `chave = valor`, e nenhuma das duas percebeu que o formato escolhido não escreve metade dos tipos que o contrato declara |
| **D-070** | a §4.1 deixou ao formato de saída decidir se a quebra de linha é rígida, e a F8 escreveu dois formatos sem decidir — o que, no Markdown e no Typst, é decidir pelo espaço |

E uma na direção contrária, que é a primeira: a **D-043** não mudou a especificação —
a §8.3 dizia desde a F0 que o caminho iterado denota o elemento corrente *"tanto no texto
quanto no `when`"*, e era o render que não obedecia. O texto normativo achou o defeito no
código, que é o que ele existe para fazer.

Se dois modelos cobrarem na mesma proporção, a 1.0 será uma linguagem diferente da que
a F0 desenhou — e melhor.

**O método, fixado pelo segundo modelo e confirmado pelo terceiro.** Escreva o modelo
como um redator escreveria, sem consultar a implementação; escreva a saída esperada **à
mão**, antes de renderizar; e só então compare. Na locação as duas coincidiram byte a
byte; no relatório divergiram em **um caractere** — `21.40 ± 0.30` onde eu tinha escrito
`21.4 ± 0.3` —, e esse caractere era a D-034. Copiar a saída do próprio motor teria
enterrado o defeito no golden, onde ele passaria a ser a definição do certo.

**E é o único método que pega o defeito sem diagnóstico.** No roteiro nº 10 o motor não
tinha o que dizer: a linha da inclusão era prosa bem-formada, o modelo carregava limpo e o
`check` passava. O que não batia era a **saída** — o documento escrito à mão não tinha um
parágrafo com o caminho de um arquivo dentro. Dos dois casos de documento falso que o
acervo já produziu, nenhum dos dois foi achado por teste de unidade, e os dois foram
achados pela mesma folha de papel.
