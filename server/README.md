# PlaceZ API

API REST do PlaceZ. O Oracle é a fonte de verdade; o app Flutter nunca acessa
o banco diretamente.

## Requisitos

- Node.js 20+
- Oracle Autonomous Database (ADB) acessível pela API

## Configuração do Oracle Autonomous Database

O caminho validado usa ADB **Serverless Always Free** com workload
**Transaction Processing** e **one-way TLS via ACL**. Nesse modo não é
necessário baixar nem configurar wallet.

### 1. Criar o ADB

No OCI Console:

- Workload type: **Transaction Processing**
- Database configuration: **Always Free**
- Network access: **Secure access from allowed IPs and VCNs only**
- Adicione o IP público da VPS como `SEU_IP/32`
- Desmarque **Require mutual TLS (mTLS) authentication**

### 2. Criar o usuário da aplicação

No **Database Actions → SQL**, logado como `ADMIN`:

```sql
CREATE USER placez IDENTIFIED BY "SenhaForteDoPlacez123";
GRANT CONNECT, RESOURCE TO placez;
GRANT DWROLE TO placez;
ALTER USER placez QUOTA UNLIMITED ON DATA;
```

O `DWROLE` permite entrar no Database Actions como `PLACEZ`. A quota é
necessária para os `INSERT`; sem ela o `CREATE TABLE` pode funcionar com
segmentação adiada e o primeiro `INSERT` falhar com `ORA-01950`.

### 3. Aplicar o schema

Faça logout do Database Actions e entre como `PLACEZ`. Confirme o schema:

```sql
SELECT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') FROM dual;
```

Deve retornar `PLACEZ`. Depois execute `sql/schema.sql`.

Em um banco que já tinha o schema de fases anteriores, aplique apenas os
scripts pendentes de `sql/migrations/` na ordem dos nomes. A migração da Fase 5
é `sql/migrations/2026-11-25_fase5.sql`.

As tabelas devem ser criadas no schema `PLACEZ`, não em `ADMIN`.

### 4. Obter a connection string

No ADB: **Database Connection** → selecione **TLS** (não Mutual TLS) →
copie a string do serviço `placezdb_high`.

Ela começa com `(description=...)` e inclui
`(security=(ssl_server_cert_dn=...))`. No `.env` ela deve ficar em uma única
linha.

## Executar localmente

```bash
cd server
npm install
cp .env.example .env
# edite o .env com as credenciais e a connection string do ADB
npm start
```

O servidor inicia mesmo sem Oracle. Nesse caso, o health check responde 200
com `db: "unavailable"` e as rotas de autenticação retornam 503.

## Health check

```text
GET http://localhost:3000/api/v1/health
```

Resposta esperada:

```json
{
  "status": "ok",
  "db": "available",
  "timestamp": "2026-11-23T12:00:00.000Z"
}
```

O health responde imediatamente; a conexão com o Oracle evolui em segundo
plano. Se `db` continuar `unavailable`, verifique o log do processo.

## Implantar na VPS

Copie a pasta `server/` sem `node_modules` e sem `.env`:

```bash
rsync -av --exclude node_modules --exclude .env \
  server/ usuario@IP_DA_VPS:/opt/placez/server/
```

Na VPS:

```bash
cd /opt/placez/server
npm ci
cp .env.example .env
nano .env
node src/index.js
```

Depois de validar o `/health`, use o systemd:

`/etc/systemd/system/placez-api.service`:

```ini
[Unit]
Description=PlaceZ API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/placez/server
EnvironmentFile=/opt/placez/server/.env
ExecStart=/usr/bin/node src/index.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Ajuste `User` e o caminho do Node conforme a VPS. Ative:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now placez-api
sudo systemctl status placez-api
```

Libere a porta 3000 na VPS e na Security List da VCN:

```bash
sudo ufw allow 3000/tcp
```

## Notificações push (Fase 8, modo no-op)

Nesta versão não há envio de push e nenhuma dependência do Firebase. O app
inicia com `NoopNotificacaoService`, que não pede permissão, não gera token e
não faz chamadas ao backend.

Quando o Firebase for configurado:

1. Adicione `firebase_core`, `firebase_messaging` e `google-services.json` no
   Android.
2. Troque a factory `criarNotificacaoService` por uma implementação FCM.
3. Implemente `PUT /me/fcm-token` e o envio no backend.
4. A coluna `usuario.fcm_token` já existe no schema.

O app e a API continuam funcionando sem esse passo; o polling do chat e o
refresh do calendário cobrem a atualização em primeiro plano.

## Gerar o APK apontando para a VPS

A URL da API é definida em tempo de build:

```bash
cd app
flutter build apk --release \
  --dart-define=API_BASE_URL=http://IP_DA_VPS:3000/api/v1
```

O `AndroidManifest.xml` já permite tráfego HTTP para a demonstração.

## Estrutura

```text
server/
  .env.example
  package.json
  sql/schema.sql
  src/
    config.js
    db.js
    http.js
    index.js
    security.js
    session.js
    middleware/auth.js
    routes/auth.js
    routes/chat.js
    routes/events.js
    routes/friends.js
    routes/health.js
  docs/api-contract.md
```

## Segurança

- Senhas são armazenadas com bcrypt (custo 10, configurável).
- Tokens de sessão são opacos; somente o hash SHA-256 é armazenado.
- O `.env` não deve ser versionado.
- A connection string e a senha do banco ficam somente no servidor.
- Nenhuma credencial Oracle é exposta ao app.
- Para a demo, a API usa HTTP na porta 3000. Em produção, use HTTPS atrás de
  um proxy reverso.
