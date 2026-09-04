# F0 — API de extensão (fechada para a v1)

> Regra que governa este documento: **`KanonLegal.jl` deve ser escrito usando exatamente
> a API abaixo.** Se ele precisar de um atalho interno ou de um caso especial no parser,
> a F0 falhou e voltamos a ela (seção 5 do documento de projeto).

## 1. Forma da extensão

Extensão é **método de função genérica**, não registro em dicionário. O núcleo define
funções genéricas e as chama; camadas adicionam métodos. Não há tabela de despacho
mantida à mão, não há estado global mutável, não há `eval`.

```julia
# no núcleo: a função genérica e o erro padrão
format(v, ::Val{name}, ctx) where {name} = throw(UnknownFormatter(typeof(v), name))

# em KanonLegal.jl, sem alterar o núcleo
format(v::Money,   ::Val{:written}, ctx) = spell_currency(v, ctx)

# em KanonScience.jl, idem
format(v::Measure, ::Val{:default}, ctx) = format_uncertainty(v, ctx)
```

**Obrigação (5-A):** se a implementação começar a manter um `Dict` de formatadores, ela
está lutando contra a linguagem. Pare e reveja.

## 2. O protocolo de tipo

Oito funções genéricas. Um tipo escalar implementa quatro; um composto, seis.

```julia
kanon_typename(::Type{T})            -> Symbol            # obrigatória
kanon_schema(::Type{T})              -> Tuple{Vararg{FieldSpec}}   # () se escalar
kanon_validate(v::T, ctx)            -> Nothing | Vector{Diagnostic}
format(v::T, ::Val{:default}, ctx)   -> AbstractString    # obrigatória
format(v::T, ::Val{name}, ctx)       -> AbstractString    # zero ou mais
kanon_formats(::Type{T})             -> Tuple{Vararg{Symbol}}      # ver 2.1
kanon_attribute(v::T, ::Val{name})   -> Bool
kanon_attributes(::Type{T})          -> Tuple{Vararg{Symbol}}
kanon_decode(::Type{T}, raw, ctx)    -> T                 # da entrada externa
kanon_compare(a::T, b)               -> Int               # -1, 0, 1; ou erro
```

```julia
struct FieldSpec
    name::Symbol
    type::Symbol
    optional::Bool
    card::Cardinality
end
```

`kanon_schema` e o campo `optional` de `FieldSpec` são o que torna
`{seller.spouse.name}` verificável sem dados e o que estende o teorema da lacuna aos
tipos compostos (ver `especificacao.md`, seções 3.1 e 14).

### 2.1 `kanon_formats` e a promessa da seção 9 do projeto

A especificação inicial promete que estender **por despacho direto**, sem passar pela
fachada, funciona igual. Isso entra em tensão com a necessidade de enumerar
formatadores para (a) validar `{x:written}` sem dados e (b) escrever a mensagem
"Formatadores disponíveis para 'text': upper, lower, title".

**Resolução:** `kanon_formats(T)` tem uma implementação padrão no núcleo que **introspecta
a tabela de métodos** de `format` procurando assinaturas `Tuple{typeof(format), T′, Val{S}, Any}`
com `T <: T′` e `S::Symbol`, e devolve os `S` **ordenados**. Uma camada pode
sobrescrevê-la para documentar ou para cobrir métodos genéricos (`format(v::T, ::Val{N}, ctx) where N`),
que a introspecção não consegue enumerar.

Isso é introspecção de **tabela de métodos**, não de dados do usuário: não executa
código do modelo, não viola a seção 11 da especificação, e é determinística por causa da
ordenação. Um formatador adicionado por despacho direto passa a existir para a validação
e para a mensagem de erro sem nenhum registro adicional — que é a promessa.

### 2.2 Fachada

```julia
register_type!(b, :money;
    julia_type = Money,
    validate   = v -> v.amount ≥ 0,
    default    = (v, ctx) -> format_currency(v, ctx),
    formats    = (written = (v, ctx) -> spell_out(v, ctx),),
    attributes = (zero = v -> iszero(v.amount),),
    decode     = (raw, ctx) -> Money(raw, ctx.currency),
    compare    = (a, b) -> cmp(a.amount, b),
    aliases    = (pt = :dinheiro,),
)
```

`aliases` dá ao tipo um nome por idioma. É necessário porque nome de tipo **não** é
palavra-chave — é identificador registrado por uma camada de domínio — e portanto não é
coberto por `register_aliases!`. Sem ele, um modelo em português teria metade do
vocabulário do plano de dados em inglês (`docs/exemplos.md`, seção 3.3). O idioma ativo é
o declarado no pragma do arquivo; o nome canônico continua valendo sempre.

A fachada **expande para os métodos da seção 2**, nada mais. Teste normativo da F6:
para cada tipo de `KanonLegal`, a definição por fachada e a definição manual equivalente
produzem a mesma saída em todo o corpus golden.

### 2.3 `@kanon_type`

Açúcar sobre a fachada, escopo da F6. Duas obrigações da F0:

1. Tudo que a macro gera deve ser escrevível à mão pelo caminho da seção 2.
2. **Teste normativo:** `@macroexpand` da macro não pode conter nenhuma referência a um
   nome não exportado por `Kanon`. É a verificação mecânica de que a macro não é um
   atalho para dentro do núcleo.

## 3. Camada de idioma

