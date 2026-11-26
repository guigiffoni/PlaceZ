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
| 409 | `EVENTO_NAO_CONFIRMADO` | RSVP em evento que ainda está em rascunho. |
| 404 | `CONVIDADO_NAO_ENCONTRADO` | Usuário não está na lista de convidados. |
| 400 | `NAO_REMOVER_CRIADOR` | Tentativa de remover o criador do evento. |
| 400 | `CRIADOR_RSVP_FIXO` | Criador tentou responder algo diferente de `VOU`. |
| 404 | `ENQUETE_NAO_ENCONTRADA` | O evento não tem combinação de dias. |
| 409 | `ENQUETE_EXISTENTE` | O evento já tem combinação de dias. |
| 409 | `EVENTO_NAO_ESTA_EM_RASCUNHO` | Combinação/voto em evento já confirmado ou cancelado. |
| 409 | `SEM_DISPONIBILIDADE` | Nenhum participante marcou disponibilidade na melhor data. |
| 404 | `CONVERSA_NAO_ENCONTRADA` | Conversa inexistente ou não visível ao usuário. |
| 409 | `CONVERSA_BLOQUEADA` | Há bloqueio entre os participantes da conversa. |
| 409 | `CONVERSA_NAO_PERMITIDA` | A conversa direta exige amizade confirmada. |
| 404 | `CHAT_NAO_ENCONTRADO` | O evento ainda não tem chat. |
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

Lista os eventos confirmados e visíveis ao usuário, ordenados por início
crescente. Cancelados e rascunhos não aparecem. `de` e `ate` são opcionais e
usam ISO-8601.

`pessoas` é uma lista de IDs separada por vírgulas (ou repetida na query).
Quando presente, retorna os eventos em que **qualquer** pessoa selecionada é
convidada (união). O filtro nunca amplia a visibilidade do usuário.

```json
{ "eventos": [ { "id": 1, "titulo": "..." } ] }
```

### `GET /eventos/rascunhos`

Lista os rascunhos visíveis ao usuário (criador ou convidado), do mais recente
para o mais antigo. Rascunhos não aparecem no calendário até serem
confirmados; esta rota alimenta a seção “Combinações pendentes”.

