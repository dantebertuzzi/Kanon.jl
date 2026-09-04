# `analyze` — caminhos, tipos e formatadores (F2.2).
#
# O que esta suíte precisa provar: caminho resolvido nunca entra no nó (I2); a
# resolução em duas etapas do §4.2 não tem precedência silenciosa; e a nulabilidade
# atravessa o tipo composto — sem isso o teorema da lacuna valeria só no primeiro nível.

struct Endereco
    rua::String
    cidade::String
end

struct Pessoa
    nome::String
    conjuge::Union{Nothing,Pessoa}
    endereco::Endereco
    idade::Int
end

Kanon.kanon_typename(::Type{Endereco}) = :address
Kanon.kanon_schema(::Type{Endereco}) = (FieldSpec(:street, :text),
                                        FieldSpec(:city, :text))
Kanon.format(v::Endereco, ::Val{:default}, ctx) = v.rua

Kanon.kanon_typename(::Type{Pessoa}) = :person
Kanon.kanon_schema(::Type{Pessoa}) = (FieldSpec(:name, :text),
                                      FieldSpec(:spouse, :person; optional = true),
                                      FieldSpec(:address, :address),
                                      FieldSpec(:age, :number))
Kanon.format(v::Pessoa, ::Val{:default}, ctx) = v.nome
Kanon.format(v::Pessoa, ::Val{:formal}, ctx) = uppercase(v.nome)

module CamadaPessoas
    using Kanon
    using ..Main: Pessoa, Endereco
    function configure!(b)
        register_type!(b, Pessoa)
        register_type!(b, Endereco)
        return b
    end
end

"O ambiente das análises desta suíte."
const ENVP = Environment(domains = [CamadaPessoas])

"Analisa e devolve a `Analysis`, sem lançar — para inspecionar diagnósticos."
function anl(src::AbstractString; env::Environment = ENVP, name = "t.kanon")
    analyze(env, parse_string(src; name, keywords = env.keywords))
end

"Códigos de referência emitidos por `src`, ordenados."
rcodes(src::AbstractString; env::Environment = ENVP) =
    [d.code for d in anl(src; env).diagnostics]

"A primeira interpolação do primeiro bloco."
first_interp(t::Template) = first(n for n in nodes1(t) if n isa Interp)

"Analisa `src` e devolve `(template, analysis)`."
function anl2(src::AbstractString; env::Environment = ENVP)
    t = parse_string(src; name = "t.kanon", keywords = env.keywords)
    (t, analyze(env, t))
end

const CONTRATO = """
kanon 1

data
  seller    : person !
  buyer     : person
  price     : money  !
  notes     : text
  witnesses : person[2] !
  signed    : boolean = true

text

: preamble
"""

modelo(corpo) = CONTRATO * corpo * "\n"

