# A escritura de `docs/exemplos.md` §1 — o alvo da F6.
#
# O modelo e a saída foram escritos na F0, antes de qualquer código, como prova de que a
# gramática funcionava. Ele exercita, num documento só: flexão por marca com sujeitos de
# gêneros distintos, elisão com emenda, bloco repetido, bloco condicional, numeração de
# cláusula por extenso, remissão que renumera, e dinheiro por extenso.

const ESCRITURA = joinpath(RAIZ, "test", "golden", "exemplos", "escritura.kanon")
const SAIDA = joinpath(RAIZ, "test", "golden", "exemplos", "escritura.txt")

const DADOS_ESCRITURA = Dict{String,Any}(
    "vendedor" => [
        Pessoa("João Alves de Souza", :m, "casado", "123.456.789-00",
               "Rua das Acácias, 120, Centro, Petrolina/PE";
               regime = "comunhão parcial de bens"),
        Pessoa("Maria Alves de Souza", :f, "casada", "987.654.321-00",
               "Rua das Acácias, 120, Centro, Petrolina/PE")],
    "comprador" => Pessoa("Ana Beatriz Lima", :f, "solteira", "111.222.333-44",
                          "Avenida Cardoso de Sá, 45, Petrolina/PE"),
    "imovel" => Imovel("12.345", :urbano,
                       "casa residencial situada na Rua do Sol, nº 300, Petrolina/PE"),
    "preco" => Kanon.Money("250000.00", :BRL),
)

@testset "a escritura de exemplos.md §1" begin
    m = load_template(ENV_LEGAL, ESCRITURA)
    saida = render(m, DADOS_ESCRITURA; today = Date(2026, 3, 12))

    @testset "o modelo carrega sem um único diagnóstico" begin
        isempty(m.analysis.diagnostics) ||
            error("o modelo de aceite não analisa limpo:\n" *
                  format_diagnostics(DiagnosticSet(m.analysis.diagnostics)))
        @test isempty(m.analysis.diagnostics)
        @test isempty(check(m, DADOS_ESCRITURA; today = Date(2026, 3, 12)))
    end

    @testset "byte a byte" begin
        esperado = rstrip(read(SAIDA, String), '\n')
        saida == esperado || println(saida)
        @test saida == esperado
    end

    # A tabela "O que cada detalhe da saída prova", de `docs/exemplos.md` §1.3, um a um.
    @testset "camada de idioma: a data por extenso" begin
        @test occursin("aos doze dias do mês de março do ano de dois mil e vinte e seis", saida)
    end

    @testset "flexão com sujeitos singulares de gêneros distintos" begin
        @test occursin("João Alves de Souza, brasileiro, casado, portador do CPF", saida)
        @test occursin("Maria Alves de Souza, brasileira, casada, portadora do CPF", saida)
        @test occursin("residente e domiciliado na", saida)
        @test occursin("residente e domiciliada na", saida)
    end

    @testset "elisão sem vírgula dupla na 2ª vendedora (caso normativo 1)" begin
        @test occursin("Petrolina/PE, doravante denominada OUTORGANTE VENDEDORA;", saida)
        @test !occursin(", ,", saida)
        @test !occursin("  ", saida)
        # e a 1ª, que tem regime, o traz
        @test occursin("sob o regime da comunhão parcial de bens, doravante", saida)
    end

    @testset "grupo misto vira masculino plural" begin
        @test occursin("Os OUTORGANTES VENDEDORES declaram, sob as penas da lei, serem " *
                       "legítimos proprietários", saida)
    end

    @testset "uma marca por palavra; nada além das marcas mudou (D-013)" begin
        # `residente` e `livre` não têm marca, e ficam como o autor escreveu
        @test occursin("residente e domiciliado na", saida)
        @test occursin("livre e desembaraçado de quaisquer ônus", saida)
        @test !occursin("residentes", saida)
        @test !occursin("livres", saida)
    end

    @testset "o rótulo de cláusula: estilo do domínio, ordinal do idioma" begin
        @test occursin("CLÁUSULA PRIMEIRA. Constitui objeto", saida)
        @test occursin("CLÁUSULA SEGUNDA. O preço certo", saida)
        @test occursin("CLÁUSULA TERCEIRA. O imposto", saida)
    end

    @testset "a remissão renumera sozinha" begin
        @test occursin("Conforme o disposto na cláusula segunda", saida)

        # inserir um bloco antes muda o número, e a remissão acompanha
        texto = read(ESCRITURA, String)
        com_extra = replace(texto, "§§ objeto" => "§§ preliminar\nDo objeto.\n\n§§ objeto")
        m2 = load_string(ENV_LEGAL, com_extra; name = "e2.kanon")
        s2 = render(m2, DADOS_ESCRITURA; today = Date(2026, 3, 12))
        @test occursin("Conforme o disposto na cláusula terceira", s2)
    end

    @testset "dinheiro: símbolo e separadores do idioma, valor por extenso" begin
        @test occursin("R\$ 250.000,00 (duzentos e cinquenta mil reais)", saida)
    end

    @testset "as regras: um bloco por vendedor, e a cláusula condicionada" begin
        @test count("OUTORGANTE VENDEDOR", saida) == 2      # dois vendedores, dois blocos
        @test occursin("imposto de transmissão", saida)     # preço > 0

        # sem preço positivo, a cláusula do imposto sai e as outras renumeram
        d = merge(DADOS_ESCRITURA, Dict("preco" => Kanon.Money("0.00", :BRL)))
        s = render(m, d; today = Date(2026, 3, 12))
        @test !occursin("imposto de transmissão", s)
        @test !occursin("CLÁUSULA TERCEIRA", s)
    end
end

@testset "sem as camadas, o mesmo modelo é recusado — nomeando o que falta" begin
    # É o teste de neutralidade em forma de exemplo (`docs/exemplos.md` §1.3, fim).
    texto = read(ESCRITURA, String)

    @testset "no núcleo puro, as palavras-chave em português não existem" begin
        e = try; load_string(Environment(), texto; name = "e.kanon"); catch err; err; end
        @test e isa KanonSyntaxError
        @test "K1006" in [d.code for d in e.diagnostics]     # idioma desconhecido
    end

    @testset "com o idioma, mas sem o domínio, faltam os tipos e o marcador" begin
        e = try
            load_string(Environment(locale = :pt), texto; name = "e.kanon")
        catch err
            err
        end
        @test e isa KanonReferenceError
        codigos = Set(d.code for d in e.diagnostics)
        @test "K2005" in codigos          # `pessoa` e `imovel` desconhecidos
        @test "K2030" in codigos          # o marcador `§` sem estilo

        # e a mensagem nomeia cada um, em vez de dizer "erro"
        texto_erro = sprint(showerror, e)
        @test occursin("pessoa", texto_erro) && occursin("imovel", texto_erro)
        @test occursin(Char(0x00A7), texto_erro)
    end
end
