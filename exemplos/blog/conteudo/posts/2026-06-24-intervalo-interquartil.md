+++
titulo = "Intervalo interquartil: a dispersão que ignora os extremos"
descricao = "Os quartis, a caixa do boxplot, e a medida de dispersão que não se deixa levar por um valor absurdo."
imagem = "/assets/imagens/diagrama-de-caixa.svg"
autor = "dante-bertuzzi"
data = 2026-06-24
serie = "Medidas de dispersão"
tags = ["Estatística", "Dispersão", "Visualização"]
+++

Os quartis dividem os dados ordenados em quatro partes com o mesmo número de valores. O
primeiro quartil, $Q_1$, deixa um quarto dos valores abaixo; o terceiro, $Q_3$, deixa
três quartos.

O **intervalo interquartil** é a distância entre eles:

$$ \mathrm{IIQ} = Q_3 - Q_1 $$

Ele mede a largura da metade central dos dados, e por isso um valor extremo não o move —
é para a dispersão o que a mediana é para o centro. No diagrama de caixa, é o
comprimento da caixa.
