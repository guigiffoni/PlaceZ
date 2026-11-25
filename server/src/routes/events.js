'use strict';

const express = require('express');
const db = require('../db');
const { autenticar } = require('../middleware/auth');
const { responderErro, bancoIndisponivel, validacao } = require('../http');

const router = express.Router();

// Só os prefixos de eventos exigem token; rotas desconhecidas continuam
// caindo no 404 global.
router.use('/eventos', autenticar);

const CAMPOS_EVENTO = `
  e.id,
  e.titulo,
  e.descricao,
  e.inicio_em,
  e.fim_em,
  e.criador_id,
  e.privado,
  e.permitir_membros_convidar,
  e.status,
  e.criado_em,
  e.atualizado_em,
  l.id                    AS local_id,
  l.nome                  AS local_nome,
  l.endereco              AS local_endereco,
  l.categoria             AS local_categoria,
  l.distancia_metros      AS local_distancia,
  l.latitude              AS local_latitude,
  l.longitude             AS local_longitude,
  u.nome                  AS criador_nome,
  u.username              AS criador_username,
  (SELECT c.rsvp FROM convidado_evento c
    WHERE c.evento_id = e.id AND c.usuario_id = :eu) AS meu_rsvp,
  (SELECT COUNT(*) FROM convidado_evento c
    WHERE c.evento_id = e.id AND c.rsvp = 'VOU') AS total_vou,
  (SELECT COUNT(*) FROM convidado_evento c
    WHERE c.evento_id = e.id AND c.rsvp = 'TALVEZ') AS total_talvez,
  (SELECT COUNT(*) FROM convidado_evento c
    WHERE c.evento_id = e.id AND c.rsvp IS NULL) AS total_sem_resposta
`;

const VISIBILIDADE = `(
  e.criador_id = :eu
  OR EXISTS (
    SELECT 1 FROM convidado_evento c2
     WHERE c2.evento_id = e.id AND c2.usuario_id = :eu
  )
)`;

function iso(valor) {
  if (valor instanceof Date) return valor.toISOString();
  if (valor == null) return null;
  const data = new Date(valor);
  return Number.isNaN(data.getTime()) ? null : data.toISOString();
}

function tratarErro(res, erro, contexto) {
  if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
  console.error(`[eventos] erro em ${contexto}:`, erro);
  return responderErro(
    res,
    500,
    'ERRO_INTERNO',
    'Não foi possível concluir a operação.',
  );
}

function temCampo(corpo, campo) {
  return Object.prototype.hasOwnProperty.call(corpo, campo);
}

function textoObrigatorio(valor, campo, max, erros) {
  const texto = String(valor == null ? '' : valor).trim();
  if (!texto || texto.length > max) {
    erros.push({
      campo,
      mensagem: `Informe um texto entre 1 e ${max} caracteres.`,
    });
  }
  return texto || null;
}

function textoOpcional(valor, campo, max, erros) {
  if (valor == null) return null;
  if (typeof valor !== 'string') {
    erros.push({ campo, mensagem: 'Informe um texto válido.' });
    return null;
  }
  const texto = valor.trim();
  if (!texto) return null;
  if (texto.length > max) {
    erros.push({
      campo,
      mensagem: `Use no máximo ${max} caracteres.`,
    });
    return null;
  }
  return texto;
}

function lerData(valor, campo, erros) {
  if (valor === undefined) return undefined;
  if (valor === null || valor === '') return null;
  const data = new Date(valor);
  if (Number.isNaN(data.getTime())) {
    erros.push({
      campo,
      mensagem: 'Informe uma data válida em ISO-8601.',
    });
    return null;
  }
  return data;
}

function lerBooleano(valor, campo, padrao, erros) {
  if (valor === undefined) return padrao;
  if (typeof valor !== 'boolean') {
    erros.push({ campo, mensagem: 'Informe verdadeiro ou falso.' });
    return padrao;
  }
  return valor;
}

function lerLocal(valor, erros) {
  if (valor === undefined) return undefined;
  if (valor === null) return null;
  if (typeof valor !== 'object' || Array.isArray(valor)) {
    erros.push({ campo: 'local', mensagem: 'Informe um local válido.' });
    return null;
  }

  const nome = textoObrigatorio(valor.nome, 'local.nome', 160, erros);
  const endereco = textoOpcional(valor.endereco, 'local.endereco', 300, erros);
  const categoria = textoOpcional(
    valor.categoria,
    'local.categoria',
    60,
    erros,
  );

  const distanciaBruta = valor.distanciaMetros ?? valor.distancia_metros;
  let distanciaMetros = null;
  if (distanciaBruta != null) {
    const numero = Number(distanciaBruta);
    if (!Number.isFinite(numero) || numero < 0) {
      erros.push({
        campo: 'local.distanciaMetros',
        mensagem: 'Informe uma distância válida em metros.',
      });
    } else {
      distanciaMetros = numero;
    }
  }

  const latitude = numeroOuNulo(valor.latitude, -90, 90, 'local.latitude', erros);
  const longitude = numeroOuNulo(
    valor.longitude,
    -180,
    180,
    'local.longitude',
    erros,
  );

  return { nome, endereco, categoria, distanciaMetros, latitude, longitude };
}