@testset "analyze: caminhos e tipos" begin
    @testset "um caminho de primeiro nível resolve com tipo, presença e cardinalidade" begin
        t, a = anl2(modelo("O preco e {price}."))
        rp = resolved(a, first_interp(t))
        @test rp.kind === :field
        @test rp.typename === :money
        @test rp.nullable == false          # obrigatório
        @test rp.card.kind === SCALAR
        @test rp.decl == t.data.fields[3].id
        @test isempty(a.diagnostics)
    end

    @testset "campo opcional é nulável; campo com padrão não é" begin
        _, a = anl2(modelo("{notes}"))
        @test resolved(a, first_interp(anl2(modelo("{notes}"))[1])).nullable == true

        t, a = anl2(modelo("{signed}"))
        rp = resolved(a, first_interp(t))
        @test rp.nullable == false          # `= true` preenche, logo não é nulo (§2.1)
        @test rp.typename === :boolean
    end

    @testset "campo de lista guarda a cardinalidade" begin
        t, a = anl2(modelo("{witnesses}"))
        rp = resolved(a, first_interp(t))
        @test rp.typename === :person
        @test Kanon.islist(rp.card)
        @test rp.card.kind === EXACT && rp.card.lo == 2
        @test rp.nullable == false
    end

    @testset "today é constante de data, não campo" begin
        t, a = anl2(modelo("Aos {today}."))
        rp = resolved(a, first_interp(t))
        @test rp.kind === :constant
        @test rp.typename === :date
        @test rp.nullable == false
        @test rp.decl == 0
    end

    @testset "um campo chamado today colide com a constante" begin
        src = """
kanon 1

data
  today : text !

text

: b
{today}
"""
        @test rcodes(src) == ["K2002"]
    end

    @testset "campo desconhecido é erro, com sugestão de nome" begin
        a = anl(modelo("{prise}"))
        @test [d.code for d in a.diagnostics] == ["K2001"]
        d = a.diagnostics[1]
        @test d.category === :reference
        @test occursin("prise", d.message)
        @test occursin("Você quis dizer `price`?", d.hint)
        @test d.path == "prise"
        @test d.line == 14
    end

    @testset "descida por tipo composto" begin
        t, a = anl2(modelo("{seller.name} mora em {seller.address.city}."))
        interps = [n for n in nodes1(t) if n isa Interp]
        @test resolved(a, interps[1]).typename === :text
        @test resolved(a, interps[2]).typename === :text
        @test isempty(a.diagnostics)
    end

    @testset "a nulabilidade atravessa o tipo composto" begin
        # `spouse` é opcional em `person`: tudo abaixo dele é nulável, e é isso que
        # estende o teorema da lacuna além do primeiro nível.
        t, a = anl2(modelo("{seller.spouse.name}"))
        rp = resolved(a, first_interp(t))
        @test rp.nullable == true
        @test rp.typename === :text

        # e o caminho irmão, que não passa por opcional, continua não-nulável
        t, a = anl2(modelo("{seller.address.city}"))
        @test resolved(a, first_interp(t)).nullable == false
    end

    @testset "campo inexistente no composto nomeia o tipo e lista os campos" begin
        a = anl(modelo("{seller.nmae}"))
        @test [d.code for d in a.diagnostics] == ["K2003"]
        d = a.diagnostics[1]
        @test occursin("person", d.message) && occursin("nmae", d.message)
        @test occursin("Você quis dizer `name`?", d.hint)   # transposição conta 1
    end

    @testset "descer em valor sem campos é erro nomeado" begin
        a = anl(modelo("{price.cents}"))
        @test [d.code for d in a.diagnostics] == ["K2004"]
        @test occursin("money", a.diagnostics[1].message)
    end

    @testset "a versão 1 não escolhe item de lista" begin
        a = anl(modelo("{witnesses.name}"))
        @test [d.code for d in a.diagnostics] == ["K2008"]
        @test occursin("one for each", a.diagnostics[1].hint)
    end

    @testset "tipo desconhecido é dito uma vez, na declaração" begin
        src = """
kanon 1

data
  x : measure !

text

: b
{x} e de novo {x} e {x.unit}
"""
        # sem cascata: o erro é da declaração, e os três usos não repetem
        @test rcodes(src) == ["K2005"]
        d = anl(src).diagnostics[1]
        @test d.line == 4
        @test occursin("measure", d.message)
    end
end

