# Registro de decisões

> Uma entrada por decisão de design não óbvia: o que se decidiu, quais eram as
> alternativas, por quê, e a data. Escrito no momento da decisão.
>
> Em seis meses ninguém lembra por que os colchetes se comportam daquele jeito, e sem o
> registro a decisão é revertida por engano por alguém tentando "simplificar".

Estado possível de uma entrada: **proposta** (aguarda aceite), **aceita**, **revista**,
**revertida**.

---

## D-001 — Numeração aninhada entra na v1

*2026-09-03 · proposta · questão 15.1*

**Decisão.** Sim, na v1. Nível dado pela repetição do marcador: `::` nível 1, `:::`
nível 2, `::::` nível 3. Cada estilo tem sua própria família de contadores.

**Alternativas.** (a) Só nível 1 na v1, hierarquia na v2. (b) Hierarquia por indentação.
(c) Hierarquia por um campo no cabeçalho (`:: payment level=2`).

**Por quê.** O argumento decisivo é o mesmo que a seção 6.1 do projeto usa para o pragma
de versão: **modelos viram acervo**. Introduzir hierarquia depois de existirem duzentas
minutas exige versão maior da linguagem, porque muda a numeração de documentos já
escritos. Introduzi-la agora custa um vetor de inteiros no passo de análise e uma regra
de zeramento. O custo é assimétrico em duas ordens de grandeza e cai todo no lado de
adiar.

Contra (b): indentação significativa no plano do texto é incompatível com prosa —
parágrafos recuados são conteúdo. Contra (c): acrescenta vocabulário ao cabeçalho para
expressar algo que a repetição do marcador já expressa visualmente.

**Risco aceito.** Aumenta a F5. Mitigação: o teto de níveis na v1 é 3, e nível órfão
(um `:::` sem `::` antes, no mesmo estilo) é erro, o que elimina a maior parte dos casos
de borda.

---

## D-002 — Uma regra de cada espécie por bloco; duas iguais é erro

*2026-09-03 · proposta · questão 15.2*

**Decisão.** Um bloco admite no máximo um `when` e no máximo um `one for each`. Duas
linhas `when` para o mesmo bloco são **erro de referência**, não conjunção implícita.
Para combinar, escreve-se uma expressão com `and`/`or` e parênteses.

**Alternativas.** (a) Múltiplos `when` combinados por `and`. (b) Múltiplos combinados
por `or`. (c) Combinação declarada (`all`/`any`).

**Por quê.** "Como duas regras se combinam" é exatamente a pergunta que o leitor não
deveria precisar fazer. Qualquer combinação implícita é adivinhada errado por parte dos
leitores, e quem adivinha certo está confiando numa convenção invisível — o modo de
falha do XSLT em miniatura. Escrever `and` custa três caracteres e remove a pergunta.

**Consequência.** `when` e `one for each` **podem** coexistir no mesmo bloco: o `when` é
então avaliado por iteração, com o identificador do sujeito denotando o elemento
corrente. `grantor one for each seller` + `grantor when seller is not minor` lê-se "um
bloco por vendedor, exceto os menores". Isso é útil e não é ambíguo, porque as duas
espécies fazem coisas diferentes.

---

## D-003 — Mistura de palavras-chave é erro; o idioma é declarado no pragma

*2026-09-03 · proposta · questão 15.3*

**Decisão.** Erro, como era a inclinação do projeto. E, além disso, o idioma é
**declarado** no pragma (`kanon 1 pt`), não inferido do primeiro cabeçalho encontrado.
Omitido, o arquivo é inglês canônico.

**Alternativas.** (a) Permitir mistura. (b) Proibir, inferindo o idioma pelo primeiro
cabeçalho. (c) Proibir com declaração explícita (escolhida).

**Por quê.** Contra (a): um arquivo misto não é legível nem por quem só sabe o inglês
canônico nem por quem só conhece os apelidos; e a suíte golden precisaria cobrir o
produto cartesiano dos dois vocabulários. Contra (b): inferência exige que o parser
consulte o ambiente para saber se `dados` é palavra-chave, o que viola a restrição
"`parse` não consulta o `Environment`" (`ast.md`, seção 8) e produz mensagens de erro
ruins ("`regras` não é uma palavra-chave" quando o problema é que o arquivo começou em
inglês).

Com (c), a tabela de apelidos é escolhida antes do lex, o parser continua puro, e a
mensagem de erro pode dizer "o arquivo declara `pt`; `rules` é a forma inglesa de
`regras`".

**Consequência.** Um comando `kanon canon modelo.kanon` que reescreve um arquivo
localizado para o inglês canônico passa a ser trivial e vale a pena na F7 — é o que
garante que o acervo continua legível se a camada de idioma sumir.

---

## D-004 — Escape de colchetes por contrabarra: `\[` e `\]`

*2026-09-03 · aceita como duplicação · **revista na F1**, 3 de setembro de 2026*

**Decisão original (revogada).** `[[` produz `[` e `]]` produz `]`, simetricamente a
`{{` e `}}`.

**Decisão em vigor.** Chaves e parênteses continuam escapando por duplicação (`{{`,
`}}`, `((`, `))`). **Colchetes escapam por contrabarra**: `\[`, `\]`, e a contrabarra
literal é `\\`. Resolvido no lexer; o render nunca vê a forma escapada.

**Por que a revisão, e ela não é estética.** Ao implementar o varredor do plano do texto
na F1, o caso normativo nº 11 (`{a}[, {b}[ e {c}]], fim`) parou de analisar. O motivo é
estrutural e não tem conserto dentro da duplicação:

> **Grupos aninham.** Dois grupos que fecham lado a lado produzem `]]` — uma sequência
> que a própria linguagem gera. Não há regra que distinga o `]]` de `[{a}[{b}]]` do `]]`
> que o autor escreveu querendo um colchete literal.

O mesmo não vale para chaves nem para parênteses: interpolação não aninha e marca de
flexão não aninha, então `}}` e `))` nunca são produzidos pela linguagem. Por isso a
revisão atinge **só** os colchetes: muda-se o que está quebrado, e nada além.

A contrabarra já existia na linguagem (o escape de coluna 0, `\:`), de modo que a
revisão não introduz caractere novo — apenas estende um que já estava lá.

**Alternativas consideradas na revisão.** (a) `]]` literal só em profundidade zero:
não resolve, porque `[[{a}] {b}]` é aninhamento legítimo em profundidade zero.
(b) Exigir espaço entre colchetes de fechamento (`] ]`): inaceitável, muda o texto de
saída. (c) Contrabarra para todos os escapes do plano do texto, abandonando a duplicação
também em chaves e parênteses: é a opção mais simples de ensinar (uma regra em vez de
duas) e continua em aberto — ver a pergunta ao fim da F1.

**O raciocínio original, e onde ele falhou.** A duplicação foi escolhida para manter a
linguagem sem caractere de escape global — cada especial escapando a si mesmo, sem
obrigar a escapar a contrabarra em prosa que nunca usa colchetes. O raciocínio estava
certo sobre o custo da contrabarra e **errado sobre um fato da própria linguagem**: ele
supunha que `]]` só apareceria se o autor o escrevesse. Não é verdade quando grupos
aninham, e grupos aninham por especificação (casos normativos 11 e 12). O erro não foi
de ponderação; foi de não confrontar a decisão com a construção que ela precisava
suportar. Escrever os casos normativos antes do código é o que o revelou.

A terceira alternativa da época — não ter escape, exigindo que colchetes literais viessem
de um campo — continua descartada: citação científica (`[1]`) e nota de rodapé são comuns
demais.

**Custo aceito.** `\[1\]` para uma citação é menos bonito que `[1]` nu, mas o colchete
nu não poderia funcionar: `[1]` é um grupo opcional sem interpolação direta, que a
validação já recusa (D-008 e o teorema da lacuna dependem disso).

**A contrabarra na coluna 0** continua existindo pelo mesmo motivo de antes: `\:` escreve
uma linha de prosa iniciada por dois-pontos, que de outro modo colidiria com o cabeçalho
de bloco. Com a revisão, ela deixou de ser uma exceção isolada e passou a ser o mesmo
mecanismo do resto do plano do texto.

---

## D-005 — Inclusão, não herança

*2026-09-03 · proposta · questão 15.5*

**Decisão.** Inclusão de blocos. **Não** há herança de modelos (`extends`/`block` à la
Jinja), e não haverá.

**Alternativas.** (a) Herança. (b) Inclusão (escolhida). (c) Ambas.

**Por quê.** Herança inverte o controle: para saber o que sai, é preciso ler o pai, e o
pai não está no arquivo. Isso torna falso o critério 1 do projeto — "um redator abre um
modelo e lê o texto que vai sair" — e é a versão branda do modo de falha do XSLT. A
inclusão é local e aditiva: no ponto da inclusão está escrito o nome do que entra ali, e
a leitura linear continua sendo um limite superior do documento.

**A consequência que decide a questão.** Inclusão compõe com o contrato e herança não.
Um fragmento incluído traz o seu próprio plano `data`, que é **unificado** com o do
hospedeiro: mesmo nome e mesmo tipo funde; mesmo nome e tipos diferentes é erro na
carga; obrigatoriedade é o máximo das duas. O checklist do modelo composto é derivado.
Com herança, o contrato de um bloco sobrescrito é indeterminado até saber quem
sobrescreve o quê. A ideia da unificação vem da CUE (`estado-da-arte.md`, seção 10.4).

**Escopo.** F7. O carregador tem raiz configurada, recusa caminho absoluto, travessia
(`..`) e link simbólico para fora da raiz, e detecta ciclo.

---

## D-006 — Sem tipos-soma na v1; a necessidade se atende na camada de domínio

*2026-09-03 · proposta · questão 15.6*

**Decisão.** Não na v1. A sintaxe `person | company` fica **reservada** (o lexer a
reconhece e erra com "tipos-soma não existem na versão 1"), para que possa ser
adicionada em 1.x sem versão maior.

**Alternativas.** (a) Tipos-soma com discriminação no plano das regras. (b) Tipos-soma
com campos comuns exigidos. (c) Não ter (escolhida).

**Por quê.** Um tipo-soma quebra a verificação estática: o tipo de `{party.name}` passa a
depender do caso em tempo de execução, e portanto a resolução do formatador — que a
especificação exige fazer **sem dados** (6.3) — deixa de ser possível, a menos que se
exija um conjunto comum de campos, e nesse ponto já se está descrevendo um supertipo.
Além disso, discriminar o caso no texto exigiria um `when` por variante dentro do plano
do texto, que é lógica na prosa.

**E a necessidade é real,** o que torna importante dizer como se atende sem o recurso:
modele `party` como **um** tipo composto na camada de domínio, com um atributo
`is company`. Os campos comuns (`name`, `document`, `address`) são campos do tipo; os
específicos são opcionais e portanto exigem `[...]`; o plano das regras discrimina com
`when party is company`. Nada disso toca o núcleo.

**Este é o melhor teste da arquitetura de camadas encontrado até aqui,** e por isso vira
caso obrigatório da F6: se `party` não puder ser modelado assim, a separação
núcleo/domínio é mais fraca do que se supõe e a decisão volta à mesa.

---

## D-007 — Um formatador por interpolação na v1

*2026-09-03 · proposta · questão 15.7*

**Decisão.** Um só. `{v:round:written}` e `{v:round(2)}` são sintaxe **reservada**: o
lexer as reconhece e erra explicitamente, em vez de aceitá-las com outro significado.

**Alternativas.** (a) Encadeamento livre. (b) Encadeamento com aridade fixa. (c) Um só
(escolhida).

**Por quê.** Encadear exige que formatadores deixem de ser *renderizadores*
(`tipo → texto`) e virem *transformações tipadas* (`money → money`, depois
`money → texto`), o que é uma pequena álgebra de funções com inferência de tipo
intermediária — bem mais superfície de bugs e de mensagens de erro do que parece. E é
lógica migrando para dentro da prosa pela porta dos fundos.

**A necessidade real** (arredondar e depois escrever por extenso) se atende com um
formatador nomeado composto na camada (`written_round2`) ou, em 1.1, com argumentos de
formatador — que é a forma que o ICU MessageFormat 2.0 adota (`:number` com opções
nomeadas) e a referência a seguir quando chegar a hora.

**Reservar as duas sintaxes agora é o que torna essa evolução aditiva.** Aceitar hoje
`{v:round:written}` como "formatador chamado `round:written`" tornaria a adição uma
mudança de semântica, isto é, versão maior.

---

## D-008 — Um único conceito de ausência; texto em branco não é lacuna

*2026-09-03 · proposta · questão 15.8*

**Decisão.** Chave ausente no JSON, `null`, `nothing` e `missing` são **o mesmo nulo**.
Não se distingue "ausente" de "presente e nulo" — a distinção não existe na linguagem.
Adicionalmente: string vazia ou só com espaços em campo `text` **obrigatório** é erro
de contrato; em campo **opcional** é normalizada para nulo, e `check` lista a
normalização como aviso.

**Alternativas.** (a) Distinguir ausente de nulo. (b) Não distinguir, e aceitar `""`
como valor. (c) Não distinguir, e tratar branco como ausência (escolhida).

**Por quê.** Contra (a): seriam dois conceitos de ausência, o que a seção 6.3 do projeto
proíbe, e a distinção é ruído em JSON gerado por ferramenta — nem todo produtor de JSON
controla se emite a chave.

Contra (b), e é o ponto que decide: `""` seria a porta pela qual a lacuna silenciosa
voltaria com todos os princípios formalmente intactos. `[, sob o regime da {regime}]`
com `regime = ""` renderiza `", sob o regime da "` — um documento defeituoso, gerado por
um motor que declara não gerar documentos defeituosos. O teorema da lacuna
(`especificacao.md`, seção 14) é falso sem esta decisão.

**Custo aceito.** Um campo de texto legitimamente vazio deixa de ser expressável.
Em documentos, isso praticamente não ocorre; se ocorrer, a saída é declarar o campo
opcional e enviar nulo, que é o que o autor quis dizer.

---

## D-009 — O checklist é JSON Schema 2020-12 com extensão `x-kanon`

*2026-09-03 · proposta · além das oito questões*

**Decisão.** `kanon contract` emite JSON Schema draft 2020-12 válido, com o que não cabe
no padrão sob a chave `x-kanon`. Saída determinística e comparável em `diff`.

**Alternativas.** (a) Formato JSON próprio, mais direto. (b) JSON Schema (escolhida).

**Por quê.** O custo de emitir JSON Schema em vez de um objeto próprio é de horas; o
benefício é que geradores de formulário, validadores e ferramentas de documentação já
existentes consomem o checklist sem adaptador — o que importa muito para o editor da F9
e para quem integrar Kanon a um sistema de cartório. Não inventar vocabulário onde há
convenção adotada é diretriz da seção 2 do projeto.

**Risco.** JSON Schema não expressa cardinalidade exata de forma natural nem
formatadores; daí o `x-kanon`. O documento emitido continua válido para quem ignora a
extensão.

---

## D-010 — Orçamento determinístico de recursos, não limite de tempo

*2026-09-03 · proposta · além das oito questões*

**Decisão.** Os limites da seção 8 do projeto são contagens: nós visitados, bytes de
saída, profundidade de inclusão, iterações. **Não** há limite de tempo dentro da
semântica da linguagem. Limite de tempo continua existindo, mas no processo da CLI.

**Por quê.** Um limite de tempo de parede torna *não determinístico se o render erra ou
não*: a mesma entrada erra numa máquina carregada e passa numa ociosa. Isso contradiz
diretamente o princípio 5 (determinismo) e tornaria a suíte golden instável em CI, que é
justamente onde uma máquina lenta aparece.

---

## D-011 — A AST é projetada para geração de código, mas a v1 interpreta

*2026-09-03 · proposta · além das oito questões*

**Decisão.** Ver `ast.md`. Nós imutáveis (I1); nenhum resultado de análise dentro do nó
(I2); nenhuma dependência de ordem de visita (I3); nada de iteração de `Dict` alcançando
o texto (I4). A numeração de blocos vive em tabela lateral produzida por `analyze`.

**Por quê.** É a obrigação explícita da seção 5-A do projeto. O ponto não óbvio, e o que
precisa estar registrado, é **qual** consequência prática ela tem: a tentação natural,
ao implementar a F5, é guardar o número calculado dentro do `Block` durante uma
travessia. Isso funciona, é mais curto, e mata a v2 — porque força mutação durante a
análise e impede analisar o mesmo modelo em dois ambientes.

**Salvaguarda.** Um teste desde a F3 afirma que nenhum campo de nó muda depois de
`analyze` e que renderizar blocos em ordem invertida produz os mesmos textos por bloco.
Se alguém precisar guardar algo no nó, o teste quebra e a decisão volta à mesa em vez de
acontecer por descuido.

---

## D-012 — Comentários no plano do texto usam `:#`, não `#`

*2026-09-03 · proposta · revisão da seção 6.2 do projeto*

