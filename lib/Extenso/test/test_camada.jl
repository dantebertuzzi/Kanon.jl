# A camada montada: um modelo em português, do arquivo ao documento.
#
# É aqui que se vê se as peças encaixam — as palavras-chave, os apelidos de tipo, a
# flexão, os separadores, a junção de listas e o extenso, todos ao mesmo tempo.

"Uma pessoa de mentira, no lugar do que `KanonLegal` trará na F6."
struct Pessoa
    nome::String
    genero::Symbol
    estado_civil::String
    regime::Union{Nothing,String}
end

Kanon.kanon_typename(::Type{Pessoa}) = :person
Kanon.kanon_schema(::Type{Pessoa}) = (
    Kanon.FieldSpec(:nome, :text),
    Kanon.FieldSpec(:estado_civil, :text),
    Kanon.FieldSpec(:regime, :text; optional = true),
)
Kanon.kanon_getfield(p::Pessoa, ::Val{:nome}) = p.nome
Kanon.kanon_getfield(p::Pessoa, ::Val{:estado_civil}) = p.estado_civil
Kanon.kanon_getfield(p::Pessoa, ::Val{:regime}) = p.regime
Kanon.format(p::Pessoa, ::Val{:default}, ctx) = p.nome
Extenso.genero(p::Pessoa) = p.genero

module DominioTeste
    using Kanon
    using ..Main: Pessoa
    configure!(b) = (register_type!(b, Pessoa; aliases = (pt = :pessoa,)); b)
end

const ENV_PT = Environment(locale = :pt, domains = [DominioTeste])

const JOAO = Pessoa("João Alves de Souza", :m, "casado", "comunhão parcial de bens")
const MARIA = Pessoa("Maria Alves de Souza", :f, "casada", nothing)
const ANA = Pessoa("Ana Beatriz Lima", :f, "solteira", nothing)

@testset "o modelo é escrito em português" begin
    @testset "as palavras-chave, e mistura é erro (D-003)" begin
        m = load_string(ENV_PT, """
kanon 1 pt

dados
  preco : dinheiro !
  nota  : texto

texto

: b
O preço é {preco}[, com a nota {nota}].

: c
A nota é {nota}.

regras
  c quando nota é presente
"""; name = "t.kanon")
        @test m isa Model

        # a forma inglesa da palavra traduzida deixou de existir
        e = try
            load_string(ENV_PT, "kanon 1 pt\n\ndata\n  a : texto !\n\ntexto\n\n: b\n{a}\n";
                        name = "t")
        catch err
            err
        end
        @test e isa KanonSyntaxError
    end

    @testset "`incluir` é a palavra da inclusão, e `include` some (D-054)" begin
        # A §9 promete que o idioma renomeia as palavras-chave, e `include`, que entrou
        # na F7, era a única que tinha ficado de fora. O modelo real nº 10 a pediu — e o
        # defeito não era a falta do apelido, era o silêncio: a linha virava prosa, e o
        # caminho do fragmento saía impresso no documento.
        raiz = mktempdir()
        write(joinpath(raiz, "criterios.kanon"), """
kanon 1 pt

dados
  prazo : numero !

texto

:: pagamento
O prazo é de {prazo} dias.
""")
        fonte(palavra) = """
kanon 1 pt

dados
  nome : texto !

texto

: abertura
Contrato de {nome}.
$palavra "criterios.kanon"
"""
        m = load_string(ENV_PT, fonte("incluir"); name = "h.kanon", root = raiz)
        @test isempty(m.analysis.diagnostics)
        s = render(m, Dict("nome" => "locação", "prazo" => 5))
        @test occursin("1. O prazo é de 5 dias.", s)
        @test !occursin("criterios.kanon", s)

        # e a forma inglesa some do arquivo que declara um idioma (D-003) — sem virar
        # erro de sintaxe, porque a linha é prosa bem-formada. Daí o aviso (D-055)
        m2 = load_string(ENV_PT, fonte("include"); name = "h.kanon", root = raiz)
        d = only(filter(x -> x.code == "K1215", collect(m2.analysis.diagnostics)))
        @test occursin("incluir \"criterios.kanon\"", something(d.hint, ""))
        @test occursin("include \"criterios.kanon\"",
                       render(m2, Dict("nome" => "locação")))
    end

    @testset "o glossário empresta a palavra a quem não tem idioma (D-056)" begin
        # `Extenso` não conhece o `KanonScience`, não o carrega e não sabe se ele está
        # presente: `teorema` é uma palavra portuguesa, e é só isso que está registrado.
        @test Kanon.term(ENV_PT, :theorem, "Theorem") == "Teorema"
        @test Kanon.term(ENV_PT, :lemma, "Lemma") == "Lemma"
        @test Kanon.term(Environment(), :theorem, "Theorem") == "Theorem"
    end

    @testset "os tipos do núcleo têm nome em português (D-025)" begin
        for (apelido, canonico) in Extenso.TIPOS
            @test typefor(ENV_PT, apelido) === typefor(ENV_PT, canonico)
        end
        @test typefor(ENV_PT, :dinheiro) === Kanon.Money
        @test typefor(ENV_PT, :pessoa) === Pessoa       # o do domínio, por `aliases`
    end
