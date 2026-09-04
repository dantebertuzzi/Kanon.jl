# F0 — Tipos da AST e passos de análise

> Requisito da seção 5-A: **a v1 interpreta, não compila**, mas a AST é projetada desde
> já para geração de código — nós imutáveis, sem estado interno, sem dependência da
> ordem de visita — para que trocar o renderizador por um compilador na v2 não exija
> refazer parser nem validador.

## 1. As três invariantes que tornam a v2 possível

Estas são obrigações, não preferências. Cada uma tem um teste correspondente.

**I1 — Todo nó é imutável.** `struct`, nunca `mutable struct`. Nenhum campo é
reatribuído depois da construção; vetores de filhos não são mutados depois que o nó
existe. *Teste:* `Aqua`-style, varrer os tipos do módulo e falhar se algum for mutável.

**I2 — Nenhum resultado de análise mora no nó.** Número de cláusula, tipo resolvido de
um caminho, nulabilidade, formatador resolvido, ordem de avaliação: nada disso é campo
de nó. Tudo vive em **tabelas laterais** produzidas por `analyze` e endereçadas por
`NodeId`. *Por quê:* um compilador calcula essas coisas em tempo de compilação e as
consome; um nó que as carrega força mutação durante a análise e impede reusar a mesma
árvore para dois ambientes. É a lição do `.aux` do LaTeX (`estado-da-arte.md`, seção 4).

**I3 — Nenhum nó depende da ordem de visita.** Renderizar um nó exige apenas o nó, a
`Analysis`, os dados e o ambiente. Não há contador incrementado durante a travessia, não
há pilha implícita. A numeração de blocos é resultado de um passo próprio, não efeito
colateral do render. *Teste:* renderizar a árvore em ordem invertida por blocos e
conferir que cada bloco isolado produz o mesmo texto que produziu na ordem normal.

Uma quarta, menos estrutural mas necessária para determinismo:

**I4 — Nada de `Dict` na saída de análise cuja iteração alcance o texto.** Onde a ordem
importa, usar `Vector` de pares ou percorrer chaves ordenadas.

## 2. Identidade e posição

```julia
const NodeId = Int32              # índice denso, atribuído na construção da árvore

struct Span
    file::Int32                   # índice em Template.sources
    line::Int32
    col::Int32
    endline::Int32
    endcol::Int32
end

abstract type Node end
# todo Node concreto tem os campos `id::NodeId` e `span::Span`
```

`NodeId` denso permite que as tabelas laterais sejam `Vector` indexado, não `Dict` —
mais rápido, e sem ordem de iteração para vazar (I4).

## 3. Plano de dados

```julia
@enum CardKind SCALAR EXACT ATLEAST RANGE ANY

struct Cardinality
    kind::CardKind
    lo::Int32       # 0 quando irrelevante
    hi::Int32       # typemax quando irrelevante
end

@enum Presence REQUIRED OPTIONAL DEFAULTED

struct Literal
    kind::Symbol            # :number :text :boolean :date :null :constant
    value::Any              # imutável: Real, String, Bool, Date, nothing, Symbol
end

struct FieldDecl
    id::NodeId
    name::Symbol
    type::Symbol            # nome do tipo tal como escrito; resolvido em analyze
    card::Cardinality
    presence::Presence
    default::Union{Nothing,Literal}
    span::Span
end

struct DataPlane
    fields::Vector{FieldDecl}      # na ordem do arquivo; ordem é semântica (erros, checklist)
end
```

## 4. Plano do texto

