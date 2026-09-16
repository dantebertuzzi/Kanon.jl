+++
titulo = "Desvio padrão explicado sem mistério"
descricao = "O que o desvio padrão mede, como calculá-lo passo a passo, e por que a versão amostral divide por n − 1."
imagem = "/assets/imagens/curva-normal.svg"
autor = "dante-bertuzzi"
data = 2026-05-06
tags = ["Estatística", "Dispersão"]
ref = "desvio-padrao"
+++

Dois grupos de alunos tiraram a mesma nota média, 7. No primeiro, as notas foram 6, 7 e
8; no segundo, 4, 7 e 10. A média não distingue os dois grupos — e é exatamente essa
diferença que o desvio padrão mede.

## A ideia: quanto os valores se afastam da média

Para cada valor, calcula-se a distância até a média. Distâncias positivas e negativas se
cancelariam na soma, então elas são elevadas ao quadrado antes de somar. A média desses
quadrados é a **variância**; a raiz dela devolve a medida à unidade original.

Para uma população de $N$ valores com média $\mu$:

$$ \sigma = \sqrt{\frac{1}{N}\sum_{i=1}^{N}(x_i - \mu)^2} $$

## Passo a passo, no segundo grupo

| nota | afastamento | quadrado |
|---:|---:|---:|
| 4  | −3 | 9 |
| 7  |  0 | 0 |
| 10 |  3 | 9 |

A soma dos quadrados é 18, a média deles é 6, e $\sigma = \sqrt{6} \approx 2{,}45$. No
primeiro grupo, o mesmo cálculo dá $\sqrt{2/3} \approx 0{,}82$.

## Por que a amostra divide por n − 1

Quando os valores são uma **amostra** e a média $\bar{x}$ foi calculada com eles mesmos,
os afastamentos ficam, em média, menores do que seriam em relação à média verdadeira. Dividir
por $n - 1$ em vez de $n$ compensa esse viés:

$$ s = \sqrt{\frac{1}{n-1}\sum_{i=1}^{n}(x_i - \bar{x})^2} $$

Com três notas, a diferença é grande: $s = \sqrt{18/2} = 3$ no segundo grupo. Com mil
valores, é desprezível.
