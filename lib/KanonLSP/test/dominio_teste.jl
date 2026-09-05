# Um tipo composto de mentira, só para que a suíte possa provar que a completação
# oferece os campos do **sujeito** — o que exige um sujeito com esquema.

struct PessoaTeste
    nome::String
    apelido::Union{Nothing,String}
end

Kanon.kanon_typename(::Type{PessoaTeste}) = :pessoa
Kanon.kanon_schema(::Type{PessoaTeste}) = (Kanon.FieldSpec(:nome, :text),
                                           Kanon.FieldSpec(:apelido, :text; optional = true))
Kanon.kanon_getfield(p::PessoaTeste, ::Val{:nome}) = p.nome
Kanon.kanon_getfield(p::PessoaTeste, ::Val{:apelido}) = p.apelido
Kanon.format(p::PessoaTeste, ::Val{:default}, ctx) = p.nome

module DominioTeste
    using Kanon
    using ..Main: PessoaTeste
    configure!(b) = (register_type!(b, PessoaTeste); b)
end

const ENV_TESTE = Kanon.Environment(domains = [DominioTeste])
