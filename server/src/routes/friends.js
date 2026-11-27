'use strict';

const express = require('express');
const db = require('../db');
const { autenticar } = require('../middleware/auth');
const { responderErro, bancoIndisponivel, validacao } = require('../http');

const router = express.Router();

// Aplica autenticação apenas aos prefixos de amigos; rotas desconhecidas
// continuam caindo no 404 global em vez de exigir token.
router.use(['/amigos', '/usuarios', '/bloqueios'], autenticar);

function normalizaUsername(valor) {
  return String(valor || '').trim().toLowerCase();
}

function iso(valor) {
  if (valor instanceof Date) return valor.toISOString();
  if (valor == null) return null;
  const data = new Date(valor);
  return Number.isNaN(data.getTime()) ? null : data.toISOString();
}

function usuarioDaLinha(linha) {
  return {
    id: linha.USUARIO_ID,
    nome: linha.USUARIO_NOME,
    username: linha.USUARIO_USERNAME,
  };
}

function tratarErro(res, erro, contexto) {
  if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
  console.error(`[amigos] erro em ${contexto}:`, erro);
  return responderErro(
    res,
    500,
    'ERRO_INTERNO',
    'Não foi possível concluir a operação.',
  );
}

async function buscaUsuario(conexao, usuarioId) {
  const resultado = await conexao.execute(
    'SELECT id, nome, username FROM usuario WHERE id = :usuarioId',
    { usuarioId },
  );
  return (resultado.rows || [])[0] || null;
}