function numeroOuNulo(valor, minimo, maximo, campo, erros) {
  if (valor == null || valor === '') return null;
  const numero = Number(valor);
  if (!Number.isFinite(numero) || numero < minimo || numero > maximo) {
    erros.push({
      campo,
      mensagem: `Informe um número entre ${minimo} e ${maximo}.`,
    });
    return null;
  }
  return numero;
}

function lerConvidados(valor, erros) {
  if (valor === undefined || valor === null) return [];
  if (!Array.isArray(valor)) {
    erros.push({
      campo: 'convidadoIds',
      mensagem: 'Envie uma lista de usuários.',
    });
    return [];
  }

  const ids = [];
  for (const item of valor) {
    const id = Number(item);
    if (!Number.isInteger(id) || id <= 0) {
      erros.push({
        campo: 'convidadoIds',
        mensagem: 'A lista de convidados contém um usuário inválido.',
      });
      continue;
    }
    if (!ids.includes(id)) ids.push(id);
  }
  if (ids.length > 200) {
    erros.push({
      campo: 'convidadoIds',
      mensagem: 'Convide no máximo 200 pessoas por vez.',
    });
  }
  return ids;
}

function lerPessoas(valor, erros) {
  if (valor === undefined || valor === null || valor === '') return [];

  const entradas = Array.isArray(valor) ? valor : [valor];
  const ids = [];
  for (const entrada of entradas) {
    for (const parte of String(entrada).split(',')) {
      const texto = parte.trim();
      if (!texto) continue;
      const id = Number(texto);
      if (!Number.isInteger(id) || id <= 0) {
        erros.push({
          campo: 'pessoas',
          mensagem: 'Informe uma lista de usuários válidos.',
        });
        continue;
      }
      if (!ids.includes(id)) ids.push(id);
    }
  }
  if (ids.length > 50) {
    erros.push({
      campo: 'pessoas',
      mensagem: 'Selecione no máximo 50 pessoas por vez.',
    });
  }
  return ids;
}

function localDaLinha(linha) {
  if (!linha.LOCAL_ID) return null;
  return {
    id: linha.LOCAL_ID,
    nome: linha.LOCAL_NOME,
    endereco: linha.LOCAL_ENDERECO,
    categoria: linha.LOCAL_CATEGORIA,
    distanciaMetros:
      linha.LOCAL_DISTANCIA == null ? null : Number(linha.LOCAL_DISTANCIA),
    latitude:
      linha.LOCAL_LATITUDE == null ? null : Number(linha.LOCAL_LATITUDE),
    longitude:
      linha.LOCAL_LONGITUDE == null ? null : Number(linha.LOCAL_LONGITUDE),
  };
}

function eventoDaLinha(linha, eu) {
  return {
    id: linha.ID,
    titulo: linha.TITULO,
    descricao: linha.DESCRICAO,
    inicioEm: iso(linha.INICIO_EM),
    fimEm: iso(linha.FIM_EM),
    local: localDaLinha(linha),
    criador: {
      id: linha.CRIADOR_ID,
      nome: linha.CRIADOR_NOME,
      username: linha.CRIADOR_USERNAME,
    },
    privado: linha.PRIVADO === 'S',
    permitirMembrosConvidar: linha.PERMITIR_MEMBROS_CONVIDAR === 'S',
    status: linha.STATUS,
    criadoEm: iso(linha.CRIADO_EM),
    atualizadoEm: iso(linha.ATUALIZADO_EM),
    meuRsvp: linha.MEU_RSVP || null,
    souCriador: linha.CRIADOR_ID === eu,
    podeConvidar:
      linha.CRIADOR_ID === eu ||
      linha.PERMITIR_MEMBROS_CONVIDAR === 'S',
    contagem: {
      vou: Number(linha.TOTAL_VOU || 0),
      talvez: Number(linha.TOTAL_TALVEZ || 0),
      semResposta: Number(linha.TOTAL_SEM_RESPOSTA || 0),
    },
    convidados: [],
  };
}

