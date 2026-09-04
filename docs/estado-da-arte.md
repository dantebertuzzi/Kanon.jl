# F0 — Estado da arte

> Levantamento crítico exigido pela seção 2 da especificação inicial.
> Posição explícita ao final: onde Kanon inova, onde copia, e onde escolhe pior de propósito.

## 0. Uma correção à tese da seção 1

A tese, como escrita, é:

> "Toda linguagem de template difundida aceita qualquer dado e improvisa no que falta. […] E nenhuma delas declara o que o modelo exige — não há contrato entre o modelo e os dados."

**A segunda frase é falsa.** Existem pelo menos cinco famílias de sistemas em produção que declaram, de alguma forma, o que o modelo exige:

| Sistema | Onde mora o contrato | Quando é verificado |
|---|---|---|
| Askama (Rust) | `struct` Rust anotado com `#[derive(Template)]` | compilação |
| HotDocs / Contract Express | *component file* separado, sete tipos de variável | montagem da entrevista |
| docassemble | blocos YAML `question`/`fields`, tipados, obrigatórios por padrão | execução da entrevista |
| JSON Schema / Pydantic | arquivo ou classe à parte | antes do render, por fora do motor |
| CUE / Dhall | o próprio arquivo (tipos e valores no mesmo lattice) | avaliação |

Se a F0 aceitasse a tese como dada, construiríamos algo que já existe e alegaríamos ineditismo — exatamente o que a seção 2 mandou evitar.

**A versão defensável da tese**, que sobrevive ao levantamento, é mais estreita e mais forte:

> Nenhuma linguagem de template de texto difundida coloca o contrato de dados **no mesmo arquivo que o redator não-técnico edita**, e nenhuma delas oferece **garantia estática de que um valor ausente não pode chegar ao texto**.

Askama coloca o contrato em código Rust (o redator não o vê). HotDocs coloca em um arquivo de componentes editado por outra ferramenta e por outra pessoa. docassemble coloca em YAML com Python embutido (é um programa). JSON Schema mora fora do modelo, e nada garante que os dois falem do mesmo conjunto de campos. CUE e Dhall não produzem prosa.

E a garantia estática — a seção 3 da especificação da linguagem, o *teorema da lacuna* — não foi encontrada em nenhum dos sistemas examinados. É o único item deste levantamento em que não achei precedente.

---

## 1. Liquid (Shopify)

**O que é.** Linguagem de template com modelo de segurança explícito: templates vêm de lojistas, portanto são dado hostil. Sem `eval`, sem I/O, sem acesso a objetos não expostos pelo *drop*.

**O que se extrai.**

1. **O modelo de segurança é o certo e Kanon deve copiá-lo quase inteiro** (seção 8). Liquid provou em escala industrial que um motor de template pode ser executado sobre entrada não confiável se — e só se — a linguagem for deliberadamente incapaz.
2. **O método de validação por suíte declarativa.** `golden_liquid.json` é um arquivo de casos (template, contexto, saída esperada, flag de erro) consumido por implementações em várias linguagens. Shopify mantém também `liquid-spec`. É o formato exato que os *golden tests* de Kanon devem ter (seção 13), e pela mesma razão: se um dia houver uma segunda implementação, a suíte é a especificação executável.

**Por que Liquid é leniente, antes de descartar a leniência.** Não é desleixo. É consequência do modelo de negócio: o template é escrito pelo lojista, os dados vêm da loja, e o render acontece no caminho crítico de uma requisição HTTP de um comprador. Falhar alto ali significa uma página de erro 500 para o cliente final por causa de um campo cosmético. A leniência é a escolha correta **quando o custo do documento defeituoso é menor que o custo da indisponibilidade**.

Kanon vive no regime oposto: não há usuário final esperando, o documento é conferido por um humano depois, e um documento com lacuna custa mais que um documento não gerado. **A leniência não é um erro do Liquid; é um erro para o nosso regime.** Isso precisa estar dito na documentação, ou a rejeição soa dogmática.

## 2. Jinja2 — e o mistério do `StrictUndefined`

**O que é.** Motor Python com herança de templates (`extends`/`block`), sistema de extensões e um objeto `Undefined` configurável. `StrictUndefined` faz qualquer acesso a variável indefinida levantar exceção — o parente mais próximo do princípio 1.

**Por que quase ninguém liga `StrictUndefined`.** A resposta importa mais que o fato, porque é a mesma armadilha que espera Kanon:

