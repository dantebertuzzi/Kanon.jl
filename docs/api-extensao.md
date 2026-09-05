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

Nove funções genéricas. Um tipo escalar implementa quatro; um composto, seis, mais um
`kanon_getfield` por campo cujo nome não seja o da propriedade Julia.

```julia
kanon_typename(::Type{T})            -> Symbol            # obrigatória
kanon_schema(::Type{T})              -> Tuple{Vararg{FieldSpec}}   # () se escalar
kanon_validate(v::T, ctx)            -> Nothing | Vector{Diagnostic}
format(v::T, ::Val{:default}, ctx)   -> AbstractString    # obrigatória
format(v::T, ::Val{name}, ctx)       -> AbstractString    # zero ou mais
kanon_formats(::Type{T})             -> Tuple{Vararg{Symbol}}      # sem :default; ver 2.1
kanon_attribute(v::T, ::Val{name})   -> Bool
kanon_attributes(::Type{T})          -> Tuple{Vararg{Symbol}}
kanon_getfield(v::T, ::Val{name})    -> valor do campo declarado por kanon_schema
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

**[acrescentada na F2.6 — D-023]** `kanon_getfield` é como o motor lê o campo que o
esquema promete. O padrão é `getproperty(v, name)`; um tipo cujo esquema não espelha a
`struct` define os métodos dele. Sem essa separação, `kanon_schema` viraria uma promessa
sobre nomes de propriedades Julia, e renomear um campo interno quebraria o acervo. É
também o que permite a `check` verificar que um composto cumpre o próprio esquema — sem
isso o teorema da lacuna tem um furo do tamanho de um tipo composto.

### 2.1 `kanon_formats` e a promessa da seção 9 do projeto

A especificação inicial promete que estender **por despacho direto**, sem passar pela
fachada, funciona igual. Isso entra em tensão com a necessidade de enumerar
formatadores para (a) validar `{x:written}` sem dados e (b) escrever a mensagem
"Formatadores disponíveis para 'text': upper, lower, title".

**Resolução:** `kanon_formats(T)` tem uma implementação padrão no núcleo que **introspecta
a tabela de métodos** de `format` procurando assinaturas `Tuple{typeof(format), T′, Val{S}, Any}`
com `T <: T′` e `S::Symbol`, e devolve os `S` **ordenados**, **sem** `:default` — que
não é nome escrevível numa interpolação: quem quer o padrão escreve `{price}`, e
`{price:default}` é erro de referência. Uma camada pode
sobrescrevê-la para documentar ou para cobrir métodos genéricos (`format(v::T, ::Val{N}, ctx) where N`),
que a introspecção não consegue enumerar.

Isso é introspecção de **tabela de métodos**, não de dados do usuário: não executa
código do modelo, não viola a seção 11 da especificação, e é determinística por causa da
ordenação. Um formatador adicionado por despacho direto passa a existir para a validação
e para a mensagem de erro sem nenhum registro adicional — que é a promessa.

### 2.2 Fachada **[revista na F2.1 — D-019]**

A fachada registra o **nome** do tipo no ambiente. O comportamento não passa por ela:

```julia
register_type!(b, Money; aliases = (pt = :dinheiro,))
```

`aliases` dá ao tipo um nome por idioma. É necessário porque nome de tipo **não** é
palavra-chave — é identificador registrado por uma camada de domínio — e portanto não é
coberto por `register_aliases!`. Sem ele, um modelo em português teria metade do
vocabulário do plano de dados em inglês (`docs/exemplos.md`, seção 3.3). O idioma ativo é
o declarado no pragma do arquivo; o nome canônico continua valendo sempre.

O nome canônico vem de `kanon_typename(T)` — o mesmo método que a seção 2 exige. Validar,
formatar, decodificar, comparar e responder atributo são métodos definidos no módulo da
camada, e existem para o motor **sem** que o ambiente saiba deles.

**Por que não closures aqui.** A forma originalmente desenhada nesta seção
(`validate = ...`, `formats = (written = ...,)` passados em runtime) só poderia ser
implementada guardando as funções num dicionário consultado pelo motor — proibido pela
obrigação 5-A — ou gerando métodos com `eval`, proibido pela seção 1. Essa forma passa
para `@kanon_type` (seção 2.3), que é macro e expande em tempo de carga. O registro da
decisão está em `docs/decisoes.md`, D-019.

### 2.3 `@kanon_type`

Açúcar sobre a fachada, escopo da F6, e o lugar da forma declarativa com closures:

```julia
@kanon_type money Money begin
    validate   = v -> v.amount ≥ 0
    default    = (v, ctx) -> format_currency(v, ctx)
    formats    = (written = (v, ctx) -> spell_out(v, ctx),)
    attributes = (zero = v -> iszero(v.amount),)
    decode     = (raw, ctx) -> Money(raw, ctx.currency)
    compare    = (a, b) -> cmp(a.amount, b)
    aliases    = (pt = :dinheiro,)
end
```

Por ser macro, ela expande em tempo de carga do módulo para os métodos da seção 2 mais
uma chamada a `register_type!` — sem `eval` em runtime e sem tabela de despacho. Duas
obrigações da F0:

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

register_list_joiner!(b, :pt, (partes, ctx) -> join_with_conjunction(partes))

register_type_alias!(b, :dinheiro, :money)
```

**[acrescentados na F4 — D-025]** `register_list_joiner!` substitui a única convenção
tipográfica do núcleo (o `", "` de `list`, §3.3), e `register_type_alias!` dá nome em
outro idioma a um tipo que **outro** registrou — o caso dos seis tipos do núcleo, que o
núcleo registra sem apelido nenhum porque é neutro.

Os dois são registro no ambiente, e não método: um método sobre `AbstractVector` seria
global, e carregar a camada mudaria a saída de um ambiente que não a declarou.

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

O idioma é ele próprio despacho: `Extenso.jl` define
`Kanon.configure_locale!(b, ::Val{:pt})`, e carregar o módulo basta para o idioma
existir. Um `locale` sem camada carregada é erro na construção, nomeando o idioma. Os
domínios são módulos, e o construtor chama `configure!` de cada um se ele o define.

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

## 9. O que o ambiente guarda, além dos tipos

Registrado pelas camadas, congelado na construção, e ordenado — toda lista que pode
alcançar uma mensagem de erro é ordenada, por I4:

| Registro | Quem registra | Conflito |
|---|---|---|
| nome de tipo e apelido | `register_type!` | dois domínios, mesmo nome |
| palavra-chave do idioma | `register_aliases!` | duas formas para canônicas diferentes |
| estilo de bloco | `register_block_style!` | dois domínios, mesma unidade de marcador |
| marcas de flexão e `apply` | `register_inflection!` | duas camadas de idioma |
| gancho de reparo | `register_repair_hook!` | duas camadas de idioma |
| símbolo de moeda | `register_currency!` | dois símbolos para a mesma moeda |
| junção de lista | `register_list_joiner!` | duas camadas de idioma |
| apelido de tipo de outrem | `register_type_alias!` | dois apelidos iguais |
| separadores decimal e de milhar | `register_separators!` | último vence (é do idioma) |
| padrão de `date:numeric` | `register_date_pattern!` | último vence (é do idioma) |

O contexto que os formatadores recebem é `FormatContext(env, today)`, e nada mais.
`today` é injetado, nunca lido do relógio.