end

@testset "flexão num documento de verdade" begin
    # O bloco iterado (`um para cada`) é da F5; aqui o sujeito é o valor inteiro, que é
    # o que exercita a flexão — singular quando é um, plural quando é a coleção.
    singular = """
kanon 1 pt

dados
  parte : pessoa !

texto

: outorgante <- parte
{nome}, brasileiro(a), {estado_civil}, residente e domiciliado(a)[, sob o regime da {regime}], doravante denominado(a) OUTORGANTE VENDEDOR(A);
"""

    plural = """
kanon 1 pt

dados
  vendedor : pessoa[1..] !

texto

: declaracao <- vendedor
O(s) OUTORGANTE(S) VENDEDOR(ES) declara(m) ser(em) legítimo(s) proprietário(s), residente e domiciliado(a).
"""

    @testset "sujeito masculino singular, e o grupo opcional presente" begin
        m = load_string(ENV_PT, singular; name = "e.kanon")
        @test render(m, Dict("parte" => JOAO)) ==
              "João Alves de Souza, brasileiro, casado, residente e domiciliado, " *
              "sob o regime da comunhão parcial de bens, doravante denominado " *
              "OUTORGANTE VENDEDOR;"
    end

    @testset "sujeito feminino, e o grupo opcional elidido (caso normativo 1)" begin
        m = load_string(ENV_PT, singular; name = "e.kanon")
        s = render(m, Dict("parte" => MARIA))
        @test s == "Maria Alves de Souza, brasileira, casada, residente e domiciliada, " *
                   "doravante denominada OUTORGANTE VENDEDORA;"
        @test !occursin(", ,", s)      # sem vírgula dupla onde o regime saiu
    end

    @testset "grupo misto vira masculino plural" begin
        m = load_string(ENV_PT, plural; name = "e.kanon")
        s = render(m, Dict("vendedor" => [JOAO, MARIA]))
        @test occursin("Os OUTORGANTES VENDEDORES declaram serem legítimos proprietários", s)
    end

    @testset "singular não pluraliza nada" begin
        m = load_string(ENV_PT, plural; name = "e.kanon")
        s = render(m, Dict("vendedor" => [MARIA]))
        @test occursin("O OUTORGANTE VENDEDOR declara ser legítimo proprietário", s)
        @test occursin("domiciliada.", s)          # a coleção de uma só é feminina
    end

    @testset "nada além das palavras marcadas mudou (D-013)" begin
        m = load_string(ENV_PT, plural; name = "e.kanon")
        s = render(m, Dict("vendedor" => [JOAO, MARIA]))
        # `residente` não tem marca: fica como está, mesmo com sujeito plural
        @test occursin("residente e domiciliado.", s)
        @test !occursin("residentes", s)
    end

    @testset "com `um para cada`, cada instância tem um vendedor por sujeito (F5)" begin
        # o mesmo texto, agora repetido: o sujeito de cada instância é singular, e as
        # marcas de plural deixam de se aplicar
        com_regra = plural * "\nregras\n  declaracao um para cada vendedor\n"
        m = load_string(ENV_PT, com_regra; name = "e.kanon")
        s = render(m, Dict("vendedor" => [JOAO, MARIA]))
        @test s == "O OUTORGANTE VENDEDOR declara ser legítimo proprietário, " *
                   "residente e domiciliado.\n\n" *
                   "O OUTORGANTE VENDEDOR declara ser legítimo proprietário, " *
                   "residente e domiciliada."
        # duas instâncias, na ordem da coleção
        @test count("OUTORGANTE", s) == 2

        # D-013 no detalhe: `VENDEDOR(ES)` é marca de NÚMERO, e com sujeito singular ela
        # não se aplica — nem para a vendedora. Gênero e número na mesma palavra pedem
        # `(as)`/`(os)`, ou duas palavras marcadas. Uma marca, um efeito.
        @test !occursin("VENDEDORA", s)
        @test occursin("domiciliada", s)      # esta tem marca de gênero, e ela aplicou
    end