async function amizadeDoPar(conexao, eu, outro, bloqueio = false) {
  const sql = `SELECT id, solicitante_id, destinatario_id, status
                 FROM amizade
                WHERE (solicitante_id = :eu AND destinatario_id = :outro)
                   OR (destinatario_id = :eu AND solicitante_id = :outro)`;
  const resultado = await conexao.execute(
    bloqueio ? `${sql} FOR UPDATE` : sql,
    { eu, outro },
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

function relacaoDaBusca(linha, eu) {
  if (!linha.AMIZADE_ID) {
    return { relacao: 'nenhuma', solicitacaoId: null };
  }
  if (linha.AMIZADE_STATUS === 'A') {
    return { relacao: 'amigos', solicitacaoId: null };
  }
  if (linha.AMIZADE_STATUS === 'P') {
    return {
      relacao:
        linha.SOLICITANTE_ID === eu
          ? 'solicitacao_enviada'
          : 'solicitacao_recebida',
      solicitacaoId: linha.AMIZADE_ID,
    };
  }
  return { relacao: 'nenhuma', solicitacaoId: null };
}

// GET /usuarios/busca?q=
router.get('/usuarios/busca', async (req, res) => {
  const eu = req.usuario.ID;
  const termo = normalizaUsername(req.query.q);

  if (termo.length < 2) {
    return validacao(res, [
      { campo: 'q', mensagem: 'Informe ao menos 2 caracteres para buscar.' },
    ]);
  }

  const pagina = Number(req.query.pagina || 1);
  const limite = Number(req.query.limite || 20);
  const erros = [];
  if (!Number.isInteger(pagina) || pagina < 1) {
    erros.push({ campo: 'pagina', mensagem: 'Informe uma página válida.' });
  }
  if (!Number.isInteger(limite) || limite < 1 || limite > 50) {
    erros.push({
      campo: 'limite',
      mensagem: 'Informe um limite entre 1 e 50.',
    });
  }
  if (erros.length) return validacao(res, erros);

  try {
    const resultado = await db.executar(
      `SELECT u.id AS usuario_id,
              u.nome AS usuario_nome,
              u.username AS usuario_username,
              a.id AS amizade_id,
              a.status AS amizade_status,
              a.solicitante_id AS solicitante_id
         FROM usuario u
         LEFT JOIN amizade a
           ON (a.solicitante_id = :eu AND a.destinatario_id = u.id)
           OR (a.destinatario_id = :eu AND a.solicitante_id = u.id)
        WHERE u.id <> :eu
          AND LOWER(u.username) LIKE :termo
          AND NOT EXISTS (
                SELECT 1
                  FROM bloqueio b
                 WHERE (b.bloqueador_id = :eu AND b.bloqueado_id = u.id)
                    OR (b.bloqueador_id = u.id AND b.bloqueado_id = :eu)
              )
        ORDER BY u.username
        OFFSET ${(pagina - 1) * limite}
        ROWS FETCH NEXT ${limite + 1} ROWS ONLY`,
      { eu, termo: `%${termo}%` },
    );

    const linhas = resultado.rows || [];
    const temMais = linhas.length > limite;
    const usuarios = linhas.slice(0, limite).map((linha) => {
      const { relacao, solicitacaoId } = relacaoDaBusca(linha, eu);
      return {
        usuario: usuarioDaLinha(linha),
        relacao,
        solicitacaoId,
      };
    });

    return res.status(200).json({ usuarios, pagina, limite, temMais });
  } catch (erro) {
    return tratarErro(res, erro, 'busca de usuários');
  }
});

// GET /amigos
router.get('/amigos', async (req, res) => {
  const eu = req.usuario.ID;

  try {
    const resultado = await db.executar(
      `SELECT a.id AS amizade_id,
              u.id AS usuario_id,
              u.nome AS usuario_nome,
              u.username AS usuario_username,
              u.localizacao_bairro,
              u.localizacao_cidade,
              r.nome   AS regiao_nome,
              r.cidade AS regiao_cidade,
              CASE WHEN af.usuario_id IS NOT NULL THEN 1 ELSE 0 END AS favorito
         FROM amizade a
         JOIN usuario u
           ON u.id = CASE
                       WHEN a.solicitante_id = :eu THEN a.destinatario_id
                       ELSE a.solicitante_id
                     END
         LEFT JOIN regiao_aproximada r ON r.id = u.regiao_id
         LEFT JOIN amizade_favorito af
           ON af.usuario_id = :eu
          AND af.amigo_usuario_id = u.id
        WHERE a.status = 'A'
          AND (a.solicitante_id = :eu OR a.destinatario_id = :eu)
        ORDER BY CASE WHEN af.usuario_id IS NOT NULL THEN 0 ELSE 1 END,
                 u.nome`,
      { eu },
    );

    const amigos = (resultado.rows || []).map((linha) => {
      const bairro =
        linha.LOCALIZACAO_BAIRRO || linha.REGIAO_NOME || null;
      const cidade =
        linha.LOCALIZACAO_CIDADE || linha.REGIAO_CIDADE || null;
      return {
        amizadeId: linha.AMIZADE_ID,
        usuario: usuarioDaLinha(linha),
        localizacaoAproximada: bairro
          ? { bairro, cidade }
          : null,
        favorito: Number(linha.FAVORITO || 0) === 1,
      };
    });

    return res.status(200).json({ amigos });
  } catch (erro) {
    return tratarErro(res, erro, 'lista de amigos');
  }
});

// PUT /amigos/:usuarioId/favorito
router.put('/amigos/:usuarioId/favorito', async (req, res) => {
  const eu = req.usuario.ID;
  const amigoId = Number(req.params.usuarioId);

  if (!Number.isInteger(amigoId) || amigoId <= 0 || amigoId === eu) {
    return validacao(res, [
      { campo: 'usuarioId', mensagem: 'Informe um amigo válido.' },
    ]);
  }

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const amizade = await amizadeDoPar(conexao, eu, amigoId);
      if (!amizade || amizade.STATUS !== 'A') {
        return { erro: { status: 404, codigo: 'AMIGO_NAO_ENCONTRADO' } };
      }

      await conexao.execute(
        `MERGE INTO amizade_favorito destino
         USING (
           SELECT :eu AS usuario_id, :amigoId AS amigo_usuario_id FROM dual
         ) origem
            ON (destino.usuario_id = origem.usuario_id
                AND destino.amigo_usuario_id = origem.amigo_usuario_id)
          WHEN NOT MATCHED THEN
            INSERT (usuario_id, amigo_usuario_id)
            VALUES (origem.usuario_id, origem.amigo_usuario_id)`,
        { eu, amigoId },
      );
      await conexao.commit();
      return { favorito: true };
    });

    if (resposta.erro) {
      return responderErro(
        res,
        resposta.erro.status,
        resposta.erro.codigo,
        'Amigo não encontrado.',
      );
    }
    return res.status(200).json(resposta);
  } catch (erro) {
    return tratarErro(res, erro, 'favoritar amigo');
  }
});

// DELETE /amigos/:usuarioId/favorito
router.delete('/amigos/:usuarioId/favorito', async (req, res) => {
  const eu = req.usuario.ID;
  const amigoId = Number(req.params.usuarioId);

  if (!Number.isInteger(amigoId) || amigoId <= 0) {
    return validacao(res, [
      { campo: 'usuarioId', mensagem: 'Informe um amigo válido.' },
    ]);
  }

  try {
    await db.executar(
      `DELETE FROM amizade_favorito
        WHERE usuario_id = :eu AND amigo_usuario_id = :amigoId`,
      { eu, amigoId },
      { autoCommit: true },
    );
    return res.status(200).json({ favorito: false });
  } catch (erro) {
    return tratarErro(res, erro, 'desfavoritar amigo');
  }
});

