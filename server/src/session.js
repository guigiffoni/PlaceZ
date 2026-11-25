'use strict';

const config = require('./config');
const db = require('./db');
const { geraToken, hashToken } = require('./security');

async function criarSessao(conexao, usuarioId) {
  const oracle = db.getOracle();
  const token = geraToken();
  const tokenHash = hashToken(token);
  const expiraEm = new Date(Date.now() + config.sessionTtlDays * 24 * 60 * 60 * 1000);

  await conexao.execute(
    `INSERT INTO sessao (token_hash, usuario_id, expira_em)
     VALUES (:tokenHash, :usuarioId, :expiraEm)`,
    {
      tokenHash,
      usuarioId,
      expiraEm: { type: oracle.DATE, val: expiraEm },
    },
  );

  return { token, expiraEm };
}

module.exports = { criarSessao };
