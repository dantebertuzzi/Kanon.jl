"""
    KanonLegal

Camada de domínio jurídico do [`Kanon`](https://github.com/dantebertuzzi/Kanon.jl):
os tipos `pessoa` e `imovel`, o estilo de bloco `§` com rótulo `CLÁUSULA PRIMEIRA`, e os
formatadores que um instrumento público precisa.

**Escrita só com a API pública.** Se este módulo precisar de um atalho para dentro do
núcleo, a F0 falhou — é a regra que governa `docs/api-extensao.md`, e este pacote é o
teste dela.

Depende de `Extenso` para o ordinal por extenso do rótulo de cláusula. O núcleo não
depende de nenhum dos dois.

Os tipos têm nome em português — `pessoa`, `imovel`, `parte` — e não em inglês com
apelido. O inglês canônico da linguagem vale para as palavras-chave (§9); um domínio
nacional traz o vocabulário dele, e `cpf` e `cláusula` não têm original a traduzir.
"""
module KanonLegal

using Dates
using Kanon
using Extenso
using Extenso: ordinal_extenso, genero

export Pessoa, Imovel, Parte

# --- pessoa ------------------------------------------------------------------

"""
    Pessoa

Uma parte física. `genero` é o que a camada de idioma consulta nos pontos de flexão —
`Extenso.genero` é protocolo dela, e o núcleo não conhece gênero (§7.1).
"""
struct Pessoa
    nome::String
    genero::Symbol                       # :m | :f
    estado_civil::String
    cpf::String
    endereco::String
    regime::Union{Nothing,String}
    nascimento::Union{Nothing,Date}
end

function Pessoa(nome, genero, estado_civil, cpf, endereco;
                regime = nothing, nascimento = nothing)
    Pessoa(nome, Symbol(genero), estado_civil, cpf, endereco, regime, nascimento)
end

Extenso.genero(p::Pessoa) = p.genero

"Idade em anos completos numa data — o cálculo que a maioridade exige."
function idade(p::Pessoa, hoje::Date)
    p.nascimento === nothing && return nothing
    anos = Dates.year(hoje) - Dates.year(p.nascimento)
    (Dates.month(hoje), Dates.day(hoje)) <
        (Dates.month(p.nascimento), Dates.day(p.nascimento)) ? anos - 1 : anos
end

@kanon_type pessoa Pessoa begin
    schema = (FieldSpec(:nome, :text),
              FieldSpec(:estado_civil, :text),
              FieldSpec(:cpf, :text),
              FieldSpec(:endereco, :text),
              FieldSpec(:regime, :text; optional = true),
              FieldSpec(:nascimento, :date; optional = true))
    default    = (v, ctx) -> v.nome
    formats    = (maiusculo = (v, ctx) -> uppercase(v.nome),
                  cpf = (v, ctx) -> v.cpf)
    attributes = (casado = v -> startswith(v.estado_civil, "casad"),
                  solteiro = v -> startswith(v.estado_civil, "solteir"))
end

"""
    maior(pessoa, hoje) -> Bool

A maioridade **não** é atributo do tipo, e não pode ser: `kanon_attribute(v, ::Val{name})`
recebe o valor e mais nada, e a idade depende da data de referência — que é injetada,
nunca lida do relógio (§2.2). Um atributo que consultasse o relógio quebraria o
determinismo por dentro, onde nada o veria.

No modelo, a maioridade se pergunta comparando: `quando parte.nascimento < 2008-01-01`.
Esta função existe para o código Julia que precisa dela fora do motor.
"""
maior(p::Pessoa, hoje::Date) = (i = idade(p, hoje); i === nothing ? false : i >= 18)

# --- imóvel ------------------------------------------------------------------

struct Imovel
    matricula::String
    tipo::Symbol                         # :urbano | :rural
    descricao::String
    area::Union{Nothing,Float64}
end

Imovel(matricula, tipo, descricao; area = nothing) =
    Imovel(matricula, Symbol(tipo), descricao, area)

