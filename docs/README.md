# F0 — Especificação

Entregáveis da fase 0, na ordem de leitura recomendada.

| Documento | Conteúdo |
|---|---|
| [`estado-da-arte.md`](estado-da-arte.md) | Levantamento crítico do que já existe, com contraexemplos à tese inicial e posição explícita sobre onde Kanon inova, copia e escolhe pior |
| [`especificacao.md`](especificacao.md) | A linguagem: léxico, EBNF dos três planos, sistema de tipos, elisão e reparo de emenda, numeração, flexão, erros, segurança, CLI, política de versão, teorema da lacuna |
| [`ast.md`](ast.md) | Tipos da AST, tabelas laterais de análise, e as quatro invariantes que mantêm aberta a porta para compilar o modelo na v2 |
| [`api-extensao.md`](api-extensao.md) | API de extensão fechada para a v1: protocolo de tipo, camadas de idioma e domínio, ambiente, API de alto nível, formato do checklist |
| [`exemplos.md`](exemplos.md) | Os dois exemplos da seção 10 escritos na sintaxe proposta, com saída exigida byte a byte, e as três lacunas que escrevê-los revelou |
| [`roadmap.md`](roadmap.md) | Onde o projeto está, como retomar, os incrementos da F2 e as invariantes que nenhuma fase pode quebrar |
| [`decisoes.md`](decisoes.md) | Quinze decisões registradas: as oito questões em aberto respondidas, mais sete decisões estruturais |

## Onde esta F0 diverge da especificação inicial

Cada divergência está marcada com **[revisão]** no texto e justificada. Em resumo:

1. **A tese foi estreitada.** "Nenhuma linguagem declara o que o modelo exige" é falso —
   Askama, HotDocs, docassemble, CUE e Dhall declaram. A tese defensável é mais estreita
   e mais forte. Ver `estado-da-arte.md`, seção 0.
2. **A definição de tipo da seção 6.3 não basta** para `money`, `measure` e `person`.
   Faltam esquema de campos, nulabilidade por campo, atributos, decodificador de entrada
   externa e comparação. Ver `especificacao.md`, seção 3.1.
3. **Comentário no plano do texto passa a ser `:#`**, porque `#` colide com títulos
   Markdown na F8. D-012.
4. **Texto em branco não é valor**: é erro em campo obrigatório e nulo em campo
   opcional. Sem isso o teorema da lacuna é falso. D-008.
5. **Limite de recurso é orçamento contado, não tempo de parede**, sob pena de o render
   deixar de ser determinístico. D-010.
6. **A flexão só altera a palavra que carrega a marca** — o motor nunca reescreve prosa
   que o autor não marcou. D-013.
7. **O reparo de emenda é local à remoção**, nunca uma normalização global do parágrafo.
   D-014.
8. **Códigos estáveis de diagnóstico** (`K3001`), para que a suíte afirme sobre o código
   e a redação das mensagens possa melhorar sem quebrar testes.
9. **O idioma do arquivo é declarado no pragma** (`kanon 1 pt`), não inferido.

## Duas adições que não estavam previstas

- **Invariante anti-XSLT** (D-015): regras só removem ou repetem blocos; nunca inserem,
  substituem ou reordenam. É a resposta estrutural ao risco 16.2.
- **Teorema da lacuna** (`especificacao.md`, seção 14): modelo válido + dados válidos ⇒
  nenhum valor ausente atinge a saída, provado sem os dados. Não encontrei precedente no
  levantamento; é o que Kanon tem de próprio.

## O que a F1 recebe pronto

- Gramática EBNF dos três planos, suficiente para escrever lexer e parser.
- Tipos da AST, com as invariantes que o parser precisa respeitar.
- Treze casos normativos de elisão e reparo de emenda, para escrever **antes** do código.
- Dois modelos completos com saída exigida, que viram os primeiros golden tests.
- Política de compatibilidade com uma definição operacional testável.

## Estado

As oito questões e as sete decisões estruturais foram **aceitas** em 3 de setembro de
2026. A F1 está implementada: `src/` tem léxico, parser dos três planos, árvore e erros
de sintaxe com linha e coluna; `test/` tem 195 testes.

A F1 revisou duas decisões e acrescentou duas, todas registradas em `decisoes.md`:

- **D-004 revista** — colchete literal passa a ser `\[` e `\]`, não `[[` e `]]`. Grupos
  aninham, então `]]` é produzido pela própria linguagem e nenhuma regra o distinguiria
  de um colchete literal. Chaves e parênteses não têm o problema e continuam duplicando.
- **D-016 (nova)** — um grupo opcional não atravessa fronteira de parágrafo.
- **D-017 (nova)** — problema na linha de versão é fatal, única exceção à acumulação.

Uma pergunta ficou em aberto pela revisão de D-004: unificar tudo na contrabarra
(`\{ \} \[ \] \( \) \\`, uma regra) ou manter as duas convenções (duplicação para
chaves e parênteses, contrabarra para colchetes)?