async function insereLocal(conexao, local) {
  const oracledb = db.getOracle();
  if (!oracledb) throw new db.BancoIndisponivelError();

  const resultado = await conexao.execute(
    `INSERT INTO local (nome, endereco, categoria, distancia_metros, latitude, longitude)
     VALUES (:nome, :endereco, :categoria, :distancia, :latitude, :longitude)
     RETURNING id INTO :id`,
    {
      nome: local.nome,
      endereco: local.endereco,
      categoria: local.categoria,
      distancia: local.distanciaMetros,
      latitude: local.latitude,
      longitude: local.longitude,
      id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
    },
  );
  return resultado.outBinds.id[0];
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

async function contextoEvento(conexao, id, eu, { bloquear = false } = {}) {
  const resultado = await conexao.execute(
    `SELECT id, titulo, descricao, inicio_em, fim_em, local_id,
            criador_id, privado, permitir_membros_convidar, status
       FROM evento
      WHERE id = :id
      ${bloquear ? 'FOR UPDATE' : ''}`,
    { id },
  );
  const linha = (resultado.rows || [])[0];
  if (!linha) return null;

  const souCriador = linha.CRIADOR_ID === eu;
  let souConvidado = souCriador;
  if (!souCriador) {
    const convite = await conexao.execute(
      `SELECT 1 AS existe
         FROM convidado_evento
        WHERE evento_id = :id AND usuario_id = :eu`,
      { id, eu },
    );
    souConvidado = (convite.rows || []).length > 0;
  }

  if (!souCriador && !souConvidado) return null;

  return {
    linha,
    souCriador,
    souConvidado,
    podeConvidar:
      souCriador || linha.PERMITIR_MEMBROS_CONVIDAR === 'S',
  };
}

async function convidadosDoEvento(conexao, id) {
  const resultado = await conexao.execute(
    `SELECT c.usuario_id, c.papel, c.rsvp, c.criado_em, c.respondido_em,
            u.nome AS usuario_nome, u.username AS usuario_username,
            cb.id AS convidado_por_id,
            cb.nome AS convidado_por_nome,
            cb.username AS convidado_por_username
       FROM convidado_evento c
       JOIN usuario u ON u.id = c.usuario_id
       LEFT JOIN usuario cb ON cb.id = c.convidado_por
      WHERE c.evento_id = :id
      ORDER BY CASE c.papel WHEN 'CRIADOR' THEN 0 ELSE 1 END, u.nome`,
    { id },
  );

  return (resultado.rows || []).map((linha) => ({
    usuario: {
      id: linha.USUARIO_ID,
      nome: linha.USUARIO_NOME,
      username: linha.USUARIO_USERNAME,
    },
    papel: linha.PAPEL,
    rsvp: linha.RSVP || null,
    convidadoPor: linha.CONVIDADO_POR_ID
      ? {
          id: linha.CONVIDADO_POR_ID,
          nome: linha.CONVIDADO_POR_NOME,
          username: linha.CONVIDADO_POR_USERNAME,
        }
      : null,
    criadoEm: iso(linha.CRIADO_EM),
    respondidoEm: iso(linha.RESPONDIDO_EM),
  }));
}

async function carregaEventoDetalhado(conexao, id, eu) {
  const resultado = await conexao.execute(
    `SELECT ${CAMPOS_EVENTO}
       FROM evento e
       JOIN usuario u ON u.id = e.criador_id
       LEFT JOIN local l ON l.id = e.local_id
      WHERE e.id = :id
        AND ${VISIBILIDADE}`,
    { id, eu },
  );
  const linha = (resultado.rows || [])[0];
  if (!linha) return null;

  const evento = eventoDaLinha(linha, eu);
  evento.convidados = await convidadosDoEvento(conexao, id);
  return evento;
}

async function adicionarConvidados(conexao, evento, eu, ids) {
  const adicionados = [];
  const ignorados = [];

  for (const usuarioId of ids) {
    if (usuarioId === evento.criadorId) {
      ignorados.push({ usuarioId, motivo: 'CRIADOR' });
      continue;
    }

    const alvo = await buscaUsuario(conexao, usuarioId);
    if (!alvo) {
      ignorados.push({ usuarioId, motivo: 'USUARIO_NAO_ENCONTRADO' });
      continue;
    }

    const jaConvidado = await conexao.execute(
      `SELECT 1 AS existe
         FROM convidado_evento
        WHERE evento_id = :eventoId AND usuario_id = :usuarioId`,
      { eventoId: evento.id, usuarioId },
    );
    if ((jaConvidado.rows || []).length > 0) {
      ignorados.push({ usuarioId, motivo: 'JA_CONVIDADO' });
      continue;
    }

    if (
      (await existeBloqueio(conexao, eu, usuarioId)) ||
      (await existeBloqueio(conexao, evento.criadorId, usuarioId))
    ) {
      ignorados.push({ usuarioId, motivo: 'BLOQUEADO' });
      continue;
    }

    if (!(await saoAmigos(conexao, eu, usuarioId))) {
      ignorados.push({ usuarioId, motivo: 'NAO_E_AMIGO' });
      continue;
    }

    await conexao.execute(
      `INSERT INTO convidado_evento (evento_id, usuario_id, convidado_por, papel)
       VALUES (:eventoId, :usuarioId, :eu, 'CONVIDADO')`,
      { eventoId: evento.id, usuarioId, eu },
    );
    adicionados.push(usuarioId);
  }

  return { adicionados, ignorados };
}

async function amigosDoUsuario(conexao, eu) {
  const resultado = await conexao.execute(
    `SELECT u.id
       FROM amizade a
       JOIN usuario u
         ON u.id = CASE
                     WHEN a.solicitante_id = :eu THEN a.destinatario_id
                     ELSE a.solicitante_id
                   END
      WHERE a.status = 'A'
        AND (a.solicitante_id = :eu OR a.destinatario_id = :eu)
      ORDER BY u.nome`,
    { eu },
  );
  return (resultado.rows || []).map((linha) => linha.ID);
}

function responderPorCodigo(res, status, codigo) {
  const mensagens = {
    EVENTO_NAO_ENCONTRADO: 'Evento não encontrado.',
    SEM_PERMISSAO: 'Você não tem permissão para esta ação.',
    EVENTO_CANCELADO: 'Este evento foi cancelado.',
    CONVIDADO_NAO_ENCONTRADO: 'Convidado não encontrado.',
    NAO_REMOVER_CRIADOR: 'O criador não pode ser removido do próprio evento.',
    CRIADOR_RSVP_FIXO: 'O criador do evento é sempre considerado confirmado.',
  };
  return responderErro(
    res,
    status,
    codigo,
    mensagens[codigo] || 'Não foi possível concluir a operação.',
  );
}

// GET /eventos
router.get('/eventos', async (req, res) => {
  const eu = req.usuario.ID;
  const erros = [];
  const de = lerData(req.query.de, 'de', erros);
  const ate = lerData(req.query.ate, 'ate', erros);
  const pessoas = lerPessoas(req.query.pessoas, erros);

  if (de && ate && de > ate) {
    erros.push({ campo: 'ate', mensagem: 'A data final deve ser após a inicial.' });
  }
  if (erros.length) return validacao(res, erros);

  try {
    const binds = { eu };
    let filtros = '';
    if (de) {
      filtros += ' AND e.inicio_em >= :de';
      binds.de = de;
    }
    if (ate) {
      filtros += ' AND e.inicio_em <= :ate';
      binds.ate = ate;
    }
    if (pessoas.length > 0) {
      const marcadores = pessoas.map((_, indice) => `:pessoa${indice}`);
      filtros += ` AND EXISTS (
        SELECT 1 FROM convidado_evento cp
         WHERE cp.evento_id = e.id
           AND cp.usuario_id IN (${marcadores.join(', ')})
      )`;
      pessoas.forEach((id, indice) => {
        binds[`pessoa${indice}`] = id;
      });
    }

    const resultado = await db.executar(
      `SELECT ${CAMPOS_EVENTO}
         FROM evento e
         JOIN usuario u ON u.id = e.criador_id
         LEFT JOIN local l ON l.id = e.local_id
        WHERE ${VISIBILIDADE}
          AND e.status <> 'CANCELADO'
          ${filtros}
        ORDER BY e.inicio_em ASC NULLS LAST, e.id ASC`,
      binds,
    );

    const eventos = (resultado.rows || []).map((linha) =>
      eventoDaLinha(linha, eu),
    );
    return res.status(200).json({ eventos });
  } catch (erro) {
    return tratarErro(res, erro, 'lista de eventos');
  }
});

// GET /calendario/pessoas-frequentes
router.get('/calendario/pessoas-frequentes', autenticar, async (req, res) => {
  const eu = req.usuario.ID;

  try {
    const resultado = await db.executar(
      `SELECT u.id AS usuario_id,
              u.nome,
              COUNT(DISTINCT c.evento_id) AS contagem
         FROM convidado_evento c
         JOIN evento e ON e.id = c.evento_id
         JOIN usuario u ON u.id = c.usuario_id
         JOIN amizade a
           ON a.status = 'A'
          AND ((a.solicitante_id = :eu AND a.destinatario_id = c.usuario_id)
            OR (a.destinatario_id = :eu AND a.solicitante_id = c.usuario_id))
        WHERE c.convidado_por = :eu
          AND c.papel = 'CONVIDADO'
          AND c.usuario_id <> :eu
          AND e.status <> 'CANCELADO'
          AND c.criado_em >= SYS_EXTRACT_UTC(SYSTIMESTAMP) - INTERVAL '30' DAY
        GROUP BY u.id, u.nome
        ORDER BY contagem DESC, u.nome ASC`,
      { eu },
    );

    const pessoas = (resultado.rows || []).map((linha) => ({
      usuarioId: linha.USUARIO_ID,
      nome: linha.NOME,
      contagem: Number(linha.CONTAGEM),
    }));

    return res.status(200).json({ pessoas });
  } catch (erro) {
    return tratarErro(res, erro, 'ranking de pessoas do calendário');
  }
});

// POST /eventos
router.post('/eventos', async (req, res) => {
  const eu = req.usuario.ID;
  const corpo = req.body || {};
  const erros = [];

  const titulo = textoObrigatorio(corpo.titulo, 'titulo', 160, erros);
  const descricao = textoOpcional(corpo.descricao, 'descricao', 2000, erros);
  const inicioEm = lerData(corpo.inicioEm, 'inicioEm', erros) ?? null;
  const fimEm = lerData(corpo.fimEm, 'fimEm', erros) ?? null;
  const local = lerLocal(corpo.local, erros) ?? null;
  const privado = lerBooleano(corpo.privado, 'privado', true, erros);
  const permitirMembrosConvidar = lerBooleano(
    corpo.permitirMembrosConvidar,
    'permitirMembrosConvidar',
    false,
    erros,
  );
  const convidadoIds = lerConvidados(corpo.convidadoIds, erros);

  if (inicioEm && fimEm && fimEm < inicioEm) {
    erros.push({
      campo: 'fimEm',
      mensagem: 'O fim deve ser posterior ao início.',
    });
  }
  if (erros.length) return validacao(res, erros);

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const oracledb = db.getOracle();
      if (!oracledb) throw new db.BancoIndisponivelError();

      const localId = local ? await insereLocal(conexao, local) : null;

      const criado = await conexao.execute(
        `INSERT INTO evento
           (titulo, descricao, inicio_em, fim_em, local_id, criador_id,
            privado, permitir_membros_convidar, status)
         VALUES
           (:titulo, :descricao, :inicioEm, :fimEm, :localId, :eu,
            :privado, :permitir, 'CONFIRMADO')
         RETURNING id INTO :id`,
        {
          titulo,
          descricao,
          inicioEm,
          fimEm,
          localId,
          eu,
          privado: privado ? 'S' : 'N',
          permitir: permitirMembrosConvidar ? 'S' : 'N',
          id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
        },
      );
      const id = criado.outBinds.id[0];

      await conexao.execute(
        `INSERT INTO convidado_evento
           (evento_id, usuario_id, convidado_por, papel, rsvp, respondido_em)
         VALUES (:id, :eu, :eu, 'CRIADOR', 'VOU', SYS_EXTRACT_UTC(SYSTIMESTAMP))`,
        { id, eu },
      );

      let adicionados = [];
      let ignorados = [];
      if (convidadoIds.length > 0) {
        const convite = await adicionarConvidados(
          conexao,
          { id, criadorId: eu },
          eu,
          convidadoIds,
        );
        adicionados = convite.adicionados;
        ignorados = convite.ignorados;
      }

      const evento = await carregaEventoDetalhado(conexao, id, eu);
      await conexao.commit();
      return {
        evento,
        convidadosAdicionados: adicionados,
        convidadosIgnorados: ignorados,
      };
    });

    return res.status(201).json(resposta);
  } catch (erro) {
    return tratarErro(res, erro, 'criação de evento');
  }
});

