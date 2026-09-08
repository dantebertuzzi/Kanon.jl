# O edital de pregão — **modelo real nº 6** do portão da 1.0.
#
# Escolhido pelo que a numeração ainda não tinha sofrido. Os cinco modelos anteriores
# numeram em um ou dois níveis e remetem sempre a bloco de nível 1, cujo número é o mesmo
# em toda execução. Um edital não se escreve assim: ele é uma árvore de itens, e o corpo
# dele remete a item aninhado o tempo todo.
#
# Quatro interseções estavam vazias, e este documento atravessa as quatro:
#
#   1. **Nível 3** (`::::`), que a §6.1 admite desde a versão 1 e que nenhum documento
#      tinha usado.
#   2. **Remissão a bloco aninhado**: `{::certidoes}` rende `2.1.1`, três componentes.
#   3. **Bloco numerado repetido dentro de outro numerado**: um item por lote, em nível 2
#      sob o item do objeto.
#   4. **Uma remissão cujo número depende dos dados**: `{::julgamento}` vem depois dos
#      lotes, e vale `1.4` com três lotes e `1.2` com um.
#
# Cobrou duas, e as duas estavam na interseção de coisas testadas em separado:
#
#   * **D-043** — `{lotes}` dentro do bloco repetido rendia a **coleção inteira** em cada
#     iteração, contra a §8.3, que diz que o identificador denota o elemento corrente.
#     Escrito pelo caminho iterado, um campo do elemento (`{socios.nome}`) nem chegava a
#     render: estourava um `FieldError` de Julia sobre `Array`.
#   * **D-044** — o rótulo do bloco, única parte do documento que o motor calcula, era a
#     única que o formato de saída não protegia: `1. ` no começo da linha é marcador de
#     lista em Markdown **e** enumeração explícita em Typst, e o número apurado passava a
#     ser um número do renderizador enquanto a remissão da prosa apontava para o antigo.

const EDITAL = joinpath(RAIZ_KANON, "test", "golden", "exemplos", "edital.kanon")
const SAIDA_EDITAL = joinpath(RAIZ_KANON, "test", "golden", "exemplos", "edital.txt")
const SAIDA_EDITAL_TYP = joinpath(RAIZ_KANON, "test", "golden", "exemplos", "edital.typ")

const HOJE_E = Date(2026, 9, 5)

const DADOS_EDITAL = Dict{String,Any}(
    "orgao" => "Município de Petrolina",
    "pregao" => "037/2026",
    "processo" => "23.456/2026",
    "objeto" => "o registro de preços para aquisição de material de expediente",
    "lotes" => ["papelaria", "suprimentos de informática", "mobiliário de escritório"],
    "valor" => Kanon.Money("250000.00", :BRL),
    "garantia" => Kanon.Money("12500.00", :BRL),
    "contato" => "licitacao@petrolina.pe.gov.br",
    "sessao" => Date(2026, 10, 6),
    "entrega" => 15,
    "recurso" => 3,
    "amostra" => "uma unidade de cada item, entregue no protocolo em até dois dias úteis",
)

