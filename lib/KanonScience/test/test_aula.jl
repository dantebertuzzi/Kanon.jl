# O roteiro de aula — **modelo real nº 10** do portão da 1.0.
#
# Escolhido pelo que a **composição** ainda não tinha sofrido. A inclusão existe desde a
# F7 e um único documento a usava: o relatório nº 3, escrito em inglês, sem camada de
# idioma, com um fragmento que traz blocos do mesmo estilo do hospedeiro e que o
# hospedeiro não cita. Quatro interseções estavam vazias, e este documento atravessa as
# quatro:
#
#   1. um fragmento incluído num modelo em **português**;
#   2. **dois estilos de bloco** com contadores independentes, e a fronteira do arquivo
#      passando no meio deles — os teoremas são do hospedeiro, os itens numerados vêm do
#      fragmento;
#   3. uma **remissão a um bloco que o arquivo citante não declara**, ao lado de outra ao
#      próprio hospedeiro, no mesmo parágrafo e com estilos diferentes;
#   4. o marcador `@` num documento em português.
#
# Cobrou três coisas, e a primeira delas não tinha diagnóstico nenhum:
#
#   * **D-054** — `include` era a única palavra-chave sem apelido de idioma, e a linha
#     `incluir "fragmentos/avaliacao.kanon"` não era inclusão nenhuma: virava **prosa**,
#     e o caminho do fragmento saía impresso no documento. O modelo carregava limpo e o
#     `check` passava.
#   * **D-055** — o parser não tinha como avisar: todo `K1xxx` era erro, e erro viaja por
#     exceção. O aviso que a D-054 pedia era descartado entre a leitura e a análise.
#   * **D-056** — `Theorem 1` em qualquer idioma. A camada científica não tem língua, o
#     `Extenso` não conhece domínio nenhum, e o núcleo não tem nem uma coisa nem outra.

const AULA = joinpath(RAIZ, "test", "golden", "exemplos", "aula.kanon")
const EXEMPLOS = joinpath(RAIZ, "test", "golden", "exemplos")
const SAIDA_AULA = joinpath(EXEMPLOS, "aula.txt")

const ENV_AULA = Environment(locale = :pt, domains = [KanonScience])
const HOJE_A = Date(2026, 9, 11)

# Os campos do roteiro e os do fragmento chegam na mesma tabela: quem preenche não sabe
# — nem precisa saber — em que arquivo cada um foi declarado (D-005).
const DADOS_AULA = Dict{String,Any}(
    "instituicao" => "Universidade Federal do Vale do São Francisco",
    "disciplina"  => "Inferência Estatística",
    "codigo"      => "EST0417",
    "turma"       => "2026.2",
    "docente"     => "Aurélio Tavares",
    "monitor"     => "Bianca Nogueira",
    "encontros"   => 16,
    "amostra"     => 1200,
    "variavel"    => "tempo de atendimento, em minutos",
    "estimativa"  => Measure(14.2, 0.08, "min"),
    "referencia"  => Measure(15.0, 0.5, "min"),
    "avaliacoes"  => ["duas provas escritas", "um trabalho computacional",
                      "as listas semanais"],
    "reposicao"   => true,
    "repositorio" => "repositorio.univasf.edu.br/est0417",
)

