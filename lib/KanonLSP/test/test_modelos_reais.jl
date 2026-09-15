# O servidor com um documento de verdade — o **modelo real nº 13**.
#
# O resto desta suíte usa modelos-brinquedo e um domínio de mentira (`dominio_teste.jl`),
# em inglês canônico, chamando o servidor dentro de um processo que já carregou tudo. Foi
# exatamente a forma que escondeu a D-058 e a D-059 na linha de comando, e escondia aqui
# cinco coisas que só um documento real, uma camada real e o lançador real mostram:
#
#   * **D-065** — o `kanon-lsp --locale pt --domain KanonLegal` morria ao iniciar; e,
#     corrigido isso, subia sem enxergar o esquema de `pessoa`: todo campo de sujeito saía
#     "o contrato não declara `nome`" num modelo que o motor aceita limpo.
#   * **D-066** — o fragmento incluído por dois documentos abertos recebia a lista de
#     diagnósticos de quem falou por último: abrir a procuração apagava o erro que a
#     notificação ainda tinha. E salvar o fragmento não mudava os hospedeiros.
#   * **D-067** — completar depois de `{notificado.` oferecia os campos da raiz e os do
#     sujeito do bloco, e não os de `parte`; `{nome:` num bloco com sujeito não oferecia
#     formatador nenhum.

const RAIZ_K = normpath(joinpath(@__DIR__, "..", "..", ".."))
const EX_R = joinpath(RAIZ_K, "test", "golden", "exemplos")
const ENV_PT = Environment(locale = :pt, domains = [KanonLegal])

"Uma cópia do acervo, para editar em disco sem tocar os goldens."
function acervo_copiado()
    dir = mktempdir()
    cp(EX_R, joinpath(dir, "ex"))
    raiz = realpath(joinpath(dir, "ex"))
    (raiz = raiz,
     notificacao = joinpath(raiz, "notificacao.kanon"),
     procuracao = joinpath(raiz, "procuracao.kanon"),
     fragmento = joinpath(raiz, "fragmentos", "procurador.kanon"))
end

"""
Um servidor dirigido **uma mensagem de cada vez**, pelo enquadramento de verdade.

`rodar!` enfileira tudo e roda de uma vez; aqui o arquivo em disco muda **entre** as
mensagens, que é o que acontece quando o redator salva o fragmento.
"""
mutable struct Passo
    server::KanonLSP.Server
    saida::IOBuffer
    n::Int
end

function Passo(env)
    saida = IOBuffer()
    Passo(KanonLSP.Server(IOBuffer(), saida, env), saida, 0)
end

function mandar!(p::Passo, obj)
    corpo = JSON3.write(obj)
    io = IOBuffer("Content-Length: $(ncodeunits(corpo))\r\n\r\n$corpo")
    KanonLSP.handle!(p.server, KanonLSP.read_message(io))
    ler_todas(String(take!(p.saida)))
end

aviso!(p::Passo, metodo, params) = mandar!(p, (jsonrpc = "2.0", method = metodo, params = params))
function pedido!(p::Passo, metodo, params)
    p.n += 1
    resposta(mandar!(p, (jsonrpc = "2.0", id = p.n, method = metodo, params = params)), p.n)
end

uri_k(caminho) = KanonLSP.uri_of(caminho)
abre!(p::Passo, caminho, texto = read(caminho, String)) =
    aviso!(p, "textDocument/didOpen",
           (textDocument = (uri = uri_k(caminho), languageId = "kanon", version = 1, text = texto),))
muda!(p::Passo, caminho, texto, v) =
    aviso!(p, "textDocument/didChange",
           (textDocument = (uri = uri_k(caminho), version = v), contentChanges = [(text = texto,)]))
salva!(p::Passo, caminho) = aviso!(p, "textDocument/didSave", (textDocument = (uri = uri_k(caminho),),))
fecha!(p::Passo, caminho) = aviso!(p, "textDocument/didClose", (textDocument = (uri = uri_k(caminho),),))

"A última lista publicada para `caminho` nas mensagens, ou `nothing` se não houve."
function publicado(msgs, caminho)
    ps = [m for m in avisos(msgs, "textDocument/publishDiagnostics") if m.params.uri == uri_k(caminho)]
    isempty(ps) ? nothing : last(ps).params.diagnostics