```julia
struct Path
    segments::Vector{Symbol}       # ≥ 1
    span::Span
end

struct TextLit <: Node
    id::NodeId
    value::String                  # já normalizado NFC, com {{ }} [[ ]] ((…)) resolvidos
    span::Span
end

struct Interp <: Node
    id::NodeId
    path::Path
    formatter::Union{Nothing,Symbol}
    span::Span
end

struct BlockRef <: Node            # {::nome}
    id::NodeId
    target::Symbol
    span::Span
end

struct FlexPoint <: Node           # portador(a)
    id::NodeId
    word::String                   # "portador"
    mark::String                   # "(a)"
    span::Span
end

struct Group <: Node               # [ ... ]
    id::NodeId
    children::Vector{Node}
    span::Span
end

struct Paragraph <: Node
    id::NodeId
    children::Vector{Node}
    span::Span
end

struct Block <: Node
    id::NodeId
    name::Symbol
    unit::Char                     # a unidade do marcador COMO ESCRITA: ':' ou '§'
    repeat::Int8                   # quantas vezes: ':'×1 é bloco simples, ':'×2 é nível 1
    subject::Union{Nothing,Path}   # do '<-'
    children::Vector{Paragraph}
    span::Span
end

struct TextPlane
    blocks::Vector{Block}          # ordem do arquivo = ordem da saída (invariante anti-XSLT)
end

# Nota da F1: uma versão anterior deste documento dava a `Block` os campos `style` e
# `level` já resolvidos. Estava errado, e o erro é justamente o que I2 proíbe: resolver
# o estilo exige o ambiente (é uma camada quem registra `§`), e um nó que carregasse o
# estilo amarraria a árvore a um ambiente — impedindo analisar o mesmo modelo com e sem
# camadas, que é o teste de neutralidade. O nó guarda o marcador como escrito; estilo e
# nível resolvidos vivem na `Analysis`.
```

Nota sobre `TextLit`: os escapes são resolvidos **no lexer**, não no render. O render
nunca vê `{{`. Isso mantém o render livre de reescrita de texto e torna a saída do lexer
diretamente emitível por um compilador como literal de string.

## 5. Plano das regras

```julia
abstract type RuleExpr end

struct PathExpr <: RuleExpr;  id::NodeId; path::Path;                    span::Span end
struct LitExpr  <: RuleExpr;  id::NodeId; lit::Literal;                  span::Span end
struct NotExpr  <: RuleExpr;  id::NodeId; operand::RuleExpr;                 span::Span end
struct BinExpr  <: RuleExpr;  id::NodeId; op::Symbol; lhs::RuleExpr; rhs::RuleExpr; span::Span end
                          # op ∈ :and :or :eq :ne :lt :le :gt :ge
struct AttrExpr <: RuleExpr;  id::NodeId; subject::Path; attr::Symbol; negated::Bool; span::Span end

struct Rule
    id::NodeId
    block::Symbol
    when::Union{Nothing,RuleExpr}
    foreach::Union{Nothing,Path}
    span::Span
end

struct RulesPlane
    rules::Vector{Rule}
end
```

`BinExpr` com `op ∈ {:and,:or}` **não é curto-circuito com efeito**: não há efeitos, logo
a avaliação pode ser feita em qualquer ordem ou vetorizada por um compilador. Vale
registrar que a avaliação da v1 será curto-circuito por eficiência, e que isso é
inobservável.

## 6. O modelo

```julia
struct LangVersion; major::Int16; minor::Int16 end

struct Template
    version::LangVersion
    language::Union{Nothing,Symbol}     # do pragma; nothing = inglês canônico
    sources::Vector{String}             # caminhos, para os Span
    data::DataPlane
    text::TextPlane
    rules::RulesPlane
    nnodes::Int32                       # para dimensionar as tabelas laterais
end
```

`Template` não conhece `Environment`. O mesmo `Template` pode ser analisado em dois
ambientes diferentes e produzir duas `Analysis` — o que é exatamente o que o teste de
neutralidade precisa fazer (rodar o mesmo modelo com e sem camadas).

## 7. Análise — as tabelas laterais

