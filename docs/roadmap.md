# Roadmap

> Estado em 4 de setembro de 2026. Escrito para retomar sem depender de memória.

## Onde estamos

| Fase | Estado | O que existe |
|---|---|---|
| **F0** Especificação | ✅ aceita | 6 documentos em `docs/`, 18 decisões registradas |
| **F1** Núcleo mínimo | ✅ concluída | léxico, gramática dos três planos, árvore, 34 códigos de diagnóstico |
| **F2** Validador | 🔨 em curso | **F2.1 concluída**: protocolo de tipo, seis tipos do núcleo, ambiente congelado |
| F3 Renderizador | ⬜ | — |
| F4 `Extenso.jl` | ⬜ | — |
| F5 Numeração e regras | ⬜ | — |
| F6 Domínios | ⬜ | — |
| F7 Ingestão e reuso | ⬜ | — |
| F8 Saída | ⬜ | — |
| F9 Editor | ⬜ | — |
| F10 Publicação | ⬜ | — |

**F1 a F6 já constituem um produto.** F7 a F9 são projetos por si só.

Suíte: **335 testes**, ~7 s.

## Como retomar

```bash
julia --project=. -e 'using Pkg; Pkg.test()'     # 199 testes, ~6 s
julia --project=. -e 'using Kanon; parse_file("modelo.kanon")'
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

Leituras obrigatórias antes de escrever a F2: `docs/especificacao.md` §3 (sistema de
tipos) e §14 (teorema da lacuna), `docs/api-extensao.md` inteiro, `docs/ast.md` §7–8.

---

## F2 — Validador (a próxima)

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

**F2.2 — `analyze`: caminhos e tipos.** ⬅ **a próxima**
Tabela `paths` e tabela `formatter` da `Analysis`. Resolução em duas etapas dentro de um
bloco com sujeito: campos do sujeito, depois campos de primeiro nível; **resolver nos
dois é erro de ambiguidade**, nunca precedência silenciosa. Formatador inexistente é
erro aqui, com a lista dos disponíveis.
*Nada disso pode ir para dentro do nó* — invariante I2, D-011.

**F2.3 — A tabela `guarded` e o teorema da lacuna.**
Interpolação de caminho nulável fora de qualquer grupo é **erro**. Grupo sem
interpolação direta é erro ("nunca elide"). Parênteses e aspas desbalanceados dentro de
um grupo são erro. Nulabilidade atravessa tipo composto: se `person.spouse` é opcional,
`{seller.spouse.name}` é nulável.
*É o incremento mais importante da fase.* Sem ele o teorema vale só no primeiro nível,
o que é o mesmo que não valer.

**F2.4 — Referências.**
`{::x}` aponta para bloco existente; regra nomeia bloco existente; remissão a bloco
repetido por `one for each` é erro; remissão a bloco que uma regra pode remover é aviso.

**F2.5 — Semântica das regras.**
Sem veracidade implícita: `when notes` é erro, escreve-se `when notes is present`.
Dois `when` para o mesmo bloco é erro (D-002). `one for each C` exige que `C` seja lista
e que o cabeçalho declare `<- C`. Comparação entre valor tipado e literal só se o tipo
declarar `kanon_compare`. Atributos `present` e `absent` no núcleo; os demais das camadas.

**F2.6 — `check(tmpl, dados)`.**
Obrigatório ausente, tipo incompatível, cardinalidade violada, decodificação da entrada
externa. **Texto em branco**: erro em campo obrigatório, normalizado para nulo em campo
opcional com aviso listado (D-008). `nothing`, `missing`, `null` e chave ausente são o
mesmo nulo.

**F2.7 — `contract(tmpl)`.**
JSON Schema draft 2020-12 + `x-kanon`, saída determinística e comparável em `diff`
(D-009).

**Critério de aceite da F2:** o modelo científico de `docs/exemplos.md` §2.1 valida sem
dados e `check` recusa, com mensagens nomeando campo e linha, um JSON a que falte
`effect`.

---

## F3 — Renderizador

Interpolação, blocos com sujeito, algoritmo dos colchetes, tipos base. Saída em texto
puro, **ainda sem nada de português**.

**Escreva os treze casos normativos de `especificacao.md` §5.3 como arquivos golden
ANTES de escrever o renderizador.** Risco 16.4: é onde os bugs vão morar. Comece pelos
casos 11 e 12, que fixam a regra de aninhamento.

Ordem sugerida: golden falhando → literais e interpolação → elisão com registro de
emendas → reparo R1–R5 → sujeito e escopo → orçamento determinístico (D-010) e testes
adversariais da §11 → teste de propriedade do teorema da lacuna.

Lembretes que a F3 não pode esquecer: `render` é puro, sem I/O, sem relógio, sem
aleatoriedade; `today` é injetado; `render` não emite diagnóstico (se `analyze` e
`check` passaram, só pode falhar por orçamento).

**Uma CLI fina cabe aqui** (`kanon check`, `kanon render`, `kanon contract`), porque as
três funções já existirão. Códigos de saída em `especificacao.md` §12.

---

## F4 — `Extenso.jl`

Flexão por marca, valores e ordinais por extenso, datas por extenso, junção de listas,
separadores decimal e de milhar, apelidos de palavra-chave, gancho de recapitalização
depois de elisão.

Parte com mais exceções e menos previsível. Publicável sozinho.

Invariante que não pode cair: **só a palavra que carrega a marca muda** (D-013). O
núcleo entrega `(palavra, marca, sujeito)`; a camada devolve a palavra inteira.

---

## F5 — Numeração e regras em execução

Contadores por estilo, nível pela repetição da unidade do marcador, zeramento dos níveis
inferiores, tabela `numbering` na `Analysis` — **nunca dentro do nó**. `layout`
(`:prefix` / `:heading`) e separador decidem onde o rótulo entra no texto. Blocos
removidos por regra não consomem número; blocos repetidos consomem um por iteração.

Invariante anti-XSLT (D-015): regras só removem ou repetem. Nunca inserem, substituem ou
reordenam.

---

## F6 — Domínios

`KanonLegal.jl` e um domínio científico mínimo, **ambos escritos só com a API pública**.
Os dois exemplos de `docs/exemplos.md` funcionando byte a byte.

Dois testes que provam a arquitetura:
- `@macroexpand` de `@kanon_type` não contém nenhum nome não exportado por `Kanon`.
- O tipo `party` (D-006) modelado como composto com atributo `is company`, sem tocar o
  núcleo. Se não der, a separação núcleo/domínio é mais fraca do que se supõe.

**Teste de neutralidade**, a espinha dorsal: roda o núcleo sem nenhuma camada e falha se
algo de português ou de direito tiver vazado. Mecanismos concretos: proibir literal de
string não-ASCII no fonte do núcleo; rodar o corpus golden com `Environment()` puro e
exigir erro nomeado; conferir que `Project.toml` do núcleo não depende de `Extenso` nem
de `KanonLegal`.

---

## F7 a F10

- **F7** — ingestão via `Tables.jl` (não escrever adaptador por formato) e
  `StructTypes.jl` para decodificar JSON. Inclusão de blocos com carregador de raiz
  configurada, sem travessia de caminho e com detecção de ciclo; contratos dos
  fragmentos **unificados** com o do hospedeiro (D-005).
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
| O exemplo jurídico de `docs/exemplos.md` ainda não analisa | precisa da camada `pt` | F4 |
| CLI não existe | — | depois da F3 |
| Corpus golden ainda não é artefato versionado | `test/golden/` | F3 |
| Sem CI, sem Aqua, sem Documenter | — | F10 |
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