// GET /eventos/:id
router.get('/eventos/:id', async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);

  if (!Number.isInteger(id) || id <= 0) {
    return responderPorCodigo(res, 404, 'EVENTO_NAO_ENCONTRADO');
  }

  try {
    const evento = await db.comConexao((conexao) =>
      carregaEventoDetalhado(conexao, id, eu),
    );
    if (!evento) {
      return responderPorCodigo(res, 404, 'EVENTO_NAO_ENCONTRADO');
    }
    return res.status(200).json({ evento });
  } catch (erro) {
    return tratarErro(res, erro, 'detalhe de evento');
  }
});

// PATCH /eventos/:id
router.patch('/eventos/:id', async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);

  if (!Number.isInteger(id) || id <= 0) {
    return responderPorCodigo(res, 404, 'EVENTO_NAO_ENCONTRADO');
  }

  const corpo = req.body || {};
  const erros = [];

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const contexto = await contextoEvento(conexao, id, eu, {
        bloquear: true,
      });
      if (!contexto) {
        return { erro: { status: 404, codigo: 'EVENTO_NAO_ENCONTRADO' } };
      }
      if (!contexto.souCriador) {
        return { erro: { status: 403, codigo: 'SEM_PERMISSAO' } };
      }

      const atual = contexto.linha;
      let titulo = atual.TITULO;
      if (temCampo(corpo, 'titulo')) {
        titulo = textoObrigatorio(corpo.titulo, 'titulo', 160, erros);
      }

      let descricao = atual.DESCRICAO;
      if (temCampo(corpo, 'descricao')) {
        descricao = textoOpcional(corpo.descricao, 'descricao', 2000, erros);
      }

      let inicioEm = atual.INICIO_EM;
      if (temCampo(corpo, 'inicioEm')) {
        const lida = lerData(corpo.inicioEm, 'inicioEm', erros);
        inicioEm = lida === undefined ? atual.INICIO_EM : lida;
      }

      let fimEm = atual.FIM_EM;
      if (temCampo(corpo, 'fimEm')) {
        const lida = lerData(corpo.fimEm, 'fimEm', erros);
        fimEm = lida === undefined ? atual.FIM_EM : lida;
      }

      let localId = atual.LOCAL_ID;
      if (temCampo(corpo, 'local')) {
        const local = lerLocal(corpo.local, erros);
        if (local === null || local === undefined) {
          localId = null;
        } else {
          localId = await insereLocal(conexao, local);
        }
      }

      if (inicioEm && fimEm && fimEm < inicioEm) {
        erros.push({
          campo: 'fimEm',
          mensagem: 'O fim deve ser posterior ao início.',
        });
      }
      if (erros.length) return { validacao: erros };

      await conexao.execute(
        `UPDATE evento
            SET titulo = :titulo,
                descricao = :descricao,
                inicio_em = :inicioEm,
                fim_em = :fimEm,
                local_id = :localId,
                atualizado_em = SYS_EXTRACT_UTC(SYSTIMESTAMP)
          WHERE id = :id`,
        { titulo, descricao, inicioEm, fimEm, localId, id },
      );

      const evento = await carregaEventoDetalhado(conexao, id, eu);
      await conexao.commit();
      return { evento };
    });

    if (resposta.erro) {
      return responderPorCodigo(
        res,
        resposta.erro.status,
        resposta.erro.codigo,
      );
    }
    if (resposta.validacao) return validacao(res, resposta.validacao);
    return res.status(200).json({ evento: resposta.evento });
  } catch (erro) {
    return tratarErro(res, erro, 'edição de evento');
  }
});

