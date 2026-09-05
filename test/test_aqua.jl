# Aqua — as verificações de higiene de pacote (F10).
#
# Duas delas exigiram decisão, e as duas dizem algo sobre a arquitetura:
#
#   **Pirataria de tipo.** Uma camada define `Kanon.format(v::Money, ::Val{:extenso})` —
#   função do núcleo, tipo do núcleo, método de terceiro. Aqua chama isso de pirataria, e
#   pela definição dela está certo. Aqui é o **mecanismo de extensão** (api-extensao.md
#   §1), e o núcleo o oferece de propósito: é o que faz uma camada acrescentar
#   comportamento sem tocar no motor. O que a definição de pirataria protege — ninguém
#   redefine o que não é seu — continua valendo, porque o núcleo *pediu* por esses
#   métodos ao definir a função genérica e o erro padrão dela.
#
#   As verificações rodam sobre o **núcleo**, que não pirateia nada.

using Aqua

@testset "Aqua" begin
    Aqua.test_all(Kanon;
        # `Kanon` não define método sobre tipo alheio: é o contrário — ele define as
        # funções genéricas que as camadas estendem.
        piracies = true,
        ambiguities = (recursive = false,),
    )
end

@testset "a extensão por `Val{nome}` não é pirataria (D-030)" begin
    # `Extenso` define `format(::Money, ::Val{:extenso}, ctx)` — função do núcleo, tipo
    # do núcleo, método de terceiro. Não é pirataria porque `Val{:extenso}` é um tipo da
    # camada: o símbolo é dela, e nenhum outro pacote escreve a mesma assinatura sem
    # inventar o mesmo nome, que é o conflito que o ambiente detecta na construção.
    #
    # Aqui se verifica o lado do núcleo: ele define as genéricas e o erro padrão, e é
    # isso que faz o método da camada ser resposta a um convite, e não invasão.
    for f in (format, kanon_typename, kanon_schema, kanon_attribute, kanon_decode,
              kanon_compare, kanon_getfield, kanon_format_locale)
        @test parentmodule(f) === Kanon
        @test !isempty(methods(f))
    end

    @testset "e o erro padrão existe, que é o convite escrito" begin
        ctx = FormatContext(Environment())
        @test_throws UnknownFormatter format(1, Val(:inexistente), ctx)
        @test_throws UnknownAttribute kanon_attribute(1, Val(:inexistente))
        @test_throws UnregisteredType kanon_typename(Function)
    end
end