**Decisão.** `#` até o fim da linha é comentário nos planos `data` e `rules`. No plano do
texto, comentário é uma **linha inteira** iniciada por `:#` na coluna 0; `#` em prosa é
prosa.

**Por quê.** A F8 tem Markdown como saída primeira, e em Markdown `#` e `##` iniciam
títulos. Com a regra original, `# CLÁUSULAS` no plano do texto desapareceria do
documento silenciosamente — que é a categoria de defeito que a linguagem inteira existe
para impedir. Descoberto na F8, o conserto seria versão maior.

`:#` reusa o sigilo estrutural que o plano do texto já tem (dois-pontos na coluna 0) e
não acrescenta conceito novo.

---

## D-013 — A flexão só altera a palavra que carrega a marca

*2026-09-03 · proposta · revisão da seção 6.4 do projeto*

**Decisão.** Um ponto de flexão é uma marca registrada colada ao fim de uma palavra. O
núcleo entrega `(palavra, marca, sujeito)` à camada de idioma e substitui pela devolução.
**Nenhuma outra palavra da prosa é alterada por nada.** Escape por duplicação de
parênteses: `((a))`.

**Por quê.** A frase "com sujeito plural, o bloco pluraliza", lida em sentido amplo,
significaria o motor pluralizando palavras arbitrárias do texto do autor. Isso é
reescrita automática de prosa: erra em nome próprio, sigla, estrangeirismo e termo
técnico (risco 16.3), erra de forma imprevisível, e não há escape razoável que cubra
tudo. Com o invariante, escrever a marca é o consentimento explícito do autor, palavra a
palavra, e o escape por marca é suficiente porque nada além da marca é tocado.

**Consequência para a redação dos modelos.** `residente e domiciliado(a)` com sujeito
feminino plural produz `residente e domiciliadas`, não `residentes e domiciliadas`. Para
o resultado completo o autor escreve `residente(s) e domiciliado(a)`. É mais trabalho ao
escrever o modelo e é o único jeito de o resultado ser previsível.

---

## D-014 — O reparo de emenda é local, nunca global

*2026-09-03 · proposta · revisão da seção 6.5 do projeto*

**Decisão.** Depois da elisão, o motor aplica as regras de pontuação **apenas nas
posições onde removeu texto** (as emendas), nunca varrendo o parágrafo.

**Alternativas.** (a) Normalização global do parágrafo (colapsar espaços múltiplos,
normalizar sequências de pontuação em todo lugar). (b) Reparo local (escolhida).

**Por quê.** Com (a), o motor editaria pontuação que o autor digitou de propósito:
espaçamento em citação, reticências, ponto-e-vírgula estilístico, dois espaços após o
ponto em texto herdado. O motor não tem o direito de editar prosa que ele não removeu —
e a violação seria descoberta em produção, num documento assinado.

O reparo local também é o que torna o algoritmo testável: cada caso da tabela normativa
(`especificacao.md`, seção 5.3) tem uma emenda identificável e um resultado exato. Um
reparo global só é testável por amostragem.

**Custo aceito.** Espaço duplo *fora* de uma emenda sobrevive à saída, mesmo quando é
erro de digitação do autor. Correto: não é problema do motor.

---

## D-015 — Regras só removem ou repetem; nunca inserem, substituem ou reordenam

*2026-09-03 · proposta · além das oito questões*

**Decisão.** Invariante normativo do plano das regras. A ordem dos blocos na saída é
sempre a ordem do plano do texto.

**Por quê.** É a resposta estrutural ao risco 16.2 e ao modo de falha real do XSLT
(`estado-da-arte.md`, seção 6): lá, qual template roda para um nó depende de casamento de
padrão e prioridade, e nenhuma leitura linear prevê a saída. Com este invariante, a
leitura do plano do texto é um **limite superior confiável** do documento: tudo que sai
está ali, na ordem em que está ali, e a regra só pode ter tirado ou repetido.

Sem ele, a mitigação do 16.2 dependeria inteiramente do editor da F9 e a linguagem seria,
de fato, pior na prática que um motor convencional. Com ele, o editor melhora a
experiência mas não é condição de sanidade.

**Consequência.** Nunca haverá em Kanon um `insert`, um `override` de bloco, um
`sort by`, nem regra que mova bloco. Pedidos nesse sentido se atendem escrevendo os
blocos na ordem desejada e removendo os que não se aplicam.


---

## D-016 — Um grupo opcional não atravessa fronteira de parágrafo

*2026-09-03 · proposta · descoberta na F1*

**Decisão.** `[` e `]` têm de abrir e fechar dentro do mesmo parágrafo. Um grupo aberto
e não fechado até a linha em branco seguinte é erro de sintaxe (`K1208`).

**Alternativas.** (a) Grupo pode abranger vários parágrafos. (b) Grupo confinado ao
parágrafo (escolhida).

**Por quê.** Com (a), a árvore deixa de ser `Bloco → Parágrafo → nós`: um grupo ficaria a
cavaleiro de dois parágrafos e nenhum dos dois o conteria. Isso obrigaria ou a achatar o
parágrafo (perdendo a unidade de que o reparo de emenda precisa para remover parágrafo
vazio, `especificacao.md` §5.2 passo 5) ou a inventar um nó "fragmento de parágrafo".

O caso normativo nº 13 — elidir um parágrafo inteiro — continua possível: o grupo abre no
começo do parágrafo e fecha no fim dele. Nada do que a especificação pedia se perdeu.

**Consequência.** Um trecho opcional que abranja vários parágrafos se escreve como
vários blocos com a mesma regra `when`, que é a construção que a linguagem já tem para
isso — e que, ao contrário do grupo gigante, aparece no plano das regras onde o leitor
pode vê-la.

---

## D-017 — Problema na linha de versão é fatal

*2026-09-03 · proposta · descoberta na F1*

**Decisão.** Um problema no pragma (ausente, malformado, versão maior desconhecida,
versão menor acima da suportada, idioma sem camada) interrompe a análise imediatamente,
em vez de acumular com os erros dos planos.

**Por quê.** É a única exceção à regra de acumulação (§10.3), e ela se justifica: se a
versão da linguagem ou o idioma são desconhecidos, todo erro subsequente é consequência
de ler o arquivo com a gramática errada. Um arquivo `kanon 2` analisado por um motor da
versão 1 produziria dezenas de erros, nenhum deles verdadeiro. O redator precisa ver
**um** problema, não vinte consequências dele.

Medido na F1: sem esta regra, um arquivo sem pragma produzia quatro diagnósticos, três
deles falsos.


---

## D-018 — Duas convenções de escape, e não uma

*2026-09-03 · proposta · pergunta deixada em aberto pela revisão de D-004*

**Decisão.** O plano do texto mantém **duas** convenções, e não se unifica tudo na
contrabarra:

