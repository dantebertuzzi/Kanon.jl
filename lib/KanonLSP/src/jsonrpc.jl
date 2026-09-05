# JSON-RPC 2.0 sobre stdio, no enquadramento que o LSP usa.
#
# Uma mensagem é `Content-Length: N\r\n\r\n` seguido de N **bytes** de JSON UTF-8. O N é
# de bytes, e não de caracteres: um cabeçalho contado em caracteres funciona em inglês e
# trava no primeiro `ã`, com o servidor esperando bytes que nunca chegam.

"O que um cliente mandou: um pedido (tem `id`) ou um aviso (não tem)."
struct Message
    method::String
    id::Union{Nothing,Int,String}
    params::Any
end

is_request(m::Message) = m.id !== nothing

"""
    read_message(io) -> Message | nothing

Lê uma mensagem enquadrada. `nothing` no fim do fluxo — que é como um editor encerra o
servidor quando o processo dele morre sem `exit`.

Cabeçalhos que não sejam `Content-Length` são ignorados: o `Content-Type` é opcional na
especificação e nenhum cliente concorda sobre ele.
"""
function read_message(io::IO)
    n = -1
    while true
        eof(io) && return nothing
        linha = readline(io)
        isempty(strip(linha)) && break                  # a linha em branco fecha o cabeçalho
        campo, _, valor = partition_header(linha)
        lowercase(campo) == "content-length" && (n = something(tryparse(Int, strip(valor)), -1))
    end
    n < 0 && return nothing

    bytes = read(io, n)
    length(bytes) == n || return nothing
    obj = JSON3.read(String(bytes))

    haskey(obj, :method) || return nothing              # é resposta a algo que não pedimos
    Message(String(obj.method),
            haskey(obj, :id) ? (obj.id isa Integer ? Int(obj.id) : String(obj.id)) : nothing,
            haskey(obj, :params) ? obj.params : nothing)
end

function partition_header(linha::AbstractString)
    i = findfirst(':', linha)
    i === nothing ? (linha, "", "") : (linha[1:(i - 1)], ":", linha[(i + 1):end])
end

"Escreve uma mensagem enquadrada. O `Content-Length` conta **bytes**."
function write_message(io::IO, obj)
    corpo = JSON3.write(obj)
    print(io, "Content-Length: ", ncodeunits(corpo), "\r\n\r\n")
    print(io, corpo)
    flush(io)
    return nothing
end

respond(io::IO, id, result) =
    write_message(io, (jsonrpc = "2.0", id = id, result = result))

"Os códigos de erro que o LSP usa; os demais nunca apareceram aqui."
const ERR_METHOD_NOT_FOUND = -32601
const ERR_INTERNAL = -32603
const ERR_REQUEST_FAILED = -32803

respond_error(io::IO, id, code::Int, message::AbstractString) =
    write_message(io, (jsonrpc = "2.0", id = id,
                       error = (code = code, message = String(message))))

notify(io::IO, method::AbstractString, params) =
    write_message(io, (jsonrpc = "2.0", method = String(method), params = params))
