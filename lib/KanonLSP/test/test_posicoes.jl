# A conversão de posição. Três diferenças numa coisa só, e duas delas só aparecem fora do
# inglês — por isso cada teste tem um caractere de cada espécie.

using KanonLSP: to_lsp, to_kanon, utf16_units, linhas_de

@testset "posições: Kanon conta pontos de código, o LSP conta unidades UTF-16" begin
    @testset "em ASCII as duas contagens só diferem pelo zero" begin
        l = "abcdef"
        @test to_lsp(l, 1) == 0
        @test to_lsp(l, 4) == 3
        @test to_kanon(l, 0) == 1
        @test to_kanon(l, 3) == 4
    end

    @testset "acento e § valem 1 nas duas, e vários bytes em nenhuma" begin
        # `ã` são 2 bytes e `§` são 2; uma implementação por índice de byte funcionaria
        # em inglês e erraria aqui, calada.
        l = "§ João"          # § J o ã o  →  1 caractere cada
        @test ncodeunits(l) > length(l)
        @test to_lsp(l, 6) == 5
        @test to_kanon(l, 5) == 6
        @test to_kanon(l, 0) == 1
    end

    @testset "fora do plano básico, uma unidade vira duas" begin
        # E aqui é o contrário: uma implementação por ponto de código funcionaria em
        # português e erraria com emoji, também calada.
        @test utf16_units('a') == 1
        @test utf16_units('ã') == 1
        @test utf16_units('§') == 1
        @test utf16_units('𝄞') == 2

        l = "𝄞x"
        @test to_lsp(l, 2) == 2          # o `x` está na 2ª posição Kanon, na 2ª UTF-16
        @test to_kanon(l, 2) == 2
        @test to_kanon(l, 1) == 1        # no meio do par substituto: o caractere que o contém
    end

    @testset "a ida e a volta se desfazem" begin
        for l in ("abc", "§ João é", "a𝄞b", "")
            for col in 1:(length(l) + 1)
                @test to_kanon(l, to_lsp(l, col)) == col
            end
        end
    end

    @testset "a última linha vazia é uma linha" begin
        # O LSP conta linhas de 0 a n-1, e uma posição no fim do arquivo aponta a última.
        @test length(linhas_de("a\nb\n")) == 3
        @test last(linhas_de("a\nb\n")) == ""
        @test length(linhas_de("a")) == 1
    end
end


# --- URI de arquivo ----------------------------------------------------------
#
# A conversão pura é testada com um caminho do Windows **numa máquina que não é
# Windows** — que é exatamente onde ela quebrou. A versão anterior escapava a barra
# invertida e os dois-pontos, produzindo `file://D%3A%5Ca%5C…`, que não é URI de arquivo
# em lugar nenhum. Nenhum teste olhava, porque todos rodavam onde o caminho é POSIX.

using KanonLSP: uri_from_abspath, path_of, is_windows_path

@testset "URI de arquivo: a ida e a volta, nas duas famílias de caminho" begin
    @testset "POSIX" begin
        @test uri_from_abspath("/tmp/x.kanon") == "file:///tmp/x.kanon"
        @test path_of("file:///tmp/x.kanon") == "/tmp/x.kanon"
        @test !is_windows_path("/tmp/x.kanon")
    end

    @testset "Windows: barras invertidas viram barras, e a unidade ganha a terceira" begin
        @test uri_from_abspath("D:\\a\\Kanon.jl\\x.kanon") ==
              "file:///D:/a/Kanon.jl/x.kanon"
        @test path_of("file:///D:/a/Kanon.jl/x.kanon") == "D:\\a\\Kanon.jl\\x.kanon"
        @test is_windows_path("/D:/a/x.kanon")

        # e o cliente que escapa os dois-pontos — o VS Code faz isso — também volta
        @test path_of("file:///D%3A/a/x.kanon") == "D:\\a\\x.kanon"
    end

    @testset "espaço e acento se escapam, e voltam intactos" begin
        for p in ("/tmp/a b/x.kanon", "/tmp/seção/ç.kanon", "/tmp/x(1).kanon")
            @test path_of(uri_from_abspath(p)) == p
        end
    end

    @testset "o que não é `file:` não tem caminho" begin
        @test path_of("untitled:Untitled-1") == ""
        @test path_of("https://exemplo/x.kanon") == ""
    end
end
