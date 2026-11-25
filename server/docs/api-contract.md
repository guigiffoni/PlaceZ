# Contrato REST — PlaceZ

Base URL: `/api/v1`

Formato: JSON em UTF-8. Datas e timestamps em ISO-8601 UTC.
Autenticação: `Authorization: Bearer <token>` nas rotas privadas.

## Envelope de erro

```json
{
  "error": {
    "code": "CODIGO_ESTAVEL",
    "message": "Mensagem legível",
    "details": []
  }
}
```

`details` é opcional e, quando presente, é uma lista de erros de validação.

Códigos usados nesta fase:

| HTTP | Código | Quando ocorre |
|---|---|---|
| 400 | `VALIDACAO` | Payload inválido. |
| 400 | `JSON_INVALIDO` | Corpo não é JSON válido. |
| 401 | `CREDENCIAIS_INVALIDAS` | Login recusado. |
| 401 | `NAO_AUTENTICADO` | Token ausente. |
| 401 | `SESSAO_EXPIRADA` | Token inválido ou expirado. |
| 404 | `NAO_ENCONTRADO` | Rota inexistente. |
| 409 | `USERNAME_EM_USO` | Username já cadastrado. |
| 404 | `USUARIO_NAO_ENCONTRADO` | Username/usuário alvo não existe. |
| 400 | `NAO_PODE_SI_MESMO` | Ação de amizade ou bloqueio contra o próprio usuário. |
| 409 | `BLOQUEADO` | Há bloqueio em qualquer direção entre os usuários. |
| 409 | `SOLICITACAO_DUPLICADA` | Já existe solicitação pendente entre o par. |
| 409 | `JA_SAO_AMIGOS` | O par já tem amizade aceita. |
| 404 | `SOLICITACAO_NAO_ENCONTRADA` | Solicitação inexistente ou sem permissão. |
| 409 | `SOLICITACAO_NAO_PENDENTE` | A solicitação já foi respondida. |
| 404 | `AMIZADE_NAO_ENCONTRADA` | O par não possui amizade aceita. |
| 404 | `BLOQUEIO_NAO_ENCONTRADO` | Bloqueio inexistente. |
| 404 | `EVENTO_NAO_ENCONTRADO` | Evento inexistente ou não visível ao usuário. |
| 403 | `SEM_PERMISSAO` | Ação de evento restrita ao criador ou a quem pode convidar. |
| 409 | `EVENTO_CANCELADO` | Evento cancelado não aceita convites nem RSVP. |
| 404 | `CONVIDADO_NAO_ENCONTRADO` | Usuário não está na lista de convidados. |
| 400 | `NAO_REMOVER_CRIADOR` | Tentativa de remover o criador do evento. |
| 400 | `CRIADOR_RSVP_FIXO` | Criador tentou responder algo diferente de `VOU`. |
| 503 | `BANCO_INDISPONIVEL` | Oracle não configurado ou indisponível. |
| 503 | `AUTENTICACAO_INDISPONIVEL` | Dependência bcryptjs ausente. |
| 500 | `ERRO_INTERNO` | Erro inesperado. |

## Autenticação (Fases 0 e 1)

### `GET /health`

Público.

```json
{
  "status": "ok",
  "db": "available",
  "timestamp": "2026-11-07T12:00:00.000Z"
}
```

`db` pode ser `available` ou `unavailable`. O status HTTP permanece 200.

### `POST /auth/registro`

Público.

Requisição:

```json
{
  "nome": "Ana Silva",
  "username": "ana.silva",
  "senha": "segredo123"
}
```

Resposta `201`:

```json
{
  "token": "token-opaco",
  "expiraEm": "2026-12-07T12:00:00.000Z",
  "usuario": {
    "id": 1,
    "nome": "Ana Silva",
    "username": "ana.silva"
  }
}
```

Regras: nome com 2 a 120 caracteres; username com 3 a 40 caracteres
(`a-z`, `0-9`, `.`, `_`, `-`); senha com 6 a 72 caracteres.

### `POST /auth/login`

Público.

```json
{
  "username": "ana.silva",
  "senha": "segredo123"
}
```

Resposta `200`: mesmo formato do registro. Credenciais erradas retornam
`401 CREDENCIAIS_INVALIDAS` sem indicar se o username existe.

### `POST /auth/logout`

