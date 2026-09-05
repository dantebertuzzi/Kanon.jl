# Diagnósticos.
#
# Erro é interface de usuário aqui, não detalhe de implementação (especificacao.md §10).
# Três regras governam este arquivo:
#
#   1. Todo diagnóstico tem um CÓDIGO ESTÁVEL. A suíte afirma sobre o código; a redação
#      da mensagem pode melhorar sem quebrar teste.
#   2. Erros são ACUMULADOS e reportados juntos, em ordem determinística.
#   3. A mensagem usa vocabulário de redator, nunca de implementação.

"""
    Diagnostic

Um problema encontrado em um modelo ou nos seus dados. `code` é estável entre versões
e está registrado em [`CODE_TITLES`](@ref).
"""
struct Diagnostic
    code::String
    severity::Symbol          # :error | :warning
    category::Symbol          # :syntax | :reference | :contract | :resource
    file::String
    line::Int32
    col::Int32
    endline::Int32
    endcol::Int32
    path::Union{Nothing,String}   # caminho do campo, quando aplicável
    message::String
    hint::Union{Nothing,String}
end

"""
    CODE_TITLES

Registro de todos os códigos de diagnóstico. O título é a linha curta que aparece no
cabeçalho do problema; a mensagem completa vem do ponto de emissão.

Um código, uma vez publicado, nunca muda de significado (política de compatibilidade,
`docs/especificacao.md` §13). Códigos novos são aditivos.

    K10xx  estrutura do arquivo e pragma
    K11xx  plano de dados
    K12xx  plano do texto
    K13xx  plano das regras
    K20xx  referência: caminhos, tipos e formatadores
    K30xx  contrato: os dados contra o contrato
    K40xx  recurso: o orçamento do render
"""
const CODE_TITLES = Dict{String,String}(
    # --- estrutura do arquivo e pragma ---
    "K1001" => "marca de ordem de byte (BOM) no início do arquivo",
    "K1002" => "arquivo sem a linha de versão",
    "K1003" => "linha de versão malformada",
    "K1004" => "versão maior da linguagem não suportada",
    "K1005" => "versão menor da linguagem não suportada",
    "K1006" => "idioma desconhecido",
    "K1007" => "arquivo não está em UTF-8",
    "K1010" => "conteúdo fora de qualquer plano",
    "K1011" => "plano declarado duas vezes",
    "K1012" => "planos fora de ordem",
    "K1013" => "plano de texto ausente",
    # --- plano de dados ---
    "K1101" => "declaração de campo malformada",
    "K1102" => "cardinalidade malformada",
    "K1103" => "marca de campo malformada",
    "K1104" => "valor padrão malformado",
    "K1105" => "campo declarado duas vezes",
    "K1106" => "tipo-soma não existe na versão 1",
    # --- plano do texto ---
    "K1201" => "cabeçalho de bloco malformado",
    "K1202" => "bloco declarado duas vezes",
    "K1203" => "interpolação não fechada",
    "K1204" => "interpolação vazia",
    "K1205" => "caminho malformado na interpolação",
    "K1206" => "encadeamento de formatadores não existe na versão 1",
    "K1207" => "argumentos de formatador não existem na versão 1",
    "K1208" => "grupo opcional não fechado",
    "K1209" => "colchete de fechamento sem abertura",
    "K1210" => "texto fora de qualquer bloco",
    "K1211" => "remissão malformada",
    "K1212" => "nível de bloco acima do teto da versão 1",
    "K1213" => "marcador de bloco desconhecido",
    "K1214" => "linha de inclusão malformada",
    # --- plano das regras ---
    "K1301" => "regra malformada",
    "K1302" => "expressão malformada",
    "K1303" => "parêntese não fechado",
    "K1304" => "operador desconhecido",
    # --- referência: caminhos e tipos ---
    "K2001" => "campo não declarado",
    "K2002" => "nome ambíguo",
    "K2003" => "campo não existe no tipo",
    "K2004" => "o valor não tem campos",
    "K2005" => "tipo desconhecido neste ambiente",
    "K2006" => "sujeito não declarado no contrato",
    "K2007" => "sujeito sem campos",
    "K2008" => "caminho atravessa uma lista",
    # --- referência: grupos opcionais e o teorema da lacuna ---
    "K2010" => "grupo opcional que nunca elide",
    "K2011" => "grupo opcional de valores garantidos",
    "K2012" => "valor que pode faltar, fora de grupo opcional",
    "K2013" => "parênteses que não fecham dentro do grupo",
    "K2014" => "aspas que não fecham dentro do grupo",
    # --- referência: blocos, níveis, remissões e regras ---
    "K2030" => "marcador de bloco sem estilo neste ambiente",
    "K2031" => "nível de bloco sem o nível anterior",
    "K2032" => "marcador sem forma não numerada",
    "K2033" => "remissão a bloco inexistente",
    "K2034" => "remissão a bloco repetido",
    "K2035" => "remissão a bloco que uma regra pode remover",
    "K2036" => "regra nomeia bloco inexistente",
    "K2037" => "duas regras da mesma espécie para o mesmo bloco",
    "K2038" => "remissão a bloco não numerado",
    # --- referência: semântica das regras ---
    "K2040" => "condição que não é verdadeira nem falsa",
    "K2041" => "atributo desconhecido no tipo",
    "K2043" => "valores que não se comparam",
    "K2044" => "comparação com nulo",
    "K2045" => "one for each sobre um valor único",
    "K2046" => "o cabeçalho do bloco não declara o sujeito repetido",
    "K2047" => "condição sempre verdadeira ou sempre falsa",
    # --- referência: inclusão ---
    "K2050" => "arquivo de inclusão fora da raiz",
    "K2051" => "inclusão cíclica",
    "K2052" => "arquivo de inclusão não encontrado",
    "K2053" => "contratos incompatíveis entre modelo e fragmento",
    "K2054" => "o fragmento redeclara um bloco do hospedeiro",
    "K2055" => "inclusão sem raiz configurada",
    # --- referência: formatadores ---
    "K2020" => "formatador desconhecido",
    # --- contrato ---
    "K3001" => "campo obrigatório ausente",
    "K3002" => "cardinalidade violada",
    "K3003" => "texto em branco em campo garantido",
    "K3004" => "texto em branco lido como ausente",
    "K3005" => "o modelo usa `today` e a data não foi informada",
    "K3010" => "tipo incompatível",
    "K3011" => "valor recusado pelo tipo",
    "K3012" => "o valor não tem um campo que o esquema promete",
    "K3021" => "campo nos dados que o contrato não declara",
    "K3030" => "valor aninhado fundo demais",
    "K3040" => "remissão a bloco que as regras removeram",
    # --- recurso ---
    "K4001" => "orçamento de nós excedido",
    "K4002" => "orçamento de bytes excedido",
    "K4003" => "profundidade de inclusão excedida",
    "K4004" => "orçamento de iterações excedido",
)

