# A interface de linha de comando (§12).
#
# Fina de propósito: `check`, `render` e `contract` já existem como funções puras, e a
# CLI só decide de onde vêm os bytes e para onde vão. Nenhuma regra da linguagem mora
# aqui — se uma aparecer, ela está no lugar errado.
#
#   kanon check    modelo.kanon [dados.json]
#   kanon render   modelo.kanon dados.json [-o saida.md]
#   kanon contract modelo.kanon [-o contrato.json]
#   kanon preview  modelo.kanon [dados.json]
#
# Códigos de saída, normativos:
#   0 sucesso · 1 erro de contrato · 2 erro de modelo · 3 erro de uso · 4 recurso

const EXIT_OK = 0
const EXIT_CONTRACT = 1
const EXIT_MODEL = 2
const EXIT_USAGE = 3
const EXIT_RESOURCE = 4

const USAGE = """
kanon — motor de modelos de documento

  kanon check    modelo.kanon [dados.json]   valida o modelo, e os dados se vierem
  kanon render   modelo.kanon dados.json     escreve o documento
  kanon contract modelo.kanon                emite o checklist em JSON Schema
  kanon preview  modelo.kanon [dados.json]   rascunho com «marcadores», nunca exporta
  kanon outline  modelo.kanon                o esqueleto: cada bloco e a regra dele
  kanon ask      modelo.kanon [dados]        pergunta o que falta, e emite os dados

Opções
  -o ARQUIVO     escreve a saída no arquivo, em vez do stdout
  --to FORMATO   text (padrão), markdown ou typst
  --today DATA   a data de hoje, em AAAA-MM-DD; `today` nunca vem do relógio
  --locale IDIOMA
  --version
  --help

Códigos de saída: 0 sucesso, 1 contrato, 2 modelo, 3 uso, 4 recurso.

Para .docx, .odt ou PDF, o caminho é o pandoc — este motor garante o conteúdo, e a
composição da página é de quem sabe fazê-la:

  kanon render modelo.kanon dados.json --to markdown | pandoc -o saida.docx
"""

"""
    main(args; stdout, stderr, env) -> Int

O corpo da CLI, escrito para ser chamável de um teste: recebe os fluxos em vez de os
buscar no processo, e devolve o código de saída em vez de encerrar.
"""
# `input`, e não `in`: `in` é função de `Base`, e o argumento nomeado a sombrearia
# dentro da função inteira — inclusive nos `x in y` que ela usa.
function main(args::Vector{String}; out::IO = Base.stdout, err::IO = Base.stderr,
              input::IO = Base.stdin, env::Union{Nothing,Environment} = nothing)
    isempty(args) && (print(err, USAGE); return EXIT_USAGE)

    if args[1] in ("--help", "-h", "help")
        print(out, USAGE)
        return EXIT_OK
    end
    if args[1] in ("--version", "-V")
        println(out, "kanon ", LANGUAGE_VERSION)
        return EXIT_OK
    end

    cmd = args[1]
    cmd in ("check", "render", "contract", "preview", "outline", "ask") ||
        (println(err, "kanon: `", cmd, "` não é um comando.\n"); print(err, USAGE); return EXIT_USAGE)

    opts = parse_options(args[2:end], err)
    opts === nothing && return EXIT_USAGE
    posicionais, saida, hoje, idioma, formato = opts

    isempty(posicionais) &&
        (println(err, "kanon: falta o arquivo do modelo."); return EXIT_USAGE)
    length(posicionais) > 2 &&
        (println(err, "kanon: argumentos demais."); return EXIT_USAGE)

    ambiente = env === nothing ? build_env(idioma, err) : env
    ambiente === nothing && return EXIT_USAGE

    try
        return run_command(cmd, posicionais, saida, hoje, formato, ambiente, out, err, input)
    catch e
        e isa KanonSyntaxError && return report(err, e, EXIT_MODEL)
        e isa KanonReferenceError && return report(err, e, EXIT_MODEL)
        e isa KanonContractError && return report(err, e, EXIT_CONTRACT)
        e isa KanonResourceError && return report(err, e, EXIT_RESOURCE)
        e isa KanonEnvironmentError && (showerror(err, e); println(err); return EXIT_USAGE)
        # `showerror` de um erro de sistema já traz o caminho e o motivo, e não traz
        # pilha: a CLI não deve responder a um arquivo faltando com um dump de Julia.
        (e isa SystemError || e isa Base.IOError) &&
            (println(err, "kanon: ", sprint(showerror, e)); return EXIT_USAGE)
        rethrow()
    end
end

function report(err::IO, e::KanonError, code::Int)
    showerror(err, e)
    return code
end