Privado. Sem corpo. Resposta `204`.

### `GET /me`

Privado. Resposta `200`:

```json
{
  "id": 1,
  "nome": "Ana Silva",
  "username": "ana.silva"
}
```

## Amigos (Fase 2)

Todas as rotas abaixo são privadas.

### `GET /usuarios/busca?q=`

Busca por username (mínimo de 2 caracteres, até 20 resultados). Exclui o
próprio usuário e usuários com bloqueio em qualquer direção.

```json
{
  "usuarios": [
    {
      "usuario": { "id": 2, "nome": "Bruno Lima", "username": "bruno" },
      "relacao": "nenhuma",
      "solicitacaoId": null
    }
  ]
}
```

`relacao` pode ser `nenhuma`, `amigos`, `solicitacao_enviada` ou
`solicitacao_recebida`. Quando houver solicitação pendente, `solicitacaoId`
identifica o registro.

### `GET /amigos`

```json
{
  "amigos": [
    {
      "amizadeId": 10,
      "usuario": { "id": 2, "nome": "Bruno Lima", "username": "bruno" }
    }
  ]
}
```

### `GET /amigos/solicitacoes`

```json
{
  "recebidas": [
    {
      "id": 11,
      "usuario": { "id": 3, "nome": "Ana Souza", "username": "ana" },
      "criadoEm": "2026-11-07T12:00:00.000Z"
    }
  ],
  "enviadas": []
}
```

### `POST /amigos/solicitacoes`

```json
{ "username": "bruno" }
```

Resposta `201`:

```json
{
  "id": 12,
  "status": "P",
  "usuario": { "id": 2, "nome": "Bruno Lima", "username": "bruno" }
}
```

Regras:

- Não é possível solicitar a si mesmo (`NAO_PODE_SI_MESMO`).
- Duplicidade em qualquer direção é bloqueada (`SOLICITACAO_DUPLICADA`).
- Par já aceito retorna `JA_SAO_AMIGOS`.
- Bloqueio em qualquer direção retorna `BLOQUEADO`.
- Pedido recusado anteriormente pode ser reenviado; o registro do par é
  reaproveitado e volta para `P`.

### `POST /amigos/solicitacoes/:id/aceitar`

Somente o destinatário. Resposta `200`:

```json
{
  "id": 12,
  "status": "A",
  "usuario": { "id": 2, "nome": "Bruno Lima", "username": "bruno" }
}
```

### `POST /amigos/solicitacoes/:id/recusar`

Somente o destinatário. Resposta `200`, com `status` `"R"`.

### `DELETE /amigos/solicitacoes/:id`

Somente o solicitante e apenas enquanto estiver pendente. Resposta `204`.

### `DELETE /amigos/:usuarioId`

Remove uma amizade aceita em qualquer direção. Resposta `204`.

### `GET /bloqueios`

```json
{
  "bloqueios": [
    {
      "usuario": { "id": 2, "nome": "Bruno Lima", "username": "bruno" },
      "criadoEm": "2026-11-07T12:00:00.000Z"
    }
  ]
}
```

### `POST /bloqueios`

```json
{ "usuarioId": 2 }
```

Resposta `201` com o usuário bloqueado. Efeitos colaterais:

- remove amizade aceita e solicitação pendente entre o par, em qualquer
  direção;
- impede nova solicitação, convite e conversa entre os dois;
- o usuário bloqueado deixa de aparecer na busca e na lista do bloqueador.

### `DELETE /bloqueios/:usuarioId`

Desfaz o bloqueio criado pelo próprio usuário. Resposta `204`. Desbloquear não
recria a amizade; é necessário enviar nova solicitação.

## Eventos (Fase 3)

Todas as rotas abaixo são privadas. Eventos são privados por padrão e só
aparecem para o criador e para os convidados; um usuário não convidado recebe
`404 EVENTO_NAO_ENCONTRADO`, sem confirmar a existência do evento.

Formato do evento retornado pela API:

```json
{
  "id": 1,
  "titulo": "Pizza com os amigos",
  "descricao": "Encontro de sexta",
  "inicioEm": "2026-11-13T23:00:00.000Z",
  "fimEm": "2026-11-14T01:00:00.000Z",
  "local": {
    "id": 7,
    "nome": "Pizzaria Bella Napoli",
    "endereco": "Rua Rio de Janeiro, 830 - Lourdes",
    "categoria": "Pizzaria",
    "distanciaMetros": 1900,
    "latitude": -19.9318,
    "longitude": -43.9428
  },
  "criador": { "id": 2, "nome": "Ana Souza", "username": "ana" },
  "privado": true,
  "permitirMembrosConvidar": false,
  "status": "CONFIRMADO",
  "criadoEm": "2026-11-08T12:00:00.000Z",
  "atualizadoEm": "2026-11-08T12:00:00.000Z",
  "meuRsvp": "VOU",
  "souCriador": true,
  "podeConvidar": true,
  "contagem": { "vou": 1, "talvez": 0, "semResposta": 2 },
  "convidados": []
}
```

`status` pode ser `RASCUNHO`, `CONFIRMADO` ou `CANCELADO`. `meuRsvp` pode ser
`VOU`, `TALVEZ` ou `null` (sem resposta). A ausência de resposta nunca conta
como presença. O criador entra automaticamente como `CRIADOR` com `rsvp`
`VOU`.

No detalhe (`GET /eventos/:id`), `convidados` vem preenchido:

```json
[
  {
    "usuario": { "id": 2, "nome": "Ana Souza", "username": "ana" },
    "papel": "CRIADOR",
    "rsvp": "VOU",
    "convidadoPor": { "id": 2, "nome": "Ana Souza", "username": "ana" },
    "criadoEm": "2026-11-08T12:00:00.000Z",
    "respondidoEm": "2026-11-08T12:00:00.000Z"
  }
]
```

### `GET /eventos?de=&ate=&pessoas=`

Lista os eventos visíveis ao usuário, exceto cancelados, ordenados por início
crescente. `de` e `ate` são opcionais e usam ISO-8601.

`pessoas` é uma lista de IDs separada por vírgulas (ou repetida na query).
Quando presente, retorna os eventos em que **qualquer** pessoa selecionada é
convidada (união). O filtro nunca amplia a visibilidade do usuário.

```json
{ "eventos": [ { "id": 1, "titulo": "..." } ] }
```

### `POST /eventos`

```json
{
  "titulo": "Pizza com os amigos",
  "descricao": "Encontro de sexta",
  "inicioEm": "2026-11-13T23:00:00.000Z",
  "fimEm": "2026-11-14T01:00:00.000Z",
  "local": {
    "nome": "Pizzaria Bella Napoli",
    "endereco": "Rua Rio de Janeiro, 830 - Lourdes",
    "categoria": "Pizzaria",
    "distanciaMetros": 1900,
    "latitude": -19.9318,
    "longitude": -43.9428
  },
  "privado": true,
  "permitirMembrosConvidar": false,
  "convidadoIds": [3]
}
```

Resposta `201`:

```json
{
  "evento": { "id": 1, "titulo": "Pizza com os amigos", "convidados": [] },
  "convidadosAdicionados": [3],
  "convidadosIgnorados": []
}
```

Regras:

- `titulo` é obrigatório (1 a 160 caracteres); `descricao` aceita até 2000.
- `inicioEm`/`fimEm` são opcionais e, quando ambos existem, o fim deve ser
  posterior ao início.
- `local` é um snapshot do catálogo mock ou do mapa/Nominatim. O backend cria
  o registro em `local` e associa ao evento.
- `privado` é `true` por padrão; `permitirMembrosConvidar` é `false`.
- O criador entra como convidado `CRIADOR`/`VOU`.
- Só é possível convidar amigos confirmados, sem bloqueio em qualquer direção
  entre quem convida, o criador e o convidado. Duplicados e o próprio criador
  são devolvidos em `convidadosIgnorados`.

### `GET /eventos/:id`

Resposta `200` com `{ "evento": { ... } }`, incluindo `convidados`. Retorna
`404 EVENTO_NAO_ENCONTRADO` para quem não é criador nem convidado.

### `PATCH /eventos/:id`

Somente o criador. Aceita qualquer subconjunto de `titulo`, `descricao`,
`inicioEm`, `fimEm` e `local` (enviar `local: null` remove o local). Resposta
`200` com `{ "evento": { ... } }`. Não altera convidados nem configurações.

### `DELETE /eventos/:id`

Somente o criador. Marca `status = CANCELADO` e responde `204`. Eventos
cancelados somem da listagem e do calendário; o detalhe continua acessível a
quem já participava.

