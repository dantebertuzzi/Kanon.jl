# Estatística sem mistério — um blog em Franklin com o Kanon como contrato

Um site estático do jeito de um blog em Jekyll: cada post é um arquivo Markdown com um
cabeçalho. A diferença está no que acontece quando o cabeçalho tem um erro. O Liquid
publica a página sem o que faltou, e ninguém fica sabendo; aqui o site **não é
construído**, e quem escreveu lê o que corrigir.

É também uma **prova de fogo do Kanon**: o motor posto no meio de um gerador de site,
com alguém que não programa editando. O que ela achou está no fim deste arquivo.

## Para quem escreve

Tudo o que se edita está em `conteudo/`. Nada fora dessa pasta precisa ser tocado para
escrever um post.

### Um post novo

Crie um arquivo em `conteudo/posts/` com o nome `AAAA-MM-DD-titulo-curto.md` — a data de
publicação, e um nome só com letras minúsculas sem acento, números e hífen:

```
conteudo/posts/2026-09-20-variancia.md
```

O arquivo começa pelo **cabeçalho**, entre duas linhas `+++`, e depois vem o texto:

```
+++
titulo = "Variância: o desvio padrão ao quadrado"
descricao = "Por que existe uma medida que ninguém consegue interpretar."
autor = "dante-bertuzzi"
data = 2026-09-20
tags = ["Estatística", "Dispersão"]
+++

O texto do post começa aqui, em Markdown.
```

| Campo | Obrigatório | Como se escreve |
|---|---|---|
| `titulo` | sim | texto entre aspas |
| `autor` | sim | a chave do autor em `conteudo/autores.toml`, entre aspas |
| `data` | sim | `AAAA-MM-DD`, **sem** aspas — a mesma do nome do arquivo |
| `descricao` | não | texto entre aspas |
| `atualizado` | não | `AAAA-MM-DD`, sem aspas |
| `serie` | não | texto entre aspas |
| `tags` | não | lista entre colchetes: `["Estatística", "Dispersão"]`, com pelo menos uma |
| `idioma` | não | `"en"` para um post em inglês; sem a linha, é português |
| `ref` | não | o mesmo texto no post em português e na tradução dele, para os dois se ligarem |
| `rascunho` | não | `true` para não publicar ainda |

Os nomes dos campos são **sem acento**: `descricao`, não `descrição`.

### O texto

É Markdown, com uma diferença que pega todo mundo: **`$` abre matemática**. Para
fórmula, `$\sigma = \sqrt{6}$` na linha e `$$ ... $$` em bloco. Para dinheiro, escreva
com contrabarra: `R\$ 3.000`. A construção avisa se encontrar `R$` seguido de número.

### Ver o site enquanto escreve

```
julia --project construir.jl servir
```

Abre o site no navegador, e a cada arquivo salvo em `conteudo/` o site é reconstruído e a
página recarrega sozinha. Se o que foi salvo tem um erro, ele aparece no terminal, e o
navegador continua mostrando a última versão que construiu. Os posts com `rascunho = true` aparecem, e o que ainda falta no
cabeçalho aparece marcado — `Por «autor», em «data»`. Eles **não** entram na página
inicial, e **não** são publicados.

### Quando a construção recusa

A mensagem diz o arquivo e o que fazer. Exemplos reais:

```
conteudo/posts/2026-05-21-mediana.md
  ✗ `autor` é do tipo `autor`, e o valor recebido não serve — não há autor
    `dante-bertuzi` em `conteudo/autores.toml`. Os autores são: `dante-bertuzzi`.

conteudo/posts/2026-05-21-mediana.md
  ✗ a linha 7 do arquivo não pôde ser lida (um valor sem aspas que não é número,
    data nem lista).
    Texto vai entre aspas (`titulo = "Média"`); data e número, sem aspas …
```

## Para quem mantém o site

```
julia --project -e 'using Pkg; Pkg.instantiate()'   # uma vez, e o ambiente é o do Manifest
julia --project construir.jl                        # publica em __site/
julia --project construir.jl servir                 # pré-visualiza, com rascunhos
julia --project teste.jl                            # a prova de fogo
```

