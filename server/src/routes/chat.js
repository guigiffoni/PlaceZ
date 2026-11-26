'use strict';

const express = require('express');
const db = require('../db');
const { autenticar } = require('../middleware/auth');
const { responderErro, bancoIndisponivel, validacao } = require('../http');

const router = express.Router();

router.use('/conversas', autenticar);

const CAMPOS_CONVERSA = `
  c.id,
  c.tipo,
  c.evento_id,
  c.criado_em,
  e.titulo    AS evento_titulo,
  u.id        AS outro_id,
  u.nome      AS outro_nome,
  u.username  AS outro_username,
  um.id       AS ultima_id,
  um.texto    AS ultima_texto,
  um.autor_id AS ultima_autor_id,
  um.criado_em AS ultima_em,
  (SELECT COUNT(*)
     FROM bloqueio b
    WHERE (b.bloqueador_id = :eu AND b.bloqueado_id = u.id)
       OR (b.bloqueador_id = u.id AND b.bloqueado_id = :eu)) AS total_bloqueios,
  (SELECT COUNT(*)
     FROM amizade a
    WHERE a.status = 'A'
      AND ((a.solicitante_id = :eu AND a.destinatario_id = u.id)
        OR (a.destinatario_id = :eu AND a.solicitante_id = u.id))) AS total_amizades
`;

const FROM_CONVERSA = `
  FROM conversa c
  LEFT JOIN usuario u
    ON u.id = CASE
                WHEN c.tipo = 'DIRETA' AND c.usuario_a_id = :eu
                  THEN c.usuario_b_id
                WHEN c.tipo = 'DIRETA'
                  THEN c.usuario_a_id
                ELSE NULL
              END
  LEFT JOIN evento e ON e.id = c.evento_id
  LEFT JOIN mensagem um
    ON um.id = (SELECT MAX(m.id)
                  FROM mensagem m
                 WHERE m.conversa_id = c.id)
`;

function iso(valor) {
  if (valor instanceof Date) return valor.toISOString();
  if (valor == null) return null;
  const data = new Date(valor);
  return Number.isNaN(data.getTime()) ? null : data.toISOString();
}

function tratarErro(res, erro, contexto) {
  if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
  console.error(`[chat] erro em ${contexto}:`, erro);
  return responderErro(
    res,
    500,
    'ERRO_INTERNO',
    'Não foi possível concluir a operação.',
  );
}

function conversaDaLinha(linha) {
  const tipo = linha.TIPO;
  const bloqueada =
    tipo === 'DIRETA' && Number(linha.TOTAL_BLOQUEIOS || 0) > 0;
  const amigos =
    tipo === 'DIRETA' && Number(linha.TOTAL_AMIZADES || 0) > 0;
  return {
    id: linha.ID,
    tipo,
    eventoId: linha.EVENTO_ID || null,
    titulo: linha.EVENTO_TITULO || null,
    outroUsuario: linha.OUTRO_ID
      ? {
          id: linha.OUTRO_ID,
          nome: linha.OUTRO_NOME,
          username: linha.OUTRO_USERNAME,
        }
      : null,
    ultimaMensagem: linha.ULTIMA_ID
      ? {
          id: linha.ULTIMA_ID,
          texto: linha.ULTIMA_TEXTO,
          autorId: linha.ULTIMA_AUTOR_ID,
          criadoEm: iso(linha.ULTIMA_EM),
        }
      : null,
    criadoEm: iso(linha.CRIADO_EM),
    atualizadoEm: iso(linha.ULTIMA_EM || linha.CRIADO_EM),
    bloqueada,
    podeEnviar: tipo === 'EVENTO' ? true : !bloqueada && amigos,
  };
}

function mensagemDaLinha(linha) {
  return {
    id: linha.ID,
    conversaId: linha.CONVERSA_ID,
    autor: {
      id: linha.AUTOR_ID,
      nome: linha.AUTOR_NOME,
      username: linha.AUTOR_USERNAME,
    },
    texto: linha.TEXTO,
    criadoEm: iso(linha.CRIADO_EM),
  };
}