@testset "analyze: sujeito do bloco" begin
    @testset "campo do sujeito resolve, e o sujeito mora na tabela, não no nó" begin
        t, a = anl2(modelo("") * """

: grantor <- seller
{name}, de {address.city}.
""")
        b = t.text.blocks[2]
        @test a.paths[Kanon.id(b)].typename === :person     # o sujeito, indexado pelo bloco
        interps = [n for p in b.children for n in p.children if n isa Interp]
        @test resolved(a, interps[1]).kind === :subject_field
        @test resolved(a, interps[1]).typename === :text
        @test resolved(a, interps[2]).typename === :text
        @test isempty(a.diagnostics)
    end

    @testset "sujeito opcional torna nulável tudo que se lê dentro do bloco" begin
        t, a = anl2(modelo("") * """

: b2 <- buyer
{name}
""")
        interps = [n for p in t.text.blocks[2].children for n in p.children if n isa Interp]
        @test resolved(a, interps[1]).nullable == true      # `buyer` é opcional
        # e, por ser nulável, exige grupo — é D-020 em ação
        @test [d.code for d in a.diagnostics] == ["K2012"]
    end

    @testset "fora do bloco com sujeito, o escopo volta ao contrato" begin
        t, a = anl2(modelo("") * """

: g <- seller
{name}

: outro
{price}
""")
        blocos = t.text.blocks
        interps = [n for p in blocos[3].children for n in p.children if n isa Interp]
        @test resolved(a, interps[1]).kind === :field
        @test isempty(a.diagnostics)
    end

    @testset "resolver nos dois escopos é ambiguidade, nunca precedência silenciosa" begin
        src = """
kanon 1

data
  seller : person !
  name   : text   !

text

: g <- seller
{name}
"""
        a = anl(src)
        @test [d.code for d in a.diagnostics] == ["K2002"]
        d = a.diagnostics[1]
        @test occursin("person", d.message)
        @test occursin("seller.name", d.hint)   # a desambiguação que o redator deve escrever
    end

    @testset "sujeito que não existe, e sujeito sem campos" begin
        @test rcodes(modelo("") * "\n: g <- vendedor\n{x}\n")[1] == "K2006"
        @test "K2007" in rcodes(modelo("") * "\n: g <- price\n{x}\n")
    end

    @testset "campo que não existe em nenhum dos dois escopos nomeia os dois" begin
        a = anl(modelo("") * "\n: g <- seller\n{nada}\n")
        @test [d.code for d in a.diagnostics] == ["K2001"]
        d = a.diagnostics[1]
        @test occursin("person", d.message) && occursin("contrato", d.message)
        @test occursin("spouse", d.hint) && occursin("price", d.hint)
    end

    @testset "no bloco com sujeito, um caminho que só falha fundo aponta o escopo certo" begin
        # `name` existe no sujeito; `nmae` não — a mensagem fala de `person`, não do contrato
        a = anl(modelo("") * "\n: g <- seller\n{spouse.nmae}\n")
        @test [d.code for d in a.diagnostics] == ["K2003"]
        @test occursin("person", a.diagnostics[1].message)
    end
end

@testset "analyze: formatadores" begin
    @testset "o formatador efetivo é :default quando o modelo não nomeia nenhum" begin
        t, a = anl2(modelo("{price}"))
        @test formatter(a, first_interp(t)) === :default
        t, a = anl2(modelo("{price:code}"))
        @test formatter(a, first_interp(t)) === :code
        @test isempty(a.diagnostics)
    end

    @testset "formatador inexistente é erro aqui, sem dados, com a lista dos que há" begin
        a = anl(modelo("{price:written}"))
        @test [d.code for d in a.diagnostics] == ["K2020"]
        d = a.diagnostics[1]
        @test occursin("written", d.message) && occursin("money", d.message)
        @test occursin("code", d.hint) && occursin("plain", d.hint) && occursin("symbol", d.hint)
    end

    @testset "escrever :default é erro: o padrão se pede escrevendo {price}" begin
        @test rcodes(modelo("{price:default}")) == ["K2020"]
    end

    @testset "um campo de lista é formatado como lista, não como o tipo do item" begin
        @test isempty(anl(modelo("{witnesses:count}")).diagnostics)
        a = anl(modelo("{witnesses:formal}"))      # `formal` existe em `person`, não em `list`
        @test [d.code for d in a.diagnostics] == ["K2020"]
        @test occursin("list", a.diagnostics[1].message)
        # e o mesmo formatador vale no campo escalar do mesmo tipo
        @test isempty(anl(modelo("{seller:formal}")).diagnostics)
    end

    @testset "a sugestão aponta o formatador próximo" begin
        d = anl(modelo("{price:cod}")).diagnostics[1]
        @test occursin("Você quis dizer `code`?", d.hint)
    end

    @testset "formatador de tipo sem formatador nomeado" begin
        d = anl(modelo("{signed:sim}")).diagnostics[1]
        @test d.code == "K2020"
        @test occursin("boolean", d.hint)
    end
end

@testset "analyze: caminhos do plano das regras" begin
    @testset "regra resolve contra o contrato, sem sujeito" begin
        src = modelo("{price}") * """

: outro
texto

rules
  outro when notes is present
"""
        t, a = anl2(src)
        r = t.rules.rules[1]
        @test isempty(a.diagnostics)
        @test resolved(a, r.when).typename === :text
    end

    @testset "campo inexistente numa regra é erro de referência" begin
        src = modelo("{price}") * """

: outro
texto

rules
  outro when observacoes is present
"""
        @test rcodes(src) == ["K2001"]
    end

    @testset "one for each resolve o caminho iterado" begin
        src = modelo("{price}") * """

: cada <- witnesses
{name}

rules
  cada one for each witnesses
"""
        t, a = anl2(src)
        @test isempty(a.diagnostics)
        rp = resolved(a, t.rules.rules[1])
        @test rp.typename === :person && Kanon.islist(rp.card)
    end
