# Ferramentas

## Ingestão

Extensões: carregadas quando `Tables.jl` ou `JSON3.jl` estão presentes. O núcleo não
depende de nenhum dos dois.

```@docs
rows
render_each
read_json
parse_json
```

## Inclusão de fragmentos

```@docs
Loader
Kanon.compose
```

## Inspeção

O que uma ferramenta de edição consome — a estrutura do modelo já resolvida, sem
reimplementar a análise (D-029).

```@docs
outline
BlockOutline
FieldUse
format_outline
```

## Linha de comando

A lógica da CLI está em `Kanon.main`, que recebe os fluxos como argumento e devolve o
código de saída em vez de encerrar o processo — é o que permite testar os cinco códigos
sem processo filho.

O que isso **não** testa é o carregamento: dentro de uma suíte que já fez `using` da
camada e do `JSON3`, o `--domain` e a leitura de `.json` não têm o que carregar. O fluxo
com camada se testa pelo `bin/kanon`, num processo à parte (D-059, D-060).

    kanon check    modelo.kanon [dados.json]
    kanon render   modelo.kanon dados.json [-o saida.md] [--to markdown|typst]
    kanon contract modelo.kanon
    kanon preview  modelo.kanon [dados.json]
    kanon outline  modelo.kanon
    kanon ask      modelo.kanon [dados] [-o dados.json]

Com camada de domínio: `--locale pt --domain KanonLegal`. Em português sem camada de
domínio, o pacote do idioma se carrega do mesmo jeito: `--locale pt --domain Extenso`
(D-068). O `ask` pergunta todo campo escalar que falta, confere cada resposta pelo
`check`, e emite os dados na forma em que vieram — JSON se a entrada era JSON ou se `-o`
termina em `.json` (D-061). Um número escrito na forma do documento é recusado com a forma
da resposta, e o ambíguo — `1.320`, num idioma em que o ponto separa milhares — com as
duas leituras (D-069).

Códigos de saída: `0` sucesso, `1` contrato, `2` modelo, `3` uso, `4` recurso.
