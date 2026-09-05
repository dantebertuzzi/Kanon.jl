# O laço de mensagens.
#
# Nenhuma regra da linguagem mora aqui, pelo mesmo motivo pelo qual nenhuma mora na CLI:
# esta camada decide de onde vêm os bytes e para onde vão, e mais nada.

"O que este servidor sabe fazer. O cliente lê isto e para de perguntar o resto."
const CAPABILITIES = (
    textDocumentSync = (openClose = true, change = 1),        # 1 = o texto inteiro
    documentSymbolProvider = true,
    hoverProvider = true,
    definitionProvider = true,
    completionProvider = (triggerCharacters = ["{", ":", "."],),
)

"""
    serve(; io_in, io_out, env)

Roda o servidor até o cliente mandar `exit`, ou até o fluxo de entrada acabar.

`env` decide quais camadas existem, e o padrão é o núcleo puro — a mesma escolha da CLI,
e pela mesma razão: um servidor que carregasse camadas por conta própria aceitaria um
modelo que o motor recusaria na hora de gerar o documento.
"""
function serve(; io_in::IO = stdin, io_out::IO = stdout,
               env::Kanon.Environment = Kanon.Environment())
    s = Server(io_in, io_out, env)
    while s.running
        msg = read_message(s.io_in)
        msg === nothing && break
        handle!(s, msg)
    end
    return s
end

"""
    handle!(server, msg)

Despacha uma mensagem. Um método desconhecido que seja **pedido** recebe erro; que seja
**aviso** é ignorado em silêncio, porque é isso que o protocolo manda — um cliente manda
avisos que o servidor não anunciou, e responder a eles com erro enche o log de ruído.
"""
function handle!(s::Server, m::Message)
    try
        despachar!(s, m)
    catch e
        e isa InterruptException && rethrow()
        is_request(m) && respond_error(s.io_out, m.id, ERR_INTERNAL,
                                       "kanon-lsp: " * sprint(showerror, e))
    end
    return nothing
end

function despachar!(s::Server, m::Message)
    if m.method == "initialize"
        return respond(s.io_out, m.id,
                       (capabilities = CAPABILITIES,
                        serverInfo = (name = "kanon-lsp",
                                      version = string(Kanon.LANGUAGE_VERSION))))
    elseif m.method == "initialized"
        return nothing
    elseif m.method == "shutdown"
        s.shutdown_requested = true
        return respond(s.io_out, m.id, nothing)
    elseif m.method == "exit"
        s.running = false
        return nothing
    end

    if m.method == "textDocument/didOpen"
        td = m.params.textDocument
        d = open_document!(s, String(td.uri), String(td.text), Int(td.version))
        return publish_diagnostics!(s, d)

    elseif m.method == "textDocument/didChange"
        uri = String(m.params.textDocument.uri)
        d = get(s.docs, uri, nothing)
        d === nothing && return nothing
        mudancas = m.params.contentChanges
        isempty(mudancas) && return nothing
        # `change = 1`: o cliente manda o texto inteiro, e a última mudança é o estado.
        set_text!(s, d, String(last(mudancas).text),
                  Int(get(m.params.textDocument, :version, d.version + 1)))
        return publish_diagnostics!(s, d)

    elseif m.method == "textDocument/didClose"
        uri = String(m.params.textDocument.uri)
        delete!(s.docs, uri)
        notify(s.io_out, "textDocument/publishDiagnostics", (uri = uri, diagnostics = []))
        delete!(s.published, uri)
        return nothing
    end

    is_request(m) || return nothing            # aviso desconhecido: silêncio, de propósito

    d = documento_de(s, m)
    if m.method == "textDocument/documentSymbol"
        return respond(s.io_out, m.id, d === nothing ? [] : document_symbols(d))

    elseif m.method == "textDocument/hover"
        d === nothing && return respond(s.io_out, m.id, nothing)
        l, c = kanon_position(d, m.params.position)
        return respond(s.io_out, m.id, hover(d, l, c))

    elseif m.method == "textDocument/definition"
        d === nothing && return respond(s.io_out, m.id, nothing)
        l, c = kanon_position(d, m.params.position)
        return respond(s.io_out, m.id, definition(s, d, l, c))

    elseif m.method == "textDocument/completion"
        d === nothing && return respond(s.io_out, m.id, [])
        l, c = kanon_position(d, m.params.position)
        return respond(s.io_out, m.id, completion(d, l, c))
    end

    respond_error(s.io_out, m.id, ERR_METHOD_NOT_FOUND, "kanon-lsp não faz `" * m.method * "`.")
end

"O documento a que um pedido se refere, ou `nothing` se ele não está aberto."
function documento_de(s::Server, m::Message)
    m.params === nothing && return nothing
    haskey(m.params, :textDocument) || return nothing
    get(s.docs, String(m.params.textDocument.uri), nothing)
end
