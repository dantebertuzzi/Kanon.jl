# Dirigir o servidor **pelo protocolo**, e não pelas funções internas.
#
# É a única forma de teste que prova o que interessa: um editor de verdade fala JSON-RPC
# enquadrado, e um servidor cujas funções passam mas cujo enquadramento erra não serve
# para nada. Por isso a suíte monta as mensagens, escreve os bytes, e lê os bytes de
# volta.

"Uma sessão: escreve mensagens num buffer, roda o servidor, e devolve o que ele escreveu."
mutable struct Sessao
    entrada::IOBuffer
    saida::IOBuffer
    n::Int
end

Sessao() = Sessao(IOBuffer(), IOBuffer(), 0)

"Enfileira um pedido e devolve o `id` dele."
function pedir!(s::Sessao, metodo::AbstractString, params = nothing)
    s.n += 1
    enquadrar!(s, (jsonrpc = "2.0", id = s.n, method = metodo, params = params))
    s.n
end

avisar!(s::Sessao, metodo::AbstractString, params = nothing) =
    enquadrar!(s, (jsonrpc = "2.0", method = metodo, params = params))

function enquadrar!(s::Sessao, obj)
    corpo = JSON3.write(obj)
    print(s.entrada, "Content-Length: ", ncodeunits(corpo), "\r\n\r\n", corpo)
    return nothing
end

"Roda o servidor sobre o que foi enfileirado e devolve as mensagens que ele emitiu."
function rodar!(s::Sessao; env = Kanon.Environment())
    seekstart(s.entrada)
    KanonLSP.serve(io_in = s.entrada, io_out = s.saida, env = env)
    ler_todas(String(take!(s.saida)))
end

"Desenquadra tudo o que o servidor escreveu. Falha se um `Content-Length` não bater."
function ler_todas(bruto::AbstractString)
    out = Any[]
    bytes = Vector{UInt8}(bruto)
    i = 1
    while i <= length(bytes)
        cabecalho = findfirst(Vector{UInt8}("\r\n\r\n"), @view bytes[i:end])
        cabecalho === nothing && break
        texto = String(@view bytes[i:(i + first(cabecalho) - 2)])
        n = parse(Int, match(r"Content-Length:\s*(\d+)"i, texto).captures[1])
        ini = i + last(cabecalho)
        push!(out, JSON3.read(String(@view bytes[ini:(ini + n - 1)])))
        i = ini + n
    end
    out
end

"A resposta ao pedido `id`."
resposta(msgs, id) = msgs[findfirst(m -> get(m, :id, nothing) == id, msgs)]

"Todos os avisos de método `metodo`."
avisos(msgs, metodo) = [m for m in msgs if get(m, :method, nothing) == metodo]

"Abre um documento e devolve a sessão pronta, já com o `initialize` feito."
function sessao_com(texto::AbstractString; uri = "file:///tmp/t.kanon")
    s = Sessao()
    pedir!(s, "initialize", (capabilities = (;),))
    avisar!(s, "initialized", (;))
    avisar!(s, "textDocument/didOpen",
            (textDocument = (uri = uri, languageId = "kanon", version = 1, text = texto),))
    s
end

"Posição LSP: linha e coluna 0-based."
pos(l, c) = (line = l, character = c)

"Um pedido posicional sobre o documento aberto."
em(s::Sessao, metodo, l, c; uri = "file:///tmp/t.kanon") =
    pedir!(s, metodo, (textDocument = (uri = uri,), position = pos(l, c)))
