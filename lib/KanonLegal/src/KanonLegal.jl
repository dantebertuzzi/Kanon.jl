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
    decode     = (raw, ctx) -> pessoa_de(raw, ctx)
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
    decode     = (raw, ctx) -> imovel_de(raw, ctx)
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
    decode     = (raw, ctx) -> parte_de(raw, ctx)
end

# --- leitura de dados externos -----------------------------------------------
#
# Um JSON — ou uma linha de tabela, ou um `Dict` montado à mão — não chega como `Pessoa`:
# chega como um dicionário de chaves e cadeias, e `kanon_decode` é o **único** ponto em
# que ele vira valor do tipo (§3.4). Sem estes métodos, a via pela qual os dados chegam na
# prática não alcançava documento jurídico nenhum: `check` recusava com "esperava um valor
# de `pessoa`", e não havia nada que o autor pudesse escrever para satisfazê-lo (D-046).
#
# A decodificação é **estrita**, como todo o resto: chave que falta é erro, valor de tipo
# errado é erro, e nenhum campo vira `nothing` por conveniência. O que é opcional no
# esquema é opcional aqui, e só isso.

"""
O valor de uma chave, ou `nothing` quando ela falta e o campo é opcional.

`null` no JSON e chave ausente valem o mesmo: o campo não veio. Distingui-los faria a
origem dos dados mudar o significado do contrato.
"""
function chave(T::Type, raw::AbstractDict, nome::AbstractString; opcional::Bool = false)
    v = get(raw, nome, nothing)
    v === nothing || return v
    opcional && return nothing
    throw(UndecodableValue(T, raw, "falta a chave `$nome`."))
end

"Uma cadeia obrigatória, pelo decodificador do núcleo — a mensagem de tipo é a dele."
texto_de(T, raw, nome, ctx; opcional = false) =
    (v = chave(T, raw, nome; opcional); v === nothing ? nothing :
     kanon_decode(AbstractString, v, ctx))

data_de(T, raw, nome, ctx; opcional = false) =
    (v = chave(T, raw, nome; opcional); v === nothing ? nothing :
     kanon_decode(Date, v, ctx))

"""
Um símbolo de um conjunto fechado — `genero`, `tipo` de imóvel.

Recusa o que não está no conjunto **nomeando o conjunto**: quem escreve o JSON não tem
como saber que `"masculino"` não vale se a mensagem não disser que vale `m` ou `f`.
"""
function simbolo_de(T::Type, raw::AbstractDict, nome::AbstractString, admitidos::Tuple)
    s = Symbol(chave(T, raw, nome))
    s in admitidos && return s
    throw(UndecodableValue(T, raw,
        "`$nome` vale `$s`, e só admite " * join(("`$a`" for a in admitidos), " ou ") * "."))
end

function pessoa_de(raw, ctx)
    raw isa Pessoa && return raw
    raw isa AbstractDict ||
        throw(UndecodableValue(Pessoa, raw, "esperava um objeto com as chaves de `pessoa`."))
    Pessoa(texto_de(Pessoa, raw, "nome", ctx),
           simbolo_de(Pessoa, raw, "genero", (:m, :f)),
           texto_de(Pessoa, raw, "estado_civil", ctx),
           texto_de(Pessoa, raw, "cpf", ctx),
           texto_de(Pessoa, raw, "endereco", ctx);
           regime = texto_de(Pessoa, raw, "regime", ctx; opcional = true),
           nascimento = data_de(Pessoa, raw, "nascimento", ctx; opcional = true))
end

function imovel_de(raw, ctx)
    raw isa Imovel && return raw
    raw isa AbstractDict ||
        throw(UndecodableValue(Imovel, raw, "esperava um objeto com as chaves de `imovel`."))
    area = chave(Imovel, raw, "area"; opcional = true)
    Imovel(texto_de(Imovel, raw, "matricula", ctx),
           simbolo_de(Imovel, raw, "tipo", (:urbano, :rural)),
           texto_de(Imovel, raw, "descricao", ctx);
           area = area === nothing ? nothing :
                  Float64(kanon_decode(Kanon.NumberValue, area, ctx)))
end

function parte_de(raw, ctx)
    raw isa Parte && return raw
    raw isa AbstractDict ||
        throw(UndecodableValue(Parte, raw, "esperava um objeto com as chaves de `parte`."))
    rep = chave(Parte, raw, "representante"; opcional = true)
    Parte(texto_de(Parte, raw, "nome", ctx),
          simbolo_de(Parte, raw, "genero", (:m, :f)),
          texto_de(Parte, raw, "documento", ctx),
          texto_de(Parte, raw, "endereco", ctx);
          empresa = (e = chave(Parte, raw, "empresa"; opcional = true);
                     e === nothing ? false : kanon_decode(Bool, e, ctx)),
          representante = rep === nothing ? nothing : pessoa_de(rep, ctx))
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
