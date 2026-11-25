'use strict';

const express = require('express');
const cors = require('cors');

const config = require('./config');
const db = require('./db');
const healthRoutes = require('./routes/health');
const authRoutes = require('./routes/auth');
const friendsRoutes = require('./routes/friends');
const eventsRoutes = require('./routes/events');
const { responderErro } = require('./http');

const app = express();

app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '100kb' }));

app.use('/api/v1', healthRoutes);
app.use('/api/v1', authRoutes);
app.use('/api/v1', friendsRoutes);
app.use('/api/v1', eventsRoutes);

app.use((req, res) => {
  return responderErro(res, 404, 'NAO_ENCONTRADO', 'Rota não encontrada.');
});

app.use((erro, req, res, next) => {
  if (erro instanceof SyntaxError && erro.status === 400 && 'body' in erro) {
    return responderErro(res, 400, 'JSON_INVALIDO', 'Corpo JSON inválido.');
  }
  console.error('[api] erro não tratado:', erro);
  return responderErro(res, 500, 'ERRO_INTERNO', 'Erro interno inesperado.');
});

async function iniciar() {
  const servidor = app.listen(config.port, '0.0.0.0', () => {
    console.log(`[api] PlaceZ API em http://localhost:${config.port}/api/v1`);
    console.log(`[api] health: http://localhost:${config.port}/api/v1/health`);
  });

  // O health check responde imediatamente; a conexão com o Oracle evolui
  // em segundo plano e aparece como db: available/unavailable.
  db.inicializar()
    .then(() => {
      const banco = db.status();
      if (!banco.disponivel) {
        console.warn(`[api] iniciando sem banco: ${banco.erro || 'motivo desconhecido'}`);
      }
    })
    .catch((erro) => {
      console.warn(`[db] falha na inicialização: ${erro.message}`);
    });

  const encerrar = async (sinal) => {
    console.log(`[api] recebido ${sinal}; encerrando...`);
    servidor.close(async () => {
      await db.fechar();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10000).unref();
  };

  process.on('SIGINT', () => encerrar('SIGINT'));
  process.on('SIGTERM', () => encerrar('SIGTERM'));
}

if (require.main === module) {
  iniciar().catch((erro) => {
    console.error('[api] falha ao iniciar:', erro);
    process.exit(1);
  });
}

module.exports = { app };