// GET /amigos/solicitacoes
router.get('/amigos/solicitacoes', async (req, res) => {
  const eu = req.usuario.ID;

  try {
    const recebidas = await db.executar(
      `SELECT a.id AS solicitacao_id,
              a.criado_em,
              u.id AS usuario_id,
              u.nome AS usuario_nome,
              u.username AS usuario_username
         FROM amizade a
         JOIN usuario u ON u.id = a.solicitante_id
        WHERE a.status = 'P'
          AND a.destinatario_id = :eu
        ORDER BY a.criado_em DESC`,
      { eu },
    );

    const enviadas = await db.executar(
      `SELECT a.id AS solicitacao_id,
              a.criado_em,
              u.id AS usuario_id,
              u.nome AS usuario_nome,
              u.username AS usuario_username
         FROM amizade a
         JOIN usuario u ON u.id = a.destinatario_id
        WHERE a.status = 'P'
          AND a.solicitante_id = :eu
        ORDER BY a.criado_em DESC`,
      { eu },
    );

    const monta = (linha) => ({
      id: linha.SOLICITACAO_ID,
      usuario: usuarioDaLinha(linha),
      criadoEm: iso(linha.CRIADO_EM),
    });

    return res.status(200).json({
      recebidas: (recebidas.rows || []).map(monta),
      enviadas: (enviadas.rows || []).map(monta),
    });
  } catch (erro) {
    return tratarErro(res, erro, 'solicitações de amizade');
  }
});

// POST /amigos/solicitacoes
router.post('/amigos/solicitacoes', async (req, res) => {
  const eu = req.usuario.ID;
  const username = normalizaUsername((req.body || {}).username);

  if (!/^[a-z0-9._-]{3,40}$/.test(username)) {
    return validacao(res, [
      {
        campo: 'username',
        mensagem: 'Use de 3 a 40 caracteres: letras, números, ponto, hífen ou sublinhado.',
      },
    ]);
  }

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const alvoResultado = await conexao.execute(
        'SELECT id, nome, username FROM usuario WHERE username = :username',
        { username },
      );
      const usuarioAlvo = (alvoResultado.rows || [])[0];
      if (!usuarioAlvo) {
        return { erro: { status: 404, codigo: 'USUARIO_NAO_ENCONTRADO' } };
      }
      if (usuarioAlvo.ID === eu) {
        return { erro: { status: 400, codigo: 'NAO_PODE_SI_MESMO' } };
      }

      if (await existeBloqueio(conexao, eu, usuarioAlvo.ID)) {
        return { erro: { status: 409, codigo: 'BLOQUEADO' } };
      }

      const existente = await amizadeDoPar(conexao, eu, usuarioAlvo.ID, true);
      let id = existente ? existente.ID : null;

      if (existente) {
        if (existente.STATUS === 'P') {
          return { erro: { status: 409, codigo: 'SOLICITACAO_DUPLICADA' } };
        }
        if (existente.STATUS === 'A') {
          return { erro: { status: 409, codigo: 'JA_SAO_AMIGOS' } };
        }

        // Pedido recusado anteriormente: reaproveita o par e volta para pendente.
        await conexao.execute(
          `UPDATE amizade
              SET solicitante_id = :eu,
                  destinatario_id = :outro,
                  status = 'P',
                  criado_em = SYS_EXTRACT_UTC(SYSTIMESTAMP),
                  respondido_em = NULL
            WHERE id = :id`,
          { eu, outro: usuarioAlvo.ID, id },
        );
      } else {
        await conexao.execute(
          `INSERT INTO amizade (solicitante_id, destinatario_id, status)
           VALUES (:eu, :outro, 'P')`,
          { eu, outro: usuarioAlvo.ID },
        );
        const criado = await conexao.execute(
          `SELECT id FROM amizade
            WHERE solicitante_id = :eu AND destinatario_id = :outro`,
          { eu, outro: usuarioAlvo.ID },
        );
        id = (criado.rows || [])[0].ID;
      }

      await conexao.commit();
      return {
        id,
        usuario: {
          id: usuarioAlvo.ID,
          nome: usuarioAlvo.NOME,
          username: usuarioAlvo.USERNAME,
        },
      };
    });

    if (resposta.erro) {
      return responderPorCodigo(res, resposta.erro.status, resposta.erro.codigo);
    }

    return res.status(201).json({
      id: resposta.id,
      status: 'P',
      usuario: resposta.usuario,
    });
  } catch (erro) {
    if (erro.errorNum === 1 || String(erro.message).includes('ORA-00001')) {
      return responderErro(
        res,
        409,
        'SOLICITACAO_DUPLICADA',
        'Já existe uma solicitação entre vocês.',
      );
    }
    return tratarErro(res, erro, 'envio de solicitação');
  }
});