end

@testset "o que o idioma formata" begin
    m = load_string(ENV_PT, """
kanon 1 pt

dados
  preco  : dinheiro !
  quando : data !
  quantos : numero !
  partes : texto[1..] !

texto

: b
{preco} ({preco:extenso}), aos {quando:extenso}, em {quando:numeric}.
São {quantos} ({quantos:extenso}) partes: {partes}.
A {quantos:ordinal_f} cláusula.
"""; name = "f.kanon")

    dados = Dict("preco" => Kanon.Money("250000.00", :BRL),
                 "quando" => Date(2026, 3, 12),
                 "quantos" => 3,
                 "partes" => ["Ana", "Bruno", "Carla"])
    s = render(m, dados)

    @testset "dinheiro: símbolo e separadores do idioma (§3.3)" begin
        @test occursin("R\$ 250.000,00", s)
        @test occursin("(duzentos e cinquenta mil reais)", s)
    end

    @testset "data por extenso, e o padrão numérico do idioma" begin
        @test occursin("aos doze dias do mês de março do ano de dois mil e vinte e seis", s)
        @test occursin("em 12/03/2026", s)
    end

    @testset "número por extenso e ordinal feminino" begin
        @test occursin("São 3 (três) partes", s)
        @test occursin("A terceira cláusula.", s)
    end

    @testset "lista com conjunção, e não com vírgula (D-025)" begin
        @test occursin("Ana, Bruno e Carla", s)
        # e o núcleo puro continua juntando por vírgula
        @test Kanon.format(["a", "b"], Val(:default), FormatContext(Environment())) == "a, b"
    end
end