async function buscaConversa(conexao, id, eu) {
  const resultado = await conexao.execute(
    `SELECT ${CAMPOS_CONVERSA}
       ${FROM_CONVERSA}
      WHERE c.id = :id
        AND c.tipo = 'DIRETA'
        AND (c.usuario_a_id = :eu OR c.usuario_b_id = :eu)`,
    { id, eu },
  );
  return (resultado.rows || [])[0] || null;
}

async function buscaConversaResumo(conexao, id, eu) {
  const resultado = await conexao.execute(
    `SELECT ${CAMPOS_CONVERSA}
       ${FROM_CONVERSA}
      WHERE c.id = :id`,
    { id, eu },
  );
  return (resultado.rows || [])[0] || null;
}

async function conversaAcessivel(conexao, id, eu) {
  const resultado = await conexao.execute(
    `SELECT id, tipo, usuario_a_id, usuario_b_id, evento_id
       FROM conversa
      WHERE id = :id`,
    { id },
  );
  const linha = (resultado.rows || [])[0];
  if (!linha) return null;

  if (linha.TIPO === 'DIRETA') {
    if (linha.USUARIO_A_ID !== eu && linha.USUARIO_B_ID !== eu) return null;
    return linha;
  }

  if (linha.TIPO === 'EVENTO') {
    const evento = await conexao.execute(
      `SELECT 1 AS ok
         FROM evento e
        WHERE e.id = :eventoId
          AND (e.criador_id = :eu
            OR EXISTS (
              SELECT 1
                FROM convidado_evento ce
               WHERE ce.evento_id = e.id AND ce.usuario_id = :eu
            ))`,
      { eventoId: linha.EVENTO_ID, eu },
    );
    return (evento.rows || []).length > 0 ? linha : null;
  }

  return null;
}

async function buscaUsuario(conexao, usuarioId) {
  const resultado = await conexao.execute(
    'SELECT id, nome, username FROM usuario WHERE id = :usuarioId',
    { usuarioId },
  );
  return (resultado.rows || [])[0] || null;
}

async function existeBloqueio(conexao, a, b) {
  const resultado = await conexao.execute(
    `SELECT 1 AS existe
       FROM bloqueio
      WHERE (bloqueador_id = :a AND bloqueado_id = :b)
         OR (bloqueador_id = :b AND bloqueado_id = :a)`,
    { a, b },
  );
  return (resultado.rows || []).length > 0;
}

async function saoAmigos(conexao, a, b) {
  const resultado = await conexao.execute(
    `SELECT 1 AS existe
       FROM amizade
      WHERE status = 'A'
        AND ((solicitante_id = :a AND destinatario_id = :b)
          OR (destinatario_id = :a AND solicitante_id = :b))`,
    { a, b },
  );
  return (resultado.rows || []).length > 0;
}

function responderPorCodigo(res, status, codigo) {
  const mensagens = {
    CONVERSA_NAO_ENCONTRADA: 'Conversa não encontrada.',
    CONVERSA_BLOQUEADA:
      'Não é possível enviar mensagens enquanto houver bloqueio.',
    CONVERSA_NAO_PERMITIDA: 'Vocês precisam ser amigos para conversar.',
    USUARIO_NAO_ENCONTRADO: 'Usuário não encontrado.',
    NAO_PODE_SI_MESMO: 'Você não pode conversar consigo mesmo.',
    BLOQUEADO: 'Há um bloqueio entre vocês.',
    EVENTO_NAO_ENCONTRADO: 'Evento não encontrado.',
    CHAT_NAO_ENCONTRADO: 'Este evento ainda não tem chat.',
    SEM_PERMISSAO: 'Você não tem permissão para esta ação.',
    EVENTO_CANCELADO: 'Este evento foi cancelado.',
  };
  return responderErro(
    res,
    status,
    codigo,
    mensagens[codigo] || 'Não foi possível concluir a operação.',
  );
}

