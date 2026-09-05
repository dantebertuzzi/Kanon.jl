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