function build_env(idioma::Union{Nothing,Symbol}, err::IO)
    try
        return Environment(locale = idioma)
    catch e
        e isa KanonEnvironmentError || rethrow()
        showerror(err, e)
        println(err)
        return nothing
    end
end

"Lê as opções. Devolve `nothing` se algo está malformado — o erro já foi escrito."
function parse_options(args::Vector{String}, err::IO)
    posicionais = String[]
    saida = nothing
    hoje = nothing
    idioma = nothing
    formato = PlainText()
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "-o"
            i += 1
            i > length(args) && (println(err, "kanon: `-o` precisa de um arquivo."); return nothing)
            saida = args[i]
        elseif a == "--today"
            i += 1
            i > length(args) && (println(err, "kanon: `--today` precisa de uma data."); return nothing)
            hoje = tryparse_date(args[i])
            hoje === nothing &&
                (println(err, "kanon: `", args[i], "` não é uma data `AAAA-MM-DD`."); return nothing)
        elseif a == "--to"
            i += 1
            i > length(args) && (println(err, "kanon: `--to` precisa de um formato."); return nothing)
            try
                formato = output_format(Symbol(args[i]))
            catch e
                e isa ArgumentError || rethrow()
                println(err, "kanon: ", e.msg)
                return nothing
            end
        elseif a == "--locale"
            i += 1
            i > length(args) && (println(err, "kanon: `--locale` precisa de um idioma."); return nothing)
            idioma = Symbol(args[i])
        elseif startswith(a, "-")
            println(err, "kanon: opção desconhecida `", a, "`.")
            return nothing
        else
            push!(posicionais, a)
        end
        i += 1
    end
    (posicionais, saida, hoje, idioma, formato)
end

function tryparse_date(s::AbstractString)
    m = match(r"^(\d{4})-(\d{2})-(\d{2})$", s)
    m === nothing && return nothing
    try
        Date(parse(Int, m.captures[1]), parse(Int, m.captures[2]), parse(Int, m.captures[3]))
    catch
        nothing
    end
end

function run_command(cmd, posicionais, saida, hoje, formato, env, out::IO, err::IO,
                    entrada::IO)
    modelo = load_template(env, posicionais[1])
    dados = length(posicionais) == 2 ? read_data(posicionais[2]) : nothing

    if cmd == "outline"
        format_outline(out, modelo)
        return EXIT_OK
    end

    if cmd == "ask"
        return do_ask(modelo, dados, saida, hoje, out, err, entrada)
    end

    if cmd == "contract"
        emit(out, saida, contract(modelo))
        return EXIT_OK
    end

    if cmd == "check"
        dados === nothing && (println(err, "kanon: modelo válido."); return EXIT_OK)
        conjunto = check(modelo, dados; today = hoje)
        isempty(conjunto) && (println(err, "kanon: modelo e dados válidos."); return EXIT_OK)
        format_diagnostics(err, conjunto)
        return haserrors(conjunto) ? EXIT_CONTRACT : EXIT_OK
    end

    if cmd == "preview"
        return do_preview(modelo, dados, saida, hoje, formato, out, err)
    end

    dados === nothing &&
        (println(err, "kanon: `render` precisa dos dados."); return EXIT_USAGE)
    emit(out, saida, render(modelo, dados; today = hoje, to = formato))
    return EXIT_OK
end

"""
`preview` é o **único** comando que produz saída incompleta, e ela é sempre visivelmente
marcada. Ele não é um modo leniente: não exporta, sai por um comando próprio, e escreve
no *stderr* a lista do que falta.

A necessidade real por trás do pedido de "modo leniente" é ver o rascunho enquanto os
dados ainda estão sendo reunidos. Atendê-la aqui é o que permite que o motor nunca
relaxe em lugar nenhum.
"""
function do_preview(modelo, dados, saida, hoje, formato, out::IO, err::IO)
    dados = dados === nothing ? Dict{String,Any}() : dados
    conjunto = check(modelo, dados; today = hoje)
    isempty(conjunto) || format_diagnostics(err, conjunto)
    println(err, "kanon: rascunho — não exporte este arquivo.")
    emit(out, saida, preview(modelo, dados; today = hoje, to = formato))
    return EXIT_OK
end

function emit(out::IO, saida::Union{Nothing,String}, texto::AbstractString)
    saida === nothing ? println(out, texto) : open(io -> println(io, texto), saida, "w")
end