// DELETE /eventos/:id  (cancelamento pelo criador)
router.delete('/eventos/:id', async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);

  if (!Number.isInteger(id) || id <= 0) {
    return responderPorCodigo(res, 404, 'EVENTO_NAO_ENCONTRADO');
  }

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const contexto = await contextoEvento(conexao, id, eu, {
        bloquear: true,
      });
      if (!contexto) {
        return { erro: { status: 404, codigo: 'EVENTO_NAO_ENCONTRADO' } };
      }
      if (!contexto.souCriador) {
        return { erro: { status: 403, codigo: 'SEM_PERMISSAO' } };
      }

      if (contexto.linha.STATUS !== 'CANCELADO') {
        await conexao.execute(
          `UPDATE evento
              SET status = 'CANCELADO',
                  atualizado_em = SYS_EXTRACT_UTC(SYSTIMESTAMP)
            WHERE id = :id`,
          { id },
        );
      }
      await conexao.commit();
      return {};
    });

    if (resposta.erro) {
      return responderPorCodigo(
        res,
        resposta.erro.status,
        resposta.erro.codigo,
      );
    }
    return res.status(204).send();
  } catch (erro) {
    return tratarErro(res, erro, 'cancelamento de evento');
  }
});

// PATCH /eventos/:id/config
router.patch('/eventos/:id/config', async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);
  const corpo = req.body || {};

  if (!Number.isInteger(id) || id <= 0) {
    return responderPorCodigo(res, 404, 'EVENTO_NAO_ENCONTRADO');
  }

  const erros = [];
  const temPrivado = temCampo(corpo, 'privado');
  const temPermissao = temCampo(corpo, 'permitirMembrosConvidar');

  if (!temPrivado && !temPermissao) {
    erros.push({
      campo: 'config',
      mensagem: 'Informe privacidade ou permissão de convite.',
    });
  }
  const privado = temPrivado
    ? lerBooleano(corpo.privado, 'privado', true, erros)
    : null;
  const permitir = temPermissao
    ? lerBooleano(
        corpo.permitirMembrosConvidar,
        'permitirMembrosConvidar',
        false,
        erros,
      )
    : null;

  if (erros.length) return validacao(res, erros);

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const contexto = await contextoEvento(conexao, id, eu, {
        bloquear: true,
      });
      if (!contexto) {
        return { erro: { status: 404, codigo: 'EVENTO_NAO_ENCONTRADO' } };
      }
      if (!contexto.souCriador) {
        return { erro: { status: 403, codigo: 'SEM_PERMISSAO' } };
      }

      await conexao.execute(
        `UPDATE evento
            SET privado = :privado,
                permitir_membros_convidar = :permitir,
                atualizado_em = SYS_EXTRACT_UTC(SYSTIMESTAMP)
          WHERE id = :id`,
        {
          id,
          privado:
            privado == null
              ? contexto.linha.PRIVADO
              : privado
                ? 'S'
                : 'N',
          permitir:
            permitir == null
              ? contexto.linha.PERMITIR_MEMBROS_CONVIDAR
              : permitir
                ? 'S'
                : 'N',
        },
      );

      const evento = await carregaEventoDetalhado(conexao, id, eu);
      await conexao.commit();
      return { evento };
    });

    if (resposta.erro) {
      return responderPorCodigo(
        res,
        resposta.erro.status,
        resposta.erro.codigo,
      );
    }
    return res.status(200).json({ evento: resposta.evento });
  } catch (erro) {
    return tratarErro(res, erro, 'configuração de evento');
  }
});