### `POST /eventos/:id/convidados`

```json
{ "usuarioIds": [3, 4] }
```

Permitido ao criador e, quando `permitirMembrosConvidar = true`, a qualquer
convidado. Quem convida precisa ser amigo confirmado de cada convidado; o
convidado também não pode ter bloqueio com o criador. Resposta `200`:

```json
{
  "evento": { "id": 1, "convidados": [] },
  "adicionados": [3],
  "ignorados": [{ "usuarioId": 4, "motivo": "NAO_E_AMIGO" }]
}
```

Motivos de `ignorados`: `CRIADOR`, `USUARIO_NAO_ENCONTRADO`,
`JA_CONVIDADO`, `BLOQUEADO` e `NAO_E_AMIGO`.

### `POST /eventos/:id/convidados/todos`

Convida em massa todos os amigos do usuário autenticado que ainda não estão no
evento, aplicando as mesmas regras. Resposta `200` no mesmo formato da rota
anterior.

### `DELETE /eventos/:id/convidados/:usuarioId`

O criador remove qualquer convidado (exceto a si mesmo). Um convidado pode
remover a si mesmo (sair do evento). Quando o criador remove alguém, responde
`200` com `{ "evento": { ... } }`; quando um convidado sai, responde `204`.

### `PATCH /eventos/:id/rsvp`

```json
{ "rsvp": "VOU" }
```

Aceita `VOU` ou `TALVEZ`. Somente convidados respondem; o criador é fixo em
`VOU` e recebe `CRIADOR_RSVP_FIXO` se tentar `TALVEZ`. Evento cancelado
responde `409 EVENTO_CANCELADO`. Resposta `200` com o evento detalhado.

### `PATCH /eventos/:id/config`

Somente o criador. Aceita um ou ambos:

```json
{ "privado": false, "permitirMembrosConvidar": true }
```

Resposta `200` com `{ "evento": { ... } }`. O criador pode alterar essa
permissão a qualquer momento.

## Calendário (Fase 4)

### `GET /calendario/pessoas-frequentes`

Privado. Retorna os amigos confirmados que o usuário logado convidou nos
últimos 30 dias, ordenados por quantidade de eventos distintos (decrescente) e,
em empate, por nome (crescente).

```json
{
  "pessoas": [
    { "usuarioId": 2, "nome": "Bruno Lima", "contagem": 3 },
    { "usuarioId": 3, "nome": "Ana Souza", "contagem": 2 }
  ]
}
```

Regras:

- Conta apenas convites feitos pelo usuário logado (`convidado_por`).
- O convidado precisa ser amigo confirmado no momento da consulta.
- Eventos cancelados não entram na contagem.
- A contagem é por evento distinto, não por convite duplicado.
- Eventos em que o usuário é apenas convidado não entram.

## Previsto para as próximas fases

Os contratos abaixo serão implementados nas fases correspondentes; ainda não
existem endpoints funcionais para eles.

### Combinação de dias

- `POST /eventos/:id/enquete` — intervalo, dias da semana e horário.
- `GET /eventos/:id/enquete`
- `PUT /eventos/:id/enquete/votos` — lista de opção/status.
- `GET /eventos/:id/enquete/melhor-dia`
- `POST /eventos/:id/enquete/aplicar-melhor-dia`

### Conversas

- `GET /conversas`
- `POST /conversas/diretas` `{ "usuarioId": 2 }`
- `POST /eventos/:id/chat`
- `GET /conversas/:id/mensagens?afterId=`
- `POST /conversas/:id/mensagens` `{ "texto": "..." }`

## Mock do app

Com `api_mode = mock`, o Flutter usa um backend mock stateful em memória e
persistido em `SharedPreferences`, cobrindo autenticação e amigos (Fase 2).
As rotas ainda não implementadas no mock continuam caindo em
`assets/mock/api_responses.json`, cujas chaves usam o formato
`"MÉTODO /caminho"`.

Contas semeadas no mock (senha `123456`):

| Username | Nome |
|---|---|
| `mock` | Usuário Mock |
| `ana` | Ana Souza |
| `bruno` | Bruno Lima |

Também é possível criar novas contas pelo próprio app; o mock persiste os
usuários, amizades e bloqueios entre execuções.