// POST /amigos/solicitacoes/:id/aceitar
router.post('/amigos/solicitacoes/:id/aceitar', async (req, res) => {
  return respondeSolicitacao(req, res, 'A');
});

// POST /amigos/solicitacoes/:id/recusar
router.post('/amigos/solicitacoes/:id/recusar', async (req, res) => {
  return respondeSolicitacao(req, res, 'R');
});

async function respondeSolicitacao(req, res, novoStatus) {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);

  if (!Number.isInteger(id) || id <= 0) {
    return responderErro(res, 404, 'SOLICITACAO_NAO_ENCONTRADA', 'Solicitação não encontrada.');
  }

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const resultado = await conexao.execute(
        `SELECT a.id, a.status, a.solicitante_id,
                u.id AS usuario_id,
                u.nome AS usuario_nome,
                u.username AS usuario_username
           FROM amizade a
           JOIN usuario u ON u.id = a.solicitante_id
          WHERE a.id = :id
            AND a.destinatario_id = :eu
          FOR UPDATE`,
        { id, eu },
      );

      const linha = (resultado.rows || [])[0];
      if (!linha) {
        return { erro: { status: 404, codigo: 'SOLICITACAO_NAO_ENCONTRADA' } };
      }
      if (linha.STATUS !== 'P') {
        return { erro: { status: 409, codigo: 'SOLICITACAO_NAO_PENDENTE' } };
      }
      if (await existeBloqueio(conexao, eu, linha.SOLICITANTE_ID)) {
        return { erro: { status: 409, codigo: 'BLOQUEADO' } };
      }

      await conexao.execute(
        `UPDATE amizade
            SET status = :novoStatus,
                respondido_em = SYS_EXTRACT_UTC(SYSTIMESTAMP)
          WHERE id = :id`,
        { novoStatus, id },
      );
      await conexao.commit();

      return {
        id: linha.ID,
        status: novoStatus,
        usuario: {
          id: linha.USUARIO_ID,
          nome: linha.USUARIO_NOME,
          username: linha.USUARIO_USERNAME,
        },
      };
    });

    if (resposta.erro) {
      return responderPorCodigo(res, resposta.erro.status, resposta.erro.codigo);
    }
    return res.status(200).json(resposta);
  } catch (erro) {
    return tratarErro(res, erro, `resposta de solicitação (${novoStatus})`);
  }
}

// DELETE /amigos/solicitacoes/:id  (cancelamento pelo solicitante)
router.delete('/amigos/solicitacoes/:id', async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);

  if (!Number.isInteger(id) || id <= 0) {
    return responderErro(res, 404, 'SOLICITACAO_NAO_ENCONTRADA', 'Solicitação não encontrada.');
  }

  try {
    const resultado = await db.executar(
      `DELETE FROM amizade
        WHERE id = :id
          AND solicitante_id = :eu
          AND status = 'P'`,
      { id, eu },
      { autoCommit: true },
    );

    if (resultado.rowsAffected === 0) {
      return responderErro(
        res,
        404,
        'SOLICITACAO_NAO_ENCONTRADA',
        'Solicitação não encontrada ou já respondida.',
      );
    }
    return res.status(204).send();
  } catch (erro) {
    return tratarErro(res, erro, 'cancelamento de solicitação');
  }
});

// DELETE /amigos/:usuarioId
router.delete('/amigos/:usuarioId', async (req, res) => {
  const eu = req.usuario.ID;
  const outro = Number(req.params.usuarioId);

  if (!Number.isInteger(outro) || outro <= 0) {
    return responderErro(res, 404, 'AMIZADE_NAO_ENCONTRADA', 'Amizade não encontrada.');
  }

  try {
    const resultado = await db.executar(
      `DELETE FROM amizade
        WHERE status = 'A'
          AND ((solicitante_id = :eu AND destinatario_id = :outro)
            OR (destinatario_id = :eu AND solicitante_id = :outro))`,
      { eu, outro },
      { autoCommit: true },
    );

    if (resultado.rowsAffected === 0) {
      return responderErro(
        res,
        404,
        'AMIZADE_NAO_ENCONTRADA',
        'Vocês não são amigos.',
      );
    }
    return res.status(204).send();
  } catch (erro) {
    return tratarErro(res, erro, 'remoção de amizade');
  }
});