@testset "a camada não vaza para o núcleo" begin
    neutro = Environment()

    @testset "o ambiente sem `locale` não tem nada de português" begin
        @test neutro.locale === nothing
        @test isempty(neutro.marks)
        @test neutro.inflect === nothing && neutro.repair === nothing
        @test neutro.joiner === nothing
        @test neutro.decimal_separator == "." && neutro.group_separator == ""
        @test currency_symbol(neutro, :BRL) == "BRL"
        @test typefor(neutro, :dinheiro) === nothing
    end

    @testset "carregar Extenso não muda a saída do núcleo puro" begin
        # é o motivo de a junção e os apelidos serem gancho de ambiente, e não método
        ctx = FormatContext(neutro)
        @test Kanon.format(["a", "b", "c"], Val(:default), ctx) == "a, b, c"
        @test Kanon.format(1200, Val(:default), ctx) == "1200"
        @test Kanon.format(Kanon.Money("1.00", :BRL), Val(:default), ctx) == "BRL 1.00"
        @test Kanon.format(Date(2026, 3, 12), Val(:numeric), ctx) == "2026-03-12"
    end

    @testset "os formatadores do idioma não existem em ambiente neutro (D-026)" begin
        # Métodos em Julia são globais: sem a declaração de idioma, bastaria este
        # arquivo carregar `Extenso` para `{p:extenso}` valer num modelo em inglês.
        @test :extenso in kanon_formats(Kanon.Money)              # existe no processo
        @test !(:extenso in kanon_formats(Kanon.Money, neutro))   # e não neste ambiente
        @test :extenso in kanon_formats(Kanon.Money, ENV_PT)

        for (T, f) in ((Kanon.Money, :extenso), (Date, :extenso), (Date, :corrente),
                       (Date, :mes), (Int, :extenso), (Int, :ordinal), (Int, :ordinal_f))
            @test Kanon.kanon_format_locale(T, Val(f)) === :pt
            @test !(f in kanon_formats(T, neutro))
        end

        # e os do núcleo continuam valendo em todo ambiente
        for f in (:code, :plain, :symbol)
            @test Kanon.kanon_format_locale(Kanon.Money, Val(f)) === nothing
            @test f in kanon_formats(Kanon.Money, neutro)
        end
    end

    @testset "pedi-lo sem a camada diz qual idioma falta, não que ele não existe" begin
        e = try
            load_string(neutro, "kanon 1\n\ndata\n  p : money !\n\ntext\n\n: b\n{p:extenso}\n";
                        name = "n.kanon")
        catch err
            err
        end
        @test e isa KanonReferenceError
        d = collect(e.diagnostics)[1]
        @test d.code == "K2020"
        @test occursin("idioma `pt`", d.message)
        @test occursin("locale = :pt", d.hint)
    end

    @testset "uma marca não registrada volta a ser prosa (§7.1)" begin
        m = load_string(neutro, "kanon 1\n\ntext\n\n: b\numa casa(s) aqui\n"; name = "t")
        @test render(m, Dict()) == "uma casa(s) aqui"
    end

    @testset "o modelo em português não carrega sem a camada" begin
        e = try
            load_string(neutro, "kanon 1 pt\n\ndados\n  a : texto !\n\ntexto\n\n: b\n{a}\n";
                        name = "t")
        catch err
            err
        end
        @test e isa KanonSyntaxError
        @test "K1006" in [d.code for d in e.diagnostics]    # idioma desconhecido
    end
end

# --- o apelido de tipo é nome, e o núcleo decide pelo canônico ----------------
#
# Descoberto ao escrever o contrato de locação (modelo real nº 2): `quando flag` era
# recusado num modelo em português e aceito no mesmo modelo em inglês. O apelido de
# idioma é resolvido por `typefor`, mas `FieldDecl.type` e `ResolvedPath.typename`
# guardam o nome **escrito** — que é o certo, porque é o que a mensagem de erro tem de
# dizer de volta ao autor. Onde a lógica comparava esse nome com o canônico, o mesmo
# modelo valia numa língua e não valia na outra.
#
# A §9 promete que o idioma renomeia palavras-chave, e nada além disso. Cada teste aqui
# é um lugar onde essa promessa tinha sido quebrada.

"O mesmo modelo, nas duas línguas, sob os ambientes que cada uma exige."
function nas_duas_linguas(corpo_pt, corpo_en)
    (load_string(ENV_PT, corpo_pt; name = "pt.kanon"),
     load_string(Environment(), corpo_en; name = "en.kanon"))
end

