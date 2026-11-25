'use strict';

const express = require('express');
const db = require('../db');
const config = require('../config');
const { autenticar } = require('../middleware/auth');
const { criarSessao } = require('../session');
const { hashSenha, verificaSenha, bcryptDisponivel } = require('../security');
const { responderErro, bancoIndisponivel, validacao } = require('../http');

const router = express.Router();

function normalizaUsername(valor) {
  return String(valor || '').trim().toLowerCase();
}

function usuarioResposta(linha) {
  return {
    id: linha.ID,
    nome: linha.NOME,
    username: linha.USERNAME,
  };
}

function validaRegistro(body) {
  const detalhes = [];
  const nome = String(body.nome || '').trim();
  const username = normalizaUsername(body.username);
  const senha = String(body.senha || '');

  if (nome.length < 2 || nome.length > 120) {
    detalhes.push({ campo: 'nome', mensagem: 'Informe um nome entre 2 e 120 caracteres.' });
  }
  if (!/^[a-z0-9._-]{3,40}$/.test(username)) {
    detalhes.push({
      campo: 'username',
      mensagem: 'Use de 3 a 40 caracteres: letras, números, ponto, hífen ou sublinhado.',
    });
  }
  if (senha.length < 6 || senha.length > 72) {
    detalhes.push({ campo: 'senha', mensagem: 'A senha deve ter entre 6 e 72 caracteres.' });
  }

  return { detalhes, nome, username, senha };
}

router.post('/auth/registro', async (req, res) => {
  if (!bcryptDisponivel()) {
    return responderErro(
      res,
      503,
      'AUTENTICACAO_INDISPONIVEL',
      'bcryptjs não está instalado. Execute npm install no diretório server.',
    );
  }

  const { detalhes, nome, username, senha } = validaRegistro(req.body || {});
  if (detalhes.length > 0) return validacao(res, detalhes);

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const existente = await conexao.execute(
        'SELECT id FROM usuario WHERE username = :username',
        { username },
      );
      if ((existente.rows || []).length > 0) {
        return { conflito: true };
      }

      const senhaHash = hashSenha(senha);
      await conexao.execute(
        `INSERT INTO usuario (nome, username, senha_hash)
         VALUES (:nome, :username, :senhaHash)`,
        { nome, username, senhaHash },
      );

      const criado = await conexao.execute(
        'SELECT id, nome, username FROM usuario WHERE username = :username',
        { username },
      );
      const linha = (criado.rows || [])[0];
      const sessao = await criarSessao(conexao, linha.ID);
      await conexao.commit();

      return {
        token: sessao.token,
        expiraEm: sessao.expiraEm.toISOString(),
        usuario: usuarioResposta(linha),
      };
    });

    if (resposta.conflito) {
      return responderErro(res, 409, 'USERNAME_EM_USO', 'Este username já está em uso.');
    }
    return res.status(201).json(resposta);
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    if (erro.errorNum === 1 || String(erro.message).includes('ORA-00001')) {
      return responderErro(res, 409, 'USERNAME_EM_USO', 'Este username já está em uso.');
    }
    console.error('[auth] erro no registro:', erro);
    return responderErro(res, 500, 'ERRO_INTERNO', 'Não foi possível criar a conta.');
  }
});

router.post('/auth/login', async (req, res) => {
  if (!bcryptDisponivel()) {
    return responderErro(
      res,
      503,
      'AUTENTICACAO_INDISPONIVEL',
      'bcryptjs não está instalado. Execute npm install no diretório server.',
    );
  }

  const username = normalizaUsername((req.body || {}).username);
  const senha = String((req.body || {}).senha || '');
  if (!username || !senha) {
    return validacao(res, [
      { campo: 'username', mensagem: 'Informe o username.' },
      { campo: 'senha', mensagem: 'Informe a senha.' },
    ]);
  }

  try {
    const resultado = await db.comConexao(async (conexao) => {
      const consulta = await conexao.execute(
        `SELECT id, nome, username, senha_hash
           FROM usuario
          WHERE username = :username`,
        { username },
      );
      const linha = (consulta.rows || [])[0];
      if (!linha || !verificaSenha(senha, linha.SENHA_HASH)) {
        return { invalido: true };
      }

      const sessao = await criarSessao(conexao, linha.ID);
      await conexao.commit();
      return {
        token: sessao.token,
        expiraEm: sessao.expiraEm.toISOString(),
        usuario: usuarioResposta(linha),
      };
    });

    if (resultado.invalido) {
      return responderErro(
        res,
        401,
        'CREDENCIAIS_INVALIDAS',
        'Username ou senha inválidos.',
      );
    }
    return res.status(200).json(resultado);
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    console.error('[auth] erro no login:', erro);
    return responderErro(res, 500, 'ERRO_INTERNO', 'Não foi possível entrar.');
  }
});

router.post('/auth/logout', autenticar, async (req, res) => {
  try {
    await db.executar(
      'DELETE FROM sessao WHERE token_hash = :tokenHash',
      { tokenHash: req.tokenHash },
      { autoCommit: true },
    );
    return res.status(204).send();
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    console.error('[auth] erro no logout:', erro);
    return responderErro(res, 500, 'ERRO_INTERNO', 'Não foi possível encerrar a sessão.');
  }
});

router.get('/me', autenticar, (req, res) => {
  return res.status(200).json({
    id: req.usuario.ID,
    nome: req.usuario.NOME,
    username: req.usuario.USERNAME,
  });
});

module.exports = router;