@kanon_type imovel Imovel begin
    schema = (FieldSpec(:matricula, :text),
              FieldSpec(:descricao, :text),
              FieldSpec(:area, :number; optional = true))
    default    = (v, ctx) -> v.descricao
    formats    = (descricao = (v, ctx) -> v.descricao,
                  matricula = (v, ctx) -> v.matricula)
    attributes = (rural = v -> v.tipo === :rural,
                  urbano = v -> v.tipo === :urbano)
end

# --- parte: o teste de D-006 -------------------------------------------------

"""
    Parte

Uma parte do instrumento, física **ou** jurídica.

É o caso que a D-006 deixou como prova: a versão 1 não tem tipos-soma, e a necessidade
se atende na camada de domínio com um composto e um atributo. `quando outorgante é
empresa` faz o que `pessoa | empresa` faria, sem que o núcleo saiba que existem duas
espécies de parte.

Se isto não desse, a separação núcleo/domínio seria mais fraca do que se supõe.
"""
struct Parte
    nome::String
    genero::Symbol
    documento::String                    # CPF ou CNPJ
    endereco::String
    empresa::Bool
    representante::Union{Nothing,Pessoa}
end

Parte(nome, genero, documento, endereco; empresa = false, representante = nothing) =
    Parte(nome, Symbol(genero), documento, endereco, empresa, representante)

Extenso.genero(p::Parte) = p.genero

@kanon_type parte Parte begin
    schema = (FieldSpec(:nome, :text),
              FieldSpec(:documento, :text),
              FieldSpec(:endereco, :text),
              FieldSpec(:representante, :pessoa; optional = true))
    default    = (v, ctx) -> v.nome
    formats    = (maiusculo = (v, ctx) -> uppercase(v.nome),)
    attributes = (empresa = v -> v.empresa,
                  fisica = v -> !v.empresa)
end

# --- o estilo de cláusula ----------------------------------------------------

"""
O rótulo de uma cláusula: `CLÁUSULA PRIMEIRA`, `CLÁUSULA SEGUNDA`.

O ordinal por extenso vem de `Extenso`, e o feminino também — `cláusula` é feminina, e
`ordinal_extenso` recebe o gênero como argumento justamente porque a camada de domínio é
quem sabe disso (§7.1: o núcleo não conhece gênero).

Níveis abaixo do primeiro saem como `PARÁGRAFO PRIMEIRO`, que é a forma dos instrumentos.
"""
function rotulo_clausula(path, ctx)
    length(path) == 1 &&
        return uppercase("cláusula " * ordinal_extenso(Int(path[1]); genero = :f))
    uppercase("parágrafo " * ordinal_extenso(Int(path[end]); genero = :m))
end

"A remissão, em caixa baixa: `conforme a cláusula segunda`."
function remissao_clausula(path, ctx)
    length(path) == 1 && return "cláusula " * ordinal_extenso(Int(path[1]); genero = :f)
    "parágrafo " * ordinal_extenso(Int(path[end]); genero = :m)
end

"""
    configure!(b)

O que é **nome**, e por isso local ao ambiente: os tipos, seus apelidos em português, e
o marcador `§`. O comportamento já existe por despacho, gerado por `@kanon_type`.

É função **deste** módulo, e não um método de `Kanon.configure!` — essa assinatura é a do
núcleo, e defini-la aqui a substituiria. O construtor do ambiente chama `m.configure!(b)`
de cada domínio (§5).
"""
function configure!(b::Kanon.EnvironmentBuilder)
    # Sem apelidos: os nomes canônicos destes tipos já são o vocabulário do domínio.
    # O inglês canônico da linguagem vale para as palavras-chave (§9), não para um
    # domínio nacional — `cpf` e `cláusula` não têm original em inglês.
    register_type!(b, Pessoa)
    register_type!(b, Imovel)
    register_type!(b, Parte)

    register_block_style!(b, :clausula;
        unit      = Char(0x00A7),        # §
        layout    = :prefix,
        separator = ". ",
        number    = rotulo_clausula,
        ref       = remissao_clausula)
    return b
end

end # module