| Onde | O quê |
|---|---|
| `conteudo/` | o que o redator edita |
| `modelos/*.kanon` | o papel dos layouts do Liquid: o contrato de cada tipo de página, e o cabeçalho e o fecho que ela ganha |
| `modelos/tipos.jl` | os tipos do site: `autor`, que se escreve pela chave, e `chamada`, um post citado por outro |
| `construir.jl` | lê o conteúdo, valida pelo Kanon e entrega ao Franklin |
| `teste.jl` | os erros de redator plantados numa cópia do conteúdo |
| `config.md`, `_layout/`, `_css/`, `_libs/` | a casca do Franklin |
| `index.md`, `sobre.md`, `posts/` | **gerados** — editar aqui é perder a edição |

Para publicar num subcaminho (GitHub Pages de projeto): `PREPATH=nome julia --project construir.jl`.

### Por que o caminho é este

1. **O cabeçalho é TOML, e não o `+++` do Franklin.** O do Franklin é código Julia
   avaliado: `data = 2026-05-06` sem aspas vira o número 2015, calado, e um `$(...)` num
   título executa código. O TOML recusa o que não é valor, e com linha.
2. **O Kanon escreve CommonMark, e o Franklin não lê CommonMark.** No Franklin, `\[` abre
   bloco de matemática e dois `$` no mesmo parágrafo viram fórmula. Por isso o cabeçalho
   e o fecho que o Kanon escreve passam pelo CommonMark.jl e entram como HTML; só o texto
   do redator vai como Markdown do Franklin.
3. **O corpo não é um campo.** Um valor que o Kanon interpola nunca altera a estrutura
   (D-028) — o corpo como campo sairia com cada asterisco escapado. O modelo marca onde
   ele entra, com `<!-- corpo -->`, e a construção o põe ali: é o `{{ content }}` do Jekyll.
4. **Campo desconhecido é erro.** No Kanon é aviso (`K3021`), porque uma tabela pode
   alimentar vários modelos; num site, `descricoa` é a `descricao` que faltou.
5. **A matemática só é renderizada no corpo.** O KaTeX roda no navegador sobre o que
   receber; o cabeçalho é valor de contrato, e um `\(` num título não é fórmula.

## O que a prova de fogo achou

No **Kanon** (corrigido junto, D-078):

- as mensagens de decodificação — as que um redator lê quando erra uma data ou um número —
  saíam sem acento: `nao e uma data do calendario`;
- `bind` era exportado e não funcionava sem qualificar: o `Base` também exporta um `bind`, e
  `using Kanon` seguido de `bind(modelo, dados)` dava `UndefVarError`. A suíte escrevia
  sempre `Kanon.bind`, e por isso nunca viu;
- `diagnostics`, que lê o resultado de `bind`, não era exportado.

Limites, registrados e não corrigidos:

- **O Markdown do Kanon é CommonMark, e "Markdown" não é um formato só.** O Franklin lê
  outro dialeto; o pandoc, um terceiro. Quem consome a saída num leitor que não é CommonMark
  precisa passá-la por um.
- **Não há camada de idioma inglesa**: o post em inglês sai com a data `2026-05-06`.
- **O diagnóstico de contrato cita a linha do modelo** (D-050), e não a do arquivo de onde o
  dado veio. Para quem escreve modelos é o certo; para o redator é ruído, e a construção
  mostra só a mensagem e a dica.
- **O Kanon não tem consulta a tabela** — o `site.data.authors[page.author]` do Liquid. O
  autor é um tipo do site que decodifica a chave; é a porta que o protocolo prevê (§3.4),
  e a chave errada vira erro de contrato com a lista das que existem.

No **Franklin**:

- o bloco `+++` é código avaliado, e a pasta do site precisa ser o próprio projeto Julia —
  sem `Project.toml` ali, ele troca de ambiente no meio da construção e perde os pacotes;
- `$` no texto abre matemática: dinheiro em reais precisa de `R\$`.
