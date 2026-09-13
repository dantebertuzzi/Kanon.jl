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

"""
Um erro de **uso** que nasce depois das opções — um arquivo de dados que o ambiente não
sabe ler, um formato que não comporta o que se pede para escrever. Sai com o código 3 e
uma frase, nunca com uma pilha de Julia.
"""
struct CliUsageError <: Exception
    msg::String
end

const USAGE = """
kanon — motor de modelos de documento

  kanon check    modelo.kanon [dados.json]   valida o modelo, e os dados se vierem
  kanon render   modelo.kanon dados.json     escreve o documento
  kanon contract modelo.kanon                emite o checklist em JSON Schema
  kanon preview  modelo.kanon [dados.json]   rascunho com «marcadores», nunca exporta
  kanon outline  modelo.kanon                o esqueleto: cada bloco e a regra dele
  kanon ask      modelo.kanon [dados]        pergunta o que falta, e emite os dados
                                             (em JSON se os dados vieram em JSON, ou
                                             se `-o` termina em .json)

Opções
  -o ARQUIVO     escreve a saída no arquivo, em vez do stdout
  --to FORMATO   text (padrão), markdown ou typst
  --today DATA   a data de hoje, em AAAA-MM-DD; `today` nunca vem do relógio
  --locale IDIOMA
  --domain NOME  carrega uma camada de domínio (repetível): --domain KanonLegal
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
    posicionais, saida, hoje, idioma, dominios, formato = opts

    isempty(posicionais) &&
        (println(err, "kanon: falta o arquivo do modelo."); return EXIT_USAGE)
    length(posicionais) > 2 &&
        (println(err, "kanon: argumentos demais."); return EXIT_USAGE)

    ambiente = env === nothing ? build_env(idioma, dominios, err) : env
    ambiente === nothing && return EXIT_USAGE

    try
        # `invokelatest`, e não uma chamada comum: o `--domain` acabou de carregar código,
        # e esta função foi compilada num mundo em que ele não existia. Sem isto, nenhum
        # método da camada — nem o `configure!`, nem o decodificador de `pessoa` — é
        # visível daqui, e a CLI de verdade não alcança camada nenhuma (D-059).
        return Base.invokelatest(run_command, cmd, posicionais, saida, hoje, formato,
                                 ambiente, out, err, input)
    catch e
        e isa CliUsageError && (println(err, "kanon: ", e.msg); return EXIT_USAGE)
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

"""
Monta o ambiente da execução: o idioma e as camadas de domínio pedidas na linha de
comando.

**Quem manda carregar é o usuário, nunca o modelo** (invariante 4 e §11.1). Um `--domain`
é o equivalente de linha de comando ao `using` que o programa escreveria, e por isso é
opção da CLI e não pragma do arquivo: um modelo que pudesse nomear o pacote a carregar
seria dado não confiável mandando o motor executar código.

Sem isto a linha de comando não alcançava documento nenhum com camada de domínio — que é
a maior parte deles (D-058).