```julia
struct ResolvedPath
    kind::Symbol                 # :field | :subject_field | :constant
    typename::Symbol             # tipo resolvido
    nullable::Bool
    card::Cardinality
    decl::NodeId                 # declaração de origem, para a mensagem de erro
end

struct Analysis
    # por nó (Vector indexado por NodeId; entradas não aplicáveis ficam vazias)
    paths::Vector{Union{Nothing,ResolvedPath}}
    formatter::Vector{Symbol}          # formatador efetivo de cada Interp (:default quando omitido)
    guarded::Vector{Bool}              # a Interp está dentro de ≥1 Group?

    # por bloco
    numbering::Vector{Vector{Int32}}   # [3], [3,1], [3,1,2]; vazio para bloco não numerado
    block_rule::Vector{Int32}          # índice da regra 'when', 0 se nenhuma
    block_foreach::Vector{Int32}       # índice da regra 'one for each', 0 se nenhuma

    # globais
    block_index::Vector{Pair{Symbol,NodeId}}   # ordenado por nome; nunca Dict (I4)
    diagnostics::Vector{Diagnostic}
end
```

`guarded` é a tabela que sustenta o teorema da lacuna: a validação exige
`guarded[i] == true` para todo `Interp i` com `paths[i].nullable == true`.

`numbering` é a tabela que sustenta a invariante I2: nenhum `Block` sabe seu número.

## 8. Os passos, e o que cada um pode e não pode fazer

```
fonte
  │ lex          léxico; resolve escapes; posições
  ▼
tokens
  │ parse        gramática dos três planos; sem consultar Environment
  ▼
Template          ── erro de SINTAXE (sem dados, sem ambiente)
  │ analyze(env)  resolve tipos, formatadores, caminhos, numeração, guarda
  ▼
Analysis          ── erro de REFERÊNCIA (sem dados, com ambiente)
  │ check(data)   valida os dados contra o contrato
  ▼
Bound             ── erro de CONTRATO (com dados)
  │ render        interpreta; puro
  ▼
texto
```

Restrições normativas de cada passo:

- **`parse` não consulta o `Environment`.** Um modelo em inglês tem uma única árvore
  possível, independente das camadas carregadas. Consequência prática: apelidos de
  idioma são resolvidos numa tabela fixa **antes** do parse, a partir do pragma, e não
  por consulta dinâmica ao ambiente durante a análise sintática.
- **`analyze` é puro em relação ao `Template`.** Não muta a árvore. Devolve `Analysis`.
- **`render` não emite diagnóstico.** Se `analyze` e `check` passaram, `render` só pode
  falhar por orçamento de recursos (`especificacao.md`, seção 11).
- **`render` é puro:** `(Template, Analysis, dados, env) → String`, sem I/O, sem relógio,
  sem aleatoriedade, sem estado global.

## 9. O caminho para a v2

O compilador da v2 substitui apenas a última seta:

```
Template + Analysis + Environment  ──►  Expr Julia  ──►  função compilada
```

Nada acima da linha muda. Concretamente, cada nó tem uma tradução direta:

| Nó | v1 (interpretador) | v2 (compilador) |
|---|---|---|
| `TextLit` | `write(io, n.value)` | literal de string emitido no corpo |
| `Interp` | busca em `Analysis` + `format` | chamada a `format` com o tipo já conhecido, despacho estático |
| `Group` | avalia diretas, elide | `if`/`else` gerado com as condições de nulo |
| `Block` | laço sobre parágrafos | corpo inline |
| `Rule` | avalia `RuleExpr` | condição gerada |
| numeração | consulta `Analysis.numbering` | constante embutida |

O teste que protege isso e que deve existir **desde a F3**, muito antes de haver
compilador: um *round-trip* que reconstrói a árvore a partir dos seus campos e confere
igualdade estrutural, e uma travessia que afirma que nenhum campo de nó mudou depois de
`analyze`. Se um dia alguém precisar guardar algo no nó, esse teste quebra, e a decisão
volta à mesa em vez de acontecer por descuido.

> Registrado em `decisoes.md`, D-011.