Em Jinja **o contrato é implícito**. Não há como saber o que um template exige sem renderizá-lo, e não há como saber se ele exige um campo em um ramo que só é atingido em janeiro. Portanto `StrictUndefined` não converte "documento defeituoso" em "erro na hora de escrever o modelo" — converte em **erro em produção, no ramo raro, com dado real**. O usuário troca uma falha silenciosa e frequente por uma falha ruidosa e imprevisível. Nessa troca, muita gente racionalmente prefere a silenciosa.

**A conclusão de projeto, e é a mais importante deste levantamento:** falhar alto só é uma boa ideia se vier acompanhado de **contrato declarado**. Rigor sem contrato é rigor de execução; rigor com contrato é rigor de autoria. Kanon deve vender o segundo, e a documentação nunca deve apresentar o princípio 1 sozinho — sempre "contrato + falha alta", nessa ordem.

**O que copiar.** O sistema de extensões (`Environment` como objeto que agrega extensões, sem estado global) é bom e a seção 9 já converge para ele.
**O que não copiar.** Herança de templates — ver a decisão D-005 em `decisoes.md`.

## 3. Handlebars / Mustache

**O que é.** "Logic-less": só interpolação, seção (`{{#x}}`) e inversão (`{{^x}}`). Variável ausente rende string vazia, por especificação.

**O limite prático do logic-less.** A disciplina é boa e o resultado é ruim, por um motivo específico: `{{#x}}` faz *dois* trabalhos ao mesmo tempo — condicional e iteração — e o significado depende do tipo do valor em tempo de execução. O autor lê `{{#seller}}` e não sabe se aquilo é um `if` ou um `for` sem saber o dado. É logic-less na forma e ambíguo na semântica.

Kanon evita isso separando os dois: `one for each` (iteração) e `when` (condição) são construções distintas, moram no plano das regras, e o plano do texto nunca decide nada.

**Mustache.jl** (jverzani) porta o mustache.js e herda a leniência da especificação: chave ausente sobe pelos contextos-pai e, não encontrada, rende nada. É o comportamento de referência que Kanon existe para recusar — e é a API que o usuário de Julia hoje espera (`render(template, dict)`), o que importa para a ergonomia da nossa API de alto nível.

## 4. LaTeX

**O que é.** O ancestral direto de `::` e `{::nome}`: `\label`/`\ref`, contadores automáticos, `\newtheorem`, remissão que se renumera sozinha.

**Por que sobrevive há quarenta anos.** Porque resolveu, com um mecanismo pequeno e composto (contador + rótulo + arquivo auxiliar), um problema que ninguém quer resolver à mão duas vezes. Um documento longo com numeração manual é insustentável, e essa é uma verdade de qualquer domínio — contrato, artigo, laudo, orçamento.

**O que extrair.** A *forma* do mecanismo, não a implementação: um contador nomeado por estilo, um rótulo que aponta para o contador, e a remissão resolvida em um passo separado do render. E, principalmente: a numeração **não mora no nó da árvore**, mora numa tabela lateral — o que em LaTeX é o `.aux` e em Kanon será o resultado do passo de análise (ver `ast.md`).

**O que não extrair.** A extensibilidade por macro-expansão. LaTeX é extensível porque é um interpretador de macros com estado global mutável, e é exatamente por isso que suas mensagens de erro são o que são. Kanon paga o preço oposto de propósito.

## 5. Typst

**O que é.** O vizinho mais próximo em ambição: linguagem moderna de documento, funções com parâmetros nomeados e tipos, rótulos `<nome>` e referências `@nome`, sistema de estilos por *set/show rules*.

**Onde a diferença precisa estar delimitada, porque é fina.** Typst tem tipos, tem rótulos, tem numeração automática, e tem uma linguagem de script decente. Três diferenças reais:

1. **Typst tipa funções, não documentos.** Uma função Typst declara os tipos dos seus parâmetros; um *documento* Typst não declara o conjunto de dados de que depende. Não existe em Typst o equivalente de `kanon contract modelo.kanon` — não há artefato que diga "este documento exige `price`, `seller` e `date`". Um `#import` de JSON com uma chave faltando dá erro no ponto de uso, em tempo de compilação do documento, e não antes.
2. **Typst é Turing-completa e o texto contém lógica.** `#if`, `#for` e chamadas de função aparecem no meio da prosa. O redator não-técnico da seção 3 não lê um `.typ` de produção. Essa é a linha divisória do critério 1.
3. **Typst produz layout; Kanon produz texto.** Typst é um sistema de composição tipográfica (PDF é a saída primeira). Kanon produz um fluxo de texto e delega a composição (F8, pandoc). São camadas diferentes da pilha, e isso é uma oportunidade e não uma rivalidade: **um backend Typst para a F8 é a melhor ideia que este levantamento produziu** — Kanon garante o conteúdo, Typst compõe a página, e não precisamos escrever um gerador de `.docx` nem controlar margens à mão.

