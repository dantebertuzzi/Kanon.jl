@testset "plano das regras" begin
    src(body) = "kanon 1\n\ntext\n\n: a\nx\n\n: b\ny\n\nrules\n" * body

    "Dump da expressão da primeira regra."
    function ex(body)
        t = ok(src(body))
        dump_expr(t.rules.rules[1].when)
    end

    @testset "as duas espécies de regra" begin
        t = ok(src("  a one for each seller\n  b when price > 0\n"))
        @test t.rules.rules[1].foreach !== nothing
        @test string(t.rules.rules[1].foreach) == "seller"
        @test t.rules.rules[2].when !== nothing
    end

    @testset "comparações" begin
        @test ex("  a when price > 0\n")   == "gt(price,number:0)"
        @test ex("  a when price >= 100\n") == "ge(price,number:100)"
        @test ex("  a when n != 3\n")      == "ne(n,number:3)"
        @test ex("  a when name == \"x\"\n") == "eq(name,text:x)"
        @test ex("  a when d < 2026-01-01\n") == "lt(d,date:2026-01-01)"
    end

    @testset "atributos" begin
        @test ex("  a when property is rural\n") == "is(property,rural)"
        @test ex("  a when seller is not minor\n") == "is(seller,minor,not)"
        @test ex("  a when notes is present\n") == "is(notes,present)"
    end

    @testset "precedência: is/comparação, not, and, or" begin
        @test ex("  a when x is rural and y is urban\n") ==
              "and(is(x,rural),is(y,urban))"
        @test ex("  a when x is rural or y is urban and z is other\n") ==
              "or(is(x,rural),and(is(y,urban),is(z,other)))"
        @test ex("  a when not x is rural and y is urban\n") ==
              "and(not(is(x,rural)),is(y,urban))"
    end

    @testset "parênteses vencem a precedência" begin
        @test ex("  a when (x is rural or y is urban) and z is other\n") ==
              "and(or(is(x,rural),is(y,urban)),is(z,other))"
    end

    @testset "caminho composto no `one for each`" begin
        t = ok(src("  a one for each contract.sellers\n"))
        @test string(t.rules.rules[1].foreach) == "contract.sellers"
    end

    @testset "sem laços, sem aritmética, sem chamada de função" begin
        @test "K1302" in codes(src("  a when price + 1 > 0\n"))
        @test "K1302" in codes(src("  a when soma(price) > 0\n"))
    end

    @testset "regra malformada" begin
        @test "K1301" in codes(src("  a\n"))
        @test "K1301" in codes(src("  a for each seller\n"))
        @test "K1301" in codes(src("  a one each seller\n"))
        @test "K1301" in codes(src("  when price > 0\n"))
    end

    @testset "parêntese não fechado" begin
        @test "K1303" in codes(src("  a when (x is rural\n"))
    end

    @testset "caminho nu analisa; a veracidade implícita é recusada na F2" begin
        t = ok(src("  a when notes\n"))
        @test t.rules.rules[1].when isa PathExpr
    end

    @testset "duas regras da mesma espécie analisam; a recusa é da F2 (D-002)" begin
        t = ok(src("  a when x is rural\n  a when y is urban\n"))
        @test length(t.rules.rules) == 2
    end
end