"""
`kanon ask` pergunta os campos que faltam, um a um, e emite os dados completos.

É o candidato herdado do docassemble, e atende à necessidade **real** por trás do pedido
de "modo leniente": quem pede modo leniente quase sempre quer ver o documento enquanto
ainda está reunindo os dados. `ask` reúne os dados; `preview` mostra o rascunho. Nenhum
dos dois afrouxa o contrato, e é por isso que os dois podem existir.

Escreve as perguntas no *stderr* e os dados no *stdout*, para que
`kanon ask m.kanon > dados.kdata` funcione.
"""
function do_ask(modelo, dados, saida, hoje, out::IO, err::IO, entrada::IO)
    valores = Dict{String,Any}()
    dados === nothing || for (k, v) in pairs(dados)
        valores[String(k)] = v
    end

    for f in modelo.template.data.fields
        haskey(valores, String(f.name)) && valores[String(f.name)] !== nothing && continue
        f.presence === OPTIONAL && continue      # opcional não se pergunta: ele pode faltar
        f.presence === DEFAULTED && continue     # o padrão preenche

        if !(canonical_typename(modelo.env, f.type) in DIGITAVEIS) || islist(f.card)
            println(err, "  ", f.name, " — ", f.type,
                    islist(f.card) ? " (uma lista)" : "",
                    ": preencha no arquivo de dados; não cabe numa linha.")
            continue
        end

        println(err, prompt_de(f))
        print(err, "  ", f.name, " = ")
        flush(err)
        linha = readline(entrada)
        isempty(strip(linha)) && continue
        valores[String(f.name)] = coerce_answer(modelo.env, f, strip(linha))
    end

    conjunto = check(modelo, valores; today = hoje)
    if haserrors(conjunto)
        format_diagnostics(err, conjunto)
        println(err, "kanon: os dados ainda não bastam.")
    end
    emit(out, saida, serialize_data(valores))
    return haserrors(conjunto) ? EXIT_CONTRACT : EXIT_OK
end

"""
Os tipos que cabem numa linha digitada.

`money` precisa de quantia **e** moeda, e um composto precisa dos campos dele: perguntar
por eles numa linha só levaria a inventar uma mini-sintaxe de entrada, que é como se
constrói o segundo formato de dados de um projeto. Para esses, `ask` diz que o campo
fica para o arquivo.
"""
const DIGITAVEIS = (:text, :number, :boolean, :date)

"""
A resposta, convertida pelo tipo **declarado** — e não adivinhada pela forma.

Pelo tipo canônico: sem isso, `nome : texto` num modelo em português cairia no ramo
geral, e a resposta `123` viraria o número 123 em vez do nome que o autor digitou.
"""
function coerce_answer(env::Environment, f::FieldDecl, texto::AbstractString)
    canonical_typename(env, f.type) === :text && return String(texto)
    parse_data_value(texto)
end

"A pergunta de um campo: o nome, o tipo, e a linha em que ele foi declarado."
prompt_de(f::FieldDecl) = string(f.name, " — ", f.type, ", linha ", f.span.line)

"Os dados no formato `chave = valor`, que é o que `kanon render` lê de volta."
function serialize_data(valores::Dict{String,Any})
    io = IOBuffer()
    for k in sort!(collect(keys(valores)))
        v = valores[k]
        v === nothing && continue
        println(io, k, " = ", v isa AbstractString ? "\"" * v * "\"" : v)
    end
    String(take!(io))
end

"""
Lê os dados. Um arquivo `.json` passa pela extensão de `JSON3`; qualquer outro é lido no
formato mínimo `chave = valor`, que existe para o núcleo não precisar de dependência
nenhuma para funcionar.
"""
function read_data(path::AbstractString)
    if endswith(lowercase(path), ".json")
        try
            return read_json(path)
        catch e
            e isa MethodError || rethrow()
            error("para ler JSON, carregue `JSON3` — ele é extensão do Kanon, e não " *
                  "dependência: `using JSON3` antes de `using Kanon`.")
        end
    end
    d = Dict{String,Any}()
    for linha in eachline(path)
        s = strip(linha)
        (isempty(s) || startswith(s, '#')) && continue
        partes = split(s, '='; limit = 2)
        length(partes) == 2 || continue
        d[strip(partes[1])] = parse_data_value(strip(partes[2]))
    end
    d
end

function parse_data_value(v::AbstractString)
    v == "null" && return nothing
    v == "true" && return true
    v == "false" && return false
    startswith(v, '"') && endswith(v, '"') && return String(v[2:(end - 1)])
    m = match(r"^(\d{4})-(\d{2})-(\d{2})$", v)
    m === nothing || return Date(parse(Int, m.captures[1]), parse(Int, m.captures[2]),
                                 parse(Int, m.captures[3]))
    n = tryparse(Int, v)
    n === nothing || return n
    f = tryparse(Float64, v)
    f === nothing ? String(v) : f
end
