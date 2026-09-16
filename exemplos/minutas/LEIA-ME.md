# Gerador de minutas

Escolha um modelo, preencha o formulário, e veja a minuta se formando ao lado — com
«marcadores» no que ainda falta. O download só se habilita quando o contrato do modelo
fecha: não existe minuta incompleta baixada.

```
julia --project -e 'using Pkg; Pkg.instantiate()'   # uma vez
julia --project servidor.jl                         # http://127.0.0.1:8080
julia --project teste.jl                            # a prova
```

O `.docx` sai pelo pandoc: o do `PATH`, ou o que `KANON_PANDOC` aponta. Sem ele, Markdown e
texto continuam baixando.

`http://127.0.0.1:8080/#procuracao/exemplo` abre a procuração já preenchida com os dados
reais do modelo.

## Como é feito

| Arquivo | O quê |
|---|---|
| `catalogo.toml` | os modelos oferecidos — os modelos reais de `test/golden/exemplos/`, usados no lugar |
| `motor.jl` | contrato, prévia, documento e exemplo: as quatro operações, sem HTTP |
| `servidor.jl` | as rotas, só em `127.0.0.1` |
| `pagina.html` | o formulário e a prévia, sem framework |
| `teste.jl` | a prova |

**O formulário não conhece modelo nenhum.** Ele lê o JSON Schema que `contract` escreve e
monta um campo por propriedade: `format: date` vira seletor de data, `oneOf` de `const`
vira lista de opções com rótulo, `array` vira lista com "Adicionar", `$ref` vira um quadro
com os campos do tipo. Obrigatório, opcional e valor padrão vêm do `required` e do
`x-kanon`. A validação e a prévia são pedidas ao servidor, que as pede ao Kanon — nenhuma
regra da linguagem mora na página (D-029).

**O problema aparece no campo.** Cada diagnóstico do Kanon traz o caminho do campo
(`outorgante[2].nome`), e a página o pendura no campo mais específico que esse caminho
alcança.

## O que a prova achou

**A promessa da D-009 não valia para documento jurídico nenhum.** O checklist em JSON Schema
existe desde a F2 para que "qualquer gerador de formulário consuma sem adaptador" — e
ninguém tinha gerado um formulário com ele. Validados num validador de terceiros
(JSONSchema.jl), os JSON reais de cinco modelos, que o motor renderiza byte a byte, eram
**recusados pelo próprio checklist**: o esquema de `pessoa` não tinha `genero`, e proibia
chaves a mais; o decodificador exige `genero`. O mesmo com `tipo` de `imovel` e `genero` e
`empresa` de `parte`. A causa é de desenho: o checklist saía de `kanon_schema`, que é o que
um **modelo lê**, e a entrada pede mais. Corrigido pela **D-079** — `kanon_json_schema`, a
forma de entrada que a camada declara.

**O checklist publicava o caminho da máquina**: `"$id": "kanon:/home/…/procuracao.kanon"`.
Mudava de um computador para outro, num arquivo prometido comparável em `diff`. Agora é o
nome do arquivo (D-079).

**E um esquema escrito à mão pode mentir.** Ao declarar a área do imóvel, escrevi que ela
aceitava número ou texto; o decodificador recusa `"360"`. O formulário, obedecendo ao
checklist, mandava texto, e a doação nunca fechava. O teste do navegador pegou — e só
depois de também ele ser corrigido: procurava a frase "Minuta pronta", que está escrita no
JavaScript da página e por isso aparecia sempre. Os dois erros eram meus, e os dois eram
exatamente a espécie que a prova existe para achar.

Limites, registrados e não corrigidos:

- **A dica de um campo obrigatório é para quem escreve o modelo.** O `K3001` diz "declare o
  campo opcional e envolva em `[...]`", e cita a linha do modelo. Para quem preenche, a ação
  é outra; a página mapeia o código à frase "Preencha este campo." — que é o uso para o qual
  os códigos são estáveis (§10.2).
- **O erro de uma chave dentro de um objeto aponta o objeto.** Falta `genero` no 2º
  outorgante e o caminho é `outorgante[2]`, não `outorgante[2].genero`: a recusa vem do
  decodificador, que recebe o objeto inteiro. A mensagem nomeia a chave.
- **O marcador da prévia é relativo ao sujeito do bloco.** «nome» aparece para o outorgante
  e para o procurador, e não diz de quem é.
- **Os nomes das chaves do núcleo são canônicos e em inglês** (`amount`, `currency`): o
  núcleo não tem idioma, e a página traduz o rótulo — só o rótulo.