| Caractere | Literal se escreve | Por quê essa e não a outra |
|---|---|---|
| `{` `}` | `{{` `}}` | interpolação não aninha, logo `}}` nunca é gerado pela linguagem |
| `(` `)` | `((` `))` | marca de flexão não aninha, logo `))` nunca é gerado pela linguagem |
| `[` `]` | `\[` `\]` | grupos **aninham**: `[{a}[{b}]]` gera `]]`, e a duplicação seria ambígua (D-004) |
| `\` | `\\` | necessário para escrever `\[` literalmente |

Fora dessas posições a contrabarra **não é especial**: `\alpha`, `C:\Users\Ana` e
`\(\alpha\)` atravessam o motor intactos.

**A alternativa, e por que foi descartada.** Unificar tudo na contrabarra
(`\{ \} \[ \] \( \) \\`) é uma regra em vez de duas, e foi a inclinação natural ao
fim da F1. Verificando no código antes de decidir, ela tem um custo que a torna pior:

> `\(` e `\)` são os delimitadores de matemática em linha do LaTeX. Com a unificação,
> um autor que colasse `\(\alpha\)` num relatório científico receberia `(\alpha)` na
> saída — **alteração silenciosa do texto do autor**, que é exatamente a categoria de
> defeito que a linguagem inteira existe para impedir.

Hoje esse trecho atravessa intacto; medido, não estimado. Como o domínio científico é
justamente o que prova a neutralidade da arquitetura (seção 10.2 do projeto), quebrar
notação científica para ganhar uma regra a menos é uma troca ruim.

Braces não entram na conta em nenhum dos dois desenhos: `\{a\}` do LaTeX quebra de
qualquer forma, porque `{` é sempre estrutural — mas quebra **com erro**, não em
silêncio, o que é aceitável.

**As duas convenções não são arbitrárias.** Elas seguem o peso estrutural do caractere:
quem aninha não pode duplicar; quem não aninha, pode. A regra que o redator aprende é
"dobre o caractere; o colchete é a exceção, porque grupo cabe dentro de grupo".

**Colisão conhecida e assumida.** `\[` e `\]` são os delimitadores de matemática em
bloco do LaTeX, e num modelo Kanon eles produzem colchetes literais. Não há saída: `[` é
estrutural em Kanon e precisaria de escape de todo modo. Fica documentado para quem
escrever modelos científicos.

**Momento da decisão.** Esta é a hora de mexer: não há acervo. Depois do congelamento da
sintaxe, trocar qualquer uma das duas convenções é versão maior.

---

## D-019 — A fachada registra o **nome**; o comportamento é sempre despacho

*2026-09-04 · aceita · surgida ao implementar a F2.1*

**Decisão.** `register_type!(b, T; aliases)` registra apenas o vínculo entre o tipo
Julia `T` e o nome que ele tem na linguagem, mais os apelidos de idioma desse nome. O
que o tipo **faz** — validar, formatar, decodificar, comparar, responder atributo — é
sempre método de função genérica, definido no módulo da camada, sem passar pelo
ambiente.

**O problema.** `api-extensao.md` §2.2 desenha a fachada recebendo *closures*
(`validate = ...`, `formats = (written = ...,)`) em tempo de execução, dentro de
`configure!(builder)`. Isso é incompatível com duas exigências já escritas no mesmo
documento: a proibição de `eval` (§1) e a obrigação 5-A, que veta manter um `Dict` de
formatadores. Uma fachada que recebe closures em runtime só pode guardá-las num
dicionário consultado pelo motor — que é exatamente o que 5-A proíbe — ou gerar métodos
com `eval`, que §1 proíbe. Não havia terceira saída, e a contradição só apareceu quando
o código foi escrito.

**Alternativas.** (a) Guardar as closures no ambiente e consultá-las no render: viola
5-A, e quebra a promessa da §2.1 de que despacho direto e fachada são equivalentes —
seriam dois caminhos com semânticas diferentes. (b) `eval` na construção do ambiente:
viola §1, introduz *world age* no meio do render e torna a construção do ambiente não
reentrante. (c) Separar nome de comportamento (escolhida).

**Por quê.** A separação já estava implícita na própria §5: "o que é global (métodos) é
aditivo e o que é conflitante (nomes) é local ao ambiente". Nome precisa ser local
porque dois domínios podem disputar `party`; comportamento não precisa, porque
`format(::Money, ::Val{:written}, ctx)` é um método e métodos são aditivos. A fachada
tentava carregar as duas coisas, e só a primeira exige um ambiente.

**Consequência para a F6.** `@kanon_type` continua sendo o açúcar prometido, e é ela
que passa a aceitar a forma da §2.2 — mas como **macro**, expandindo em tempo de carga
do módulo da camada para os métodos da §2 mais uma chamada a `register_type!`. As duas
obrigações da §2.3 continuam valendo e ficam mais fáceis de honrar: tudo que a macro
gera é escrevível à mão, e `@macroexpand` não menciona nada de não exportado.

**O que isso preserva.** O teste normativo "um formatador acrescentado só por despacho
aparece na validação e na mensagem de erro, sem registro adicional" passa a valer por
construção, e não por coincidência de implementação: não existe outro caminho.

---

## D-020 — A nulabilidade do sujeito atravessa o bloco inteiro

*2026-09-04 · aceita, **revista na F2.5** no mesmo dia · surgida ao implementar a F2.2*

**2ª revisão (F5).** A garantia deixou de valer só para o sujeito e passou a valer para
**todo caminho** que o `when` do bloco afirme presente. `b when notes is present` com
`{notes}` no texto era o padrão mais natural da linguagem e exigia colchetes redundantes:
o autor já tinha escrito a condição, e o motor mandava escrevê-la de novo em outra
notação. A garantia cobre o **prefixo**, e não o caminho inteiro — `seller is present`
não diz nada sobre `spouse`, que é opcional dentro de `person`.

**Revisão (F2.5).** O refinamento previsto abaixo foi feito assim que `block_rule` e
`block_foreach` passaram a existir. Um sujeito **não** propaga nulabilidade quando o
bloco tem `one for each C` — a iteração entrega um elemento, nunca o nulo — ou quando o
`when` do bloco afirma a presença do sujeito.

O reconhecimento da afirmação é deliberadamente conservador: uma conjunção em que algum
termo seja `C is present`, `C is not absent` ou `not (C is absent)`. Um `or` não garante;
uma condição que implique a presença por caminho indireto também não. Dizer que garante
quando não garante reabriria a lacuna que a F2.3 fechou; o custo de não reconhecer é um
par de colchetes a mais, e o redator sempre pode escrevê-lo.

**Decisão.** Um bloco cujo sujeito é um caminho nulável torna nulável **todo** caminho
lido dentro dele pela via do sujeito. `: b <- buyer` com `buyer` opcional faz `{name}`
nulável, e portanto exigir grupo (F2.3).

**Alternativas.** (a) Tratar o sujeito como sempre presente dentro do bloco, deixando a
ausência para o render. (b) Propagar (escolhida).

**Por quê.** Contra (a): o bloco existiria com o sujeito nulo e `{name}` renderizaria
vazio — a lacuna silenciosa que o teorema da §14 proíbe, aberta justamente no ponto em
que o modelo parece mais seguro. A propagação é a leitura conservadora, e a
conservadora é a única compatível com "falhar alto".

**Consequência, e o que a F2.5 precisa saber.** Hoje a única saída do redator é envolver
o texto em grupo. Isso é correto mas incômodo, e há duas construções que deveriam
dispensá-lo, porque tornam o sujeito presente por construção:

- `b when buyer is present` — a regra já garante que o bloco só existe com o sujeito;
- `b one for each buyers` — a iteração entrega um elemento, nunca o nulo.

Ambas dependem da tabela de regras por bloco, que só existe na F2.5. Quando ela existir,
o refinamento é: o sujeito de um bloco assim **não** propaga nulabilidade. Até lá a
exigência de grupo vale, o que é o lado seguro de errar — afrouxar depois é aditivo,
apertar depois quebraria acervo.

**O que não muda em hipótese nenhuma.** A nulabilidade que vem do próprio caminho
(`{seller.spouse.name}`) continua valendo dentro de qualquer bloco: nenhuma regra sobre
o sujeito diz coisa alguma sobre `spouse`.

---

## D-021 — Grupo cujas interpolações diretas são todas garantidas também é erro

*2026-09-04 · aceita · surgida ao implementar a F2.3*

**Decisão.** `[no valor de {price}]`, com `price` obrigatório, é erro (`K2011`), pelo
mesmo motivo e com a mesma força com que a §4.4 já torna erro o grupo **sem** nenhuma
interpolação direta (`K2010`): nenhum dos dois pode elidir.

**A lacuna da especificação.** A §4.4 escreve a regra como "um grupo sem nenhuma
interpolação direta nunca poderia ser elidido: é erro", e dá a razão — *nunca poderia
ser elidido*. Essa razão vale igualmente para um grupo cujas interpolações diretas são
todas obrigatórias ou com padrão: a regra de elisão diz que o grupo sai se **alguma
direta resolve para nulo**, e uma direta que o contrato garante nunca resolve para nulo.
A especificação enunciou o caso extremo de uma regra mais geral e parou nele.

**Alternativas.** (a) Seguir a letra e aceitar o grupo garantido. (b) Aviso em vez de
erro. (c) Erro (escolhida).

**Por quê.** Contra (a): o grupo garantido é pior que ruído — ele **mente**. O redator
que escreve `[pelo preço de {price}]` está declarando "este trecho é dispensável", e o
motor entrega um trecho que nunca sai. Quem lê o modelo depois acredita na intenção
escrita, não no comportamento. Contra (b): um aviso que ninguém corrige é a lacuna
silenciosa em outro disfarce, e a linguagem não tem severidade intermediária para
verdade estrutural. Com (c), a correção é sempre uma das duas que a mensagem sugere, e
ambas são de uma edição: tornar o campo opcional, ou tirar os colchetes.

**Momento.** É a hora de decidir, porque não há acervo. Depois do congelamento da
sintaxe, apertar essa regra quebraria modelos existentes; afrouxá-la, não. Errar para o
lado apertado é o único que continua reversível.

**Efeito colateral aceito: aninhar grupos passa a exigir intenção.** `[[{notes}]]` é
`K2010` e `[a [b {notes}] c {price}]` é `K2011`, porque em ambos o grupo externo não tem
nenhuma direta nulável própria. O aninhamento legítimo continua valendo, e é o que a
prática de fato produz — cada grupo com a sua nulável:

```
[casado com {spouse.name}[, sob o regime de {spouse.regime}]]
```

---

## D-022 — Campo a mais nos dados é aviso, não erro

*2026-09-04 · aceita · surgida ao implementar a F2.6*

**Decisão.** Um campo que a entrada traz e o contrato não declara é aviso (`K3021`), com
sugestão de nome. Ele é ignorado: só o que o modelo declara chega ao documento.

**Alternativas.** (a) Erro, coerente com o `additionalProperties: false` que
`contract(tmpl)` emite. (b) Silêncio. (c) Aviso (escolhida).

**Por quê.** Contra (a): a mesma fonte alimenta vários modelos — uma tabela de quarenta
colunas serve cinco documentos que usam seis campos cada — e recusar tornaria a ingestão
da F7 inútil sem uma projeção manual por modelo. Contra (b): o campo a mais é o sintoma
mais visível de um nome digitado errado, e desperdiçá-lo é perder a chance de dizer
"você quis dizer `seller`?" no momento certo.

**O que torna (c) seguro, e não uma frouxidão.** Um campo a mais **nunca esconde um erro
sozinho**: se o nome foi digitado errado, o campo declarado aparece como ausente e o erro
sai por `K3001`, que é erro de verdade. O aviso não substitui nada — ele acrescenta a
explicação ao erro que já existe. Nenhum dado não declarado alcança o documento, e a
garantia da §11 continua inteira.

**A tensão com o checklist, assumida.** `contract(tmpl)` continua emitindo
`additionalProperties: false`, porque descreve o **documento de dados do modelo** — a
forma canônica que um gerador de formulário deve produzir. O motor é mais tolerante que
o schema de propósito: ele recebe de fontes ricas, e o schema descreve um payload feito
sob medida. Se a divergência incomodar, a saída é uma opção no `contract`, nunca
apertar o `check`.

---

## D-023 — `kanon_getfield`: o esquema é a interface, a `struct` é a implementação

*2026-09-04 · aceita · surgida ao implementar a F2.6*

**Decisão.** Uma nona função genérica no protocolo de tipo:

```julia
kanon_getfield(v, ::Val{name})            # padrão: getproperty(v, name)
```

É por ela que o motor lê `seller.name`. O padrão serve quando o nome do esquema é o nome
da propriedade Julia; um tipo cujo esquema não espelha a `struct` define os métodos dele.

**O que faltava.** `api-extensao.md` §2 lista oito funções e **nenhuma lê um campo**.
`kanon_schema` promete que `person` tem `name`, e nada no protocolo dizia como obter esse
`name` de um valor. A F3 bateria nisso de frente; a F2.6 bateu antes, e por um motivo
mais grave que a conveniência.

**Por que isso era um furo no teorema.** `{seller.name}` é não-nulável *porque o esquema
declara `name` obrigatório*. Sem uma forma de ler o campo, `check` não tinha como
verificar que o `person` recebido cumpre a própria declaração — e um `Pessoa("", …)`
atravessaria a validação inteira para abrir no texto exatamente o buraco que a §14 supõe
impossível. A verificação existe agora, desce nos aninhados e nas coleções, e tem teto de
profundidade porque nada impede um ciclo nos dados.

**Por que não `getproperty` direto.** Amarrar o esquema aos nomes das propriedades Julia
faria de `kanon_schema` uma promessa sobre a implementação: renomear um campo interno
quebraria os modelos do acervo. O esquema é a interface pública do tipo, e uma interface
que vaza a implementação não é interface.

**Consequência para a F6.** `@kanon_type` gera os `kanon_getfield` junto com o resto, e o
teste normativo da §2.3 continua valendo — tudo que a macro gera é escrevível à mão.

---

## D-024 — O marcador de rascunho vive no texto, não nos dados

*2026-09-04 · aceita · surgida ao implementar a F3*

**Decisão.** `preview` não fabrica valores. O marcador `«campo»` é um sentinela de
render — `PreviewMarker` —, produzido no ponto da interpolação e convertido em texto ali
mesmo. Os dados que chegam ao rascunho são os mesmos que chegariam ao `render`.

**O que a implementação ingênua fazia.** A primeira versão preenchia os campos ausentes
com a cadeia `"«preco»"` antes de chamar o motor. Ela falhou no primeiro modelo real, e
por um motivo que não tem conserto: **`«preco»` não é um `money`**. Um marcador só pode
ser injetado como dado se o tipo aceitar texto, e a proibição de coerção da §3.4 garante
que ele não aceita. O rascunho falhava exatamente onde ele precisa funcionar — no campo
que ainda não veio.

**Alternativas.** (a) Um valor nulo próprio por tipo, para o marcador ocupar. (b) Relaxar
a decodificação no modo rascunho. (c) O marcador no texto (escolhida).

**Por quê.** Contra (a): a §14 proíbe que qualquer tipo tenha valor nulo próprio — não
existe "`money` vazio" —, e criar um só para o rascunho o traria de volta pela porta dos
fundos, onde ele acabaria escapando para o render. Contra (b): dois caminhos de
decodificação, um deles frouxo, é a definição de modo leniente.

**Consequência, e o que ela protege.** Um campo **nulável** que falta continua elidindo o
grupo no rascunho, exatamente como faria no documento — o rascunho mostra o texto que
sairá, e não uma versão inflada dele. Só o valor **garantido** que falta vira marcador,
porque é o único cuja ausência não tem representação no texto final. E `render` continua
recusando os mesmíssimos dados: o rascunho é um comando à parte, não um modo.

---

## D-025 — O que a camada de idioma substitui é gancho de ambiente, nunca método global

*2026-09-04 · aceita · surgida ao implementar a F4*

**Decisão.** Dois pontos de extensão novos, ambos no `EnvironmentBuilder`:

```julia
register_list_joiner!(b, :pt, juntar)     # "a, b e c" no lugar de "a, b, c"
register_type_alias!(b, :dinheiro, :money)
```

**O problema da junção de lista.** A §3.3 diz que o `", "` do formatador padrão de `list`
é "a única convenção tipográfica no núcleo" e que ela é "substituível pela camada de
idioma". O caminho óbvio seria a camada definir
`format(v::AbstractVector, ::Val{:default}, ctx)` — mas métodos em Julia são **globais e
aditivos**: bastaria carregar `Extenso` para que um `Environment()` neutro passasse a
juntar com `e`, e o teste de neutralidade da F6 cairia. Pior, cairia com o motor
funcionando: o vazamento seria invisível até alguém rodar o teste.

Gancho de ambiente resolve porque o que é conflitante é local (§5): `Extenso` carregado
não muda ambiente nenhum que não tenha declarado `locale = :pt`.

**O problema do apelido de tipo.** `register_type!` aceita `aliases`, mas só de quem
registra o tipo — e os seis tipos do núcleo são registrados pelo **núcleo**, que é neutro
e não tem apelido a dar. Sem `register_type_alias!`, um modelo em português declararia
`preco : money`, e metade do plano de dados ficaria em inglês. A §2.2 previu o caso do
tipo de domínio e não o do tipo do núcleo.

**A regra que sai daí, e vale para toda camada futura.** Comportamento é método —
global, aditivo, seguro. **Nome e convenção de apresentação são registro no ambiente** —
local, e por isso reversível. Quando as duas leituras forem possíveis, é a segunda que
preserva a neutralidade, e a neutralidade é o que sustenta a arquitetura inteira.

---

## D-026 — Formatador de camada declara o idioma a que pertence

*2026-09-04 · aceita · surgida ao responder "o Extenso só é em português?"*

**Decisão.** Uma décima função genérica, opcional:

```julia
kanon_format_locale(::Type{T}, ::Val{name}) -> Symbol | Nothing   # padrão: nothing
```

Um formatador que declara idioma só é **visível** em ambiente que tenha esse `locale`.
`kanon_formats(T)` continua enumerando tudo que existe no processo — é o protocolo, e ele
não conhece ambiente; quem filtra é `kanon_formats(T, env)`, e é essa lista que a
validação usa.

**O defeito.** Método em Julia é global e aditivo. Bastava `Extenso` estar carregado no
processo para que um `Environment()` **neutro** — `locale = nothing`, zero marcas —
aceitasse `{preco:extenso}` e renderizasse `mil e duzentos reais`. Um relatório em inglês
ganhava português de brinde por causa de um `using` em outro arquivo.

**O que isso não era.** Não violava a letra da especificação: o teste de neutralidade da
F6 roda "o núcleo sem nenhuma camada", num processo onde `Extenso` nem existe, e lá
passava. Também não impedia dois idiomas de coexistirem — `:extenso` e `:written` são
nomes diferentes. O que caía era a promessa prática, no único lugar em que ela é
verificável pelo usuário e não pela suíte.

**Alternativas.** (a) Aceitar, tratando formatador como comportamento puro — o que a §5
autoriza, já que "o que é global (métodos) é aditivo". (b) Registro de formatadores no
ambiente: viola a obrigação 5-A e traz de volta a tabela de despacho à mão. (c) Declarar o
idioma por despacho (escolhida).

**Por quê (c).** Ela mantém a divisão que a D-025 estabeleceu — **comportamento é método,
visibilidade é do ambiente** — sem inventar mecanismo novo: a declaração é ela própria um
método, e a camada a escreve do lado dela. Contra (a): a §5 fala de métodos serem
aditivos como uma garantia de que camadas não brigam, e não como licença para vazar
idioma; ler assim contradiz a invariante 3 do roadmap, que é a que sustenta a
arquitetura.

**Efeito colateral que vale mais que a correção.** A mensagem melhorou: quem escreve
`{preco:extenso}` sem a camada agora lê "`extenso` é um formatador do idioma `pt`;
construa o ambiente com `locale = :pt`", em vez de ser mandado procurar um erro de
digitação num nome que está certo.

---

## D-027 — A neutralidade é da linguagem e do documento, não das mensagens do motor

*2026-09-05 · aceita · surgida ao escrever o teste de neutralidade da F6*

**Decisão.** O idioma das mensagens de diagnóstico **não** faz parte da invariante de
neutralidade. O teste de neutralidade verifica que nada de idioma ou de domínio alcança
a **linguagem** (palavras-chave, tipos, marcadores, marcas, formatadores) nem o
**documento gerado** — e não o vocabulário com que o motor conversa com quem o opera.

**O mecanismo que caiu.** O roadmap propunha "proibir literal de string não-ASCII no
fonte do núcleo" como um dos mecanismos concretos. Ele foi escrito supondo mensagens em
inglês; as do Kanon estão em português, e há mais de mil caracteres acentuados em
`src/` — o teste falharia na primeira execução, e falharia apontando para o lugar errado.

**Por quê.** Um compilador de C com mensagens em português continua compilando C. O que
tornaria o Kanon uma linguagem portuguesa seria `dados` ser palavra-chave sem camada, ou
`R$` sair de um ambiente neutro — não `referência` aparecer numa mensagem de erro. A
prova disso é que trocar todas as mensagens para o inglês não mudaria **um byte** de
nenhum documento gerado.

**Os mecanismos que ficaram**, todos em `test/test_neutralidade.jl`, e todos rodando com
o núcleo **sem camada carregada** — um teste que precisasse de `Extenso` para provar que
`Extenso` não vazou não provaria nada:

- `Project.toml` do núcleo não menciona camada nenhuma, e as dependências são só `Dates`
  e `Unicode`;
- nenhuma palavra-chave em português é reconhecida pela tabela canônica;
- os seis tipos do núcleo têm nome em inglês, e nenhum nome de domínio resolve;
- o único estilo de bloco é `:`, sem `§` nem `@`;
- não há marca de flexão, gancho de idioma nem símbolo de moeda;
- os valores de fábrica são ISO e ponto decimal, e não de país nenhum;
- um modelo em português é recusado nomeando o que falta, um a um.

**O que o teste ganha ao não medir acentos.** Ele mede comportamento, e comportamento é
o que quebra. O não-ASCII teria dado uma falsa sensação de rigor enquanto D-026 — um
formatador de camada vazando para ambiente neutro — passava despercebida por duas fases.

---

## D-028 — O valor interpolado nunca altera a estrutura do documento

*2026-09-05 · aceita · surgida ao implementar a F8*

**Decisão.** Ao emitir num formato com marcação — Markdown, Typst —, o motor escapa o
**valor interpolado** e não toca na **prosa do modelo**. `**importante**` escrito pelo
autor sai como negrito; `*Maria*` vindo dos dados sai como as três letras e os dois
asteriscos.

**Por quê.** É o mesmo princípio do projeto inteiro, dito para outro problema: o dado
preenche o documento, não o reescreve. Um nome com `#` não pode abrir uma cláusula falsa,
e um campo com `\` não pode escapar nada. É a preocupação de quem escapa HTML, pela mesma
razão — e aqui com o peso extra de que o documento pode ser assinado.

Não escapar a prosa é a outra metade da decisão, e vem de D-014: o motor não tem o
direito de editar o texto que o autor digitou. Um modelo Markdown que escreve `**` quer
negrito.

**A precisão que a implementação exigiu.** Escapar tudo em toda posição é conservador e
inútil: `12.345` viraria `12\.345` e nenhum valor sairia legível. Em Markdown há duas
classes — o que é marcação **em qualquer posição** (ênfase, código, colchetes, HTML) e o
que só é marcação **no início de uma linha** (títulos, citações, itens de lista). O
segundo grupo só é escapado quando o valor de fato cai no começo de uma linha, e **quem
sabe disso é o render**, que tem o buffer: `escape_value` recebe a posição.

Isso importa porque um valor pode conter quebras de linha. `"X\n\n# Cláusula"` põe um
título no documento se o `#` não for escapado *ali* — e escapá-lo em toda posição encheria
o texto de barras sem proteger nada.

**O que fica assumido.** `$` é escapado sempre, mesmo produzido por um formatador da
camada: `R$ 250.000,00` sai como `R\$ 250.000,00` no fonte, e renderiza correto. Separar
"o que o formatador escreveu" de "o que veio do dado" exigiria que o formatador
devolvesse texto marcado, e o custo dessa mudança na API é maior que o de uma barra no
fonte intermediário.

**Sobre `.docx` e PDF.** O motor não os gera, e não deve: `kanon render --to markdown |
pandoc -o saida.docx` põe a composição de página em quem sabe fazê-la. O Kanon garante o
conteúdo.

---

## D-029 — O editor é uma aplicação; a biblioteca entrega o que ele consome

*2026-09-05 · aceita · surgida ao implementar a F9*

**Decisão.** A F9 do roadmap mistura duas coisas de naturezas diferentes: uma **interface**
— o editor de três colunas, com a regra ao lado de cada bloco e a pré-visualização sempre
visível — e a **API que ela precisa** para existir. O motor entrega a segunda:
`outline(model)`, mais `kanon outline` e `kanon ask` na linha de comando.

**Por quê.** Um editor gráfico é uma aplicação, com ciclo de vida, dependências de
interface e público próprios; embutir um numa biblioteca de motor de documentos amarraria
os dois. O que ninguém mais pode fornecer é a estrutura do modelo **já resolvida** — qual
regra governa cada bloco, que número ele consome, que campos ele usa, e quais deles podem
faltar.

**A restrição que isso impõe, e que é o ponto.** `outline` sai inteiro da `Analysis`, sem
uma segunda travessia com regras próprias. Se tivesse regras próprias, a coluna do meio
poderia discordar do motor — e uma ferramenta que mente sobre o que vai sair é pior que
nenhuma, porque o redator passa a confiar nela.

Pelo mesmo motivo a condição é **reconstruída da árvore** e não copiada do arquivo:
`a and b or c` aparece como `(a and b) or c`, que é o que o motor faz. "Como isto se
combina" é precisamente a pergunta que o leitor não deveria ter de fazer (D-002).

**`kanon ask`, e o pedido de modo leniente.** Quem pede modo leniente quase sempre quer
ver o documento enquanto ainda reúne os dados. `ask` reúne os dados, perguntando um a um
o que falta; `preview` mostra o rascunho com «marcadores». **Nenhum dos dois afrouxa o
contrato**, e é exatamente por isso que os dois podem existir — a necessidade era real, e
o que a atendia mal era a solução proposta.

`ask` pergunta apenas o que cabe numa linha digitada: `text`, `number`, `boolean`, `date`.
Um `money` precisa de quantia e moeda, e um composto precisa dos campos dele; perguntar
por eles numa linha só levaria a inventar uma mini-sintaxe de entrada, que é como um
projeto ganha o segundo formato de dados que ninguém queria.

---

## D-030 — O `Val{nome}` faz da extensão por despacho algo que não é pirataria

*2026-09-05 · registrada · observada ao rodar o Aqua na F10*

**A observação.** `Extenso` define `Kanon.format(v::Money, ::Val{:extenso}, ctx)` —
função do núcleo, tipo do núcleo, método escrito por um terceiro. Pela definição corrente,
isso deveria ser **pirataria de tipo**, e o Aqua deveria acusar.

Ele não acusa. E o motivo é que a acusação estaria errada: o `Val{:extenso}` **é** um tipo
da camada, porque o símbolo `:extenso` é dela. A assinatura completa é
`(Money, Val{:extenso}, Any)`, e nenhum outro pacote pode escrever essa mesma assinatura
sem inventar o mesmo nome — que é exatamente o conflito que o ambiente detecta na
construção.

**Por que isso vale registro.** O `Val{nome}` foi escolhido na F0 por outra razão: enumerar
formatadores sem dados, por introspecção da tabela de métodos (§2.1). A propriedade de não
ser pirataria veio junto, de graça, e é ela que torna a arquitetura de camadas defensável
para quem chega de fora — a pergunta "mas isso não é *type piracy*?" tem resposta
mecânica, e a resposta é uma ferramenta padrão do ecossistema dizendo que não.

**O que continua sendo verdade.** Uma camada que definisse `format(v::Money, ::Val{N},
ctx) where {N}` — genérico no nome — seria pirataria de verdade, e mereceria a acusação:
ela reivindicaria *todos* os formatadores de um tipo que não é dela. A §2.1 já previa esse
método como o caso que a introspecção não enumera; agora se sabe que ele é também o caso
que a higiene do ecossistema recusa.

---

## D-031 — O apelido de idioma é nome; quem decide pelo tipo decide pelo canônico

*2026-09-05 · aceita · surgida ao escrever o modelo real nº 2*

**O defeito.** `quando flag` sobre um campo `flag : booleano !` era recusado com `K2040`
— "esta condição é do tipo `booleano`, e uma condição precisa ser verdadeira ou falsa".
A mensagem afirmava que o tipo era booleano e o recusava por não ser booleano. O mesmo
modelo em inglês, com `flag : boolean` e `when flag`, passava.

A causa é uma só, e produziu quatro sintomas:

| Onde | O que acontecia num modelo em português |
|---|---|
| `require_boolean!` | `quando flag` recusado, com a mensagem que se contradiz |
| `type_schema` | o `$defs` do checklist saía sem `type` — **o JSON Schema validava qualquer coisa** |
| `coerce_answer` | `kanon ask` lia a resposta `123` de um campo `texto` como o número 123 |
| `do_ask` | nenhum campo do núcleo era "digitável", e `ask` mandava todos para o arquivo |

**Decisão.** `FieldDecl.type` e `ResolvedPath.typename` continuam guardando o nome
**escrito** — é o que a mensagem tem de dizer de volta ao autor, e a D-027 exige isso.
Onde a lógica *decide* algo pelo tipo, ela resolve antes o apelido com
`canonical_typename(env, name)`. Onde ela *fala* com o autor, fala pelo escrito.

**Alternativas.** (a) Canonicalizar na resolução, fazendo `typename` guardar o canônico.
(b) Resolver no ponto da decisão (escolhida).

**Por quê.** Contra (a): a mensagem passaria a dizer "`boolean`" a quem escreveu
`booleano`, o que é a D-027 ao contrário — o motor falando a língua dele com quem
escolheu outra. O erro estava em confundir os dois papéis do nome, e a correção que os
mantém separados é a que não troca um defeito por outro.

**O que isto revela sobre a §9.** A promessa é que o idioma renomeia palavras-chave, e
nada além disso. Ela não era verificada em lugar nenhum: toda a suíte em português usava
tipos de `KanonLegal`, cujos nomes são canônicos, e toda a suíte de contrato, de regras e
de `ask` estava em inglês. **O buraco era exatamente a interseção dos dois.** Os testes
agora afirmam a equivalência das duas línguas sobre o mesmo modelo.

---

## D-032 — Regra que pode deixar um nível sem o anterior é aviso, não erro

*2026-09-05 · aceita · surgida ao escrever o modelo real nº 2*

**O buraco.** A §6.2 faz de "nível *n* sem nível *n*−1 antes" um erro **estático**
(`K2031`), verificado sobre o texto como está escrito. O plano das regras produz em
execução exatamente o estado que aquela checagem proíbe: basta a cláusula ser condicional
e o parágrafo dela não ser.

O documento que sai não é apenas feio. O contador do nível 1 nunca é incrementado, e o
rótulo do parágrafo é `0.1` — um número que não existe. Num contrato, `PARÁGRAFO PRIMEIRO`
encabeça a página, subordinado a uma cláusula que não está lá.

**Decisão.** `K2039`, aviso na análise: o bloco que abre o nível anterior pode ser
removido por uma regra, e este não está preso à mesma condição.

**Alternativas.** (a) Erro. (b) Remover os filhos junto com o pai. (c) Aviso (escolhida).
(d) Nada.

**Por quê.** Contra (b): quebra duas frases da especificação de uma vez — a §8.4 ("regras
só removem ou repetem", e o filho não tem regra) e a §8.2 ("bloco sem regra é sempre
incluído"). Contra (a): as duas condições podem coincidir de propósito, e o motor não tem
como saber; é a mesma situação do `K2035`, e a mesma resposta. Contra (d): é a categoria
de defeito que o projeto existe para impedir — saída errada, em silêncio, num documento
que ninguém revisa duas vezes.

**O reconhecimento é conservador.** Só a igualdade **estrutural** das duas condições
dispensa o aviso. Comparar índice de regra não serviria: a §8.2 dá a cada bloco a sua
própria linha de `when`, e por construção dois blocos nunca compartilham uma. O custo de
não reconhecer um caso é repetir a condição do pai no `when` do filho.

---

## D-033 — O tipo `list` do núcleo é inalcançável pelo plano de dados

*2026-09-05 · **proposta**, aguarda decisão de versão · surgida ao escrever o modelo real nº 2*

**A observação.** `moveis : lista` com uma lista de três itens é recusado por `K3002`:
"`moveis` é um valor único, e veio uma lista de 3. Declare `moveis : lista[]` no modelo".
Mas `lista[]` significa *lista de listas*, e com uma lista simples produz três `K3010`.

Não há como escrever, no plano de dados, um campo do tipo `list` da §3.3. **O tipo existe,
tem formatador (`count`), tem atributo (`empty`), tem decodificador, e nenhum modelo pode
declará-lo.**

**O que o autor quer, e já tem.** `moveis : texto[]` faz tudo: junta com a conjunção do
idioma, responde a `{moveis:count}`, responde a `é empty`. A cardinalidade do §2.1 já é a
forma de dizer "vários", e ela diz também *vários de quê* — que é mais do que `list` diz.

**As saídas, e o que cada uma custa.**

| | O que fazer | Custo |
|---|---|---|
| (a) | Remover `list` do núcleo | Versão maior da linguagem: remove um tipo (§13) |
| (b) | Fazer `: lista` aceitar uma lista | Duas grafias para a mesma coisa, e a pior das duas — sem o tipo do elemento |
| (c) | Deixar como está, e corrigir a mensagem | O tipo continua morto; a sugestão para de mentir |

**Recomendação: (c) agora, (a) na 1.0.** A mensagem de `K3002` sugerir `lista[]` é um
defeito independente da decisão maior — ela manda o autor para um lugar onde ele levará
mais três erros. Corrigi-la é aditivo. Remover o tipo é decisão de congelamento, e o
portão ainda tem treze modelos pela frente: se nenhum deles precisar de `list`, a remoção
está justificada por evidência em vez de por argumento.

**Por que isto não foi visto antes.** `list` é o único tipo do núcleo que nenhum dos dois
exemplos da F0 usava, e o formatador padrão dele — a única convenção tipográfica do
núcleo, declarada como tal na §3.3 — é testado por dentro, chamando `format` sobre um
vetor. Nenhum teste tentou **declarar um campo** desse tipo. É a diferença entre testar a
peça e escrever um documento com ela, que é o que o portão da 1.0 existe para forçar.

---

## D-034 — Algarismo significativo se lê em decimal, nunca por aritmética de ponto flutuante

*2026-09-05 · aceita · surgida ao escrever o modelo real nº 3*

**O defeito.** A regra do PDG que `KanonScience` implementa — a incerteza fica com um
algarismo significativo, ou dois quando o primeiro é 1 ou 2 — decidia o primeiro
algarismo assim:

```julia
expoente = floor(Int, log10(uncertainty))
primeiro = floor(Int, uncertainty / 10.0^expoente)
```

`0.3 / 10.0^-1` vale `2.9999999999999996` em `Float64`. O `floor` devolve **2**, a
incerteza cai na regra dos dois algarismos, e o relatório sai com `21.40 ± 0.30` no
lugar de `21.4 ± 0.3` — **uma casa decimal a mais do que a medição sustenta**, que é
exatamente o que a regra existe para impedir.

Quebrava com `0.3`, `0.03` e `0.0003`; não quebrava com `3.0` nem `30.0`, porque só ali a
potência de dez divide exato. **Um defeito que depende do dado é um defeito que passa na
revisão**, e este passaria como um dígito a mais — a coisa que um revisor de periódico
procura e um leitor acredita.

**Decisão.** `decimal_lead(u)` lê o primeiro algarismo e o expoente da **representação
decimal mais curta que volta ao mesmo `Float64`** — que é o número que quem mediu
escreveu.

**Alternativas.** (a) Somar uma tolerância antes do `floor`. (b) `Rational` ou
`BigFloat`. (c) Ler a representação decimal (escolhida).

**Por quê.** Contra (a): a tolerância certa depende da magnitude, e escolher uma é trocar
um erro conhecido por um erro que aparece mais longe. Contra (b): `BigFloat` tem precisão
em **estado global** (`setprecision`) e a F2.1 já o recusou pela mesma razão; `Rational`
resolveria, mas a pergunta não é sobre o valor exato do binário — é sobre qual algarismo
a pessoa escreveu, e isso é uma propriedade da escrita decimal, não do número real.

A conversão mais curta é especificada e determinística, e não depende de estado nenhum.

**O que isto ensina para além do caso.** Toda vez que o motor precisar do *dígito* de um
número — e não do seu valor —, a pergunta é sobre a representação, e a aritmética é a
ferramenta errada. É a mesma família do arredondamento por `Rational{BigInt}` da F2.1,
com o problema de cabeça para baixo.

---

## D-035 — Um diagnóstico aponta o arquivo do trecho, e não o do modelo carregado

*2026-09-05 · aceita · surgida ao escrever o modelo real nº 3*

**O defeito.** `Span` sempre guardou um índice na tabela de fontes do modelo composto —
a informação estava lá desde a F1. Quem emitia o diagnóstico é que a ignorava e usava o
nome do arquivo que foi carregado.

O resultado, num modelo com fragmentos: **o nome do hospedeiro com a linha do
fragmento**. Um hospedeiro de oito linhas produzia `host.kanon: linha 11`. Quem seguisse
o ponteiro não acharia nada, e um editor saltaria para o vazio.

**Decisão.** `err!` e `cerr!` resolvem o arquivo por `source_of(tmpl, span)`. E o
relatório da §10.4 ganha o nome em cada problema **quando há mais de um arquivo** — com
um só, o cabeçalho já o disse e repeti-lo seria ruído.

**Alternativas.** (a) Manter o nome do carregado, aceitando que a linha é do fragmento.
(b) Resolver pelo índice (escolhida).

**Por quê.** Contra (a): a §10.2 promete que um diagnóstico carrega **arquivo, linha e
coluna**, e um ponteiro que aponta para o lugar errado é pior que nenhum ponteiro — quem
o segue conclui que o erro é do hospedeiro e vai procurar lá. A F9 depende disso de forma
direta: um editor mapeia código de diagnóstico a ação, e a ação acontece num arquivo.

**Por que não apareceu antes.** A suíte da F7 verifica que a inclusão **compõe** — que os
blocos entram, que o contrato unifica, que o ciclo erra. Nenhum teste tinha um fragmento
com um erro dentro. É a mesma forma dos buracos que os modelos nº 2 e nº 3 acharam: a
peça foi testada, a interseção não.

---

## D-036 — `load_source`: uma porta que lê sem lançar

*2026-09-05 · aceita · surgida ao implementar o servidor de linguagem*

**O problema.** Todas as portas do motor lançam: `parse_string` lança `KanonSyntaxError`,
`compose` lança `KanonReferenceError`, e `load_string` lança de novo quando a análise
acusa erro. Para um programa isso é certo — a §14 exige que nada renderize com contrato
insatisfeito.

Para uma **ferramenta interativa** é inútil. Um editor não pode ser interrompido por
exceção a cada tecla, e precisa de duas coisas ao mesmo tempo que o `throw` torna
mutuamente exclusivas: **a lista do que está errado** e **a estrutura do que o motor
conseguiu entender**. O arquivo com erro é justamente o arquivo em que o redator passa o
tempo todo.

**Decisão.** `load_source(env, text; name, root) -> Loaded`, com
`Loaded(model, diagnostics)`. `model` é `nothing` **só** quando não houve árvore — erro
de sintaxe ou de inclusão, os dois casos em que a §10.3 já manda suprimir as fases
seguintes. Com árvore, o modelo vem mesmo com erro de referência.

`load_string` e `load_template` continuam lançando, e não mudaram de comportamento.

**Alternativas.** (a) A ferramenta chamar `parse_string` e `analyze` por conta própria.
(b) Um argumento `strict = false` em `load_string`. (c) Uma porta própria (escolhida).

**Por quê.** Contra (a): funciona, e é o começo de a ferramenta ter caminho próprio —
hoje ela repetiria o `compose`, amanhã repetiria uma decisão. Contra (b): uma função cujo
tipo de retorno depende de um argumento booleano é pior de usar e pior de ler, e a
tentação seguinte seria usar o modo leniente em produção, que a §14 proíbe.

**O que ela não é.** Não é modo leniente: nada aqui renderiza. É `analyze` com o
resultado embrulhado, e o `throw` movido para quem quer ele.

---

## D-037 — O trecho de um nó termina no último nó, e não no último caractere

*2026-09-05 · aceita · surgida ao implementar o servidor de linguagem*

**O defeito.** `scan_run!` mantinha a posição final em `lastl, lastc`, e só `push_char!`
a atualizava — isto é, **só prosa avançava o fim do trecho**. Um parágrafo terminado em
interpolação, grupo, remissão ou ponto de flexão declarava um trecho que parava antes
dele.

`{a}` sozinho num parágrafo produzia `Paragraph` com trecho `(9,1)–(9,1)`, enquanto a
`Interp` dentro dele ocupava `(9,1)–(9,3)`. **O pai era menor que o filho**, o que
nenhuma leitura da árvore espera.

Passou despercebido porque nada no motor consulta o trecho de um parágrafo: os
diagnósticos apontam o nó culpado, e o render não usa posição. Foi a primeira consulta
por posição — "que nó está sob o cursor" — que topou nele.

**Decisão.** Depois de fechar o trecho, o fim é o do último filho, quando ele for maior.
O grupo fechado já termina no `]`, que vem depois de qualquer filho, e a comparação o
preserva.

**Por que a comparação, e não a atribuição.** Porque as duas fontes são legítimas: o `]`
de um grupo é posição de caractere e é o fim certo; o fim de um parágrafo é o do último
nó. Escolher a maior das duas é a regra que vale nos dois casos, e não tem exceção para
alguém esquecer depois.

**A regra geral que isto fixa.** O trecho de um nó **contém** os trechos dos filhos dele.
Não estava escrito em lugar nenhum porque parecia óbvio demais para escrever.

---

## D-038 — Completar lê a última análise que deu certo

*2026-09-05 · aceita · surgida ao implementar o servidor de linguagem*

**A descoberta.** Completar é a única funcionalidade que roda **exatamente quando o
arquivo não analisa**. No instante em que alguém pede uma sugestão, o que ele digitou é
`{`, ou `{price:`, ou `{::` — nenhum deles fecha, e nenhum produz árvore.

Um servidor que consultasse só a análise corrente não sugeriria nada, nunca. A primeira
versão fazia isso, e a suíte a pegou na primeira execução com uma lista vazia.

**Decisão.** O documento guarda `last_model` — a última análise que produziu árvore — e
**só a completação** o lê. Diagnóstico, estrutura e o que está sob o cursor continuam
saindo da análise corrente.

**Por que isso não é a ferramenta discordando do motor (D-029).** A distinção é *onde a
resposta é calculada*, e não *quão recente ela é*. As sugestões continuam saindo do
`Environment` e das tabelas que o motor produziu; o que muda é de qual instante. Uma
completação que varresse o texto atrás de palavras seria a ferramenta com regra própria —
e sugeriria `extenso` para um campo `text` sem que nada a corrigisse.

**Por que a divisão é essa, e não "tudo usa o último bom".** Para um arquivo quebrado, o
diagnóstico tem uma resposta certa, e é dizer o que está quebrado. Mostrar o diagnóstico
de dois segundos atrás seria mentir sobre o estado do arquivo — que é o oposto do que
esta ferramenta existe para fazer.

---

## D-039 — O servidor não escolhe as camadas; quem o inicia escolhe

*2026-09-05 · aceita · surgida ao implementar o servidor de linguagem*

**A tentação.** Um servidor de linguagem que carregasse `Extenso`, `KanonLegal` e
`KanonScience` por conta própria funcionaria para todo mundo sem configuração nenhuma, e
seria a decisão que qualquer um tomaria primeiro.

**Por que ela está errada.** Um modelo que usa `pessoa` sem a camada carregada **é um
modelo inválido**, e o motor o recusa. Um servidor que aceitasse esse modelo mostraria o
arquivo limpo enquanto a CLI o recusa — e o redator descobriria a diferença no dia da
entrega, com o editor dizendo que está tudo certo.

O teste de neutralidade existe para impedir exatamente isso dentro do motor; deixar a
ferramenta desfazê-lo por fora seria pior, porque ninguém procuraria ali.

**Decisão.** `serve(; env)` recebe o ambiente, e o padrão é o **núcleo puro** — a mesma
escolha da CLI, que recebe `--locale`. Quem inicia o processo sabe que acervo vai editar;
o servidor não tem como adivinhar, e adivinhar errado é pior que perguntar.

---

## D-040 — O sujeito tem dois ofícios, e só o primeiro precisa de campos

*2026-09-05 · aceita · surgida ao escrever o modelo real nº 4*

**O que a especificação já dizia, em dois lugares que ninguém tinha lido juntos.**

- §4.2: o sujeito é aquilo contra o que um caminho resolve primeiro. **Precisa de campos.**
- §7.1: *"O sujeito é também o argumento passado à camada de idioma nos pontos de
  flexão."* **Não precisa de campos nenhum** — `flexionar` chama `genero(sujeito)` e
  `numero(sujeito)`, e um vetor responde ao segundo perfeitamente.

O `K2007` era escrito para o primeiro ofício e recusava os dois: *"só um valor com campos
serve de sujeito"*.

**A consequência, medida.** `Extenso.numero(::AbstractVector)` existe desde a F4, é
testado na suíte de unidade, e **nenhum modelo podia alcançá-lo** a menos que os
elementos da lista fossem de um tipo composto — isto é, a menos que houvesse uma camada
de domínio. Um certificado com três concluintes, escrito só com os tipos do núcleo, não
tinha como escrever `aluno(s) matriculado(s)`.

`Extenso` se anuncia desde a F4 como publicável sozinho. Metade do que ele faz era
inalcançável sem `KanonLegal`.

**Decisão.** Um sujeito sem campos é legítimo **quando o bloco tem alguma marca que este
ambiente registra**. Continua sendo erro quando não tem: sem campos para ler e sem marca
para flexionar, o `<-` não tem efeito nenhum sobre o bloco, e é quase sempre um `{campo}`
que o redator escreveu como `<- campo` por engano.

**Alternativas.** (a) Manter a recusa e mandar usar um tipo de domínio. (b) Aceitar
qualquer sujeito sem campos. (c) Aceitar quando há marca (escolhida).

**Por quê.** Contra (a): obriga a definir um `struct` Julia para escrever um certificado,
o que põe a camada de domínio no caminho de quem só quer o idioma — e contradiz a
promessa do `Extenso`. Contra (b): perde um diagnóstico que pega um engano real, e o
engano é frequente, porque `<-` e `{}` são as duas formas de nomear o mesmo campo.

A forma da (c) é a da **D-021**, e de propósito: *o que nunca pode fazer nada é erro*. Lá
era o grupo que nunca elide; aqui é o sujeito que não lê nem flexiona.

**Por que a pergunta é ao ambiente, e não ao léxico.** `casa(s)` num modelo sem camada de
idioma é prosa literal (§7.1), e um sujeito posto ali para flexioná-la não flexionaria
nada. `has_inflection` consulta `hasmark(env, ...)`, e por isso o mesmo modelo que passa
com a camada carregada é recusado sem ela — que é exatamente o comportamento que o teste
de neutralidade exige.

**Compatibilidade.** É afrouxamento: torna válido um modelo antes inválido, e a §13 põe
isso em **versão menor**. Nenhum modelo existente muda de comportamento, porque todos os
que agora passam antes erravam.

**O que continua fora do alcance, e é do idioma e não da linguagem.** O plural de um verbo
em português não é o singular mais um sufixo — `concluiu` ⟶ `concluíram` muda o radical —,
e a marca só sufixa (D-013). A frase se escreve com particípios e adjetivos, que sufixam,
ou o autor escreve `concluiu((ram))` e deixa a forma dupla, como o documento em papel faz.

---

## D-041 — Os separadores são dois, e aplicá-los é do núcleo

*2026-09-05 · aceita · surgida ao escrever o modelo real nº 5*

**O defeito, visto no documento.** Um laudo de avaliação escreve a mesma área duas vezes:
uma como `number` do núcleo, vinda do registro do imóvel, e outra como `measure`, vinda da
medição. Saíam assim, com duas linhas de distância:

```
... com área registrada de 41.250 metros quadrados.
1. Área do terreno: 41250,0 ± 0,8 m².
```

`KanonScience.localized` trocava o separador **decimal** à mão e nunca agrupava os
milhares. Num laudo, dois formatos para o mesmo número é a espécie de coisa que se
contesta.

**A causa é da API, e não da camada.** A §3.3 diz, com `measure` citado pelo nome: *"Um
tipo composto que formate números obtém os separadores do contexto, nunca os embute."*
**Separadores, no plural.** A API dava `decimal_separator(ctx)` e `group_separator(ctx)` —
duas cadeias — e **nenhuma função que os aplicasse**. Cada camada que formata número
reimplementa o agrupamento, e a primeira que o fez esqueceu metade dele.

**Decisão.** `fixed_number(v, digits, ctx)` e `plain_number(v, ctx)` passam a ser parte da
API de extensão, exportados e documentados. São os mesmos que o `number` e o `money` do
núcleo usam, e agora o `measure` usa. `KanonScience` perdeu a dependência de `Printf` no
caminho.

**Alternativas.** (a) Corrigir só o `KanonScience`. (b) Exportar a função (escolhida).

**Por quê.** Contra (a): deixa a armadilha armada para a próxima camada, e a próxima
camada é escrita por alguém de fora — que é o público que a `api-extensao.md` existe para
servir. Um contrato que manda fazer uma coisa e não dá a ferramenta para fazê-la está
convidando cada implementador a errar por conta própria.

**Por que nenhum teste pegou.** É o mesmo padrão dos cinco anteriores, pela quinta vez: a
suíte do `measure` roda **sem idioma**, onde não há separador nenhum a aplicar; a suíte em
português nunca tinha usado um `measure`. **A interseção de duas coisas testadas
separadamente.**

---

## D-042 — Tipo desconhecido sugere a camada, e não só a lista

*2026-09-05 · aceita · surgida ao escrever o modelo real nº 5*

**A observação.** `K2005` dizia *"`area` é declarado do tipo `measure`, que este ambiente
não conhece"* e sugeria: *"Tipos disponíveis: boolean, booleano, data, date, dinheiro,
imovel, …"*. Uma lista de quinze nomes e nenhuma indicação do que fazer.

A sugestão por distância de edição é certa para um erro de digitação. Mas quando **nenhum
nome conhecido se parece com o escrito**, a causa provável não é digitação — é uma camada
que não foi carregada, que neste projeto é a razão mais comum de um tipo não existir.

**Decisão.** Quando não há nome próximo, a dica diz primeiro que o tipo pode vir de uma
camada e como carregá-la, e só então lista o que existe. A §10.4 manda sugerir a correção
provável quando há uma, e havia.

**O que não muda.** Com um nome próximo, o *"Você quis dizer `X`?"* continua vindo antes
de tudo: para um erro de digitação, a camada é ruído.

---

## D-043 — O caminho iterado é o elemento em toda parte, e não só nas regras

*2026-09-07 · aceita · surgida ao escrever o modelo real nº 6*

**A observação.** A §8.3 diz, desde a F0, que dentro de um bloco repetido *"o
identificador do caminho denota o elemento corrente, tanto no texto quanto no `when` do
próprio bloco"*, e que *"o bloco não tem acesso à coleção inteira"*. Três lugares do motor
precisam saber disso, e dois sabiam:

- `RuleScope.scope_value` substitui o elemento — é o `when`;
- `resolve_in_contract` substitui o elemento — é a análise, e o comentário dela até diz
  o que aconteceria sem isso: *"`{witnesses}` renderizaria a lista inteira em cada
  iteração — e em silêncio, que é a pior forma de estar errado"*;
- `path_value`, no render, **não substituía**. Lia a coleção nos dados validados.

O efeito tinha duas faces, e a segunda é mais grave que a primeira:

1. `{lotes}` rendia os três lotes juntos em cada uma das três iterações, com a
   conjunção do idioma — um documento plausível, e errado, sem aviso nenhum;
2. `{socios.nome}` — o campo do elemento escrito pelo caminho iterado — nem chegava a
   render: `descend_value` recebia o vetor e `kanon_getfield` caía no `getproperty`
   padrão, estourando `FieldError: type Array has no field nome`. Um erro de Julia
   escapando do motor, sem diagnóstico e sem código.

**Por que nenhum teste viu.** Todo bloco repetido do acervo lê o elemento por um **campo
do sujeito** — `{nome}`, `{cpf}` —, que resolve pela outra porta (`:subject_field`) e
desce no sujeito da instância, que é o elemento. O caminho iterado escrito por extenso só
tem razão de existir quando o elemento **não tem campos**: uma lista de `texto`. E sujeito
sem campos era `K2007` até a D-040, três dias antes — o modelo nº 4 destravou a construção
e o nº 6 foi o primeiro a repetir um bloco sobre ela.

**Decisão.** A resolução ganha um terceiro tipo, `:element`, ao lado de `:field` e
`:subject_field`. Não é um refinamento de `:field`: é **outra origem de valor** — a
coleção está nos dados validados e o elemento está na instância do bloco, e sem a marca o
render não teria como saber qual dos dois o caminho pede. Quem decide continua sendo a
análise, e o render obedece à tabela lateral, que é a divisão de trabalho do projeto
inteiro.

O elemento corrente é o **sujeito da instância**, e é por isso que o render não precisa de
mais nada: a §8.3 obriga o cabeçalho a declarar `<- C` com o mesmo caminho do
`one for each`, e `check_foreach!` recusa o modelo que não o faça.

**O que veio junto.** A razão da nulabilidade (`K2012`) não pode mais culpar a
cardinalidade que a iteração consumiu: numa repetição, lista opcional não torna o elemento
opcional — lista ausente é iteração nenhuma —, e a causa está adiante, num campo do
elemento.

**Alternativa descartada.** Carregar o caminho iterado no `RenderCtx`, como o `RuleScope`
faz. Funcionaria, e poria a mesma substituição em três cópias — a quarta viria com o
próximo consumidor da árvore.

---

## D-044 — O rótulo é a única coisa que o motor calcula, e a única que o formato não protegia

*2026-09-07 · aceita · surgida ao escrever o modelo real nº 6*

**A observação.** A F8 protege uma frase: *o valor interpolado nunca altera a estrutura do
documento*. O edital mostrou a metade que faltava. Emitido em Markdown, o item `1.` de
cada cláusula vira `<ol><li>`, e o `1.1.` vira outra lista dentro dele: o número que o
motor apurou passa a ser um número que o **renderizador** redefine — quatro listas de um
item, cada uma renumerando do seu jeito —, enquanto a remissão da prosa continua texto
literal apontando para o número antigo. Um documento que se contradiz.

No Typst dá no mesmo por outro caminho: *"starting a line with a number followed by a dot
creates an explicitly numbered enumeration item"*.

**Por que passava.** A suíte da F8 tinha o caso, e afirmava o contrário: *"o rótulo do
bloco é do estilo, e não é escapado — ele é estrutura, e vem da camada, não dos dados"*. A
**proveniência** é a razão certa para a pergunta errada. O risco de um valor é injeção, e
por isso ele é escapado; o risco do rótulo não é injeção nenhuma — é que o formato
reinterprete como marcação o único pedaço do documento que o motor calculou. Nenhum modelo
real tinha sido emitido em formato de marcação **com numeração numérica**: a do
`KanonLegal` é `CLÁUSULA PRIMEIRA`, a do `KanonScience` é `Theorem 1`, e nenhuma das duas
começa por dígito.

**Decisão.** O rótulo sai por um gancho de formato, `label(fmt, texto)`, irmão de
`heading`. O padrão é identidade — em texto puro não há marcação a desarmar —, e os dois
formatos de marcação escapam.

Rótulo e separador vão **juntos** para o gancho: o `1` é do rótulo e o `. ` que faz dele um
marcador é do separador do estilo, e escapar só o rótulo não protegeria nada. Foi o
primeiro remendo, e ele não funcionou.

E as duas linguagens escapam em lugares diferentes, o que é a razão de o escape ser método
de formato e não uma função só:

| | forma | por quê |
|---|---|---|
| Markdown | `1\. Texto` | o marcador é dígitos **seguidos** de `.`; quebrada a sequência, a linha deixa de ser candidata |
| Typst | `\1. Texto` | a barra vai antes do dígito — é a forma que a documentação da linguagem indica |

**O que veio junto.** O escape de valor do Typst passou a olhar o **início de linha**, que
ele recebia e ignorava — o método do Markdown já o usava. Sem isso, um valor com
`"\n\n1. Cláusula falsa"` abria no Typst a estrutura que a F8 existe para impedir, e o
buraco estava aberto desde que o formato entrou.

---

## D-045 — A garantia da regra vale nas duas grafias, e a comparação também garante

*2026-09-07 · aceita · surgida ao escrever o modelo real nº 7*

**A observação.** A escritura de doação separa os donatários maiores dos menores
comparando a data de nascimento — que é a forma que a docstring de `KanonLegal.maior`
prescreve desde a F6, porque a maioridade depende de uma data de referência e um atributo
de tipo recebe o valor e mais nada. O bloco dos menores escreve `{nascimento}`, e o motor
exigiu um grupo opcional em volta:

```
K2012: `nascimento` pode faltar, porque `nascimento` é opcional em `pessoa`,
       e está fora de qualquer grupo opcional.
```

O grupo pedido é um trecho de reserva **para um caso que o plano das regras já eliminou**:
o bloco só existe quando `donatarios.nascimento > 2008-09-07`, e `eval_comparison`
devolve `false` quando um dos lados falta — *ausência não se compara* está escrito no
código desde a F5. Escrevê-lo seria documentar uma falsidade.

Isolado, o defeito era **dois**, e um deles não tem nada a ver com comparação:

| sonda | regra | texto | antes |
|---|---|---|---|
| A | `quando p.nascimento é presente` | `{nascimento}` | **K2012** |
| B | `quando p.nascimento é presente` | `{p.nascimento}` | passa |
| C | `quando p.nascimento > 2008-09-07` | `{p.nascimento}` | **K2012** |

A diferença entre A e B é só a **grafia**: a regra fala pelo caminho do contrato e o texto
pela do sujeito, que é o que a §4.2 convida a fazer — e a garantia era colhida numa e
consultada na outra, comparando vetores de símbolos que nunca seriam iguais.

**Decisão, em duas partes.**

1. **A grafia.** Toda garantia que comece pelo caminho do sujeito do bloco entra também na
   grafia de dentro dele, e `resolve_in_subject` passa a consultá-la — antes não consultava
   garantia nenhuma.
2. **A comparação.** Os seis operadores da §8.1 afirmam a presença dos dois lados, na
   mesma posição em que `is present` já afirmava: **afirmativa e sob `and`**. Sob `not` a
   comparação é verdadeira *porque* o valor falta, e sob `or` o bloco existe sem ela — e é
   por isso que `collect_present!` nunca desceu por esses dois.

A soundness não é opinião: ela é o `return false` de `eval_comparison`. O teorema da
lacuna continua valendo — o que mudou é que o motor passou a enxergar uma garantia que ele
mesmo dava.

**Alternativa descartada.** Manter a exigência "por explicitude". O grupo que ela obriga a
escrever diz ao leitor *"quando este valor faltar, este trecho sai"*, e a verdade é
*"quando este valor faltar, o bloco inteiro não existe"*. Uma linguagem que obriga o autor
a escrever a explicação errada é pior que uma que não obriga nada.

---

## D-046 — Um tipo de domínio que não decodifica é inalcançável pelos dados

*2026-09-07 · aceita · surgida ao escrever o modelo real nº 7*

**A observação.** Os dados do modelo nº 7 vêm de um arquivo JSON, que é como eles chegam
na prática. `check` recusou quatro dos cinco campos que importam:

```
K3010: `doador` é do tipo `pessoa`, e o valor recebido não serve —
       esperava um valor de `pessoa`.
```

E não havia nada que o autor do JSON pudesse escrever para satisfazê-lo. **Nenhuma das
camadas implementava `kanon_decode`**, e o padrão do núcleo aceita só o que já é do tipo:
`pessoa`, `imovel` e `parte` só existiam se alguém os construísse em Julia. Um documento
jurídico gerado a partir de um sistema — o caso normal — estava fora do alcance do motor,
e a extensão de JSON prometia o contrário na própria docstring: *"objetos aninhados viram
`Dict` … que é exatamente o que `kanon_decode` de um tipo composto recebe"*.

**Por que passava.** A suíte de ingestão testa a leitura com os **tipos do núcleo**, que
decodificam; a suíte das camadas constrói os valores em Julia, porque é o que um teste de
unidade faz. Entre as duas, a pergunta "um JSON alcança `pessoa`?" não era feita por
ninguém — e o certificado, o único modelo alimentado de fora até aqui, lê uma planilha de
`texto` e `numero`.

**Decisão.** `pessoa`, `imovel` e `parte` implementam `decode`, e a decodificação é
**estrita como o resto do motor**: chave que falta é erro que nomeia a chave, valor de tipo
errado é erro do decodificador do núcleo — a mensagem é a dele —, e conjunto fechado
(`genero`, `tipo` de imóvel) recusa **nomeando o conjunto**, porque quem escreve o JSON não
tem como adivinhar que `"masculino"` não vale.

`null` e chave ausente valem o mesmo: o campo não veio. Distingui-los faria a origem dos
dados mudar o significado do contrato.

**O que veio junto.** `money` já decodificava de `{"amount", "currency"}`, e a mensagem de
quem escrevia a quantia sozinha só dizia a forma completa quando ela era **número**:
`"480000.00"` — que é como um JSON gerado por sistema escreve quantia — caía no ramo
genérico *"esperava uma quantia com moeda"*, que diz o que falta e não o que escrever.

**O que não muda.** O núcleo não ganhou decodificação genérica por esquema. Ela seria
derivável dos `FieldSpec`, mas construir o valor exige o construtor do tipo, que é da
camada — e uma inferência que acerta na maioria dos casos é exatamente o que a §3.4 chama
de coerção implícita.

---

## D-047 — A camada científica também precisava de `kanon_decode`, e por uma razão a mais

*2026-09-10 · aceita · surgida ao escrever o modelo real nº 8*

**A observação.** A D-046 fechou a porta do JSON para `pessoa`, `imovel` e `parte`, e parou
ali. `KanonScience` ficou de fora — e é a camada cujo tipo é um **número medido**, isto é,
a única cujos valores um instrumento produz sozinho. Um laboratório não digita medição em
Julia; ele exporta o que o equipamento registrou. O certificado de calibração levou sete
`K3010` de uma vez, quatro deles do mesmo campo, porque `pontos` é uma lista de quatro.

**Por que passava.** Pelo mesmo buraco da D-046, e com uma agravante: a dívida estava
**escrita no roadmap**, com o gatilho anotado — *"um laudo alimentado por JSON ou
planilha"*. Corrigi-la antes de um documento pedir teria sido adivinhar a forma da
correção; foi o documento que disse qual é.

**Decisão.** `measure` implementa `decode`, estrito como o do domínio jurídico, com uma
recusa que o outro não tinha por que ter: **um número solto não é uma medição**. Aceitar
`21.4` como `measure` daria incerteza zero a um número que ninguém mediu com incerteza
zero — e a incerteza é justamente quem decide quantos algarismos o valor mostra. O erro
sairia impresso, com casas que a medição não sustenta, que é o oposto do que esta camada
existe para garantir. A mensagem diz isso, e não só que o tipo não bate.

A unidade é opcional e **falta como cadeia vazia**, que é como o `struct` a guarda — e é
essa a porta pela qual a D-049 entrou.

**O que não muda.** Continua sem decodificação genérica por esquema, pela razão da D-046:
construir o valor exige o construtor do tipo, que é da camada.

---

## D-048 — A versão 1 não emparelha repetições, e recusa quem finge que sim

*2026-09-10 · aceita · surgida ao escrever o modelo real nº 8*

**A observação.** O certificado mede quatro pontos e precisa de uma ressalva **no ponto**
cuja incerteza excede um centésimo do valor. A forma óbvia é escrever a ressalva como
bloco filho do bloco repetido:

```kanon
::: ponto <- pontos
Indicação média de {pontos}, com incerteza relativa de {pontos:relative}.

:::: ponto_impreciso <- pontos
Neste ponto a incerteza excede um centésimo do valor indicado.
```

O modelo carrega **sem um único diagnóstico**, e o documento sai assim:

```
3.4. Indicação média de 1.000,4 ± 1,5 °C, com incerteza relativa de 0,1%.

3.4.1. Neste ponto a incerteza excede um centésimo do valor indicado.
```

A ressalva é do ponto **3.1** — o de 20,1 ± 0,3 °C, cuja incerteza relativa é 1,5%. Ela
saiu pendurada no ponto de **melhor** incerteza do lote, afirmando dele o contrário do que
é verdade. Um certificado de calibração assinado com essa frase é um documento falso.

**Por que acontece.** É consequência mecânica da §8.4: cada bloco se expande no seu lugar,
na ordem do arquivo, e duas repetições sobre a mesma coleção são **duas varreduras
independentes**. O pai consome quatro números; o filho, que vem depois, consome o número
seguinte do nível de baixo — e o nível de baixo pertence, por construção, ao último número
consumido pelo de cima. A numeração está mecanicamente correta. Só o sentido é falso, que
é a espécie de erro que nenhuma releitura pega.

O modelo nº 7 já tinha dois blocos repetidos sobre a mesma lista, e não sofreu: eram
**irmãos**, e cada donatário caía em exatamente um deles. Nem por isso a doação escapa da
consequência mais fraca — os donatários saem agrupados por bloco, e não na ordem da lista.
A ordem dos **blocos** é a do arquivo (§8.4); a ordem dos **elementos** não é promessa
nenhuma, e é bom que esteja escrito.

**Decisão.** Erro `K2048`: um bloco de nível *n* cujo nível *n*−1 é aberto por um bloco
repetido é recusado, repita ele próprio ou não. Erro, e não aviso, porque não há leitura em
que aquele número esteja certo — é a diferença para o `K2039`, onde as duas condições podem
coincidir de propósito e só o motor não sabe.

A mensagem diz as duas saídas que existem: escrever o bloco como **irmão** do repetido,
nomeando o elemento no próprio texto — que é o que o certificado faz, e por isso a ressalva
diz *"a indicação de 20,1 ± 0,3 °C"* e não *"neste ponto"* —, ou trazer o texto para dentro
do bloco repetido.

**O que fica em aberto.** Emparelhar repetições — o filho iterando em passo com o pai — é
uma construção que a linguagem não tem, e que a versão 1 não vai ter: a instância do filho
precisaria pertencer à instância do pai, e hoje o plano não tem onde guardar isso. É
candidata a versão maior, e o `K2048` existe para que, até lá, ninguém acredite tê-la
escrito.

---

## D-049 — O branco de um campo de composto vale como ausente, nas duas portas

*2026-09-10 · aceita · surgida ao escrever o modelo real nº 8*

**A observação.** O certificado diz *"todos expressos em {padrao.unit}"* dentro de um grupo,
porque a unidade é opcional em `measure`. Com uma medição sem unidade, o grupo não elidia:

```
3. Mediram-se os pontos adiante relacionados, todos expressos em , e a incerteza …
```

**Por que acontece.** `measure` guarda a unidade num `String`, e a ausência é `""` — não há
`nothing` a pôr no lugar sem transformar o campo num `Union`, que é pior para a camada e
não muda nada para o motor. `check_composite!` lê isso como ausente desde a F2 e segue
adiante; `descend_value`, no render, lia `""` como um valor presente e vazio. **Duas portas
do mesmo valor, com regras diferentes** — a mesma forma da D-041.

A D-008 já tinha decidido a regra: texto em branco não é um valor. Ela só nunca tinha
descido um nível, porque nenhum documento até aqui lera um campo opcional de tipo composto
dentro de um grupo — a dívida estava anotada desde a F2 e o gatilho era exatamente este.

**Decisão.** `descend_value` devolve ausente para campo de composto em branco. A regra da
D-008 vale em qualquer profundidade, e vale nas duas portas.

**O que não muda.** No primeiro nível, o branco continua **avisando** (`K3004`): lá ele é
acidente de quem forneceu os dados. Dentro do composto não há aviso, porque `""` é a
representação normal da ausência num `struct`, e avisar seria ruído em todo documento
correto.

---

## D-050 — O diagnóstico de um elemento diz qual elemento

*2026-09-10 · aceita · surgida ao escrever o modelo real nº 8*

**A observação.** Com `pontos : measure[1..]` e quatro medições no JSON, uma chave faltando
numa delas produzia:

```
K3010: `pontos` é do tipo `measure`, e o valor recebido não serve — falta a chave
       `uncertainty`.
```

E, antes da D-047, a mesma frase **quatro vezes**, uma por elemento. A linha citada é a do
modelo, que está certa: é o contrato que está sendo violado. O que faltava era dizer qual
elemento o viola — o autor do JSON tinha de descobrir sozinho.

**Por que passava.** O caminho já carregava o índice (`pontos[3]`), e o `K3001` de um
elemento nulo já dizia *"o 3º valor"*. Só o `K3010` não dizia, porque `decode_value` monta a
frase com o nome do campo, e é chamada tanto para o valor único quanto para o elemento.

**Decisão.** `decode_value` recebe a posição quando há uma, e escreve *"o 3º valor de
`pontos`"* — a mesma forma que o `K3001` já usava. O valor único continua sem posição,
porque não tem uma.

---

## D-051 — O motor cita a palavra-chave que o autor escreveu

*2026-09-10 · aceita · dívida puxada pelo modelo nº 6, cobrada pelo nº 8*

**A observação.** Num modelo `pt`, o motor falava a outra língua em pelo menos cinco
lugares:

```
K2034: o bloco `lote` se repete (`one for each`, linha 93) …     ← escrito `um para cada`
outline: * um por pontos, quando observacao is present           ← nem inglês nem português
K1301: esperava `when` ou `one for each` depois de `ponto`        ← palavras que não existem
       naquele arquivo
{unit} : text opcional                                            ← o tipo é `texto` ali
```

A §9 promete que a camada de idioma renomeia as palavras-chave, e a `KeywordTable` fazia
metade do trabalho: sabia ler `um para cada` e não sabia escrevê-lo. É a mesma forma da
D-035 — posição certa e nome errado valem menos que nada, porque mandam o autor procurar no
arquivo o que não está lá.

**Decisão.** A `KeywordTable` ganha o mapa reverso, montado junto com ela (duas listas
divergem), e `written(kt, canon)` é o inverso de `keyword`. Mora na tabela, e não no
`Environment`, porque `parse` também precisa dela e não consulta o ambiente (invariante 8).

A regra que ela estabelece: **o que é citação do modelo sai na língua do modelo; o que é
prosa da ferramenta sai em português** (D-027). No esqueleto de um modelo `pt` lê-se
`um para cada pontos, quando não (pontos é precise)`; num modelo em inglês, `one for each
witnesses, when notes is present` — com `sempre` e `bloco condicional` em português nos
dois, porque isso é a ferramenta falando.

`present` e `absent` são palavras-chave e saem traduzidas; o nome de um **atributo de tipo**
(`precise`) não é, e sai como o domínio o registrou. Traduzir atributo é outro assunto, e
continua na tabela de dívidas.

**O que veio junto.** O `não` de uma condição passou a mostrar os parênteses da árvore:
`não (pontos é precise)`. Sem eles a frase se lê das duas maneiras, e o esqueleto existe
para responder essa pergunta, não para devolvê-la.

---

## D-052 — Numa planilha, a coluna com ponto é o campo do composto

*2026-09-10 · aceita · surgida ao escrever o modelo real nº 9*

**A observação.** O certificado de verificação é emitido um por linha do CSV que o sistema
do laboratório exporta, e cada balança tem duas medições — a carga aplicada e a indicação —,
cada uma com valor, incerteza e unidade. `render_each` recusou todas as linhas:

```
K3001: linha 1 da tabela: `carga` é exigido pelo modelo (linha 13) e não foi informado.
       Informe o valor, ou declare o campo opcional …
```

A planilha **trazia** `carga`, em três colunas. `input_field` lê só o nome declarado do
campo, e uma célula não guarda um composto. Como todo tipo de domínio do projeto é
composto — `pessoa`, `imovel`, `parte`, `measure` —, **`render_each`, que existe para
planilhas, não alcançava camada de domínio nenhuma**. E a mensagem mandava o autor fazer a
coisa errada: ele tinha o valor, e não tinha como escrevê-lo.

**Por que passava.** O certificado nº 4 lê "planilha", mas é um `NamedTuple` montado em
Julia, com listas dentro das células — coisa que nenhum CSV tem — e só tipos do núcleo. A
suíte de ingestão testa tabelas de `text` e `money` já construídos. A pergunta "um CSV
alcança um tipo de domínio?" não era de ninguém, pela mesma forma da D-046.

**Decisão.** A extensão de tabelas aninha as colunas cujo nome tem ponto: `carga.value`,
`carga.uncertainty` e `carga.unit` viram o objeto `carga`, que `kanon_decode` recebe na
mesma forma em que o receberia de um JSON. O ponto é o separador que o modelo já usa em
`{carga.value}`, e por isso quem escreve o cabeçalho da planilha não aprende convenção nova.

- **Célula vazia é chave ausente**, pela razão da D-046: a origem dos dados não pode mudar
  o significado do contrato.
- **Um grupo com todas as células vazias é campo ausente.** É a única forma de uma linha
  dizer que a medição opcional não foi feita, e sem ela todo campo opcional composto seria
  obrigatório numa planilha.
- **A coluna inteira e as partes dela, juntas, são recusadas** — `carga` e `carga.value`
  diriam o valor duas vezes, e escolher uma é adivinhar.
- **Tabela sem coluna com ponto passa intacta**, e segue sem conversão no caminho.

**Alternativas descartadas.** Ler os nomes com ponto direto em `input_field`, no núcleo:
serviria a qualquer entrada, e poria no núcleo uma convenção de **formato** — quem conhece
o formato é a extensão, como a de JSON conhece o objeto aninhado. Uma sintaxe no plano de
dados para mapear colunas (`carga : measure <- carga_valor, carga_incerteza`): mistura o
contrato com o arranjo de um arquivo que o modelo não deveria conhecer, e é vocabulário
novo para o que o ponto já diz.

**O que veio junto.** O diagnóstico de um registro dizia `linha 1 da tabela` logo depois de
`linha 13, coluna 3`, que é a do modelo — duas linhas de dois arquivos na mesma frase. E a
linha 1 de um CSV aberto no editor é o **cabeçalho**. Agora diz `no 1º registro da tabela`.

---

## D-053 — A incerteza relativa tem os algarismos de uma incerteza

*2026-09-10 · aceita · surgida ao escrever o modelo real nº 9*

**A observação.** Conferindo à mão o certificado da balança rodoviária — carga de
20.000 kg, indicação de 20.003,5 ± 5 kg —, a incerteza relativa esperada é 0,025 %. O
certificado dizia **`0,0%`**: incerteza nula, que é o que a frase afirma de um instrumento
cuja incerteza é de cinco quilos. A balança de plataforma, com 0,020 %, também saía `0,0%`.

E o defeito já estava publicado. O certificado nº 8, dois dias antes, dizia do padrão de
`100,00 ± 0,05 °C` que a incerteza relativa era `0,1%` — o **dobro** dos 0,05 % que ele
tem. Passou porque o golden dele foi conferido na incerteza absoluta, que a D-034 já
tinha acertado, e não na relativa.

**Por que acontecia.** `relative` formatava com uma casa decimal fixa. É a D-034 do outro
lado da mesma medição: a regra do PDG estava certa para a incerteza absoluta e nunca tinha
sido aplicada à relativa, que também é uma incerteza.

**Decisão.** A incerteza relativa segue a mesma regra — um algarismo significativo, dois
quando o primeiro é 1 ou 2 —, pela mesma `decimals_for`. O relatório nº 3 passa de `0.2%`
a `0.19%`, e o certificado nº 8 de `0,1%` a `0,05%` no padrão e a `0,15%` e `0,30%` em dois
pontos. **Três goldens mudaram**, e a mudança é o conserto: eles fixavam algarismos que a
medição não sustenta, ou a falta dos que ela sustenta.

**A lição de método.** O golden do nº 9 foi escrito à mão antes de a saída ser lida, como o
roadmap manda desde o nº 3. Os do nº 3 e do nº 8 também foram — mas a conta à mão da
relativa foi feita com a mesma casa fixa que o motor usava. Conferir à mão protege contra o
motor, e não contra a convenção errada que o autor do golden compartilha com ele.

---

## D-054 — `include` é palavra-chave, e palavra-chave tem apelido de idioma

*2026-09-11 · aceita · surgida ao escrever o modelo real nº 10*

**A observação.** O roteiro de aula é o primeiro documento em português que inclui um
fragmento. Escrito como um redator escreveria, ele traz a linha `incluir
"fragmentos/avaliacao.kanon"` no plano do texto. O modelo **carregava limpo**, o `check`
passava, e o roteiro saía com um parágrafo dizendo `incluir
"fragmentos/avaliacao.kanon"` — o caminho do arquivo impresso no documento, e nenhum
diagnóstico em lugar nenhum. Só a remissão `{::avaliacao}`, que apontava um bloco do
fragmento, acusou alguma coisa: `K2033`, bloco inexistente — um sintoma três linhas
adiante da causa.

**Por que passava.** A §9 promete que a camada de idioma renomeia as palavras-chave, e a
tabela do `Extenso` traz as dezesseis que existiam quando ela foi escrita. `include`
entrou na F7, com a inclusão de fragmentos, e não entrou na tabela: era a única palavra
da linguagem sem forma portuguesa. Nenhum modelo em português tinha incluído um fragmento
— o único que inclui é o relatório nº 3, escrito em inglês — e a interseção "inclusão ×
idioma" não tinha documento nenhum.

**Decisão.** `:include => "incluir"` entra em `PALAVRAS`. Pela D-003 a forma inglesa
**deixa de valer** num arquivo que declara idioma, como acontece com todas as outras.

**O que isso não conserta.** O apelido resolve o português e não resolve o silêncio: quem
escrever `include` num modelo `pt` — a forma que este repositório documentou até hoje —
cai exatamente no mesmo buraco. É a D-055.

---

## D-055 — Uma linha que quis ser inclusão não vira prosa em silêncio

*2026-09-11 · aceita · surgida ao escrever o modelo real nº 10*

**A observação.** O defeito da D-054 não era a falta do apelido. Era o documento sair
errado sem que nada avisasse — a mesma categoria da D-048, e a mais cara de todas, porque
as outras se veem lendo a saída uma vez e esta se vê lendo a saída **e sabendo o que
deveria estar lá**.

**Por que passava.** Uma linha que o plano do texto não reconhece é prosa. É assim de
propósito: `: Considerando o exposto` é prosa, e não um bloco chamado `Considerando`. Mas
o próprio `parse_text.jl` já tinha escrito o limite dessa regra para o cabeçalho de bloco
— *"a presença de `<-` denuncia a INTENÇÃO de escrever um cabeçalho, e quando ela aparece
e o resto não casa o resultado é erro, não prosa silenciosa"*. A inclusão não tinha a
cláusula equivalente.

**Decisão.** `K1215`, **aviso**: uma linha cuja forma inteira seja uma palavra, um espaço
e um caminho terminado em `.kanon` entre aspas, e cuja palavra não seja a da inclusão nem
qualquer outra palavra-chave, é avisada. A mensagem diz o que vai acontecer — *"o caminho
vai sair impresso no documento"* — e a dica escreve a linha certa **na língua do arquivo**
(D-051): num modelo `pt`, `incluir "x.kanon"`.

Aviso, e não erro, por uma razão estreita: um documento pode falar da própria linguagem, e
a linha citada em prosa é legítima. Não há escape para ela, e recusar fecharia a porta a um
texto que ninguém teria como escrever de outro jeito. O que estava errado era o silêncio.

**A forma é estreita de propósito.** A linha inteira, uma palavra só, e o `.kanon` entre
aspas: `Ele disse "clausulas.kanon" e saiu.` não avisa, `incluir "clausulas.txt"` não
avisa, e `incluir o arquivo "clausulas.kanon"` não avisa. Prosa é o que o plano do texto
tem de mais comum, e um aviso que a alcance por engano custa mais do que resolve.

**O que veio junto, e é a metade que importa.** O aviso não tinha por onde sair. Todo
`K1xxx` era erro até aqui, e erro viaja por exceção; um aviso do parser era acumulado no
contexto e **descartado** entre a leitura e a análise, porque o `Template` não tinha onde
guardá-lo. O diagnóstico existia no código e não chegava a ninguém. `Template` passou a
carregar os avisos da leitura, `compose` junta os do hospedeiro e os dos fragmentos, e
`analyze` começa a lista com eles. `Span` e `NodeId` mudaram-se para `src/span.jl`: o
`Diagnostic` nasce de um `Span` e o `Template` passou a guardar `Diagnostic`, e em Julia um
campo precisa do tipo já definido.

---

## D-056 — O glossário: a palavra que o idioma empresta a quem não tem idioma

*2026-09-11 · aceita · surgida ao escrever o modelo real nº 10*

**A observação.** O roteiro de aula numera teoremas com o marcador `@`, e saía `Theorem
1. A média amostral…` num documento em português. Era uma dívida conhecida desde o
certificado nº 8, com o gatilho já puxado; o nº 10 é o documento que a cobra, porque é o
primeiro que numera um teorema em português.

**Por que é difícil.** As três saídas óbvias quebram uma declaração cada:

- pôr `Teorema` dentro do `KanonScience`, que se anuncia **sem idioma**, em inglês
  canônico, e é a prova em forma de pacote de que a linguagem não é portuguesa;
- pôr o estilo `@` dentro do `Extenso`, que não conhece domínio nenhum, não carrega o
  `KanonScience` e não sabe se ele está presente;
- pôr qualquer das duas coisas no núcleo, que não tem nem idioma nem domínio
  (invariante 3).

**Decisão.** Um **glossário** no ambiente: `register_term!(b, lang, chave, palavra)` e
`term(ctx, chave, padrão)`. O domínio declara a chave e a palavra inglesa de que se
contenta; o idioma registra a tradução, que para ele é só uma palavra da própria língua; e
o núcleo transporta o par sem entender nenhum dos dois lados. `theorem_number` passa a ser
`term(ctx, :theorem, "Theorem") * " " * join(path, ".")`.

É a forma da D-041 — a camada obtém do contexto o que é do idioma — aplicada ao rótulo em
vez de ao separador. E o padrão é obrigatório na chamada de propósito: quem pergunta tem de
saber escrever a própria resposta, e assim uma camada de domínio continua funcionando em
ambiente neutro, que é onde o teste de neutralidade a observa.

**Alternativas descartadas.** Um pacote-ponte `KanonScienceExtenso`, que é a resposta
canônica de Julia para o cruzamento de dois pacotes: correta, e cara demais para uma
palavra — seriam seis pacotes num repositório de cinco, e um por par de camadas daí em
diante. O estilo consultar `ctx.env.locale` e ter a tabela dentro do domínio: é a primeira
saída descartada, com um `if` no lugar do dicionário.

**O que o glossário não é.** Não é tradução de diagnóstico (D-027), nem tabela de
palavras-chave (essas são do léxico, e o parser não consulta o ambiente — invariante 8).
É o texto que a camada escreve **dentro do documento**, e é a única coisa que ela escreve
por conta própria.

---

## D-057 — O rascunho mostra a cópia que o contrato promete

*2026-09-11 · aceita · surgida ao escrever o modelo real nº 11*

**A observação.** A minuta do contrato de prestação de serviços é o estado normal de um
contrato: o escritório a escreve com o escopo em aberto e o preço em negociação. O
rascunho saía com `«valor»`, com `«inicio»` — e **sem a cláusula das entregas**, que é
justamente a parte em aberto. `entregas : texto[1..] !` promete ao menos um item no
documento pronto, e o rascunho mostrava zero.

**Por que acontecia.** `instances_of` devolve zero iterações quando a coleção está
ausente, o que é a resposta certa para o `render` — e a única resposta que ele conhecia.
O plano é montado em `bind`, que não sabia distinguir rascunho de documento.

**Decisão.** No rascunho, um bloco repetido sobre coleção **garantida** ausente produz
**uma** iteração, com o marcador no lugar do elemento. Sobre coleção **opcional**
ausente, nenhuma — porque o documento pronto pode legitimamente não ter nenhuma.

É a doutrina da D-024 aplicada ao plano do bloco em vez do valor interpolado: *"só o valor
garantido que falta vira marcador, porque é o único cuja ausência não tem representação no
texto final"*. Um bloco repetido sobre `[1..] !` tem representação garantida no texto
final; sobre `[]`, não tem.

**Garantida quer dizer as duas coisas**: obrigatória (ou com valor padrão) **e** com
mínimo maior que zero. `texto[1..]` sem `!` não garante nada, e `texto[] !` tampouco.
Só o campo de primeiro nível, de propósito: uma coleção dentro de composto depende de o
composto existir, e afirmar a garantia ali seria afirmar mais do que o contrato diz.

**O que isso não promete.** O rascunho mostra **uma** cópia, não a quantidade final: ele
não sabe quantas entregas serão contratadas, e não inventa. Quando o bloco repetido é de
nível 1, os números dos blocos seguintes ainda mudam entre o rascunho e o documento — e
com uma cópia eles mudam menos, e a estrutura aparece. Zero cópias escondia a estrutura
inteira.

---

## D-058 — A camada de domínio na linha de comando

*2026-09-11 · aceita · surgida ao escrever o modelo real nº 11*

**A observação.** O modelo nº 11 devia ser o primeiro a passar pela CLI. Não passou:
`kanon check contrato.kanon --locale pt` recusa o documento com dezesseis diagnósticos,
porque `pessoa`, `dinheiro` e o marcador `§` vêm do `KanonLegal`, e **a CLI não tinha
como carregar uma camada de domínio**. `--locale` era a única opção de ambiente.

O alcance é maior que o modelo: dos dez modelos reais escritos até aqui, **nove** usam
camada de domínio. A linha de comando — que a §12 documenta desde a F0 e que é como o
redator chega ao motor — não alcançava nenhum deles.

**Por que passou tanto tempo.** `test_cli.jl` exercita os cinco códigos de saída com
modelos-brinquedo, escritos em inglês canônico e sem camada nenhuma, porque a suíte do
núcleo não pode depender de camada (invariante 3). A suíte de cada camada chama o motor
de dentro de Julia, onde `Environment(domains = [...])` sempre esteve à mão. A pergunta
"e pela linha de comando?" não era de ninguém — a mesma forma da D-046 e da D-052.

**Decisão.** `--domain NOME`, repetível: `kanon render c.kanon d.json --locale pt
--domain KanonLegal`. O nome é resolvido no ambiente Julia ativo; o que não estiver
instalado é erro de **uso** (código 3), com a linha do `Pkg.add` na mensagem, e nunca uma
pilha de Julia.

**Quem manda carregar é o usuário, e isto não afrouxa a invariante 4.** Um `--domain` é o
equivalente de linha de comando ao `using` que o programa escreveria. O que a invariante
proíbe é o **modelo** mandar carregar código — um pragma `domain KanonLegal` no arquivo
seria dado não confiável escolhendo o que o motor executa, e é por isso que ele não
existe, nem vai existir. A linha de comando é do operador, não do documento.

**Alternativas descartadas.** Um pragma no modelo (acima). Uma variável de ambiente
`KANON_DOMAINS`: mesma capacidade, menos visível no comando que a usa, e invisível no
histórico do shell. Um arquivo de configuração por projeto: resolve o incômodo de repetir
a opção, e não resolve nada que a opção não resolva — se o incômodo aparecer, ele é
aditivo depois.

**O que veio junto.** A dica do `K2005` — tipo desconhecido — mandava carregar a camada e
passá-la em `domains = [...]`, que é a forma de quem chama o motor de dentro de Julia. Um
redator na linha de comando lia a dica e não tinha o que fazer com ela. Agora ela diz as
duas formas.

---

## D-059 — A camada carregada pela linha de comando existe para o resto da execução

*2026-09-13 · aceita · surgida ao escrever o modelo real nº 12*

**A observação.** A procuração nº 12 foi o primeiro modelo levado ao `bin/kanon` num
processo novo. `kanon ask procuracao.kanon partes.json --locale pt --domain KanonLegal`
respondeu: *"o idioma `pt` não tem camada carregada"*. A D-058 tinha sido dada como feita
dois dias antes, com a suíte verde.

**A causa.** O `--domain` faz `Base.require` e, na mesma função, constrói o `Environment`.
O `require` define métodos novos — o `configure_locale!` de `pt` que o `Extenso` traz, o
`configure!` da camada, o `kanon_decode` de `pessoa` —, e o código que já estava rodando
não os vê: ele foi compilado num mundo em que eles não existiam (*world age*). A CLI de
verdade, portanto, **continuava sem alcançar camada nenhuma**.

**Por que a suíte passou.** O `runtests.jl` do `KanonLegal` faz `using KanonLegal` no
topo, e o `Kanon.main` chamado depois disso roda num mundo em que a camada já existia. O
`require` dentro dele não carregava nada. **O teste da D-058 testava a opção num processo
em que ela não tinha efeito.**

**Decisão.** A construção do ambiente e o comando inteiro rodam por `Base.invokelatest`,
depois dos `require`. E o teste do fluxo roda o `bin/kanon` num **processo à parte** —
é a única forma de exercitar o caminho, e é mais lenta (dois processos, ~20 s) por isso.

**Alternativas.** (a) Carregar as camadas no `bin/kanon`, antes de chamar `main`: o
script teria de ler as opções duas vezes, e o `main` chamado de outro programa voltaria a
ter o defeito. (b) `invokelatest` no ponto de chamada (escolhida): uma linha, no único
lugar em que o mundo muda.

**A lição, que vale mais que a correção.** O teste que confirma uma correção precisa
rodar **no mesmo lugar em que o defeito foi observado**. A D-058 foi observada na linha de
comando e confirmada dentro de Julia, onde o defeito não existe.

---

## D-060 — Um `.json` na linha de comando carrega o leitor de JSON

*2026-09-13 · aceita · surgida ao escrever o modelo real nº 12*

**A observação.** Com a D-059 corrigida, o mesmo comando saía com uma pilha de Julia:
*"para ler JSON, carregue `JSON3`"*, levantada por `error()` e não capturada. O `bin/kanon`
faz `using Kanon` e nada mais, e o `JSON3` é **extensão**, não dependência. Nenhum arquivo
`.json` era lido pela linha de comando de verdade — e o JSON é o único formato de dados
que carrega uma `pessoa`. Somada à D-059, a CLI não alcançava documento jurídico nenhum
por dois caminhos independentes.

**Decisão.** Ao ler um `.json`, a CLI carrega o `JSON3` se ele ainda não está carregado,
e lê por `invokelatest`. Se o pacote não estiver instalado no ambiente, é erro de **uso**
(código 3), com a linha do `Pkg.add` — nunca uma pilha.

**Isto não afrouxa a invariante 4.** O que carrega é sempre o mesmo pacote, e nunca um
nome que venha do modelo ou dos dados. É o operador quem pede, ao dar à CLI um arquivo
`.json`, pelo mesmo raciocínio da D-058.

**Alternativa descartada.** Tornar o `JSON3` dependência do núcleo: resolveria a CLI e
tiraria do núcleo a propriedade de funcionar sem dependência nenhuma, que a F7 escolheu
de propósito.

---

## D-061 — O que o `ask` emite, o `render` lê de volta

*2026-09-13 · aceita · surgida ao escrever o modelo real nº 12 · revê parte da D-029*

**A observação.** O fluxo do balcão — as partes num JSON do cadastro, o resto digitado —
quebrou em três pontos, todos contra a frase que a documentação do `ask` já dizia:

| O que acontecia | Consequência |
|---|---|
| a `pessoa` vinda do JSON saía como `outorgado = Dict{String, Any}(...)` | o `render` recusava o arquivo com "é uma coleção, e veio um valor único" — uma mensagem sobre o formato que o `ask` escreveu, e não sobre os dados |
| o opcional nunca era perguntado | o réu, o número do processo, a validade — **onde a procuração varia** — não tinham como entrar pelo `ask` |
| a resposta só era conferida depois da última pergunta, e a pergunta não dizia a forma | `sim` num booleano e `13/09/2027` numa data viravam dois `K3010` no fim, e o atendente recomeçava |

**Por que passou.** A suíte do `ask` usava um modelo em inglês, sem camada, de cinco
campos escalares, e lia a saída de volta com `chave = valor` — que é o formato em que ela
tinha sido escrita. Nenhum teste tinha dado ao `ask` um dado que o `chave = valor` não
escreve, porque nenhum modelo de teste tinha um.

**Decisão.**

1. **Os dados saem na forma em que vieram**: JSON se `-o` termina em `.json` ou, sem
   `-o`, se a entrada era `.json`; `chave = valor` nos demais casos. O JSON sai pelo
   emissor ordenado do próprio núcleo (o do checklist), com as chaves em ordem alfabética
   em toda profundidade — o arquivo vai a `diff`. Pedir `chave = valor` com um composto
   nos dados é erro de uso, com a sugestão do `-o dados.json`.
2. **O `ask` pergunta tudo o que falta**, inclusive o opcional e o que tem padrão. Enter
   deixa o opcional em branco e mantém o padrão, e a pergunta diz qual dos dois.
3. **A resposta é conferida na hora, pelo `check`**, e a pergunta se repete com a
   mensagem dele. A pergunta diz a forma: `aaaa-mm-dd`, `verdadeiro ou falso` na língua
   do arquivo, número com ponto decimal. O booleano aceita a palavra do idioma do modelo.

**O que isto revê da D-029.** A D-029 dizia "opcional não se pergunta: ele pode faltar".
Poder faltar é verdade do contrato, e não razão para não perguntar: o `ask` existe para
que o redator não abra o arquivo de dados, e o opcional que ele não pergunta obriga a
abri-lo. O resto da D-029 — só se pergunta o que cabe numa linha — continua valendo, e a
procuração confirma: as partes vêm do cadastro, e é certo que venham.

**Alternativas.** Para o formato: (a) JSON sempre, como a §12 escrevia desde a F0 —
quebraria o `kanon ask m.kanon > dados.kdata` de quem não tem o `JSON3`; (b) escolher o
formato pelo **conteúdo** — JSON só se houver composto — faria o mesmo comando mudar de
formato conforme os dados, que é adivinhar; (c) pela forma da entrada e da saída pedida
(escolhida). Para a conferência: uma validação própria do `ask` — descartada pela razão
da D-029: a ferramenta que discorda do motor é pior que nenhuma.

---

## D-062 — No Typst, o valor não apaga texto

*2026-09-13 · aceita · surgida ao compilar o golden do modelo real nº 12*

**A observação.** O golden da procuração foi o primeiro `.typ` do acervo **compilado** —
o do edital nº 6 era comparado byte a byte e nunca tinha passado pelo Typst. Compilado
com o Typst 0.15.1, ele saiu certo; e a mesma sessão, conferindo a tabela de escape contra
o compilador, achou três construções que não estavam nela e que **não abrem marcação
visível: apagam**.

| No valor | O Typst lê | O documento |
|---|---|---|
| `processo 123//2026, vara` | comentário de linha | `processo 123` — o resto da linha some |
| `~200 m²` | espaço inseparável | ` 200 m²` |
| `sim -? não` | hífen opcional | `sim  não` |

Nenhuma dá erro de compilação. É a classe mais cara do roadmap — o documento sai, e diz
menos do que o dado dizia —, num formato que existe para virar PDF e ir à assinatura.

**Decisão.** O escape do Typst acrescenta `~` sempre; `?` depois de `-` e no começo do
valor; `-` no fim do valor; e `/` junto de outra barra ou em qualquer das bordas do valor.
As bordas contam porque a vizinha é prosa do autor, que o escape não vê: `{a}/` com
`a = "x/"` formaria `//` na emenda. A barra sozinha no meio do valor não leva escape —
`Petrolina/PE` e `S/A` não formam nada, e escapá-las seria o ruído que a F8 recusou.

**O método, que é o que fica.** A tabela de escape de um formato se confere contra o
**compilador** do formato, e não contra a documentação dele. O golden em Typst agora afirma
também que tirar as contrabarras devolve o texto puro — o escape só acrescenta.

---

## D-063 — O número por extenso não leva vírgula entre as classes

*2026-09-14 · aceita · surgida ao escrever o modelo real nº 13*

**A observação.** A notificação nº 13 cobra `R$ 18.750,00`, e o motor escreveu *"dezoito
mil, setecentos e cinquenta reais"*. O projeto já dizia o contrário em três lugares: a
docstring de `inteiro_extenso` (*"escreve-se `mil e duzentos`, mas `mil duzentos e
trinta`"*), a de `juntar_escalas` (*"é o que separa `mil e duzentos` de `mil duzentos e
trinta`"*) e o comentário do próprio teste. **As asserções logo abaixo do comentário
exigiam a vírgula** — `inteiro_extenso(1230) == "mil, duzentos e trinta"`.

E o laudo nº 5, já publicado, tinha *"seiscentos e dezoito mil, setecentos e
cinquenta reais"* no golden escrito à mão.

**Por que passou.** É a lição da D-053, pela terceira vez: o golden escrito à mão protege
contra o motor, e não contra uma convenção que o autor do golden compartilha com ele. O
teste foi escrito olhando a saída; o comentário, olhando a regra. Os modelos anteriores
tinham valores redondos — `mil e oitocentos`, `quarenta e dois mil` —, e o laudo, o único
que não tinha, foi conferido com a mesma vírgula.

**Decisão.** Nenhuma vírgula entre as classes. O `e` entra antes da **última parte
escrita** quando o grupo dela é menor que cem ou é centena exata; nas demais emendas, espaço:
`mil duzentos e trinta`, `um milhão e duzentos mil`, `um milhão duzentos mil e trezentos`.
A regra antiga olhava o grupo das **unidades**, e errava também quando ele era zero:
`1.200.000` saía `um milhão, duzentos mil`.

**Alternativa descartada.** Manter a vírgula e corrigir os comentários. A vírgula entre as
classes aparece em cheque e em contrato, mas a forma que os três textos do projeto
descreviam é a das gramáticas e a que o redator oficial usa; e, entre o que o projeto
escreveu como regra e o que o teste escreveu olhando a saída, vale a regra.

---

## D-064 — A pergunta do `ask` diz de que arquivo é a linha

*2026-09-14 · aceita · surgida ao escrever o modelo real nº 13*

**A observação.** Com a qualificação do advogado movida para um fragmento, o `ask` da
procuração perguntou `oab — texto, linha 17`. A linha 17 é do fragmento; na procuração ela
é outra coisa. É a forma da D-035 — a posição certa com o nome errado, que vale menos que
nada —, agora na pergunta do `ask`.

**Decisão.** Um campo declarado fora do modelo aberto é perguntado com o caminho do
arquivo relativo ao modelo: `oab — texto, fragmentos/procurador.kanon, linha 17`.

---

## D-065 — O `kanon-lsp` enxerga a camada que carrega

*2026-09-14 · aceita · surgida ao escrever o modelo real nº 13*

**A observação, em duas camadas.** O modelo nº 13 foi escrito pelo servidor de linguagem,
iniciado como um editor o inicia: `kanon-lsp --locale pt --domain KanonLegal`, num processo
novo.

1. O servidor **morria ao iniciar**: *"o idioma `pt` não tem camada carregada"*, com pilha.
   O lançador fazia `@eval using` e construía o `Environment` na mesma função — a D-059,
   no outro lançador.
2. Corrigido isso, o servidor **subia e mentia**: todo campo de sujeito da notificação saía
   como `K2001 o contrato não declara \`nome\``, oito erros num modelo que o `kanon check`
   aceita limpo. Uma instrução de nível superior roda inteira no mundo em que começou, e
   em `KanonLSP.serve(env = ambiente(ARGS))` o `ambiente` carregava a camada e o `serve`
   continuava sem ver o esquema de `pessoa`.

O segundo é o pior dos dois, e só apareceu porque o primeiro foi corrigido: um servidor que
não sobe o redator percebe; um que sublinha em vermelho o modelo certo ensina o redator a
ignorar o sublinhado.

**Por que passou.** A suíte do `KanonLSP` roda o servidor dentro de Julia, com um domínio
de mentira em inglês canônico, e nunca executou o `bin/kanon-lsp`.

**Decisão.** O lançador carrega a camada com `Base.require`, constrói o ambiente por
`invokelatest`, e chama o `serve` também por `invokelatest`, em instrução separada. Camada
inexistente é erro de uso (código 3) sem pilha. A suíte roda o lançador num processo à
parte, com a camada de verdade, e afirma que a notificação abre sem diagnóstico.

---

## D-066 — O que o editor mostra num fragmento é a soma do que os documentos abertos dizem

*2026-09-14 · aceita · surgida ao escrever o modelo real nº 13*

**A observação.** O fragmento `procurador.kanon` é incluído pela procuração e pela
notificação. Com um erro que só existe para a notificação — o fragmento usa `{processo}`,
que a procuração declara e a notificação não —, a sequência *abrir a notificação, abrir a
procuração* publicava o erro no fragmento e, em seguida, **a lista vazia**: o LSP substitui
a lista inteira a cada publicação, e o servidor publicava a de quem falou por último. O
editor mostrava limpo um fragmento com o qual um documento aberto não renderiza. Na ordem
inversa, fechar a notificação deixava o erro preso no fragmento.

E o hospedeiro lê o fragmento **do disco**: salvar a correção do fragmento não mudava
nenhum hospedeiro até alguém digitar nele.

**Por que passou.** O único teste de fragmento do servidor tinha um hospedeiro. Nenhum
fragmento do acervo servia a dois documentos — este é o primeiro.

**Decisão.**

1. O servidor guarda, por documento aberto, os arquivos sobre os quais ele tem algo a
   dizer. O que se publica num arquivo é a **soma** do que todos os documentos abertos
   dizem sobre ele; ao fechar um documento, republicam-se os arquivos que ele alcançava.
2. O diagnóstico publicado num fragmento por um hospedeiro diz **de onde** vem: *"Ao ser
   incluído por \`notificacao.kanon\`."* Um erro de fragmento depende do contrato de quem
   inclui, e a mesma frase é verdadeira lida num hospedeiro e falsa lida no outro. O mesmo
   diagnóstico dito por dois hospedeiros sai uma vez, com os dois nomeados; quando o próprio
   fragmento aberto diz a mesma coisa, o erro é dele, e a origem não se acrescenta.
3. `didSave` reanalisa os demais documentos abertos, e o servidor anuncia `save`.

**Alternativa descartada.** Os hospedeiros lerem o fragmento do **buffer** aberto, e não do
disco: o editor mostraria um documento que o `kanon render` não produz, porque o motor lê
o disco. A ferramenta discordaria do motor (D-029).

---

## D-067 — A completação oferece o que o motor aceita naquele ponto

*2026-09-14 · aceita · surgida ao escrever o modelo real nº 13*

**A observação.** Escrevendo a notificação no editor, quatro listas de completação estavam
erradas, e todas pela mesma razão — a completação resolvia o caminho por conta própria, e
não como o motor resolve:

| Onde | O que vinha | O que o motor aceita |
|---|---|---|
| `{notificado.`, num bloco de sujeito `pessoa` | os campos da raiz e os de `pessoa` | os de `parte` |
| `{representante.`, no bloco `<- notificado` | os campos da raiz e os de `parte` | os de `pessoa` |
| `{nome:`, no bloco `<- advogado` | nada | os formatadores de `texto` |
| `{especiais:`, com `especiais : texto[]` | os formatadores de `texto` | os de `list` |

O `.` é gatilho **anunciado** pelo servidor: o editor abria sozinho a primeira lista, e o
redator escolhia `cpf` para uma empresa. E a quinta, achada ao dar à suíte uma camada de
verdade: `kanon_formats(T)` sem o ambiente enumera o processo inteiro, e o `kanon-lsp`
sempre tem camada carregada — num ambiente sem idioma, `{preco:` oferecia `extenso`, que o
motor recusa com `K2020`.

**Decisão.** Depois do ponto, os campos do tipo à esquerda dele, resolvido pelo contrato e,
se não, pelo sujeito do bloco (§4.2); o formatador pelo mesmo caminho, os de `list` quando o
campo é coleção, e sempre por `kanon_formats(T, env)`, a função que a análise usa. O bloco
de uma linha se procura **no arquivo** do documento, como `at` já fazia.

**O método.** A suíte do servidor usava um domínio de mentira para ficar independente das
camadas, e por isso nunca teve um processo com `Extenso` carregado. Independência da suíte
e realismo do processo são coisas diferentes, e a segunda é a que o redator tem.

---

## D-068 — O idioma sem camada de domínio chega à linha de comando

*2026-09-14 · aceita · surgida ao escrever o modelo real nº 14*

**A observação.** O atestado de capacidade técnica é um modelo `pt` sem camada de domínio,
e foi o primeiro deles levado ao `bin/kanon`. Com o `Extenso` instalado no ambiente,
`kanon ask atestado.kanon contrato.json --locale pt` saiu com *"o idioma `pt` não tem
camada carregada. Carregue o pacote que define `Kanon.configure_locale!(b, ::Val{:pt})`"*
— uma instrução para quem está dentro de Julia, e nada que o operador pudesse digitar.
O `Extenso` só chegava à linha de comando como dependência de uma camada de domínio, e o
certificado nº 4 e o edital nº 6 nunca tinham passado por ela.

O contorno óbvio, `--domain Extenso`, saiu com outro erro, e esse mentia: *"o tipo `text`
é registrado por `kanon` e por `Extenso`"*. O construtor do ambiente chamava
`getfield(m, :configure!)` sempre que `isdefined(m, :configure!)`, e `isdefined` enxerga
o que o módulo **importou**: o `Extenso` faz `using Kanon`, que exporta `configure!`, e o
construtor rodava o registro do núcleo uma segunda vez, em nome da camada.

**Por que passou.** As suítes do certificado e do edital constroem
`Environment(locale = :pt)` num processo que já fez `using Extenso`. E toda camada de
domínio do acervo define o seu `configure!`, então nenhuma chegou ao ramo do importado.

**Decisão.**

1. O `--domain` carrega também o pacote de idioma: `--locale pt --domain Extenso`. Ele
   já era, pela D-058, o equivalente de linha de comando ao `using`, e um `using Extenso`
   é o que o programa em Julia escreve. A ajuda diz as duas formas.
2. O construtor chama o `configure!` **do próprio módulo**, e passa adiante o módulo que
   só importou o do núcleo — que é o que a §5 sempre disse.
3. `--locale` com um idioma que nenhum pacote carregado define é erro de **uso**, antes de
   construir o ambiente, e a mensagem diz o que digitar: `--locale pt --domain NOME`. A
   dica do `K1006` diz as duas formas, como a do `K2005` desde a D-058.

**Alternativas.** (a) `--locale pt` carregar o `Extenso` sozinho: o núcleo teria de saber
que o pacote de `pt` se chama `Extenso`, e a invariante 3 proíbe. (b) Descobrir o pacote
varrendo as dependências do ambiente ativo: carregar o que o operador não pediu, pela
mesma razão por que o modelo não pode pedir (invariante 4). (c) Uma opção nova, só para
idioma: duas opções para o mesmo `using`, com a diferença de nome sustentando uma
distinção que o construtor não faz — ele recebe módulos. (d) `--domain` para o pacote de
idioma (escolhida). O nome da opção é o preço: `domain` diz menos do que ela faz.

---

## D-069 — O `ask` recusa o número escrito na forma do documento

*2026-09-14 · aceita · surgida ao escrever o modelo real nº 14*

**A observação.** No balcão do atestado, o fiscal digitou os quantitativos como o
documento os escreve:

| Resposta | O que acontecia |
|---|---|
| `1.320` (metros de drenagem) | o `ask` lia `1.32`, o `check` não tinha o que objetar, e o atestado dizia **`1,32 m de rede de drenagem pluvial`** — sem aviso nenhum |
| `12.480,50` (m² de pavimentação) | recusado com *"o valor recebido não serve — esperava um numero"*, sem dizer a forma a escrever |

A pergunta dizia "ponto decimal, sem separador de milhar" desde a D-061. Mas num idioma em
que o ponto separa os milhares, `1.320` é um número válido **nas duas formas**, e a
resposta ambígua passava. É o defeito mais caro da lista do portão: um atestado de
capacidade técnica prova a experiência da empresa numa licitação pelos quantitativos, e
este reduzia mil trezentos e vinte metros a pouco mais de um.

**Por que passou.** A suíte do `ask` é em inglês canônico, sem idioma, onde não há
separador de milhar e `1.320` só tem uma leitura. A dívida estava na tabela, com o
gatilho "o primeiro modelo com `numero` preenchido pelo `ask`".

**Decisão.**

1. Num ambiente cujo separador de milhar é o ponto, a resposta com a forma de um número
   de **um** grupo — `1.320`, `12.480`, `-1.320`, sem zero à esquerda — é **recusada**, e
   a pergunta se repete com as duas leituras escritas: *"Escreva `1320` se é o número
   inteiro, ou `1.32` se é decimal."*
2. A resposta que só é número na forma do documento (`12.480,50`, `87,25`, `1.234.567`)
   é recusada com a forma pronta: *"a resposta se escreve com ponto decimal e sem separador de
   milhar: `12480.50`."*
3. O `check` recusa um número vindo como cadeia com a forma, como já fazia com a data:
   *"o número se escreve com ponto decimal e sem separador de milhar na entrada."*

**Alternativas.** (a) Aceitar a forma do documento no `ask`: é um segundo formato de
entrada — o que o `ask` recusa para `dinheiro` —, e a ambiguidade de `1.320` continuaria
sem resposta, só trocada de lado. (b) Mudar a pergunta: ela já dizia a forma, e o fiscal
digitou como o documento escreve mesmo assim. (c) Recusar e dizer as duas leituras
(escolhida): a pergunta a mais custa uma linha, e o documento errado custa a licitação.

**O que não mudou.** O arquivo `chave = valor` escrito à mão tem a mesma ambiguidade —
`drenagem = 1.320` é lido `1.32` — e o JSON não, porque lá o número é da gramática do
JSON. Nenhum modelo chegou a um arquivo de dados digitado com número agrupado, e fica na
tabela de dívidas com esse gatilho.