function Diagnostic(code::AbstractString, category::Symbol, span::Span, file::AbstractString,
                    message::AbstractString; hint = nothing, path = nothing,
                    severity::Symbol = :error)
    @assert haskey(CODE_TITLES, code) "código de diagnóstico não registrado: $code"
    Diagnostic(String(code), severity, category, String(file),
               span.line, span.col, span.endline, span.endcol,
               path === nothing ? nothing : String(path),
               String(message), hint === nothing ? nothing : String(hint))
end

"""
    DiagnosticSet

Coleção ordenada de diagnósticos. A ordem é determinística — arquivo, linha, coluna,
código — para que a saída seja comparável em `diff` e estável em teste.
"""
struct DiagnosticSet
    diagnostics::Vector{Diagnostic}
end

DiagnosticSet() = DiagnosticSet(Diagnostic[])

Base.isempty(s::DiagnosticSet) = isempty(s.diagnostics)
Base.length(s::DiagnosticSet) = length(s.diagnostics)
Base.iterate(s::DiagnosticSet, st...) = iterate(s.diagnostics, st...)
Base.getindex(s::DiagnosticSet, i) = s.diagnostics[i]

sortkey(d::Diagnostic) = (d.file, d.line, d.col, d.code)

"Ordena e devolve um conjunto novo. Nunca muta o argumento."
sorted(s::DiagnosticSet) = DiagnosticSet(sort(s.diagnostics; by = sortkey))

haserrors(s::DiagnosticSet) = any(d -> d.severity === :error, s.diagnostics)

# --- exceções ---------------------------------------------------------------

abstract type KanonError <: Exception end

"Modelo malformado. Reportado na leitura, sem dados e sem ambiente."
struct KanonSyntaxError <: KanonError
    diagnostics::DiagnosticSet
end

"Campo, formatador ou bloco inexistente. Detectável sem dados."
struct KanonReferenceError <: KanonError
    diagnostics::DiagnosticSet
end

"Modelo válido, dados incompatíveis."
struct KanonContractError <: KanonError
    diagnostics::DiagnosticSet
end

"""
Excedeu o orçamento de recursos — a única falha que o render pode ter (§11, D-010).

Mora aqui, com as outras exceções, e não no renderizador, porque `check` também pode
estourar o orçamento: as regras são avaliadas antes de qualquer texto sair.
"""
struct KanonResourceError <: KanonError
    diagnostics::DiagnosticSet
end

diagnostics(e::KanonError) = e.diagnostics

const CATEGORY_LABEL = Dict(
    :syntax    => "sintaxe",
    :reference => "referência",
    :contract  => "contrato",
    :resource  => "recurso",
)

"""
    format_diagnostics(io, set)

Escreve os diagnósticos no formato de `docs/especificacao.md` §10.4.
"""
function format_diagnostics(io::IO, set::DiagnosticSet)
    ds = sorted(set).diagnostics
    isempty(ds) && return nothing

    files = unique(d.file for d in ds)
    header = length(files) == 1 ? files[1] : "$(length(files)) arquivos"
    n = length(ds)
    println(io, header, ": ", n, n == 1 ? " problema encontrado" : " problemas encontrados")

    for d in ds
        println(io)
        title = "  $(CATEGORY_LABEL[d.category]), $(CODE_TITLES[d.code])"
        pad = max(1, 66 - length(title))
        println(io, title, " "^pad, "[", d.code, "]")
        loc = d.line > 0 ? "linha $(d.line), coluna $(d.col): " : ""
        println(io, "    ", loc, d.message)
        d.hint === nothing || println(io, "    ", d.hint)
    end
    return nothing
end

function format_diagnostics(set::DiagnosticSet)
    io = IOBuffer()
    format_diagnostics(io, set)
    String(take!(io))
end

function Base.showerror(io::IO, e::KanonError)
    format_diagnostics(io, e.diagnostics)
end

Base.show(io::IO, ::MIME"text/plain", s::DiagnosticSet) = format_diagnostics(io, s)