// GET /conversas
router.get('/conversas', async (req, res) => {
  const eu = req.usuario.ID;

  try {
    const resultado = await db.executar(
      `SELECT ${CAMPOS_CONVERSA}
         ${FROM_CONVERSA}
        WHERE (
          (c.tipo = 'DIRETA'
            AND (c.usuario_a_id = :eu OR c.usuario_b_id = :eu))
          OR
          (c.tipo = 'EVENTO'
            AND EXISTS (
              SELECT 1
                FROM evento e2
               WHERE e2.id = c.evento_id
                 AND (e2.criador_id = :eu
                   OR EXISTS (
                     SELECT 1
                       FROM convidado_evento ce
                      WHERE ce.evento_id = e2.id
                        AND ce.usuario_id = :eu
                   ))
            ))
        )
        ORDER BY NVL(um.criado_em, c.criado_em) DESC, c.id DESC`,
      { eu },
    );

    const conversas = (resultado.rows || []).map(conversaDaLinha);
    return res.status(200).json({ conversas });
  } catch (erro) {
    return tratarErro(res, erro, 'lista de conversas');
  }
});

// POST /conversas/diretas
router.post('/conversas/diretas', async (req, res) => {
  const eu = req.usuario.ID;
  const outro = Number((req.body || {}).usuarioId);

  if (!Number.isInteger(outro) || outro <= 0) {
    return validacao(res, [
      { campo: 'usuarioId', mensagem: 'Informe um usuário válido.' },
    ]);
  }
  if (outro === eu) {
    return responderPorCodigo(res, 400, 'NAO_PODE_SI_MESMO');
  }

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const alvo = await buscaUsuario(conexao, outro);
      if (!alvo) {
        return { erro: { status: 404, codigo: 'USUARIO_NAO_ENCONTRADO' } };
      }
      if (await existeBloqueio(conexao, eu, outro)) {
        return { erro: { status: 409, codigo: 'BLOQUEADO' } };
      }
      if (!(await saoAmigos(conexao, eu, outro))) {
        return { erro: { status: 409, codigo: 'CONVERSA_NAO_PERMITIDA' } };
      }

      const usuarioA = Math.min(eu, outro);
      const usuarioB = Math.max(eu, outro);
      const existente = await conexao.execute(
        `SELECT id
           FROM conversa
          WHERE tipo = 'DIRETA'
            AND usuario_a_id = :usuarioA
            AND usuario_b_id = :usuarioB`,
        { usuarioA, usuarioB },
      );
      let conversaId = (existente.rows || [])[0]?.ID;

      if (!conversaId) {
        const oracledb = db.getOracle();
        if (!oracledb) throw new db.BancoIndisponivelError();
        const criada = await conexao.execute(
          `INSERT INTO conversa (tipo, usuario_a_id, usuario_b_id)
           VALUES ('DIRETA', :usuarioA, :usuarioB)
           RETURNING id INTO :id`,
          {
            usuarioA,
            usuarioB,
            id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
          },
        );
        conversaId = criada.outBinds.id[0];
      }

      const linha = await buscaConversa(conexao, conversaId, eu);
      await conexao.commit();
      return { conversa: conversaDaLinha(linha), criada: !existente.rows?.length };
    });

    if (resposta.erro) {
      return responderPorCodigo(
        res,
        resposta.erro.status,
        resposta.erro.codigo,
      );
    }
    return res
      .status(resposta.criada ? 201 : 200)
      .json({ conversa: resposta.conversa });
  } catch (erro) {
    return tratarErro(res, erro, 'abertura de conversa direta');
  }
});