O ambiente é construído com `invokelatest` porque o `require` acima muda o mundo: os
métodos que a camada acabou de definir não existem para o código que já estava rodando.
Um teste que carrega a camada antes de chamar `main` nunca vê isso — a camada já
estava carregada —, e foi assim que a D-058 passou verde sem funcionar no `bin/kanon`
(D-059).
"""
function build_env(idioma::Union{Nothing,Symbol}, dominios::Vector{Symbol}, err::IO)
    mods = Module[]
    for nome in dominios
        m = try
            Base.require(Main, nome)
        catch e
            println(err, "kanon: a camada `", nome, "` não está disponível neste ",
                    "ambiente Julia.")
            println(err, "       Instale o pacote e rode de novo: ",
                    "`julia -e 'using Pkg; Pkg.add(\"", nome, "\")'`.")
            return nothing
        end
        push!(mods, m)
    end
    try
        return Base.invokelatest(Environment; locale = idioma, domains = mods)
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
    dominios = Symbol[]
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
        elseif a == "--domain"
            i += 1
            i > length(args) && (println(err, "kanon: `--domain` precisa do nome de uma camada."); return nothing)
            nome = Symbol(args[i])
            nome in dominios &&
                (println(err, "kanon: a camada `", nome, "` foi pedida duas vezes."); return nothing)
            push!(dominios, nome)
        elseif startswith(a, "-")
            println(err, "kanon: opção desconhecida `", a, "`.")
            return nothing
        else
            push!(posicionais, a)
        end
        i += 1
    end
    (posicionais, saida, hoje, idioma, dominios, formato)
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
        origem = length(posicionais) == 2 ? posicionais[2] : nothing
        return do_ask(modelo, dados, origem, saida, hoje, out, err, entrada)
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

Três coisas que o modelo real nº 12 cobrou, todas da mesma frase — **o que o `ask` emite,
o `render` lê de volta** (D-061):

- **Pergunta tudo o que falta**, e não só o obrigatório. O opcional é onde o documento
  varia — o réu, o número do processo —, e um `ask` que nunca o oferece só produz o
  documento mínimo. Enter deixa o opcional em branco e mantém o padrão.
- **A resposta é conferida na hora**, pelo mesmo `check` que o `render` vai usar, e a
  pergunta se repete com a mensagem dele. Uma data digitada `13/09/2027` não descobre
  que está errada depois da última pergunta.
- **Os dados saem na forma em que vieram**: JSON se a entrada era JSON ou se `-o`
  termina em `.json`, e `chave = valor` nos demais casos. O `chave = valor` não escreve
  lista nem composto, e uma `pessoa` vinda de um JSON saía como `Dict{String, Any}(...)`
  — um arquivo que o `render` recusava com "é uma coleção, e veio um valor único".
"""
function do_ask(modelo, dados, origem, saida, hoje, out::IO, err::IO, entrada::IO)
    formato = formato_dos_dados(saida, origem)
    valores = Dict{String,Any}()
    dados === nothing || for (k, v) in pairs(dados)
        valores[String(k)] = v
    end

    for f in modelo.template.data.fields
        nome = String(f.name)
        haskey(valores, nome) && valores[nome] !== nothing && continue

        if !(canonical_typename(modelo.env, f.type) in DIGITAVEIS) || islist(f.card)
            println(err, "  ", f.name, " — ", f.type,
                    islist(f.card) ? " (uma lista)" : "",
                    f.presence === OPTIONAL ? ", opcional" : "",
                    ": preencha no arquivo de dados; não cabe numa linha.")
            continue
        end

        println(err, prompt_de(modelo.env, f; onde = onde_declarado(modelo, f)))
        while true
            print(err, "  ", f.name, " = ")
            flush(err)
            eof(entrada) && (println(err); break)
            linha = strip(readline(entrada))
            isempty(linha) && break              # obrigatório fica faltando; o resto, como está
            valor = coerce_answer(modelo.env, f, linha)
            recusa = recusa_da_resposta(modelo, f, valor, hoje)
            recusa === nothing && (valores[nome] = valor; break)
            println(err, "  ", recusa)
        end
    end

    texto = serialize_data(formato, valores)   # antes do diagnóstico: formato errado é uso
    conjunto = check(modelo, valores; today = hoje)
    if haserrors(conjunto)
        format_diagnostics(err, conjunto)
        println(err, "kanon: os dados ainda não bastam.")
    end
    emit(out, saida, texto)
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

E o booleano pela palavra **do arquivo**: num modelo `pt` o literal se escreve
`verdadeiro`, e é o que o redator digita. `true` continua valendo, porque é a forma do
arquivo de dados.
"""
function coerce_answer(env::Environment, f::FieldDecl, texto::AbstractString)
    canon = canonical_typename(env, f.type)
    canon === :text && return String(texto)
    if canon === :boolean
        k = keyword(env.keywords, texto)
        k === KW_TRUE && return true
        k === KW_FALSE && return false
    end
    parse_data_value(texto)
end

"""
O que o motor diria desta resposta, ou `nothing` se ela serve.

Pergunta ao `check`, e não a uma validação própria: um `ask` que aceitasse o que o
`render` recusa seria a ferramenta discordando do motor, que a D-029 diz ser pior que
nenhuma.
"""
function recusa_da_resposta(modelo, f::FieldDecl, valor, hoje)
    conjunto = check(modelo, Dict{String,Any}(String(f.name) => valor); today = hoje)
    for d in conjunto
        d.severity === :error && d.path == String(f.name) && d.code != "K3001" &&
            return d.message
    end
    nothing
end

"""
A pergunta de um campo: o nome, o tipo, a linha em que ele foi declarado, a forma em que
a resposta se escreve e o que Enter faz.

