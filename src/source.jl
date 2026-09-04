# Leitura do arquivo-fonte.
#
# Três normalizações acontecem aqui e em nenhum outro lugar (especificacao.md §1.1):
# BOM é erro (não é ignorado em silêncio), `\r\n` vira `\n`, e o texto é normalizado
# para NFC. Sem NFC, `José` escrito com `é` (U+00E9) e `José` escrito com `e`+U+0301
# são identificadores diferentes, e o erro resultante é indepurável.

"""
    SourceFile

Um arquivo `.kanon` já normalizado, quebrado em linhas. `lines[i]` é o conteúdo da
linha `i` **sem** o `\\n` final.
"""
struct SourceFile
    name::String
    text::String
    lines::Vector{String}
end

"Lança `KanonSyntaxError` para problemas que impedem qualquer leitura."
function read_source(path::AbstractString)
    bytes = read(path)
    read_source(bytes, path)
end

function read_source(bytes::Vector{UInt8}, name::AbstractString)
    diags = Diagnostic[]
    at = Span(1, 1, 1)

    if !isvalid(String, bytes)
        push!(diags, Diagnostic("K1007", :syntax, at, name,
            "o arquivo não está codificado em UTF-8.";
            hint = "Kanon exige UTF-8; converta o arquivo antes de usá-lo."))
        throw(KanonSyntaxError(DiagnosticSet(diags)))
    end

    raw = String(bytes)
    if startswith(raw, "\ufeff")
        push!(diags, Diagnostic("K1001", :syntax, at, name,
            "o arquivo começa com uma marca de ordem de byte (BOM).";
            hint = "Salve o arquivo como UTF-8 sem BOM."))
        throw(KanonSyntaxError(DiagnosticSet(diags)))
    end

    return source_from_text(raw, name)
end

function source_from_text(raw::AbstractString, name::AbstractString)
    text = Unicode.normalize(replace(String(raw), "\r\n" => "\n", "\r" => "\n"), :NFC)
    lines = split(text, '\n')
    # `split` produz uma linha vazia final quando o texto termina em `\n`; ela não é
    # uma linha do documento.
    if !isempty(lines) && isempty(lines[end]) && endswith(text, '\n')
        pop!(lines)
    end
    SourceFile(String(name), text, String.(lines))
end

nlines(s::SourceFile) = length(s.lines)
line(s::SourceFile, i::Integer) = 1 <= i <= length(s.lines) ? s.lines[i] : ""
