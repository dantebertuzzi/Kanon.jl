# O servidor do gerador de minutas.
#
#     julia --project servidor.jl            http://127.0.0.1:8080
#     PORTA=9000 julia --project servidor.jl
#
# Escuta só na própria máquina. Expor o motor é seguro pelo que a §11 já garante — sem
# código, sem I/O, sem rede, orçamento contado (D-010) —, mas um servidor público pede
# ainda limite por origem e TLS, que não são assunto de um exemplo.

using HTTP, JSON3
isdefined(@__MODULE__, :Minutas) || include(joinpath(@__DIR__, "motor.jl"))
using .Minutas

const PAGINA = joinpath(@__DIR__, "pagina.html")
const LIMITE_DO_CORPO = 512 * 1024

json(status, x) = HTTP.Response(status, ["Content-Type" => "application/json; charset=utf-8"], JSON3.write(x))
erro(status, mensagem) = json(status, (; erro = mensagem))

function rotear(req::HTTP.Request)
    uri = HTTP.URI(req.target)
    caminho = uri.path

    if req.method == "GET" && caminho == "/"
        return HTTP.Response(200, ["Content-Type" => "text/html; charset=utf-8"], read(PAGINA))
    end
    if req.method == "GET" && caminho == "/api/modelos"
        return json(200, [(; e.id, e.titulo, e.descricao) for e in catalogo()])
    end

    m = match(r"^/api/modelos/([a-z0-9_]+)/(contrato|exemplo|previa|documento)$", caminho)
    m === nothing && return erro(404, "não há nada em $caminho")
    e = Minutas.entrada(m[1])
    e === nothing && return erro(404, "não há modelo `$(m[1])` no catálogo")
    acao = m[2]

    if req.method == "GET"
        acao == "contrato" && return HTTP.Response(200, ["Content-Type" => "application/json; charset=utf-8"], contrato(e))
        acao == "exemplo" && return HTTP.Response(200, ["Content-Type" => "application/json; charset=utf-8"], exemplo(e))
        return erro(405, "`$acao` se pede com POST")
    end

    req.method == "POST" || return erro(405, "método $(req.method) não é aceito aqui")
    length(req.body) > LIMITE_DO_CORPO && return erro(413, "os dados passam de $(LIMITE_DO_CORPO ÷ 1024) KiB")
    dados = try
        ler_dados(String(req.body))
    catch err
        return erro(400, "o corpo não é JSON: " * sprint(showerror, err))
    end
    dados isa AbstractDict || return erro(400, "o corpo é um objeto JSON")

    if acao == "previa"
        return json(200, previa(e, dados))
    elseif acao == "documento"
        formato = get(HTTP.queryparams(uri), "formato", "md")
        r = documento(e, dados, formato)
        r.ok || return json(422, (; problemas = r.problemas))
        return HTTP.Response(200, ["Content-Type" => r.tipo,
                                   "Content-Disposition" => "attachment; filename=\"$(r.nome)\""], r.bytes)
    end
    erro(405, "`$acao` se pede com GET")
end

"Um erro do servidor vira 500 com a mensagem, e não derruba o processo."
function atender(req)
    try
        rotear(req)
    catch err
        @error "falha ao atender $(req.method) $(req.target)" exception = (err, catch_backtrace())
        erro(500, sprint(showerror, err))
    end
end

function main()
    porta = parse(Int, get(ENV, "PORTA", "8080"))
    catalogo()                                  # carrega e analisa os modelos antes de abrir a porta
    println("Gerador de minutas em http://127.0.0.1:$porta")
    HTTP.serve(atender, "127.0.0.1", porta)
end

abspath(PROGRAM_FILE) == @__FILE__() && main()