@testset "o edital de pregão — modelo real nº 6" begin
    m = load_template(ENV_PT_NU, EDITAL)
    saida = render(m, DADOS_EDITAL; today = HOJE_E)

    @testset "o modelo carrega sem um único diagnóstico, e sem domínio nenhum" begin
        isempty(m.analysis.diagnostics) ||
            error("o modelo não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(m.analysis.diagnostics)))
        @test isempty(m.analysis.diagnostics)
        @test isempty(check(m, DADOS_EDITAL; today = HOJE_E))
        @test length(m.env.types) == 6          # só os do núcleo
    end

    @testset "byte a byte, em texto" begin
        esperado = rstrip(read(SAIDA_EDITAL, String), '\n')
        saida == esperado || println(saida)
        @test saida == esperado
    end

    @testset "byte a byte, em Typst" begin
        s = render(m, DADOS_EDITAL; today = HOJE_E, to = :typst)
        esperado = rstrip(read(SAIDA_EDITAL_TYP, String), '\n')
        s == esperado || println(s)
        @test s == esperado
    end

    @testset "o caminho iterado é o elemento, e não a coleção (D-043, §8.3)" begin
        # Os três lotes saem diferentes. Antes, cada iteração rendia a lista inteira —
        # em silêncio, que é a pior forma de estar errado.
        @test occursin("1.1. Compõe o objeto o lote papelaria,", saida)
        @test occursin("1.2. Compõe o objeto o lote suprimentos de informática,", saida)
        @test occursin("1.3. Compõe o objeto o lote mobiliário de escritório,", saida)
        @test !occursin("lote papelaria, suprimentos de informática e mobiliário", saida)
    end

    @testset "o nível 3 numera, e a remissão a ele tem três componentes" begin
        @test occursin("2.1. A habilitação jurídica", saida)
        @test occursin("2.1.1. As certidões apresentadas", saida)
        @test occursin("as certidões do item 2.1.1", saida)
    end

    @testset "o número depois dos repetidos é dos dados, e a remissão acompanha" begin
        # Três lotes empurram `julgamento` para 1.4; um lote o deixa em 1.2. O número não
        # existe antes de haver dados, e por isso a remissão sai do plano, não da análise.
        @test occursin("1.4. O julgamento far-se-á", saida)
        @test occursin("O critério do item 1.4,", saida)

        um = merge(DADOS_EDITAL, Dict{String,Any}("lotes" => ["papelaria"]))
        s = render(m, um; today = HOJE_E)
        @test occursin("1.2. O julgamento far-se-á", s)
        @test occursin("O critério do item 1.2,", s)
        @test !occursin("1.3.", s)
    end

    @testset "o bloco condicional removido não consome número (§6.2)" begin
        sem = copy(DADOS_EDITAL)
        delete!(sem, "amostra")
        delete!(sem, "garantia")
        s = render(m, sem; today = HOJE_E)
        @test !occursin("amostra do objeto", s) && !occursin("garantia de execução", s)
        @test occursin("2.2. A regularidade fiscal", s)
        @test !occursin("2.3.", s)
        # e o que vem depois não se desloca: os contadores de nível 2 zeram por pai
        @test occursin("3.1. O objeto será entregue", s)
        @test occursin("o prazo do item 3.1", s)
    end

    @testset "o rótulo sai com o número que o motor apurou (D-044)" begin
        md = render(m, DADOS_EDITAL; today = HOJE_E, to = :markdown)
        typ = render(m, DADOS_EDITAL; today = HOJE_E, to = :typst)
        # Markdown: a barra vai antes do ponto; Typst: antes do dígito.
        @test occursin("1\\. Constitui objeto", md)
        @test occursin("1\\.1. Compõe o objeto", md)
        @test occursin("\\1. Constitui objeto", typ)
        @test occursin("\\1.1. Compõe o objeto", typ)
        # em texto puro não há marcação a desarmar, e o rótulo sai como sempre saiu
        @test occursin("1. Constitui objeto", saida)
    end

    @testset "no Typst o valor é escapado e a prosa do autor não" begin
        typ = render(m, DADOS_EDITAL; today = HOJE_E, to = :typst)
        @test occursin("licitacao\\@petrolina.pe.gov.br", typ)   # `@` abre remissão lá
        @test occursin("R\\\$ 250.000,00", typ)                  # `\$` abre matemática
        @test occursin("(duzentos e cinquenta mil reais)", typ)  # a prosa, intacta
        @test occursin("licitacao@petrolina.pe.gov.br", saida)   # e em texto, nada muda
    end

    @testset "extenso e ordinal do idioma, num modelo sem camada de domínio" begin
        @test occursin("prazo de quinze dias", saida)
        @test occursin("prazo de três dias úteis", saida)
        @test occursin("R\$ 12.500,00 (doze mil e quinhentos reais)", saida)
        @test occursin("6 de outubro de 2026", saida)
    end

    @testset "remeter a bloco repetido é recusado, e a mensagem diz por quê (K2034)" begin
        fonte = replace(read(EDITAL, String),
                        "O critério do item {::julgamento}" => "O critério do item {::lote}")
        e = try; load_string(ENV_PT_NU, fonte; name = "e.kanon"); catch err; err; end
        @test e isa KanonReferenceError
        d = collect(e.diagnostics)[1]
        @test d.code == "K2034"
        @test occursin("não há como nomear uma das cópias", d.message)
    end
end