**Posição:** Typst não é concorrente do núcleo; é candidato a backend de saída. A concorrência com Typst só existiria se ele ganhasse um plano de contrato — e nada indica que esse seja o rumo dele.

## 6. XSLT — a lição negativa

**O que é.** Transformação declarativa de XML em XML/texto por regras de template casadas contra uma árvore.

**O modo de falha, com precisão.** O diagnóstico popular ("separou apresentação de lógica e ficou ilegível") é impreciso e, se aceito como está, leva a conclusões erradas. O que de fato quebrou o XSLT foi outra coisa: **o controle de fluxo é implícito.** Qual `xsl:template` roda para um nó é decidido por casamento de padrão e por regras de prioridade que não estão escritas em lugar nenhum do arquivo. Não existe leitura linear de um stylesheet que preveja a saída. Some-se a isso que XSLT 1.0 é praticamente uma linguagem funcional escrita em XML, com variáveis imutáveis e recursão como único laço, e o resultado é um sistema onde toda pergunta sobre o comportamento exige simular a execução mentalmente.

**A consequência direta para o plano das regras de Kanon — e este é um invariante que precisa estar na especificação:**

> **Regras só removem ou repetem blocos. Nunca inserem, nunca substituem, nunca reordenam.**

Com esse invariante, a ordem dos blocos na saída é *exatamente* a ordem do plano do texto, e a leitura linear do plano do texto é um limite superior confiável do documento gerado. É o que separa o plano das regras de Kanon de um stylesheet XSLT, e é o que torna o risco 16.2 gerenciável por ferramenta (F9) em vez de fatal por linguagem.

## 7. JSON Schema, Pydantic, Tables.jl — o vocabulário que já existe

**Não inventar tipos do zero.** Três convenções a respeitar:

- **JSON Schema** dá o vocabulário de contrato que o mundo já lê: `required`, `type`, `default`, `minItems`/`maxItems`, `enum`. O `kanon contract` (seção 11) deve emitir **JSON Schema válido (draft 2020-12)** com um bloco de extensão `x-kanon` para o que não cabe (formatadores, cardinalidade exata, atributos). Custo próximo de zero, benefício alto: qualquer formulário, validador ou gerador de UI do mercado consome o checklist sem adaptador. Ver D-009.
- **Pydantic** dá o modelo mental de "declarar campo tipado e receber validação e mensagem de erro de graça" — e dá também um aviso: o `ValidationError` do Pydantic acumula todos os erros em uma lista com caminho (`loc`), tipo (`type`) e mensagem. É o formato de diagnóstico que a seção 7 pede, já testado em campo. Copiar a *estrutura* (caminho + código estável + mensagem), não a redação.
- **Tables.jl** dá a interface que qualquer fonte de dados tabular em Julia já implementa. A F7 não deve escrever adaptadores para XLSX, CSV, Parquet e bancos: deve aceitar qualquer objeto `Tables.istable` e mapear linha → registro. É integração de uma tarde, não uma fase.

Acrescento uma quarta, que não estava na lista e deveria: **StructTypes.jl**, a convenção que JSON3.jl usa para saber como desserializar um tipo Julia. Se os tipos compostos de Kanon declararem `StructTypes.StructType`, a decodificação de JSON para `person` sai de graça e pelo caminho que o ecossistema já conhece.

## 8. Quarto e R Markdown — onde está o flanco

**O que são.** Documento com blocos de código executável; o número no texto vem de `r mean(x)` ou de um chunk Python/R/Julia avaliado no render.

**O flanco de ataque, dito com precisão.** Não é que Quarto seja ruim — é excelente no que faz. É que o modelo dele tem duas propriedades que o desqualificam para documento de fé pública:

