+++
titulo = "Sobre"
descricao = "Quem escreve, e como este site é feito."
+++

Os textos são de Dante Bertuzzi, e tratam de estatística e probabilidade para quem usa
os números no trabalho sem ter estudado a teoria.

## Como o site é feito

Cada página é um arquivo Markdown em `conteudo/`. O cabeçalho — título, data, autor,
etiquetas — é validado pelo [Kanon](https://dantebertuzzi.github.io/Kanon.jl/) contra o
modelo da página, e só então o [Franklin](https://franklinjl.org/) monta o HTML.

A diferença para um site em Jekyll com Liquid está no que acontece quando alguma coisa
falta: o Liquid publica a página sem ela, e o Kanon não publica o site.