```json
{ "eventos": [ { "id": 7, "titulo": "...", "status": "RASCUNHO" } ] }
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
  "convidadoIds": [3],
  "rascunho": false
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
- Evento confirmado exige `inicioEm`; `fimEm` é opcional e, quando ambos
  existem, o fim deve ser posterior ao início.
- `rascunho: true` cria o evento com `status = RASCUNHO` e sem datas. O
  rascunho não aparece no calendário; a data é definida pela combinação de
  dias (Fase 5).
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

## Combinação de dias (Fase 5)

### `POST /eventos/:id/enquete`

Somente o criador, com o evento em `RASCUNHO` e sem enquete anterior.

```json
{
  "dataInicio": "2026-11-26",
  "dataFim": "2026-12-10",
  "diasSemana": [6, 7],
  "horaInicio": "19:00",
  "horaFim": "22:00",
  "fusoOffsetMinutos": -180
}
```

Regras:

- `dataInicio`/`dataFim` usam `AAAA-MM-DD`; o intervalo pode ter até 60 dias.
- `diasSemana`: 1 = segunda … 7 = domingo; ao menos um dia.
- `horaFim` deve ser posterior a `horaInicio`.
- O backend gera uma opção para cada data do intervalo que caia nos dias
  escolhidos.
- `fusoOffsetMinutos` é o deslocamento local do criador em relação a UTC
  (ex.: `-180` para UTC-3). Ele é usado ao aplicar a melhor data no evento.

Resposta `201` com `{ "enquete": { ... }, "melhorDia": { ... } }`.

Cada opção tem o formato:

```json
{
  "id": 10,
  "data": "2026-11-28",
  "horaInicio": "19:00",
  "horaFim": "22:00",
  "disponiveis": 1,
  "indisponiveis": 1,
  "totalVotos": 2,
  "percentual": 50,
  "meuVoto": "DISPONIVEL"
}
```

`percentual` é a proporção de `disponiveis` sobre `totalVotos`.

### `GET /eventos/:id/enquete`

Disponível para o criador e para os convidados. Resposta `200` com
`{ "enquete": { ... }, "melhorDia": { ... } }` ou
`404 ENQUETE_NAO_ENCONTRADA`.

### `PUT /eventos/:id/enquete/votos`

```json
{ "votos": [{ "opcaoId": 10, "status": "DISPONIVEL" }] }
```

- Disponível para o criador e para os convidados, enquanto o evento está em
  `RASCUNHO`.
- Votar novamente na mesma opção atualiza o voto (não duplica).
- Opção de outro evento retorna `400 VALIDACAO`.
- Resposta `200` com `{ "enquete": { ... }, "melhorDia": { ... } }`.

### `GET /eventos/:id/enquete/melhor-dia`

Resposta `200` com `{ "melhorDia": { ... } }` ou `null` quando não há opções.

- Vence a opção com maior número de `DISPONIVEL`.
- Empate: data mais próxima de hoje; se equidistante, prefere a futura e
  depois a mais cedo.

### `POST /eventos/:id/enquete/aplicar-melhor-dia`

Somente o criador, com o evento em `RASCUNHO`.

- Aplica a melhor opção em `inicioEm`/`fimEm`, convertendo do fuso local para
  UTC, e muda o evento para `status = CONFIRMADO`.
- Retorna `409 SEM_DISPONIBILIDADE` se ninguém marcou disponibilidade na
  melhor data.
- Resposta `200` com `{ "evento": { ... }, "enquete": { ... }, "melhorDia": { ... } }`.

## Conversas (Fase 6)

### `GET /conversas`

Lista as conversas visíveis ao usuário — diretas e chats de evento — ordenadas
pela última mensagem (decrescente).

- Conversa direta: `tipo = DIRETA`, `outroUsuario` preenchido e `titulo`
  nulo.
- Chat de evento: `tipo = EVENTO`, `outroUsuario` nulo, `titulo` com o nome
  do evento e `podeEnviar = true` para os participantes.

```json
{
  "conversas": [
    {
      "id": 1,
      "tipo": "DIRETA",
      "eventoId": null,
      "titulo": null,
      "outroUsuario": { "id": 3, "nome": "Bruno Lima", "username": "bruno" },
      "ultimaMensagem": {
        "id": 12,
        "texto": "Até mais tarde!",
        "autorId": 2,
        "criadoEm": "2026-11-25T22:00:00.000Z"
      },
      "criadoEm": "2026-11-25T21:00:00.000Z",
      "atualizadoEm": "2026-11-25T22:00:00.000Z",
      "bloqueada": false,
      "podeEnviar": true
    }
  ]
}
```

`bloqueada` indica bloqueio em qualquer direção. `podeEnviar` exige amizade
confirmada e ausência de bloqueio. O histórico continua legível após um
bloqueio ou remoção de amizade; apenas o envio é desabilitado.

### `POST /conversas/diretas`

```json
{ "usuarioId": 3 }
```

Cria ou reabre a conversa direta com um amigo confirmado. É idempotente:
retorna `201` na criação e `200` se a conversa já existir. Resposta com
`{ "conversa": { ... } }`.

Erros: `400 NAO_PODE_SI_MESMO`, `404 USUARIO_NAO_ENCONTRADO`,
`409 BLOQUEADO`, `409 CONVERSA_NAO_PERMITIDA`.

### `GET /conversas/:id/mensagens?afterId=`

Somente participantes da conversa. Retorna até 200 mensagens em ordem
crescente. Com `afterId`, retorna apenas mensagens com `id` maior (polling
incremental).

```json
{
  "mensagens": [
    {
      "id": 12,
      "conversaId": 1,
      "autor": { "id": 2, "nome": "Ana Souza", "username": "ana" },
      "texto": "Até mais tarde!",
      "criadoEm": "2026-11-25T22:00:00.000Z"
    }
  ],
  "ultimaId": 12
}
```

### `POST /conversas/:id/mensagens`

```json
{ "texto": "Combinado!" }
```

Somente participantes. O texto é obrigatório (1 a 2000 caracteres, após
`trim`). Resposta `201` com `{ "mensagem": { ... } }`.

Erros: `409 CONVERSA_BLOQUEADA` ou `409 CONVERSA_NAO_PERMITIDA`.

O polling é responsabilidade do app: 5 s na conversa aberta e 15 s na lista,
sem chamadas em segundo plano.

## Chat de evento (Fase 7)

Chat opcional, persistente e vinculado ao evento. Não é um grupo entre amigos
(isso é P1).

### `POST /eventos/:id/chat`

Somente o criador do evento, desde que o evento não esteja cancelado. Cria o
chat na primeira chamada e é idempotente depois disso (`201` na criação,
`200` se já existir). Resposta com `{ "conversa": { ... } }`.

### `GET /eventos/:id/chat`

Visível ao criador e aos convidados do evento. Retorna
`404 CHAT_NAO_ENCONTRADO` se o criador ainda não ativou o chat e
`404 EVENTO_NAO_ENCONTRADO` para quem não participa do evento.

### Acesso e mensagens

- O chat usa a mesma tabela `mensagem` e as mesmas rotas
  `GET/POST /conversas/:id/mensagens`.
- Criador e convidados do evento podem ler e enviar.
- Remover um convidado do evento remove o acesso ao chat.
- O histórico permanece disponível depois que o evento acontece; cancelar o
  evento não apaga o chat.
- Não há criação de chat de evento por convidados nem chat de grupo entre
  amigos no MVP.

## Previsto para as próximas fases

Os contratos abaixo serão implementados nas fases correspondentes; ainda não
existem endpoints funcionais para eles.

### FCM (Fase 8)

- `PUT /me/fcm-token` `{ "token": "..." }` — registra o token do dispositivo.
- `DELETE /me/fcm-token` — remove o token no logout.

## Mock do app

Com `api_mode = mock`, o Flutter usa um backend mock stateful em memória e
persistido em `SharedPreferences`, cobrindo autenticação, amigos, eventos,
calendário, combinação de dias, conversas 1:1 e chat de evento (Fases 1–7).
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