1. **Renderizar executa código arbitrário.** Um `.qmd` é um programa. Isso é inaceitável no modelo de segurança da seção 8, e é o motivo pelo qual ninguém aceita um `.qmd` de terceiro por e-mail e roda.
2. **O valor atravessa a fronteira como texto.** `r round(m, 2)` produz uma string. A incerteza, a unidade e os algarismos significativos que existiam no objeto R morrem na fronteira, e a coerência entre "0,42" e "± 0,07" passa a ser responsabilidade do autor a cada ocorrência. É precisamente o problema que o tipo `measure` de Kanon resolve por construção (seção 10.2), e é o argumento honesto do 5-A sobre tipos ricos.

**Mas o flanco tem dois gumes.** O que Quarto entrega e Kanon não entregará é *reprodutibilidade computacional*: o número no documento é derivado dos dados brutos pelo próprio documento. Em Kanon o número é derivado por um script Julia à parte e **injetado**. Para o público científico isso é uma perda real, e a resposta honesta é: o script Julia é o notebook, o `.kanon` é o relatório, e a fronteira entre os dois é o contrato — que é auditável, coisa que a fronteira do Quarto não é. Essa resposta precisa estar na documentação antes que alguém a levante como objeção.

## 9. O que já existe em Julia

- **Mustache.jl** — logic-less, leniente, API `render(tmpl, data)`. É a expectativa instalada de API.
- **OteraEngine.jl** — sintaxe Jinja, sem dependências, e um recurso chamado *Julia Code Block*: `{< number^2 >}` executa Julia dentro do template. É exatamente o oposto do nosso modelo de segurança. Convivemos: público diferente (páginas web dinâmicas, Genie/Oxygen), garantias opostas.
- **Não existe em Julia** motor de template com contrato de dados declarado. O nicho está vazio.

**Nota prática de registro (verificada, não estimada).** As diretrizes de AutoMerge do General exigem distância de Damerau-Levenshtein ≥ 3 (sensível a caixa) contra todo pacote existente. Medi contra a `Registry.toml` atual:

- `Kanon` → distância **2** de `Kaimon` e **2** de `Kanones`;
- `Extenso` → distância **2** de `Extents`.

Ambos **reprovam** na checagem automática e exigirão o rótulo manual `Override AutoMerge: name similarity is okay` e revisão humana. `KanonLegal` (distância 4) passa. Não é impeditivo, mas é surpresa na F10 se ninguém souber antes. Alternativas com folga, se o custo da revisão manual incomodar: `Kanonis`, `PorExtenso`.

## 10. Sistemas que não estavam na lista e mudam o quadro

### 10.1 HotDocs, Contract Express, docassemble — os incumbentes do domínio de destino

Este é o levantamento que faltava na seção 2, e é o mais relevante para o caso de uso inicial: **montagem de documentos jurídicos já é uma indústria com trinta anos**.

- **HotDocs** (1993, hoje Mitratech): variáveis tipadas em sete tipos (Text, Date, Number, True/False, Multiple Choice, Computation, Personal Information); a variável tipada recusa entrada incompatível; templates inserem templates. O contrato existe — mora num *component file* separado, editado em ferramenta gráfica.
- **Contract Express** (Thomson Reuters): mesma ideia no mercado corporativo.
- **docassemble** (open source, Python): campos tipados, **obrigatórios por padrão** (`required: False` é o que se escreve para relaxar). E um mecanismo notável: quando o documento referencia uma variável indefinida, docassemble **não rende vazio nem quebra — ele procura a pergunta que define aquela variável e a faz ao usuário**. É "falhar alto" convertido em "perguntar".

**O que isso obriga a admitir.** O princípio 1 de Kanon não é novo no domínio jurídico; é o padrão do domínio há décadas. O que é novo é o pacote: contrato *no mesmo arquivo de texto*, formato aberto e diferenciável em git, sem entrevista obrigatória, sem execução de código, e neutro de domínio.

**O que isso ensina, e vale ouro para a F9.** A ideia do docassemble de transformar ausência em pergunta é melhor que a nossa "pré-visualização com marcadores «CPF»" da seção 14-A. Vale registrar como candidata: `kanon ask modelo.kanon dados.json` percorre os campos faltantes e os pede um a um, produzindo o JSON completo. É a mesma necessidade que o "modo leniente" tentava atender, atendida sem relaxar nada.

### 10.2 Askama, Tera, Go `html/template`, Hamlet — templates tipados em compilação