@testset "o roteiro de aula — modelo real nº 10" begin
    m = load_template(ENV_AULA, AULA)       # a raiz é a do próprio modelo
    saida = render(m, DADOS_AULA; today = HOJE_A)

    @testset "o modelo carrega sem um único diagnóstico" begin
        isempty(m.analysis.diagnostics) ||
            error("o modelo não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(m.analysis.diagnostics)))
        @test isempty(m.analysis.diagnostics)
        @test isempty(check(m, DADOS_AULA; today = HOJE_A))
    end

    @testset "byte a byte" begin
        esperado = rstrip(read(SAIDA_AULA, String), '\n')
        saida == esperado || println(saida)
        @test saida == esperado
    end

    @testset "o rótulo do teorema é do idioma do modelo (D-056)" begin
        @test occursin("Teorema 1. A média amostral", saida)
        @test occursin("Teorema 1.1. A estimativa é precisa", saida)
        @test !occursin("Theorem", saida)

        # e sem camada de idioma a mesma camada escreve o inglês que sempre escreveu:
        # perguntar ao ambiente não é ter idioma
        neutro = load_string(Environment(domains = [KanonScience]), """
            kanon 1

            data
              x : text !

            text

            @@ t
            {x}
            """; name = "n.kanon")
        @test render(neutro, Dict("x" => "a")) == "Theorem 1. a"

        # o glossário é do idioma, e responde o padrão quando ele não tem a palavra
        @test Kanon.term(ENV_AULA, :theorem, "Theorem") == "Teorema"
        @test Kanon.term(ENV_AULA, :corollary, "Corollary") == "Corollary"
        @test Kanon.term(Environment(), :theorem, "Theorem") == "Theorem"
    end

    @testset "duas famílias de contadores, e a fronteira do arquivo no meio delas" begin
        # os teoremas são do hospedeiro; os itens numerados vêm do fragmento, e o
        # contador de cada estilo conta só a sua (§6.2)
        @test occursin("Teorema 2. O intervalo de confiança", saida)
        @test occursin("\n1. O aproveitamento será apurado", saida)
        @test occursin("\n1.1. Haverá prova de reposição", saida)
        @test occursin("\n2. Os conjuntos de dados", saida)
    end

    @testset "a remissão alcança um bloco que o arquivo citante não declara" begin
        # `{::avaliacao}` está escrito no roteiro e o bloco está no fragmento: a remissão
        # só resolve depois da composição, e cada estilo rende a sua forma
        @test occursin("O Teorema 1 será demonstrado no primeiro encontro, e os " *
                       "critérios do item 1 valem para toda a turma.", saida)
        @test !occursin("{::", saida)
    end

    @testset "o fragmento traz o próprio contrato" begin
        # o roteiro não declara `avaliacoes`, `reposicao` nem `repositorio`, e mesmo
        # assim eles são exigidos: os dois contratos foram unificados na carga
        sem = Dict{String,Any}(k => v for (k, v) in DADOS_AULA
                               if k ∉ ("avaliacoes", "repositorio"))
        faltando = Set(d.path for d in check(m, sem; today = HOJE_A))
        @test "avaliacoes" in faltando
        @test "repositorio" in faltando
        # e o que o fragmento declara com valor padrão não é exigido de ninguém
        @test occursin("sob a licença CC BY 4.0", saida)
    end

    @testset "a palavra da inclusão é do idioma do arquivo (D-054)" begin
        fonte = read(AULA, String)
        @test occursin("incluir \"fragmentos/avaliacao.kanon\"", fonte)

        # a forma inglesa some do arquivo que declara um idioma (D-003) — e some sem
        # virar erro de sintaxe: a linha é prosa bem-formada, e é por isso que o
        # silêncio era possível
        ing = replace(fonte, "incluir \"fragmentos" => "include \"fragmentos")
        e = try
            load_string(ENV_AULA, ing; name = "a.kanon", root = EXEMPLOS)
        catch err
            err
        end
        @test e isa KanonReferenceError
        codigos = Set(d.code for d in e.diagnostics)
        @test "K1215" in codigos      # a linha que quis ser inclusão
        @test "K2033" in codigos      # e a remissão que ficou sem bloco
    end

    @testset "a linha que quis ser uma inclusão é avisada, e não recusada (D-055)" begin
        # sem a remissão ao fragmento nada mais quebra, e até aqui o modelo carregava
        # limpo: o caminho do arquivo saía impresso no meio do roteiro, sem um único
        # diagnóstico — a forma mais cara de defeito que este projeto conhece
        fonte = replace(read(AULA, String),
                        ", e os critérios do item {::avaliacao} valem para toda a turma" => "",
                        "incluir \"fragmentos" => "inclua \"fragmentos")
        m2 = load_string(ENV_AULA, fonte; name = "a.kanon", root = EXEMPLOS)
        d = only(filter(x -> x.code == "K1215", collect(m2.analysis.diagnostics)))
        @test d.severity === :warning
        @test occursin("`inclua` não é a palavra que a escreve", d.message)
        @test occursin("vai sair impresso no documento", d.message)
        # a dica escreve a palavra na língua do arquivo (D-051)
        @test occursin("incluir \"fragmentos/avaliacao.kanon\"", something(d.hint, ""))

        # e o aviso é fiel: a linha sai mesmo impressa
        dados = Dict{String,Any}(k => v for (k, v) in DADOS_AULA)
        s = render(m2, dados; today = HOJE_A)
        @test occursin("inclua \"fragmentos/avaliacao.kanon\"", s)

        # a linha com a palavra certa não avisa nada
        @test isempty(m.analysis.diagnostics)
    end

    @testset "sem raiz, o motor não lê arquivo nenhum" begin
        # `load_template` toma o diretório do próprio modelo como raiz — incluir um irmão
        # é o caso normal. Quem carrega de uma cadeia não tem diretório nenhum, e aí a
        # inclusão pede raiz explícita (§11): ler arquivo é a única coisa que o motor faz
        # com o disco, e ele não a faz por conta própria.
        e = try
            load_string(ENV_AULA, read(AULA, String); name = "a.kanon")
        catch err
            err
        end
        @test e isa KanonReferenceError
        @test "K2055" in Set(d.code for d in e.diagnostics)
    end

    @testset "sem a camada científica, o mesmo roteiro é recusado" begin
        e = try
            load_template(Environment(locale = :pt), AULA; root = EXEMPLOS)
        catch err
            err
        end
        @test e isa KanonReferenceError
        codigos = Set(d.code for d in e.diagnostics)
        @test "K2005" in codigos      # o tipo `measure`
        @test "K2030" in codigos      # e o marcador `@`, que é da mesma camada
    end
end