// GET /conversas/:id/mensagens?afterId=
router.get('/conversas/:id/mensagens', async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);
  const afterIdBruto = req.query.afterId;
  const afterId =
    afterIdBruto === undefined || afterIdBruto === ''
      ? null
      : Number(afterIdBruto);

  if (!Number.isInteger(id) || id <= 0) {
    return responderPorCodigo(res, 404, 'CONVERSA_NAO_ENCONTRADA');
  }
  if (afterId !== null && (!Number.isInteger(afterId) || afterId < 0)) {
    return validacao(res, [
      {
        campo: 'afterId',
        mensagem: 'Informe um identificador de mensagem válido.',
      },
    ]);
  }

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const conversa = await conversaAcessivel(conexao, id, eu);
      if (!conversa) {
        return { erro: { status: 404, codigo: 'CONVERSA_NAO_ENCONTRADA' } };
      }

      const resultado = await conexao.execute(
        `SELECT *
           FROM (
             SELECT m.id,
                    m.conversa_id,
                    m.autor_id,
                    m.texto,
                    m.criado_em,
                    u.nome AS autor_nome,
                    u.username AS autor_username
               FROM mensagem m
               JOIN usuario u ON u.id = m.autor_id
              WHERE m.conversa_id = :id
                AND (:afterId IS NULL OR m.id > :afterId)
              ORDER BY m.id DESC
           )
          WHERE ROWNUM <= 200
          ORDER BY id ASC`,
        { id, afterId },
      );

      const mensagens = (resultado.rows || []).map(mensagemDaLinha);
      return { mensagens };
    });

    if (resposta.erro) {
      return responderPorCodigo(
        res,
        resposta.erro.status,
        resposta.erro.codigo,
      );
    }
    return res.status(200).json({
      mensagens: resposta.mensagens,
      ultimaId: resposta.mensagens.length
        ? resposta.mensagens[resposta.mensagens.length - 1].id
        : afterId || 0,
    });
  } catch (erro) {
    return tratarErro(res, erro, 'lista de mensagens');
  }
});

// POST /conversas/:id/mensagens
router.post('/conversas/:id/mensagens', async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);
  const texto = String((req.body || {}).texto || '').trim();

  if (!Number.isInteger(id) || id <= 0) {
    return responderPorCodigo(res, 404, 'CONVERSA_NAO_ENCONTRADA');
  }
  if (!texto || texto.length > 2000) {
    return validacao(res, [
      {
        campo: 'texto',
        mensagem: 'Informe uma mensagem entre 1 e 2000 caracteres.',
      },
    ]);
  }

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const oracledb = db.getOracle();
      if (!oracledb) throw new db.BancoIndisponivelError();

      const linha = await conversaAcessivel(conexao, id, eu);
      if (!linha) {
        return { erro: { status: 404, codigo: 'CONVERSA_NAO_ENCONTRADA' } };
      }

      if (linha.TIPO === 'DIRETA') {
        const outro =
          linha.USUARIO_A_ID === eu
            ? linha.USUARIO_B_ID
            : linha.USUARIO_A_ID;
        if (await existeBloqueio(conexao, eu, outro)) {
          return { erro: { status: 409, codigo: 'CONVERSA_BLOQUEADA' } };
        }
        if (!(await saoAmigos(conexao, eu, outro))) {
          return { erro: { status: 409, codigo: 'CONVERSA_NAO_PERMITIDA' } };
        }
      }

      const criada = await conexao.execute(
        `INSERT INTO mensagem (conversa_id, autor_id, texto)
         VALUES (:id, :eu, :texto)
         RETURNING id INTO :mensagemId`,
        {
          id,
          eu,
          texto,
          mensagemId: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
        },
      );
      const mensagemId = criada.outBinds.mensagemId[0];

      const mensagem = await conexao.execute(
        `SELECT m.id,
                m.conversa_id,
                m.autor_id,
                m.texto,
                m.criado_em,
                u.nome AS autor_nome,
                u.username AS autor_username
           FROM mensagem m
           JOIN usuario u ON u.id = m.autor_id
          WHERE m.id = :mensagemId`,
        { mensagemId },
      );

      await conexao.commit();
      return { mensagem: mensagemDaLinha((mensagem.rows || [])[0]) };
    });

    if (resposta.erro) {
      return responderPorCodigo(
        res,
        resposta.erro.status,
        resposta.erro.codigo,
      );
    }
    return res.status(201).json({ mensagem: resposta.mensagem });
  } catch (erro) {
    return tratarErro(res, erro, 'envio de mensagem');
  }
});

