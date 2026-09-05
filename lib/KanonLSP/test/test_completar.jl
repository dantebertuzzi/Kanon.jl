# Completar.
#
# O ponto que a suíte tem de provar: as sugestões saem do **modelo**, e não de uma
# varredura de texto. Um formatador que não existe para aquele tipo não aparece; um campo
# do sujeito aparece só dentro do bloco que tem sujeito. Uma completação que só soubesse
# procurar palavras no arquivo sugeriria `extenso` para um `text` e ninguém notaria até o
# render falhar.

const MODELO_COMPLETAR = """
kanon 1

data
  seller : text  !
  price  : money !

text

: preamble <- seller
Preâmbulo.

:: payment
O pagamento.

rules
  payment  when price is positive
"""

"""
As sugestões na linha `l` e coluna `c` (1-based), como pares rótulo => detalhe.

A sessão imita o que um editor faz, e a ordem importa: abre o arquivo **como ele estava**
— analisando —, avisa a mudança que o redator acabou de digitar, e só então pede a
sugestão. Pedir sobre um arquivo que nunca analisou é uma situação que não existe no uso
real, e testá-la assim esconderia que a completação depende da última análise boa.
"""
function completar(base, digitando, l, c; env = Kanon.Environment())
    s = sessao_com(base)
    avisar!(s, "textDocument/didChange",
            (textDocument = (uri = "file:///tmp/t.kanon", version = 2),
             contentChanges = [(text = digitando,)]))
    id = pedir!(s, "textDocument/completion",
                (textDocument = (uri = "file:///tmp/t.kanon",),
                 position = pos(l - 1, c - 1)))
    [String(x.label) => String(x.detail) for x in resposta(rodar!(s; env = env), id).result]
end

"O mesmo, quando o texto em que se pede a sugestão já analisa."
completar(texto, l, c; env = Kanon.Environment()) = completar(texto, texto, l, c; env = env)

"O modelo com uma linha do plano do texto substituída pelo que está sendo digitado."
digitando(base, linha) = replace(base, "Preâmbulo." => linha)

rotulos(cs) = [first(x) for x in cs]

@testset "completar" begin
    @testset "dentro de `{`, os campos do contrato" begin
        # `Preâmbulo.` vira `{` no fim: a linha não analisa, e é justamente aí que se pede
        cs = completar(MODELO_COMPLETAR, digitando(MODELO_COMPLETAR, "Preâmbulo de {"), 10, 15)
        @test "seller" in rotulos(cs)
        @test "price" in rotulos(cs)
        @test "::" in rotulos(cs)
        @test Dict(cs)["price"] == "money !"
    end

    @testset "e os campos do sujeito, marcados como tais" begin
        # O bloco tem `<- seller`, de tipo `text`, que é escalar e não tem esquema: um
        # sujeito composto traz os campos dele. Aqui o teste usa um domínio de mentira.
        texto = """
        kanon 1

        data
          p : pessoa !

        text

        : b <- p
        Nome: {
        """
        cs = completar(replace(texto, "Nome: {" => "Nome:"), texto, 9, 8; env = ENV_TESTE)
        @test "nome" in rotulos(cs)
        @test occursin("do sujeito", Dict(cs)["nome"])
        @test occursin("opcional no sujeito", Dict(cs)["apelido"])
    end

    @testset "depois de `:`, só os formatadores daquele tipo" begin
        cs = completar(MODELO_COMPLETAR, digitando(MODELO_COMPLETAR, "Custa {price:"), 10, 14)
        # `default` não entra: `kanon_formats` o exclui de propósito, e `{price:default}`
        # não é forma que o modelo escreva — o padrão se pede omitindo o formatador.
        @test Set(rotulos(cs)) == Set(["code", "plain", "symbol"])
        @test !("upper" in rotulos(cs))          # `upper` é de `text`, e o campo é `money`

        cs2 = completar(MODELO_COMPLETAR, digitando(MODELO_COMPLETAR, "Quem: {seller:"), 10, 15)
        @test "upper" in rotulos(cs2)
        @test !("symbol" in rotulos(cs2))
    end

    @testset "depois de `{::`, só os blocos numerados" begin
        cs = completar(MODELO_COMPLETAR, digitando(MODELO_COMPLETAR, "Ver {::"), 10, 8)
        @test rotulos(cs) == ["::payment"]        # `preamble` é `:`, e não tem número
        @test occursin("hoje é 1", Dict(cs)["::payment"])
    end

    @testset "no plano de dados, depois do `:`, os tipos deste ambiente" begin
        cs = completar(MODELO_COMPLETAR,
                       replace(MODELO_COMPLETAR, "  price  : money !" => "  price  : "), 5, 12)
        @test "money" in rotulos(cs) && "date" in rotulos(cs)
        @test !("seller" in rotulos(cs))
    end

    @testset "no plano das regras, os blocos que ainda não têm regra" begin
        texto = MODELO_COMPLETAR * "  "
        cs = completar(texto, 17, 3)
        @test "preamble" in rotulos(cs)
        @test !("payment" in rotulos(cs))         # esse já tem
    end

    @testset "e as palavras-chave, na forma escrita do arquivo" begin
        cs = completar(MODELO_COMPLETAR, 16, 12)
        @test "when" in rotulos(cs) && "present" in rotulos(cs)
    end

    @testset "`{{` é chave literal e não abre completação" begin
        @test isempty(completar(MODELO_COMPLETAR,
                                digitando(MODELO_COMPLETAR, "Literal {{"), 10, 11))
    end

    @testset "depois de `}` a interpolação fechou" begin
        @test isempty(completar(MODELO_COMPLETAR,
                                digitando(MODELO_COMPLETAR, "Fim {seller} "), 10, 14))
    end

    @testset "um arquivo que nunca analisou não tem o que oferecer, e não quebra" begin
        @test isempty(completar("kanon 1\n\ntext\n\n: b\n{", 6, 2))
    end

    @testset "a sugestão vem da última análise boa, e não da corrente" begin
        # É a razão de `last_model` existir: no instante em que alguém pede a sugestão, o
        # que ele digitou é `{`, e o arquivo não analisa. Um servidor que consultasse só a
        # análise corrente não sugeriria nada nunca.
        quebrado = digitando(MODELO_COMPLETAR, "Preâmbulo de {")
        @test Kanon.load_source(Kanon.Environment(), quebrado; name = "t").model === nothing
        @test "seller" in rotulos(completar(MODELO_COMPLETAR, quebrado, 10, 15))
    end
end
