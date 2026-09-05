# Os tipos do domínio jurídico, e a prova de D-006.

@testset "os tipos, definidos por @kanon_type" begin
    ctx = FormatContext(ENV_LEGAL)
    ana = Pessoa("Ana Lima", :f, "solteira", "111", "Rua A")
    joao = Pessoa("João Alves", :m, "casado", "222", "Rua B"; regime = "comunhão parcial")

    @testset "pessoa" begin
        @test kanon_typename(Pessoa) === :pessoa
        @test [f.name for f in kanon_schema(Pessoa)] ==
              [:nome, :estado_civil, :cpf, :endereco, :regime, :nascimento]
        @test kanon_schema(Pessoa)[5].optional          # `regime` é opcional
        @test Kanon.format(ana, Val(:default), ctx) == "Ana Lima"
        @test Kanon.format(ana, Val(:maiusculo), ctx) == "ANA LIMA"
        @test kanon_attribute(joao, Val(:casado))
        @test kanon_attribute(ana, Val(:solteiro))
        @test !kanon_attribute(ana, Val(:casado))
    end

    @testset "o gênero é protocolo da camada de idioma, não do núcleo (§7.1)" begin
        @test Extenso.genero(ana) === :f
        @test Extenso.genero(joao) === :m
        @test Extenso.genero([joao, ana]) === :m     # grupo misto
    end

    @testset "imovel" begin
        casa = Imovel("12.345", :urbano, "casa na Rua do Sol")
        sitio = Imovel("99", :rural, "sítio")
        @test Kanon.format(casa, Val(:descricao), ctx) == "casa na Rua do Sol"
        @test Kanon.format(casa, Val(:matricula), ctx) == "12.345"
        @test kanon_attribute(casa, Val(:urbano)) && !kanon_attribute(casa, Val(:rural))
        @test kanon_attribute(sitio, Val(:rural))
    end

    @testset "a idade se calcula sobre uma data injetada, nunca sobre o relógio" begin
        p = Pessoa("X", :m, "solteiro", "1", "R"; nascimento = Date(2008, 6, 15))
        @test idade(p, Date(2026, 6, 14)) == 17
        @test idade(p, Date(2026, 6, 15)) == 18
        @test maior(p, Date(2026, 6, 15))
        @test !maior(p, Date(2026, 6, 14))
        # sem nascimento, não há o que afirmar
        @test idade(Pessoa("Y", :m, "solteiro", "1", "R"), Date(2026, 1, 1)) === nothing
    end
end

@testset "D-006: `parte` prova que a v1 não precisa de tipos-soma" begin
    # A decisão previu que a necessidade de `pessoa | empresa` se atenderia na camada,
    # com um composto e um atributo. Se não desse, a separação núcleo/domínio seria mais
    # fraca do que se supõe.
    fisica = Parte("Ana Lima", :f, "111.222.333-44", "Rua A")
    juridica = Parte("Acme Ltda", :f, "00.000.000/0001-00", "Av. B"; empresa = true,
                     representante = Pessoa("Bo", :m, "casado", "9", "R"))

    @testset "as duas espécies moram no mesmo tipo" begin
        @test kanon_typename(Parte) === :parte
        @test typefor(ENV_LEGAL, :parte) === Parte
        @test kanon_attribute(juridica, Val(:empresa))
        @test kanon_attribute(fisica, Val(:fisica))
    end

    @testset "e o modelo distingue por atributo, sem tipo-soma" begin
        m = load_string(ENV_LEGAL, """
kanon 1 pt

dados
  outorgante : parte !

texto

: cabecalho <- outorgante
{nome}, inscrito no CNPJ {documento}[, neste ato representado por {representante.nome}].

: pessoa_fisica <- outorgante
{nome}, portador do CPF {documento}.

regras
  cabecalho      quando outorgante é empresa
  pessoa_fisica  quando não (outorgante é empresa)
"""; name = "d006.kanon")
        # `is not` traduzido palavra a palavra daria `é não`, agramatical: a localização
        # troca palavras, não ordem sintática. A forma natural usa o `não` prefixo.
        @test isempty(m.analysis.diagnostics)
        @test render(m, Dict("outorgante" => juridica)) ==
              "Acme Ltda, inscrito no CNPJ 00.000.000/0001-00, neste ato representado por Bo."
        # `representante` é opcional em `parte`, e o teorema exigiu o grupo: sem o
        # representante, o trecho inteiro sai
        sem_rep = Parte("Beta SA", :f, "11.111.111/0001-11", "Rua C"; empresa = true)
        @test render(m, Dict("outorgante" => sem_rep)) ==
              "Beta SA, inscrito no CNPJ 11.111.111/0001-11."
        @test render(m, Dict("outorgante" => fisica)) ==
              "Ana Lima, portador do CPF 111.222.333-44."
    end

    @testset "o núcleo continua sem saber que há duas espécies" begin
        # nenhum tipo-soma foi registrado, e a v1 continua recusando a sintaxe deles
        @test length(kanon_schema(Parte)) == 4
        e = try
            load_string(ENV_LEGAL,
                        "kanon 1 pt\n\ndados\n  x : pessoa | imovel !\n\ntexto\n\n: b\n{x}\n";
                        name = "soma.kanon")
        catch err
            err
        end
        @test e isa KanonSyntaxError
        @test "K1106" in [d.code for d in e.diagnostics]
    end
