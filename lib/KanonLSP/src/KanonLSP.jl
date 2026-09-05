"""
    KanonLSP

Servidor de linguagem do [`Kanon`](https://github.com/dantebertuzzi/Kanon.jl): a terceira
coluna do editor que a F9 pediu, no formato que serve a todos os editores em vez de a um.

**Nenhuma regra da linguagem mora aqui.** Diagnóstico, estrutura, tipo resolvido,
nulabilidade, numeração e remissão saem da `Analysis` e do `outline`; este pacote decide
apenas o que o protocolo exige — enquadramento, posições e forma de resposta. Uma
ferramenta que discordasse do motor seria pior que nenhuma (D-029), e o jeito de garantir
que ela não discorde é ela não ter opinião.

O que o servidor faz hoje:

| pedido | de onde sai |
|---|---|
| diagnósticos | `load_source`, publicados **por arquivo** — o do fragmento vai para o fragmento |
| estrutura do arquivo | `outline`, com a regra de cada bloco no `detail` |
| o que está sob o cursor | as tabelas da `Analysis`: tipo, formatador, nulabilidade, grupo, número |
| ir para a definição | do uso para a declaração, da remissão para o bloco, atravessando fragmento |
| completar | campos, campos do sujeito, formatadores **do tipo**, blocos, tipos, palavras-chave |

Quais camadas existem é decisão de quem inicia o servidor, e o padrão é o núcleo puro —
a mesma escolha da CLI, e pela mesma razão.

```julia
using Kanon, Extenso, KanonLegal, KanonLSP
KanonLSP.serve(env = Environment(locale = :pt, domains = [KanonLegal]))
```
"""
module KanonLSP

using JSON3
using Kanon

include("posicoes.jl")
include("jsonrpc.jl")
include("documentos.jl")
include("localizar.jl")
include("recursos.jl")
include("servidor.jl")

export serve

end # module