// POST /eventos/:id/convidados
router.post('/eventos/:id/convidados', async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);
  const erros = [];
  const convidadoIds = lerConvidados(
    (req.body || {}).usuarioIds ?? (req.body || {}).convidadoIds,
    erros,
  );

  if (!Number.isInteger(id) || id <= 0) {
    return responderPorCodigo(res, 404, 'EVENTO_NAO_ENCONTRADO');
  }
  if (convidadoIds.length === 0 && erros.length === 0) {
    erros.push({
      campo: 'usuarioIds',
      mensagem: 'Selecione ao menos um amigo para convidar.',
    });
  }
  if (erros.length) return validacao(res, erros);

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const contexto = await contextoEvento(conexao, id, eu);
      if (!contexto) {
        return { erro: { status: 404, codigo: 'EVENTO_NAO_ENCONTRADO' } };
      }
      if (contexto.linha.STATUS === 'CANCELADO') {
        return { erro: { status: 409, codigo: 'EVENTO_CANCELADO' } };
      }
      if (!contexto.podeConvidar) {
        return { erro: { status: 403, codigo: 'SEM_PERMISSAO' } };
      }

      const convite = await adicionarConvidados(
        conexao,
        { id, criadorId: contexto.linha.CRIADOR_ID },
        eu,
        convidadoIds,
      );
      const evento = await carregaEventoDetalhado(conexao, id, eu);
      await conexao.commit();
      return { evento, ...convite };
    });

    if (resposta.erro) {
      return responderPorCodigo(
        res,
        resposta.erro.status,
        resposta.erro.codigo,
      );
    }
    return res.status(200).json({
      evento: resposta.evento,
      adicionados: resposta.adicionados,
      ignorados: resposta.ignorados,
    });
  } catch (erro) {
    return tratarErro(res, erro, 'convite de participantes');
  }
});

