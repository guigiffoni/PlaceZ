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

const MIMES_FOTO = new Set(['image/jpeg', 'image/png', 'image/webp']);
const LIMITE_FOTO_BYTES = 512 * 1024;

function mimeDaImagem(buffer) {
  if (buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return 'image/jpeg';
  }
  if (
    buffer.length >= 8 &&
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47
  ) {
    return 'image/png';
  }
  if (
    buffer.length >= 12 &&
    buffer.toString('ascii', 0, 4) === 'RIFF' &&
    buffer.toString('ascii', 8, 12) === 'WEBP'
  ) {
    return 'image/webp';
  }
  return null;
}

router.put('/me/foto', autenticar, async (req, res) => {
  const corpo = req.body || {};
  const imagem = String(corpo.imagemBase64 || '').trim();
  let mime = String(corpo.mime || 'image/jpeg').trim().toLowerCase();

  if (!imagem) {
    return validacao(res, [
      { campo: 'imagemBase64', mensagem: 'Envie uma imagem.' },
    ]);
  }
  if (!MIMES_FOTO.has(mime)) {
    return validacao(res, [
      { campo: 'mime', mensagem: 'Use image/jpeg, image/png ou image/webp.' },
    ]);
  }

  const buffer = Buffer.from(imagem, 'base64');
  if (buffer.length === 0 || buffer.length > LIMITE_FOTO_BYTES) {
    return validacao(res, [
      {
        campo: 'imagemBase64',
        mensagem: 'A imagem deve ter no máximo 512 KB.',
      },
    ]);
  }

  const mimeDetectado = mimeDaImagem(buffer);
  if (!mimeDetectado) {
    return validacao(res, [
      {
        campo: 'imagemBase64',
        mensagem: 'Envie uma imagem JPEG, PNG ou WebP válida.',
      },
    ]);
  }
  mime = mimeDetectado;

  try {
    await db.executar(
      `UPDATE usuario
          SET foto = :foto,
              foto_mime = :mime,
              foto_atualizada_em = SYS_EXTRACT_UTC(SYSTIMESTAMP)
        WHERE id = :eu`,
      { foto: buffer, mime, eu: req.usuario.ID },
      { autoCommit: true },
    );
    return res.status(200).json({
      mime,
      tamanho: buffer.length,
      atualizadoEm: new Date().toISOString(),
    });
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    console.error('[auth] erro ao salvar foto:', erro);
    return responderErro(
      res,
      500,
      'ERRO_INTERNO',
      'Não foi possível salvar a foto.',
    );
  }
});

router.delete('/me/foto', autenticar, async (req, res) => {
  try {
    await db.executar(
      `UPDATE usuario
          SET foto = NULL,
              foto_mime = NULL,
              foto_atualizada_em = NULL
        WHERE id = :eu`,
      { eu: req.usuario.ID },
      { autoCommit: true },
    );
    return res.status(204).send();
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    console.error('[auth] erro ao remover foto:', erro);
    return responderErro(
      res,
      500,
      'ERRO_INTERNO',
      'Não foi possível remover a foto.',
    );
  }
});

router.get('/usuarios/:id/foto', autenticar, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) {
    return responderErro(
      res,
      404,
      'FOTO_NAO_ENCONTRADA',
      'Foto não encontrada.',
    );
  }

  try {
    const resultado = await db.executar(
      `SELECT foto, foto_mime, foto_atualizada_em
         FROM usuario
        WHERE id = :id`,
      { id },
    );
    const linha = (resultado.rows || [])[0];
    let foto = linha ? linha.FOTO : null;
    if (foto && typeof foto.getData === 'function') {
      foto = await foto.getData();
    }

    if (!foto || foto.length === 0) {
      return responderErro(
        res,
        404,
        'FOTO_NAO_ENCONTRADA',
        'Foto não encontrada.',
      );
    }

    res.set('Content-Type', linha.FOTO_MIME || 'image/jpeg');
    res.set('Content-Length', String(foto.length));
    res.set('Cache-Control', 'private, max-age=300');
    if (linha.FOTO_ATUALIZADA_EM) {
      res.set(
        'ETag',
        `"${new Date(linha.FOTO_ATUALIZADA_EM).getTime()}"`,
      );
    }
    return res.status(200).send(foto);
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    console.error('[auth] erro ao ler foto:', erro);
    return responderErro(
      res,
      500,
      'ERRO_INTERNO',
      'Não foi possível carregar a foto.',
    );
  }
});

router.patch('/me', autenticar, async (req, res) => {
  const nome = String((req.body || {}).nome || '').trim();
  if (nome.length < 2 || nome.length > 120) {
    return validacao(res, [
      {
        campo: 'nome',
        mensagem: 'Informe um nome entre 2 e 120 caracteres.',
      },
    ]);
  }

  try {
    await db.executar(
      'UPDATE usuario SET nome = :nome WHERE id = :eu',
      { nome, eu: req.usuario.ID },
      { autoCommit: true },
    );
    return res.status(200).json({
      id: req.usuario.ID,
      nome,
      username: req.usuario.USERNAME,
    });
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    console.error('[auth] erro ao editar perfil:', erro);
    return responderErro(
      res,
      500,
      'ERRO_INTERNO',
      'Não foi possível atualizar o perfil.',
    );
  }
});

module.exports = router;
