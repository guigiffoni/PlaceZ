'use strict';

const config = require('./config');

let oracledb = null;
let pool = null;
let ultimoErro = null;
let inicializacao = null;

class BancoIndisponivelError extends Error {
  constructor(mensagem) {
    super(mensagem || 'Banco Oracle indisponível.');
    this.name = 'BancoIndisponivelError';
    this.code = 'BANCO_INDISPONIVEL';
  }
}

async function inicializar() {
  if (inicializacao) return inicializacao;

  inicializacao = (async () => {
    try {
      // O driver é carregado de forma tolerante para que o health check
      // funcione mesmo quando o Oracle ou as dependências ainda não existem.
      oracledb = require('oracledb');
      // outFormat é uma configuração global do driver, não uma propriedade da
      // conexão. Sem isso, conexao.execute() direto retorna arrays e rotas
      // como auth/friends/events quebram ao acessar linha.ID.
      oracledb.outFormat = oracledb.OUT_FORMAT_OBJECT;
    } catch (erro) {
      ultimoErro = `driver oracledb indisponível: ${erro.message}`;
      return;
    }

    if (!config.db.user || !config.db.password || !config.db.connectString) {
      ultimoErro = 'credenciais Oracle não configuradas no .env';
      return;
    }

    try {
      pool = await oracledb.createPool({
        user: config.db.user,
        password: config.db.password,
        connectString: config.db.connectString,
        poolMin: config.db.poolMin,
        poolMax: config.db.poolMax,
        poolIncrement: 1,
      });
      ultimoErro = null;
      console.log('[db] pool Oracle inicializado.');
    } catch (erro) {
      ultimoErro = erro.message;
      console.warn(`[db] Oracle indisponível: ${erro.message}`);
    }
  })();

  return inicializacao;
}

function status() {
  return {
    disponivel: pool !== null,
    erro: ultimoErro,
  };
}

function getOracle() {
  return oracledb;
}

async function pegaConexao() {
  if (!pool) {
    throw new BancoIndisponivelError(ultimoErro || 'Pool Oracle não inicializado.');
  }
  const conexao = await pool.getConnection();
  return conexao;
}

async function comConexao(fn) {
  const conexao = await pegaConexao();
  try {
    return await fn(conexao);
  } finally {
    try {
      await conexao.close();
    } catch (_) {
      // A conexão pode já ter sido fechada pelo driver.
    }
  }
}

async function executar(sql, binds = {}, opcoes = {}) {
  const oracle = getOracle();
  return comConexao((conexao) =>
    conexao.execute(sql, binds, {
      outFormat: oracle ? oracle.OUT_FORMAT_OBJECT : undefined,
      ...opcoes,
    }),
  );
}

async function fechar() {
  if (pool) {
    try {
      await pool.close(10);
    } catch (erro) {
      console.warn(`[db] falha ao fechar pool: ${erro.message}`);
    } finally {
      pool = null;
    }
  }
}

module.exports = {
  BancoIndisponivelError,
  inicializar,
  status,
  getOracle,
  pegaConexao,
  comConexao,
  executar,
  fechar,
};