**Askama** (Rust) é o contraexemplo mais duro: templates Jinja-like ligados a uma `struct`, checados em tempo de compilação; campo inexistente é erro de compilação, tipo errado é erro de compilação. É o princípio 1 de Kanon, com prova estática mais forte que a nossa.

Três diferenças que preservam o espaço de Kanon:

1. **O contrato mora em código Rust.** O redator não o vê nem o edita, e não existe artefato legível por não-programador que descreva o que o documento exige.
2. **É para HTML, e o público é o programador.** Não há flexão, não há numeração de cláusula, não há remissão cruzada.
3. **O acoplamento é de compilação.** Trocar o modelo exige recompilar a aplicação. Um cartório com duzentas minutas não recompila nada; edita um arquivo.

**Go `html/template`** merece nota de rodapé pela opção `missingkey=error`: um motor leniente por padrão com uma flag de rigor. É a prova empírica da previsão feita na seção 4 — a flag existe, quase ninguém a liga, e o padrão continua sendo o leniente.

### 10.3 ICU MessageFormat 2.0 e Project Fluent — a flexão já tem um padrão

**A seção 6.4 está reinventando, em pequeno, algo que tem norma Unicode.** MessageFormat 2.0 estabilizou como parte do CLDR em 2025 e cobre exatamente o problema dos pontos de flexão: seleção por gênero, plural (com as categorias de plural do CLDR por idioma), ordinal, número e data numa única string traduzível. Fluent (Mozilla) resolve o mesmo com seletores e termos.

**Por que ainda assim não adotamos MF2 como sintaxe:** MF2 exige que o *autor da mensagem* escreva as variantes explicitamente (`.match $gender` com um ramo por caso). Isso coloca lógica dentro da prosa — reprovado pelo princípio 2 — e transforma "portador(a)" em cinco linhas. A escolha de Kanon (marca colada à palavra, camada de idioma resolve) é mais legível e menos poderosa. É uma escolha deliberadamente pior em expressividade.

**O que adotar mesmo assim:** as **categorias de plural do CLDR** como vocabulário interno da camada de idioma, em vez de inventar um esquema próprio de gênero/número. E o vocabulário de "função de formatação" do MF2 (`:number`, `:date`, com opções nomeadas) como referência ao decidir, na v1.1, se formatadores ganham argumentos.

### 10.4 CUE e Dhall — contrato e dado no mesmo arquivo

Os dois já fazem o que a tese dizia que ninguém faz: declarar restrições junto do dado, com verificação estática, sem Turing-completude (Dhall é total por construção). Não produzem prosa e não têm ambição de documento — mas destroem a versão ampla da tese e confirmam a versão estreita. Da CUE vale copiar uma ideia: **detectar conflito entre contratos na composição**, que é exatamente o que precisamos quando um bloco incluído traz o seu próprio plano de dados (D-005).

### 10.5 Pandoc templates

Vale uma linha porque é o que a F8 vai usar: os templates do pandoc têm `$if(x)$`/`$for(x)$` e são lenientes. Usaremos o pandoc como conversor de formato, **nunca como motor de template** — o `.md` que sai de Kanon já está completo.

---

## 11. Posição

### Onde Kanon inova

1. **Garantia estática de ausência (o "teorema da lacuna").** Toda interpolação de campo opcional é obrigada, pela validação do modelo, a estar dentro de um grupo `[...]`; todo grupo com interpolação direta nula é elidido. Logo, modelo válido + dados válidos ⇒ nenhum valor ausente atinge a saída, e isso é provado sem os dados. Não encontrei precedente. Askama prova que o campo existe; Kanon prova que a *lacuna* não aparece.
2. **O contrato no arquivo que o redator edita**, em vez de em código, em ferramenta gráfica ou em schema separado.
3. **Elisão com reparo de emenda como algoritmo especificado e testado.** Em todo motor examinado isso é responsabilidade manual do autor (`{% if %}` com a vírgula do lado certo). Em Kanon é da linguagem, com casos de teste normativos.
4. **Numeração e remissão como primitiva do núcleo combinada a contrato de dados.** LaTeX e Typst têm numeração sem contrato; HotDocs tem contrato sem numeração (herda a do Word).
5. **Extensão por despacho múltiplo sem registro global**, com o domínio jurídico obrigado a usar só a API pública — vizinhança nova porque nenhuma das linguagens acima está numa linguagem com despacho múltiplo.

### Onde Kanon copia, e de quem