// POST /eventos/:id/convidados/todos
router.post('/eventos/:id/convidados/todos', async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);

  if (!Number.isInteger(id) || id <= 0) {
    return responderPorCodigo(res, 404, 'EVENTO_NAO_ENCONTRADO');
  }

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const contexto = await contextoEvento(conexao, id, eu);
      if (!contexto) {
        return { erro: { status: 404, codigo: 'EVENTO_NAO_ENCONTRADO' } };
      }
      if (contexto.linha.STATUS === 'CANCELADO') {
        return { erro: { status: 409, codigo: 'EVENTO_CANCELADO' } };
      }
      if (!contexto.podeConvidar) {
        return { erro: { status: 403, codigo: 'SEM_PERMISSAO' } };
      }

      const amigos = await amigosDoUsuario(conexao, eu);
      const convite = await adicionarConvidados(
        conexao,
        { id, criadorId: contexto.linha.CRIADOR_ID },
        eu,
        amigos,
      );
      const evento = await carregaEventoDetalhado(conexao, id, eu);
      await conexao.commit();
      return { evento, ...convite };
    });

    if (resposta.erro) {
      return responderPorCodigo(
        res,
        resposta.erro.status,
        resposta.erro.codigo,
      );
    }
    return res.status(200).json({
      evento: resposta.evento,
      adicionados: resposta.adicionados,
      ignorados: resposta.ignorados,
    });
  } catch (erro) {
    return tratarErro(res, erro, 'convite em massa');
  }
});