// GET /bloqueios
router.get('/bloqueios', async (req, res) => {
  const eu = req.usuario.ID;

  try {
    const resultado = await db.executar(
      `SELECT b.criado_em,
              u.id AS usuario_id,
              u.nome AS usuario_nome,
              u.username AS usuario_username
         FROM bloqueio b
         JOIN usuario u ON u.id = b.bloqueado_id
        WHERE b.bloqueador_id = :eu
        ORDER BY u.nome`,
      { eu },
    );

    const bloqueios = (resultado.rows || []).map((linha) => ({
      usuario: usuarioDaLinha(linha),
      criadoEm: iso(linha.CRIADO_EM),
    }));

    return res.status(200).json({ bloqueios });
  } catch (erro) {
    return tratarErro(res, erro, 'lista de bloqueios');
  }
});

// POST /bloqueios
router.post('/bloqueios', async (req, res) => {
  const eu = req.usuario.ID;
  const usuarioId = Number((req.body || {}).usuarioId);

  if (!Number.isInteger(usuarioId) || usuarioId <= 0) {
    return validacao(res, [
      { campo: 'usuarioId', mensagem: 'Informe um usuário válido.' },
    ]);
  }
  if (usuarioId === eu) {
    return responderErro(res, 400, 'NAO_PODE_SI_MESMO', 'Você não pode bloquear a si mesmo.');
  }

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const alvo = await buscaUsuario(conexao, usuarioId);
      if (!alvo) {
        return { erro: { status: 404, codigo: 'USUARIO_NAO_ENCONTRADO' } };
      }

      // Bloquear encerra amizade e qualquer pedido pendente entre os dois.
      await conexao.execute(
        `DELETE FROM amizade
          WHERE (solicitante_id = :eu AND destinatario_id = :outro)
             OR (destinatario_id = :eu AND solicitante_id = :outro)`,
        { eu, outro: usuarioId },
      );

      await conexao.execute(
        `MERGE INTO bloqueio b
         USING (SELECT :eu AS bloqueador_id, :outro AS bloqueado_id FROM dual) s
            ON (b.bloqueador_id = s.bloqueador_id AND b.bloqueado_id = s.bloqueado_id)
          WHEN NOT MATCHED THEN
            INSERT (bloqueador_id, bloqueado_id)
            VALUES (s.bloqueador_id, s.bloqueado_id)`,
        { eu, outro: usuarioId },
      );

      await conexao.commit();
      return {
        usuario: {
          id: alvo.ID,
          nome: alvo.NOME,
          username: alvo.USERNAME,
        },
      };
    });

    if (resposta.erro) {
      return responderPorCodigo(res, resposta.erro.status, resposta.erro.codigo);
    }
    return res.status(201).json(resposta);
  } catch (erro) {
    return tratarErro(res, erro, 'bloqueio de usuário');
  }
});

// DELETE /bloqueios/:usuarioId
router.delete('/bloqueios/:usuarioId', async (req, res) => {
  const eu = req.usuario.ID;
  const outro = Number(req.params.usuarioId);

  if (!Number.isInteger(outro) || outro <= 0) {
    return responderErro(res, 404, 'BLOQUEIO_NAO_ENCONTRADO', 'Bloqueio não encontrado.');
  }

  try {
    await db.executar(
      `DELETE FROM bloqueio
        WHERE bloqueador_id = :eu AND bloqueado_id = :outro`,
      { eu, outro },
      { autoCommit: true },
    );
    return res.status(204).send();
  } catch (erro) {
    return tratarErro(res, erro, 'desbloqueio de usuário');
  }
});

function responderPorCodigo(res, status, codigo) {
  const mensagens = {
    USUARIO_NAO_ENCONTRADO: 'Usuário não encontrado.',
    NAO_PODE_SI_MESMO: 'Você não pode enviar solicitação para si mesmo.',
    BLOQUEADO: 'Não é possível interagir com este usuário por causa de um bloqueio.',
    SOLICITACAO_DUPLICADA: 'Já existe uma solicitação entre vocês.',
    JA_SAO_AMIGOS: 'Vocês já são amigos.',
    SOLICITACAO_NAO_ENCONTRADA: 'Solicitação não encontrada.',
    SOLICITACAO_NAO_PENDENTE: 'Esta solicitação já foi respondida.',
  };
  return responderErro(
    res,
    status,
    codigo,
    mensagens[codigo] || 'Não foi possível concluir a operação.',
  );
}

module.exports = router;
