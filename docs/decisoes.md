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