// POST /eventos/:id/chat
router.post('/eventos/:id/chat', autenticar, async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);

  if (!Number.isInteger(id) || id <= 0) {
    return responderPorCodigo(res, 404, 'EVENTO_NAO_ENCONTRADO');
  }

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const oracledb = db.getOracle();
      if (!oracledb) throw new db.BancoIndisponivelError();

      const eventoRes = await conexao.execute(
        `SELECT id, titulo, criador_id, status
           FROM evento
          WHERE id = :id`,
        { id },
      );
      const evento = (eventoRes.rows || [])[0];
      if (!evento) {
        return { erro: { status: 404, codigo: 'EVENTO_NAO_ENCONTRADO' } };
      }
      if (evento.CRIADOR_ID !== eu) {
        return { erro: { status: 403, codigo: 'SEM_PERMISSAO' } };
      }
      if (evento.STATUS === 'CANCELADO') {
        return { erro: { status: 409, codigo: 'EVENTO_CANCELADO' } };
      }

      const existente = await conexao.execute(
        `SELECT id FROM conversa WHERE evento_id = :id`,
        { id },
      );
      let conversaId = (existente.rows || [])[0]?.ID;
      let criada = false;

      if (!conversaId) {
        const nova = await conexao.execute(
          `INSERT INTO conversa (tipo, evento_id)
           VALUES ('EVENTO', :id)
           RETURNING id INTO :conversaId`,
          {
            id,
            conversaId: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
          },
        );
        conversaId = nova.outBinds.conversaId[0];
        criada = true;
      }

      const linha = await buscaConversaResumo(conexao, conversaId, eu);
      await conexao.commit();
      return { conversa: conversaDaLinha(linha), criada };
    });

    if (resposta.erro) {
      return responderPorCodigo(
        res,
        resposta.erro.status,
        resposta.erro.codigo,
      );
    }
    return res
      .status(resposta.criada ? 201 : 200)
      .json({ conversa: resposta.conversa });
  } catch (erro) {
    return tratarErro(res, erro, 'criação de chat de evento');
  }
});

// GET /eventos/:id/chat
router.get('/eventos/:id/chat', autenticar, async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);

  if (!Number.isInteger(id) || id <= 0) {
    return responderPorCodigo(res, 404, 'EVENTO_NAO_ENCONTRADO');
  }

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const eventoRes = await conexao.execute(
        `SELECT e.id
           FROM evento e
          WHERE e.id = :id
            AND (e.criador_id = :eu
              OR EXISTS (
                SELECT 1
                  FROM convidado_evento ce
                 WHERE ce.evento_id = e.id AND ce.usuario_id = :eu
              ))`,
        { id, eu },
      );
      if ((eventoRes.rows || []).length === 0) {
        return { erro: { status: 404, codigo: 'EVENTO_NAO_ENCONTRADO' } };
      }

      const conversaRes = await conexao.execute(
        `SELECT id FROM conversa WHERE evento_id = :id`,
        { id },
      );
      const conversaId = (conversaRes.rows || [])[0]?.ID;
      if (!conversaId) {
        return { erro: { status: 404, codigo: 'CHAT_NAO_ENCONTRADO' } };
      }

      const linha = await buscaConversaResumo(conexao, conversaId, eu);
      return { conversa: conversaDaLinha(linha) };
    });

    if (resposta.erro) {
      return responderPorCodigo(
        res,
        resposta.erro.status,
        resposta.erro.codigo,
      );
    }
    return res.status(200).json({ conversa: resposta.conversa });
  } catch (erro) {
    return tratarErro(res, erro, 'consulta de chat de evento');
  }
});

module.exports = router;
