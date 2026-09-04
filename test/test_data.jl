@testset "plano de dados" begin
    src(body) = "kanon 1\n\ndata\n" * body * "\ntext\n\n: b\nx\n"

    @testset "as três marcas, e apenas três" begin
        t = ok(src("  a : text !\n  b : text = \"padrão\"\n  c : text\n"))
        @test [f.presence for f in t.data.fields] == [REQUIRED, DEFAULTED, OPTIONAL]
        @test t.data.fields[2].default.kind === :text
        @test t.data.fields[2].default.value == "padrão"
    end

    @testset "só o campo opcional é nulável" begin
        t = ok(src("  a : text !\n  b : text\n"))
        @test (t.data.fields[1].presence === OPTIONAL) == false
        @test (t.data.fields[2].presence === OPTIONAL) == true
    end

    @testset "cardinalidades" begin
        t = ok(src("""
  a : person
  b : person[]
  c : person[2]
  d : person[1..]
  e : person[2..5]
  f : person[..5]
"""))
        cards = [(f.card.kind, f.card.lo, f.card.hi) for f in t.data.fields]
        @test cards[1] == (SCALAR, 0, 0)
        @test cards[2][1] === ANY
        @test cards[3] == (EXACT, 2, 2)
        @test cards[4][1] === ATLEAST && cards[4][2] == 1
        @test cards[5] == (RANGE, 2, 5)
        @test cards[6] == (RANGE, 0, 5)
    end

    @testset "cardinalidade malformada" begin
        @test "K1102" in codes(src("  a : person[x]\n"))
        @test "K1102" in codes(src("  a : person[5..2]\n"))
    end

    @testset "literais de valor padrão" begin
        t = ok(src("""
  n : number  = 42
  r : number  = -3.5
  s : text    = "olá"
  b : boolean = true
  d : date    = 2026-03-12
  h : date    = today
"""))
        ls = [f.default for f in t.data.fields]
        @test (ls[1].kind, ls[1].value) == (:number, 42)
        @test ls[2].value == -3.5
        @test (ls[3].kind, ls[3].value) == (:text, "olá")
        @test (ls[4].kind, ls[4].value) == (:boolean, true)
        @test (ls[5].kind, ls[5].value) == (:date, Kanon.Dates.Date(2026, 3, 12))
        @test (ls[6].kind, ls[6].value) == (:constant, :today)
    end

    @testset "data inexistente" begin
        @test "K1104" in codes(src("  d : date = 2026-13-45\n"))
    end

    @testset "declaração malformada" begin
        @test "K1101" in codes(src("  a text !\n"))
        @test "K1101" in codes(src("  a :\n"))
        @test "K1101" in codes(src("  : text !\n"))
        @test "K1101" in codes(src("  a : text ! sobra\n"))
    end

    @testset "obrigatório e padrão são exclusivos" begin
        @test "K1103" in codes(src("  a : text ! = \"x\"\n"))
    end

    @testset "campo declarado duas vezes" begin
        @test "K1105" in codes(src("  a : text !\n  a : number !\n"))
    end

    @testset "tipo-soma é reservado e erra explicitamente (D-006)" begin
        @test "K1106" in codes(src("  a : person | company\n"))
    end

    @testset "comentário respeita aspas" begin
        t = ok(src("  a : text = \"tem # dentro\"   # e um comentário fora\n"))
        @test t.data.fields[1].default.value == "tem # dentro"
    end

    @testset "acentuação em nome de campo" begin
        t = ok(src("  endereço_do_imóvel : text !\n"))
        @test t.data.fields[1].name === :endereço_do_imóvel
    end
end