end

@testset "o estilo de cláusula" begin
    e = stylefor(ENV_LEGAL, Char(0x00A7))

    @testset "o rótulo é ordinal por extenso, no feminino" begin
        @test e.number(Int32[1], nothing) == "CLÁUSULA PRIMEIRA"
        @test e.number(Int32[2], nothing) == "CLÁUSULA SEGUNDA"
        @test e.number(Int32[11], nothing) == "CLÁUSULA DÉCIMA PRIMEIRA"
        @test e.layout === :prefix && e.separator == ". "
    end

    @testset "a remissão é a mesma forma, em caixa baixa" begin
        @test e.ref(Int32[2], nothing) == "cláusula segunda"
    end

    @testset "o nível 2 é parágrafo, no masculino" begin
        @test e.number(Int32[1, 1], nothing) == "PARÁGRAFO PRIMEIRO"
        @test e.number(Int32[3, 2], nothing) == "PARÁGRAFO SEGUNDO"
    end

    @testset "`§` sozinho não é cabeçalho: só o núcleo tem forma não numerada" begin
        e2 = try
            load_string(ENV_LEGAL, "kanon 1 pt\n\ntexto\n\n§ solto\nx\n"; name = "s.kanon")
        catch err
            err
        end
        @test e2 isa KanonReferenceError
        @test "K2032" in [d.code for d in e2.diagnostics]
    end
end

@testset "@kanon_type não é atalho para dentro do núcleo (§2.3)" begin
    # A obrigação 2 da §2.3, verificada mecanicamente: tudo que a macro gera é escrevível
    # à mão pelo caminho da §2, e nenhum nome não exportado por `Kanon` aparece.
    expandido = @macroexpand KanonLegal.@kanon_type teste Int begin
        schema     = (FieldSpec(:a, :text),)
        getfield   = (a = :x,)
        default    = (v, ctx) -> string(v)
        formats    = (dobro = (v, ctx) -> string(2v),)
        attributes = (par = v -> iseven(v),)
        compare    = (a, b) -> cmp(a, b)
        locale     = :pt
    end

    # A macro referencia o núcleo por `GlobalRef`, então a varredura é exata: todo nome
    # de `Kanon` que a expansão menciona aparece aqui, e nenhum outro.
    nomes = Symbol[]
    outros = Any[]
    function varrer(e)
        if e isa GlobalRef
            e.mod === Kanon && push!(nomes, e.name)
            e.mod === Kanon || e.mod === Base || push!(outros, e)
        elseif e isa Expr
            foreach(varrer, e.args)
        end
    end
    varrer(expandido)

    @test !isempty(nomes)
    @test isempty(outros)                    # nada de módulo terceiro na expansão
    exportados = names(Kanon)
    for n in unique(nomes)
        @test n in exportados
    end

    @testset "e gera exatamente os métodos da §2" begin
        @test Set(unique(nomes)) == Set([:kanon_typename, :kanon_schema, :kanon_getfield,
                                         :format, :kanon_format_locale, :kanon_attributes,
                                         :kanon_attribute, :kanon_compare])
    end
end