```julia
register_inflection!(b, :pt;
    marks = ("(a)", "(o)", "(es)", "(s)", "(as)", "(os)"),
    apply = (word, mark, subject, ctx) -> inflect(word, mark, gender(subject), number(subject)),
)

register_aliases!(b, :pt, (
    data = "dados", text = "texto", rules = "regras",
    when = "quando", and = "e", or = "ou", not = "não",
    is = "é", present = "presente", absent = "ausente", today = "hoje",
))

register_repair_hook!(b, :pt, (text, seams, ctx) -> recapitalize_after_elision(text, seams))
```

O protocolo de sujeito que a camada de idioma usa é ela mesma quem define
(`gender(v)`, `number(v)` despachados sobre os tipos do domínio). **O núcleo não conhece
gênero nem número** — ele apenas entrega `(palavra, marca, sujeito)`.

`apply` recebe a palavra inteira, não só a marca, e devolve a palavra inteira já
flexionada. É o que permite `portador(a)` → `portadoras` sem que o núcleo saiba
pluralizar coisa alguma (`especificacao.md`, seção 7).

## 4. Camada de domínio: estilos de bloco

```julia
register_block_style!(b, :clause;
    unit      = '§',                 # nível n = unidade repetida n+1 vezes: §§, §§§, …
    layout    = :prefix,             # :prefix | :heading
    separator = ". ",
    number    = (path, ctx) -> uppercase("cláusula " * ordinal_written(path[1], :f, ctx)),
    ref       = (path, ctx) -> "cláusula " * ordinal_written(path[1], :f, ctx),
)
```

`unit` é a **unidade** do marcador, não a forma de nível 1: registrar `"§§"` tornaria
impossível derivar `§§§`. `layout` e `separator` dizem onde o rótulo entra no texto —
lacuna encontrada ao escrever os exemplos (`docs/exemplos.md`, seção 3.1).

`path` é o vetor de contadores (`[3]`, `[3,1]`), o que dá à camada liberdade para
renderizar `3.1`, `Parágrafo Primeiro da Cláusula Terceira` ou `Teorema 3.1` sem
nenhuma mudança no núcleo.

## 5. Ambiente

**Camada = módulo Julia.** Um módulo de camada define métodos (efeito de carga, imutável)
e opcionalmente uma função `configure!(builder)` para o que não é despacho: apelidos,
estilos de bloco, marcas de flexão, constantes, limites.

```julia
env = Environment(locale = :pt, domains = [Legal])
```

O construtor:

1. cria um `EnvironmentBuilder` limpo;
2. aplica `configure!` do núcleo, depois da camada de idioma, depois de cada domínio **na
   ordem do vetor** — ordem determinística e visível;
3. **detecta conflitos na construção**, não no render: dois domínios registrando o mesmo
   apelido, o mesmo marcador de bloco ou o mesmo nome de tipo é erro **aqui**, com a
   mensagem nomeando os dois domínios;
4. congela: `Environment` é imutável. Não há `register_*!` em `Environment`, só em
   `EnvironmentBuilder`.

Dois `Environment` com domínios diferentes coexistem no mesmo processo sem interferência,
porque o que é global (métodos) é aditivo e o que é conflitante (nomes) é local ao
ambiente.

## 6. API de alto nível

```julia
env  = Environment(locale = :pt, domains = [Legal])

tmpl = load_template(env, "escritura.kanon")   # lex + parse + analyze; erros de sintaxe e referência
check(tmpl, dados)                              # erros de contrato; devolve DiagnosticSet (vazio = ok)
render(tmpl, dados; today = Date(2026,9,3))     # String, ou lança
contract(tmpl)                                  # JSON Schema 2020-12 + x-kanon
preview(tmpl, dados)                            # rascunho com «marcadores», nunca exporta
```

`load_template` devolve um objeto que embute `Template` e `Analysis`; ele é reutilizável
sem reparse (exigência de desempenho da seção 14 do projeto). Assinaturas paralelas
`load_string(env, str; name)` para testes.

`render` lança `KanonContractError` se `check` não passou — não existe render sem
validação, nem como opção.

## 7. Formato do checklist

`contract(tmpl)` emite JSON Schema draft 2020-12:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "kanon:escritura.kanon",
  "type": "object",
  "required": ["seller", "buyer", "property", "price"],
  "additionalProperties": false,
  "properties": {
    "price":     { "$ref": "#/$defs/money",  "x-kanon": { "type": "money",  "line": 6, "presence": "required", "formatters": ["written"] } },
    "date":      { "$ref": "#/$defs/date",   "x-kanon": { "type": "date",   "line": 7, "presence": "defaulted", "default": "today" } },
    "witnesses": { "type": "array", "items": { "$ref": "#/$defs/person" }, "minItems": 2, "maxItems": 2,
                   "x-kanon": { "type": "person", "line": 8, "presence": "optional", "cardinality": "exact(2)" } }
  },
  "$defs": { "money": {}, "date": {}, "person": {} }
}
```

Escolha do JSON Schema, e não de um formato próprio: qualquer gerador de formulário,
validador ou ferramenta de documentação do mercado consome o checklist sem adaptador, e
o `x-kanon` carrega o que o JSON Schema não expressa. Custo próximo de zero
(D-009).

Saída **determinística**: chaves em ordem de declaração no `properties`, `required` na
ordem do arquivo, sem espaços variáveis. O checklist é comparável em `diff`.

## 8. O que a API de extensão deliberadamente **não** oferece

Enumerado para que não volte como pedido no meio da implementação:

- registrar palavra-chave nova ou construção sintática nova (a gramática é fechada por
  versão da linguagem, e apelidos não são sintaxe nova);
- ganchos no parser;
- executar código a partir do modelo, em qualquer forma;
- ler arquivo ou rede durante o render;
- mutar um `Environment` já construído;
- estado global compartilhado entre ambientes.
