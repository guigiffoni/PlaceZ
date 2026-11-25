'use strict';

const { responderErro, bancoIndisponivel } = require('../http');
const db = require('../db');
const { hashToken } = require('../security');

async function autenticar(req, res, next) {
  const cabecalho = req.headers.authorization || '';
  if (!cabecalho.startsWith('Bearer ')) {
    return responderErro(res, 401, 'NAO_AUTENTICADO', 'Token de sessão ausente.');
  }

  const token = cabecalho.slice('Bearer '.length).trim();
  if (!token) {
    return responderErro(res, 401, 'NAO_AUTENTICADO', 'Token de sessão ausente.');
  }

  const tokenHash = hashToken(token);

  try {
    const resultado = await db.executar(
      `SELECT u.id, u.nome, u.username
         FROM sessao s
         JOIN usuario u ON u.id = s.usuario_id
        WHERE s.token_hash = :tokenHash
          AND s.expira_em > SYS_EXTRACT_UTC(SYSTIMESTAMP)`,
      { tokenHash },
    );

    const linhas = resultado.rows || [];
    if (linhas.length === 0) {
      return responderErro(res, 401, 'SESSAO_EXPIRADA', 'Sessão expirada ou inválida.');
    }

    req.usuario = linhas[0];
    req.tokenHash = tokenHash;
    return next();
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) {
      return bancoIndisponivel(res);
    }
    console.error('[auth] erro ao validar sessão:', erro);
    return responderErro(res, 500, 'ERRO_INTERNO', 'Erro ao validar a sessão.');
  }
}

module.exports = { autenticar };