// DELETE /eventos/:id/convidados/:usuarioId
router.delete('/eventos/:id/convidados/:usuarioId', async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);
  const usuarioId = Number(req.params.usuarioId);

  if (!Number.isInteger(id) || id <= 0) {
    return responderPorCodigo(res, 404, 'EVENTO_NAO_ENCONTRADO');
  }
  if (!Number.isInteger(usuarioId) || usuarioId <= 0) {
    return responderPorCodigo(res, 404, 'CONVIDADO_NAO_ENCONTRADO');
  }

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const contexto = await contextoEvento(conexao, id, eu);
      if (!contexto) {
        return { erro: { status: 404, codigo: 'EVENTO_NAO_ENCONTRADO' } };
      }
      if (contexto.linha.STATUS === 'CANCELADO') {
        return { erro: { status: 409, codigo: 'EVENTO_CANCELADO' } };
      }
      if (usuarioId === contexto.linha.CRIADOR_ID) {
        return { erro: { status: 400, codigo: 'NAO_REMOVER_CRIADOR' } };
      }
      if (!contexto.souCriador && usuarioId !== eu) {
        return { erro: { status: 403, codigo: 'SEM_PERMISSAO' } };
      }

      const removido = await conexao.execute(
        `DELETE FROM convidado_evento
          WHERE evento_id = :id AND usuario_id = :usuarioId`,
        { id, usuarioId },
      );
      if (removido.rowsAffected === 0) {
        return { erro: { status: 404, codigo: 'CONVIDADO_NAO_ENCONTRADO' } };
      }

      const evento = await carregaEventoDetalhado(conexao, id, eu);
      await conexao.commit();
      return { evento };
    });

    if (resposta.erro) {
      return responderPorCodigo(
        res,
        resposta.erro.status,
        resposta.erro.codigo,
      );
    }
    if (!resposta.evento) return res.status(204).send();
    return res.status(200).json({ evento: resposta.evento });
  } catch (erro) {
    return tratarErro(res, erro, 'remoção de convidado');
  }
});

// PATCH /eventos/:id/rsvp
router.patch('/eventos/:id/rsvp', async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);
  const rsvp = String((req.body || {}).rsvp || '').trim().toUpperCase();

  if (!Number.isInteger(id) || id <= 0) {
    return responderPorCodigo(res, 404, 'EVENTO_NAO_ENCONTRADO');
  }
  if (rsvp !== 'VOU' && rsvp !== 'TALVEZ') {
    return validacao(res, [
      {
        campo: 'rsvp',
        mensagem: 'Informe VOU ou TALVEZ.',
      },
    ]);
  }

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const contexto = await contextoEvento(conexao, id, eu, {
        bloquear: true,
      });
      if (!contexto) {
        return { erro: { status: 404, codigo: 'EVENTO_NAO_ENCONTRADO' } };
      }
      if (contexto.linha.STATUS !== 'CONFIRMADO') {
        return { erro: { status: 409, codigo: 'EVENTO_CANCELADO' } };
      }
      if (contexto.souCriador && rsvp !== 'VOU') {
        return { erro: { status: 400, codigo: 'CRIADOR_RSVP_FIXO' } };
      }

      await conexao.execute(
        `UPDATE convidado_evento
            SET rsvp = :rsvp,
                respondido_em = SYS_EXTRACT_UTC(SYSTIMESTAMP)
          WHERE evento_id = :id AND usuario_id = :eu`,
        { rsvp, id, eu },
      );

      const evento = await carregaEventoDetalhado(conexao, id, eu);
      await conexao.commit();
      return { evento };
    });

    if (resposta.erro) {
      return responderPorCodigo(
        res,
        resposta.erro.status,
        resposta.erro.codigo,
      );
    }
    return res.status(200).json({ evento: resposta.evento });
  } catch (erro) {
    return tratarErro(res, erro, 'resposta de RSVP');
  }
});

module.exports = router;