end

@testset "analyze: invariantes" begin
    fonte = modelo("{seller.name} paga {price:code} em {today}.") * """

: g <- seller
{name}, de {address.city}[, casado com {spouse.name}].
"""

    @testset "I2 — nenhum resultado de análise entra no nó" begin
        t, a = anl2(fonte)
        antes = dump_tree(t)
        analyze(ENVP, t)
        @test dump_tree(t) == antes                # analyze não muta a árvore
        for n in nodes1(t)
            n isa Interp || continue
            for proibido in (:type, :typename, :nullable, :resolved, :card)
                @test !(proibido in fieldnames(typeof(n)))
            end
        end
        # as tabelas são Vector indexado por NodeId, nunca Dict (I4)
        @test a.paths isa Vector
        @test a.formatter isa Vector
        @test length(a.paths) == t.nnodes
    end

    @testset "analisar duas vezes dá a mesma análise" begin
        t = parse_string(fonte; name = "t.kanon", keywords = ENVP.keywords)
        a1, a2 = analyze(ENVP, t), analyze(ENVP, t)
        @test a1.paths == a2.paths
        @test a1.formatter == a2.formatter
        @test a1.block_index == a2.block_index
    end

    @testset "o mesmo modelo em dois ambientes dá duas análises" begin
        t = parse_string(fonte; name = "t.kanon", keywords = ENVP.keywords)
        com = analyze(ENVP, t)
        sem = analyze(Environment(), t)             # núcleo puro: `person` não existe
        @test isempty(com.diagnostics)
        @test !isempty(sem.diagnostics)
        @test "K2005" in [d.code for d in sem.diagnostics]
    end

    @testset "os erros são acumulados e ordenados por linha (§10.3)" begin
        a = anl(modelo("{prise} e {seller.nmae} e {price:written}"))
        @test length(a.diagnostics) == 3
        @test issorted([(d.line, d.col, d.code) for d in a.diagnostics])
        @test Set(d.code for d in a.diagnostics) == Set(["K2001", "K2003", "K2020"])
    end

    @testset "o índice de blocos é ordenado por nome, e não é Dict" begin
        _, a = anl2(fonte)
        @test a.block_index isa Vector{Pair{Symbol,NodeId}}
        @test issorted(a.block_index; by = first)
        @test Set(first.(a.block_index)) == Set([:preamble, :g])
    end

    @testset "as tabelas das fases seguintes existem e estão vazias" begin
        _, a = anl2(fonte)
        @test any(a.guarded)                        # há um grupo na fonte
        @test isempty(a.numbering)                  # F5
        @test isempty(a.block_rule) && isempty(a.block_foreach)
    end
end

@testset "load_string e load_template" begin
    @testset "modelo bom devolve um Model reutilizável" begin
        m = load_string(ENVP, modelo("{price} para {seller.name}."))
        @test m isa Model
        @test m.env === ENVP
        @test m.template isa Template
        @test m.analysis isa Analysis
        @test isempty(m.analysis.diagnostics)
    end

    @testset "erro de referência lança, com o formato da §10.4" begin
        e = try; load_string(ENVP, modelo("{prise}")); catch err; err; end
        @test e isa KanonReferenceError
        texto = sprint(showerror, e)
        @test occursin("referência", texto)
        @test occursin("[K2001]", texto)
        @test occursin("linha 14", texto)
    end

    @testset "erro de sintaxe suprime a análise: não há árvore para validar" begin
        e = try; load_string(ENVP, "kanon 1\n\ntext\n\n: b\n{prise\n"); catch err; err; end
        @test e isa KanonSyntaxError
    end

    @testset "load_template lê do disco" begin
        caminho = joinpath(mktempdir(), "m.kanon")
        write(caminho, modelo("{price}"))
        m = load_template(ENVP, caminho)
        @test m isa Model
        @test m.template.sources[1] == caminho
    end
end
