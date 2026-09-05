# O certificado de conclusão — **modelo real nº 4** do portão da 1.0.
#
# Escolhido, como o nº 3, pelo que resta vazio. Duas interseções não tinham documento
# nenhum, e este atravessa as duas:
#
#   1. **Português sem camada de domínio.** Todo modelo em português até aqui usava tipos
#      de `KanonLegal`. Este usa só os do núcleo, com os nomes que `Extenso` dá a eles, e
#      o estilo de bloco do próprio núcleo. É a prova, pelo lado do documento, de que
#      `Extenso` é publicável sozinho — o que a docstring dele promete desde a F4.
#   2. **Ingestão de tabela.** `render_each` existia desde a F7 e nenhum modelo real o
#      usava. Um certificado por linha de planilha é exatamente o caso para o qual a
#      inclusão de `Tables.jl` foi escrita.
#
# Cobrou uma coisa, e ela estava escondida atrás de uma restrição que parecia óbvia:
# `K2007` recusava sujeito sem campos, e com isso a **flexão de número era inalcançável**
# para qualquer modelo cujos elementos não fossem compostos (D-040).

const CERTIFICADO = joinpath(RAIZ_KANON, "test", "golden", "exemplos", "certificado.kanon")
const SAIDA_CERT = joinpath(RAIZ_KANON, "test", "golden", "exemplos", "certificado.txt")

const HOJE_C = Date(2026, 9, 5)

"A planilha da turma: duas emissões, uma coletiva e uma individual."
const TURMA = (
    concluintes = [["Ana Beatriz Lima", "Rubens Tavares Filho", "Helena Duarte Pires"],
                   ["Carlos Menezes da Rocha"]],
    curso = fill("Redação de Instrumentos Públicos", 2),
    instituicao = fill("Escola Superior de Notariado", 2),
    carga = [40, 40],
    inicio = fill(Date(2026, 3, 3), 2),
    conclusao = fill(Date(2026, 6, 12), 2),
    conteudo = fill(["escrituras públicas", "procurações", "atas notariais",
                     "reconhecimento de firmas"], 2),
    conceito = ["distinção", nothing],
    registro = [47, 48],
)

@testset "o certificado — modelo real nº 4" begin
    m = load_template(ENV_PT_NU, CERTIFICADO)

    @testset "o modelo carrega sem um único diagnóstico, e sem domínio nenhum" begin
        isempty(m.analysis.diagnostics) ||
            error("o modelo não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(m.analysis.diagnostics)))
        @test isempty(m.analysis.diagnostics)
        @test isempty(m.env.types) == false
        # nenhum tipo de domínio: só os seis do núcleo
        @test length(m.env.types) == 6
    end

    docs = render_each(m, TURMA; today = HOJE_C)

    @testset "um documento por linha da planilha" begin
        @test length(docs) == 2
    end

    @testset "byte a byte, a primeira emissão" begin
        esperado = rstrip(read(SAIDA_CERT, String), '\n')
        docs[1] == esperado || println(docs[1])
        @test docs[1] == esperado
    end

    @testset "a flexão de número vem do sujeito, e o sujeito é uma lista de texto" begin
        # É o que a D-040 destravou. Sem ela, `: corpo <- concluintes` era `K2007` e um
        # modelo sem domínio não flexionava nada.
        @test occursin("alunos regularmente matriculados e considerados aptos", docs[1])
        @test occursin("aluno regularmente matriculado e considerado apto", docs[2])
        @test !occursin("alunos", docs[2])
    end

    @testset "a lista se junta com a conjunção do idioma" begin
        @test occursin("Ana Beatriz Lima, Rubens Tavares Filho e Helena Duarte Pires", docs[1])
        @test occursin("por Carlos Menezes da Rocha,", docs[2])   # um só, sem vírgula nem `e`
        @test occursin("atas notariais e reconhecimento de firmas", docs[1])
    end

    @testset "sem gênero declarado, a marca escapada sai como o autor a escreveu (§7.3)" begin
        # `pelo((a))` é literal de propósito: um `texto` não tem gênero a declarar, e sem
        # o escape a marca sumiria, deixando `pelo` onde o documento quer a forma dupla.
        @test occursin("promovido pelo(a) Escola Superior de Notariado", docs[1])
        @test occursin("promovido pelo(a) Escola Superior de Notariado", docs[2])
    end

    @testset "o grupo do conceito elide na linha que não o tem" begin
        @test occursin("e 12 de junho de 2026, com o conceito distinção.", docs[1])
        @test occursin("e 12 de junho de 2026.", docs[2])
        @test !occursin("conceito", docs[2])
        @test !occursin(", ,", docs[2]) && !occursin("  ", docs[2])
    end

    @testset "extenso, ordinal e data corrente, todos do idioma" begin
        @test occursin("carga horária de quarenta horas", docs[1])
        @test occursin("registro nº quadragésimo sétimo", docs[1])
        @test occursin("registro nº quadragésimo oitavo", docs[2])
        @test occursin("entre 3 de março de 2026 e 12 de junho de 2026", docs[1])
        @test occursin("Petrolina, 5 de setembro de 2026.", docs[1])
    end

    @testset "a numeração é a do núcleo, porque não há estilo de domínio" begin
        @test occursin("1. O conteúdo programático", docs[1])
        @test occursin("2. Este certificado consta", docs[1])
    end

    @testset "a linha que não satisfaz o contrato é nomeada, e nada é gerado" begin
        # `render_each` falha na primeira linha ruim, e não depois de gerar metade.
        ruim = merge(TURMA, (registro = [47, nothing],))
        e = try; render_each(m, ruim; today = HOJE_C); catch err; err; end
        @test e isa KanonContractError
        d = collect(e.diagnostics)[1]
        @test d.code == "K3001"
        @test occursin("linha 2", d.message) || occursin("linha 2", something(d.hint, ""))
    end
end