A forma vem dita porque nenhuma outra coisa a diz: `13/09/2027` é como uma data se
escreve em português, e não é como ela entra.
"""
function prompt_de(env::Environment, f::FieldDecl; onde::AbstractString = "linha $(f.span.line)")
    kt = env.keywords
    partes = [string(f.name, " — ", f.type, ", ", onde)]
    canon = canonical_typename(env, f.type)
    canon === :date && push!(partes, "aaaa-mm-dd")
    canon === :boolean && push!(partes, written(kt, KW_TRUE) * " ou " * written(kt, KW_FALSE))
    canon === :number && push!(partes, "ponto decimal, sem separador de milhar")
    f.presence === OPTIONAL && push!(partes, "opcional: Enter deixa em branco")
    f.presence === DEFAULTED && f.default !== nothing &&
        push!(partes, "Enter mantém " * literal_text(kt, f.default))
    join(partes, " · ")
end

"""
Onde o campo foi declarado, dito como o autor o encontra: a linha, e o arquivo quando ele
não é o modelo aberto.

Um campo que veio de fragmento tem a linha **do fragmento**, e `oab — texto, linha 17`
mandava o redator à linha 17 da procuração, onde está outra coisa — a forma da D-035, na
pergunta do `ask` (D-064).
"""
function onde_declarado(modelo, f::FieldDecl)
    fontes = modelo.template.sources
    (f.span.file <= 1 || f.span.file > length(fontes)) && return "linha $(f.span.line)"
    base = dirname(fontes[1])
    arquivo = isempty(base) ? fontes[f.span.file] : relpath(fontes[f.span.file], base)
    string(arquivo, ", linha ", f.span.line)
end

extensao_json(caminho::AbstractString) = endswith(lowercase(caminho), ".json")

"JSON se `-o` pede, ou, sem `-o`, se os dados vieram em JSON."
function formato_dos_dados(saida, origem)
    saida === nothing || return extensao_json(saida) ? :json : :kdata
    origem !== nothing && extensao_json(origem) ? :json : :kdata
end

"""
Os dados no formato em que o `render` os lê de volta.

`chave = valor` só escreve escalar. Um composto ou uma lista nele não é um arquivo de
dados, é a representação de um `Dict` de Julia — e o formato recusa em vez de escrevê-la.
"""
function serialize_data(formato::Symbol, valores::AbstractDict)
    if formato === :json
        io = IOBuffer()
        write_json(io, json_de(valores))
        return String(take!(io))
    end
    io = IOBuffer()
    for k in sort!(collect(keys(valores)))
        v = valores[k]
        v === nothing && continue
        (v isa AbstractDict || v isa AbstractVector) &&
            throw(CliUsageError("`$k` é " * (v isa AbstractVector ? "uma lista" : "um objeto") *
                                ", e o formato `chave = valor` não o escreve. " *
                                "Peça os dados em JSON: `-o dados.json`."))
        println(io, k, " = ", v isa AbstractString ? "\"" * v * "\"" : v)
    end
    String(take!(io))
end

"Chaves em ordem alfabética, de todo objeto e em toda profundidade: o arquivo vai a `diff`."
json_de(v::AbstractDict) =
    JObj(Pair{String,Any}[String(k) => json_de(v[k]) for k in sort!(collect(keys(v)); by = string)])
json_de(v::AbstractVector) = Any[json_de(x) for x in v]
json_de(v::Date) = Dates.format(v, "yyyy-mm-dd")
json_de(v) = v

"""
Lê os dados. Um arquivo `.json` passa pela extensão de `JSON3`; qualquer outro é lido no
formato mínimo `chave = valor`, que existe para o núcleo não precisar de dependência
nenhuma para funcionar.
"""
function read_data(path::AbstractString)
    if extensao_json(path)
        json_disponivel() || throw(CliUsageError(
            "para ler `$path`, o JSON3 precisa estar instalado neste ambiente Julia: " *
            "`julia -e 'using Pkg; Pkg.add(\"JSON3\")'`."))
        return Base.invokelatest(read_json, path)
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

"""
Carrega o JSON3 se ele ainda não está carregado, e diz se a leitura de JSON existe.

O `bin/kanon` só faz `using Kanon`, e o JSON3 é extensão, não dependência: sem isto um
arquivo `.json` — o único formato de dados que carrega uma `pessoa` — não era lido pela
linha de comando de verdade, e a recusa saía como pilha de Julia (D-060). Como o
`--domain`, é o operador quem pede, ao dar um arquivo `.json`; o pacote carregado é
sempre o mesmo, e nunca um nome vindo dos dados.
"""
function json_disponivel()
    Base.get_extension(@__MODULE__, :KanonJSON3Ext) === nothing || return true
    try
        Base.require(Main, :JSON3)
    catch
        return false
    end
    Base.get_extension(@__MODULE__, :KanonJSON3Ext) !== nothing
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