end

"A posição LSP logo depois de `trecho`, na primeira linha que o contém — em caracteres."
function depois_de(texto, trecho)
    for (i, l) in enumerate(split(texto, '\n'))
        j = findfirst(trecho, l)
        j === nothing || return (line = i - 1, character = length(l[1:last(j)]))
    end
    error("`$trecho` não está no texto")
end

function completar!(p::Passo, caminho, texto, trecho)
    r = pedido!(p, "textDocument/completion",
                (textDocument = (uri = uri_k(caminho),), position = depois_de(texto, trecho)))
    [String(i.label) for i in r.result]
end

@testset "o servidor com os modelos reais nº 12 e nº 13" begin
    @testset "a notificação abre limpa, com a camada e o idioma de verdade" begin
        p = Passo(ENV_PT)
        a = acervo_copiado()
        msgs = abre!(p, a.notificacao)
        @test publicado(msgs, a.notificacao) == []
        @test publicado(msgs, a.fragmento) === nothing       # nada a dizer do fragmento

        # os campos do sujeito resolvem: é `pessoa`, lida pelo sujeito do bloco
        texto = read(a.notificacao, String)
        pos = depois_de(texto, "{represent")
        h = pedido!(p, "textDocument/hover", (textDocument = (uri = uri_k(a.notificacao),), position = pos))
        @test occursin("tipo: `pessoa`", h.result.contents.value)
        @test occursin("sujeito do bloco", h.result.contents.value)
    end

    @testset "completar depois do ponto oferece os campos do tipo à esquerda (D-067)" begin
        p = Passo(ENV_PT)
        a = acervo_copiado()
        abre!(p, a.notificacao)
        original = read(a.notificacao, String)

        # `{notificado.` num bloco cujo sujeito é `pessoa`: os campos de `parte`, e só eles
        t = replace(original, "desde {vencimento:corrente}" => "desde {notificado.")
        muda!(p, a.notificacao, t, 2)
        @test completar!(p, a.notificacao, t, "{notificado.") ==
              ["nome", "documento", "endereco", "representante"]

        # `{representante.` pelo sujeito `notificado`: os campos de `pessoa`
        t = replace(original, "seu representante legal, {representante}]" =>
                              "seu representante legal, {representante.")
        muda!(p, a.notificacao, t, 3)
        campos = completar!(p, a.notificacao, t, "{representante.")
        @test "estado_civil" in campos && "cpf" in campos
        @test !("notificante" in campos)                      # a raiz não entra

        # o formatador de uma coleção é o de `list`, como o motor valida
        abre!(p, a.procuracao)
        pr = replace(read(a.procuracao, String), "{especiais}" => "{especiais:")
        muda!(p, a.procuracao, pr, 2)
        fmts = completar!(p, a.procuracao, pr, "{especiais:")
        @test Set(fmts) == Set(String.(Kanon.kanon_formats(Kanon.typefor(ENV_PT, :list), ENV_PT)))
        @test !("upper" in fmts)

        # e o formatador de um campo do sujeito, no fragmento
        abre!(p, a.fragmento)
        f = replace(read(a.fragmento, String), "{nome:upper}" => "{nome:")
        muda!(p, a.fragmento, f, 2)
        @test "upper" in completar!(p, a.fragmento, f, "{nome:")
    end

    @testset "o formatador de outro idioma não se oferece (D-067)" begin
        # o processo tem o `Extenso` carregado; um ambiente neutro não tem idioma
        p = Passo(Environment())
        dir = mktempdir()
        caminho = joinpath(dir, "m.kanon")
        texto = "kanon 1\n\ndata\n  preco : money !\n\ntext\n\n: b\nCusta {preco:\n"
        write(caminho, replace(texto, "{preco:" => "{preco}."))
        abre!(p, caminho, replace(texto, "{preco:" => "{preco}."))
        muda!(p, caminho, texto, 2)
        fmts = completar!(p, caminho, texto, "{preco:")
        @test !isempty(fmts)
        @test !("extenso" in fmts)
    end

    @testset "o fragmento de dois documentos: a soma do que os dois dizem (D-066)" begin
        p = Passo(ENV_PT)
        a = acervo_copiado()
        # um erro que só existe para a notificação: a procuração declara `processo`
        write(a.fragmento, replace(read(a.fragmento, String),
            "[, endereço eletrônico {email}]" =>
            "[, endereço eletrônico {email}][, atuando no processo nº {processo}]"))

        msgs = abre!(p, a.notificacao)
        d = only(publicado(msgs, a.fragmento))
        @test d.code == "K2001"
        @test occursin("Ao ser incluído por `notificacao.kanon`.", d.message)

        # abrir a procuração não apaga o erro que a notificação continua tendo
        msgs = abre!(p, a.procuracao)
        @test publicado(msgs, a.procuracao) == []
        frag = publicado(msgs, a.fragmento)
        @test frag === nothing || length(frag) == 1

        # e editar a procuração também não
        msgs = muda!(p, a.procuracao, read(a.procuracao, String) * "\n", 2)
        frag = publicado(msgs, a.fragmento)
        @test frag === nothing || (length(frag) == 1 && occursin("notificacao.kanon", only(frag).message))

        # fechada a notificação, o erro sai — ele era só dela
        msgs = fecha!(p, a.notificacao)
        @test publicado(msgs, a.fragmento) == []
    end

    @testset "salvar o fragmento republica os hospedeiros (D-066)" begin
        p = Passo(ENV_PT)
        a = acervo_copiado()
        abre!(p, a.procuracao)
        abre!(p, a.notificacao)
        original = read(a.fragmento, String)

        # o mesmo erro nos dois hospedeiros, salvo em disco: os dois nomeados
        errado = replace(original, "{oab}" => "{inscricao}")
        write(a.fragmento, errado)
        msgs = salva!(p, a.fragmento)
        frag = publicado(msgs, a.fragmento)
        @test !isempty(frag)
        # cada hospedeiro diz o erro com o próprio contrato na dica, e cada um é nomeado
        @test any(x -> occursin("`notificacao.kanon`", x.message), frag)
        @test any(x -> occursin("`procuracao.kanon`", x.message), frag)

        # corrigido e salvo, o fragmento limpa sem que ninguém mexa nos hospedeiros
        write(a.fragmento, original)
        msgs = salva!(p, a.fragmento)
        @test publicado(msgs, a.fragmento) == []
        @test publicado(msgs, a.notificacao) == []
        @test publicado(msgs, a.procuracao) == []
    end

    @testset "o kanon-lsp de verdade, num processo novo (D-065)" begin
        # Num processo à parte: esta suíte já carregou `KanonLegal`, e dentro dela os dois
        # defeitos do lançador não existem.
        a = acervo_copiado()
        lancador = joinpath(RAIZ_K, "lib", "KanonLSP", "bin", "kanon-lsp")
        julia = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project())`
        entrada = IOBuffer()
        for obj in ((jsonrpc = "2.0", id = 1, method = "initialize", params = (capabilities = (;),)),
                    (jsonrpc = "2.0", method = "textDocument/didOpen",
                     params = (textDocument = (uri = uri_k(a.notificacao), languageId = "kanon",
                                               version = 1, text = read(a.notificacao, String)),)),
                    (jsonrpc = "2.0", id = 2, method = "shutdown"),
                    (jsonrpc = "2.0", method = "exit"))
            corpo = JSON3.write(obj)
            print(entrada, "Content-Length: ", ncodeunits(corpo), "\r\n\r\n", corpo)
        end
        seekstart(entrada)
        erro = IOBuffer()
        saida = read(pipeline(ignorestatus(`$julia $lancador --locale pt --domain KanonLegal`);
                              stdin = entrada, stderr = erro), String)
        mensagens = String(take!(erro))
        @test !occursin("não tem camada carregada", mensagens)
        @test !occursin("Stacktrace", mensagens)
        msgs = ler_todas(saida)
        @test resposta(msgs, 1).result.serverInfo.name == "kanon-lsp"
        @test publicado(msgs, a.notificacao) == []          # e não oito `K2001`

        r = run(pipeline(ignorestatus(`$julia $lancador --domain KanonInventado`);
                         stdin = IOBuffer(), stderr = erro))
        @test r.exitcode == 3
        texto = String(take!(erro))
        @test occursin("não está disponível", texto)
        @test !occursin("Stacktrace", texto)
    end
end