@testset "o apelido de tipo é nome; o comportamento é do tipo canônico (§9)" begin
    @testset "um campo `booleano` é condição, como `boolean` é" begin
        pt, en = nas_duas_linguas(
            "kanon 1 pt\n\ndados\n  flag : booleano !\n\ntexto\n\n: a\nSai.\n\n: b\nSempre.\n\nregras\n  a  quando flag\n",
            "kanon 1\n\ndata\n  flag : boolean !\n\ntext\n\n: a\nSai.\n\n: b\nSempre.\n\nrules\n  a  when flag\n")
        @test isempty(pt.analysis.diagnostics)
        @test render(pt, Dict("flag" => true)) == render(en, Dict("flag" => true))
        @test render(pt, Dict("flag" => false)) == "Sempre."
    end

    @testset "o checklist de um modelo em português descreve os tipos" begin
        # Sem isto o `$defs` saía só com `x-kanon`, e o JSON Schema de um modelo em
        # português validava qualquer coisa — o oposto do que a §2.4 promete.
        m = load_string(ENV_PT,
            "kanon 1 pt\n\ndados\n  nome : texto !\n  n : numero !\n  q : data !\n  b : booleano !\n\ntexto\n\n: a\n{nome}{n}{q}{b}\n";
            name = "pt.kanon")
        js = contract(m)
        @test occursin("\"type\": \"string\"", js)
        @test occursin("\"type\": \"number\"", js)
        @test occursin("\"type\": \"boolean\"", js)
        @test occursin("\"format\": \"date\"", js)

        # e o nome do `$defs` continua sendo o que o autor escreveu
        @test occursin("#/\$defs/texto", js)
    end

    @testset "`ask` converte pelo tipo declarado, e `texto` é texto" begin
        m = load_string(ENV_PT, "kanon 1 pt\n\ndados\n  nome : texto !\n\ntexto\n\n: a\n{nome}\n";
                        name = "pt.kanon")
        f = only(m.template.data.fields)
        @test Kanon.coerce_answer(m.env, f, "123") === "123"

        # e o booleano pela palavra do arquivo, que é a que o redator digita (D-061)
        mb = load_string(ENV_PT, "kanon 1 pt\n\ndados\n  ok : booleano !\n\ntexto\n\n: a\nx\n";
                         name = "pt.kanon")
        fb = only(mb.template.data.fields)
        @test Kanon.coerce_answer(mb.env, fb, "verdadeiro") === true
        @test Kanon.coerce_answer(mb.env, fb, "falso") === false
        @test Kanon.coerce_answer(mb.env, fb, "true") === true      # a forma do arquivo de dados
        @test Kanon.coerce_answer(mb.env, fb, "sim") == "sim"       # e o resto o check recusa
        @test occursin("verdadeiro ou falso", Kanon.prompt_de(mb.env, fb))
        @test Kanon.canonical_typename(ENV_PT, :texto) === :text
        @test Kanon.canonical_typename(ENV_PT, :text) === :text      # o canônico é ele mesmo
        @test Kanon.canonical_typename(ENV_PT, :inexistente) === :inexistente
    end

    @testset "a sugestão de um tipo também sai na língua do arquivo" begin
        # O inverso do mesmo cuidado: `written_typename`. Sugerir `text[]` a quem escreve
        # em português seria a D-027 ao contrário. E `lista` é recusado na análise, com o
        # nome que o autor escreveu (D-071).
        a = Kanon.load_source(ENV_PT, "kanon 1 pt\n\ndados\n  itens : lista\n\ntexto\n\n: a\nCom [{itens}].\n";
                              name = "pt.kanon")
        x = only(a.diagnostics)
        @test x.code == "K2009"
        @test occursin("do tipo `lista`, que não se declara", x.message)
        @test occursin("itens : texto[]", x.hint)
        @test !(:lista in typenames(ENV_PT))
        @test Kanon.written_typename(ENV_PT, :text) === :texto
        @test Kanon.written_typename(Environment(), :text) === :text
    end

    @testset "atributos e formatadores têm nome em português, ao lado do inglês (D-076)" begin
        corpo(vazio, positivo, maiusculo, simbolo, numerico, inteiro) =
            "kanon 1 pt\n\ndados\n  nome : texto !\n  itens : texto[]\n  n : numero !\n" *
            "  preco : dinheiro !\n  dia : data !\n\ntexto\n\n" *
            ": a\n{nome:$maiusculo}, {preco:$simbolo}, {dia:$numerico}, {n:$inteiro}.\n\n" *
            ": b\nSem itens.\n\n: c\nPositivo.\n\n" *
            "regras\n  b  quando itens é $vazio\n  c  quando n é $positivo\n"
        pt = load_string(ENV_PT, corpo("vazio", "positivo", "maiusculo", "simbolo", "numerico", "inteiro");
                         name = "pt.kanon")
        en = load_string(ENV_PT, corpo("empty", "positive", "upper", "symbol", "numeric", "integer");
                         name = "en.kanon")
        @test isempty(pt.analysis.diagnostics) && isempty(en.analysis.diagnostics)
        for (itens, n) in ((String[], 3.7), (["x"], -2))
            d = Dict("nome" => "ana", "itens" => itens, "n" => n,
                     "preco" => Kanon.Money("1200.5", :BRL), "dia" => Date(2026, 9, 16))
            @test render(pt, d) == render(en, d)
        end
        @test render(pt, Dict("nome" => "ana", "itens" => String[], "n" => 3.7,
                              "preco" => Kanon.Money("1200.5", :BRL), "dia" => Date(2026, 9, 16))) ==
              "ANA, R\$ 1.200,50, 16/09/2026, 4.\n\nSem itens.\n\nPositivo."

        # o adjetivo concorda com o campo, e os dois gêneros são o mesmo atributo
        @test Kanon.attribute_name(ENV_PT, Vector{String}, :vazia) === :empty
        @test Kanon.attribute_name(ENV_PT, Float64, :negativa) === :negative
    end

    @testset "o apelido é do idioma: não existe em ambiente neutro (D-076)" begin
        a = Kanon.load_source(Environment(), "kanon 1\n\ndata\n  nome : text !\n\ntext\n\n: a\n{nome:maiusculo}\n";
                              name = "en.kanon")
        @test only(a.diagnostics).code == "K2020"
        @test Kanon.formatter_name(Environment(), String, :maiusculo) === nothing
    end

    @testset "a lista do que existe sai na língua do modelo (D-076)" begin
        a = Kanon.load_source(ENV_PT,
            "kanon 1 pt\n\ndados\n  nome : texto !\n  itens : texto[]\n\ntexto\n\n" *
            ": a\n{nome:maiuscula}\n\n: b\nx\n\nregras\n  b  quando itens é vazo\n";
            name = "pt.kanon")
        f = only(filter(d -> d.code == "K2020", collect(a.diagnostics)))
        @test occursin("Você quis dizer `maiusculo`?", f.hint)
        @test !occursin("upper", f.hint)
        g = only(filter(d -> d.code == "K2041", collect(a.diagnostics)))
        # antes da D-076: `Atributos de \`texto\`: absent, empty, present`
        @test occursin("ausente, presente, vazio", g.hint)
    end

    @testset "todo apelido aponta para um nome que alguma camada define (D-076)" begin
        # O `Extenso` não carrega o `KanonScience`, e por isso os nomes dele entram aqui
        # como texto: um apelido para um nome que ninguém define seria erro de digitação
        # que nenhum modelo acusaria.
        ciencia_attr = (:precise, :dimensionless)
        ciencia_fmt = (:relative,)
        nucleo = (String, Float64, Kanon.Money, Date, Bool, Vector{String})
        for (_, c) in Extenso.ATRIBUTOS
            @test c in ciencia_attr || any(T -> c in kanon_attributes(T), nucleo)
        end
        for (_, c) in Extenso.FORMATADORES
            @test c in ciencia_fmt || any(T -> c in kanon_formats(T), nucleo)
        end
    end

    @testset "a mensagem de erro fala o nome escrito, não o canônico" begin
        # A canonicalização é da lógica; a redação continua sendo do autor.
        e = try
            load_string(ENV_PT, "kanon 1 pt\n\ndados\n  n : numero !\n\ntexto\n\n: a\nSai.\n\nregras\n  a  quando n\n";
                        name = "pt.kanon")
        catch err
            err
        end
        @test e isa KanonReferenceError
        d = collect(e.diagnostics)[1]
        @test d.code == "K2040"
        @test occursin("numero", d.message)
        @test !occursin("number", d.message)
    end
end