| Ideia | Origem |
|---|---|
| Modelo de segurança (dado hostil, incapacidade deliberada) | Liquid |
| Suíte golden declarativa como especificação executável | golden-liquid / liquid-spec |
| Falha em valor indefinido | Jinja `StrictUndefined`, Go `missingkey=error` |
| Contrato tipado de documento | HotDocs, docassemble, Askama |
| Vocabulário do checklist | JSON Schema 2020-12 |
| Estrutura do diagnóstico acumulado (caminho + código + mensagem) | Pydantic |
| Rótulo, contador, remissão, tabela lateral de numeração | LaTeX |
| Categorias de plural e o problema da flexão | CLDR / ICU MessageFormat 2.0 |
| Lógica fora da prosa | Mustache, XSLT (pelo avesso) |
| Interface de ingestão | Tables.jl, StructTypes.jl |
| Ausência vira pergunta, não vira vazio | docassemble |

### Onde Kanon escolhe pior, de propósito

1. **Expressividade.** Sem laços gerais, sem condicionais na prosa, sem aritmética, sem funções. Jinja e Typst fazem coisas que Kanon nunca fará. Ganha-se análise estática, segurança e legibilidade por não-programador.
2. **Reprodutibilidade computacional.** Quarto deriva o número dos dados no próprio documento; Kanon exige um passo externo. Ganha-se um documento que é dado, não programa.
3. **Prototipagem.** Sem modo leniente, escrever um modelo novo é mais chato que em qualquer motor leniente. Mitigação: `kanon preview` e, se aceito, `kanon ask`.
4. **Desempenho.** A v1 interpreta; Askama gera código nativo. Aceitável — não é motor de página web.
5. **Ecossistema.** Julia é pequena. A especificação é portável, a implementação não. É a razão pela qual estes documentos precisam ser legíveis sem o código.
6. **Flexão menos poderosa que MF2.** Marcas coladas à palavra cobrem menos casos que seletores explícitos. Ganha-se prosa legível.

### O que este levantamento mudou na especificação

- A tese da seção 1 foi reescrita para a forma estreita (acima).
- O invariante anti-XSLT ("regras só removem ou repetem") entrou como norma da linguagem.
- O `kanon contract` passa a emitir JSON Schema 2020-12 + `x-kanon` (D-009).
- Typst entra como candidato a backend da F8, ao lado do pandoc.
- CLDR entra como vocabulário interno da camada de idioma.
- `kanon ask` entra como candidato à F9, substituindo com vantagem a pré-visualização com marcadores.
- Os nomes `Kanon` e `Extenso` reprovam na checagem automática do General e precisarão de revisão manual.

---

## Fontes

- [golden-liquid (jg-rp)](https://github.com/jg-rp/golden-liquid) · [Shopify/liquid-spec](https://github.com/Shopify/liquid-spec)
- [Askama — type-safe compiled templates for Rust](https://github.com/askama-rs/askama) · [askama.rs — creating templates](https://askama.rs/en/stable/creating_templates.html)
- [HotDocs — Variables Overview](https://help.hotdocs.com/author/current/Variables_Overview.htm) · [HotDocs (Wikipedia)](https://en.wikipedia.org/wiki/HotDocs)
- [docassemble](https://docassemble.org/) · [Document Assembly Line — editing your interview](https://assemblyline.suffolklitlab.org/docs/authoring/customizing_interview/)
- [Typst — Reference (ref/label)](https://typst.app/docs/reference/model/ref/) · [Typst (Wikipedia)](https://en.wikipedia.org/wiki/Typst)
- [ICU MessageFormat 2.0](https://unicode-org.github.io/icu/userguide/format_parse/messages/mf2.html) · [message-format-wg](https://github.com/unicode-org/message-format-wg)
- [CUE — Introduction](https://cuelang.org/docs/introduction/) · [Taming the beast: Jsonnet, Dhall, CUE](https://lobste.rs/s/y6abdu/taming_beast_comparing_jsonnet_dhall_cue)
- [Mustache.jl](https://github.com/jverzani/Mustache.jl) · [mustache(5)](https://mustache.github.io/mustache.5.html)
- [OteraEngine.jl](https://github.com/MommaWatasu/OteraEngine.jl) · [docs](https://mommawatasu.github.io/OteraEngine.jl/stable/)
- [RegistryCI — AutoMerge guidelines](https://juliaregistries.github.io/RegistryCI.jl/stable/guidelines/)
