'use strict';

const express = require('express');
const db = require('../db');
const { autenticar } = require('../middleware/auth');
const { responderErro, bancoIndisponivel, validacao } = require('../http');

const router = express.Router();

router.use(['/locais', '/regioes'], autenticar);

function iso(valor) {
  if (valor instanceof Date) return valor.toISOString();
  if (valor == null) return null;
  const data = new Date(valor);
  return Number.isNaN(data.getTime()) ? null : data.toISOString();
}

function haversineMetros(lat1, lng1, lat2, lng2) {
  const raioTerra = 6371000;
  const rad = (graus) => (graus * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(lat1)) *
      Math.cos(rad(lat2)) *
      Math.sin(dLng / 2) ** 2;
  return 2 * raioTerra * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function localDaLinha(linha) {
  return {
    id: linha.ID,
    nome: linha.NOME,
    endereco: linha.ENDERECO,
    categoria: linha.CATEGORIA,
    cidade: linha.CIDADE,
    latitude: Number(linha.LATITUDE),
    longitude: Number(linha.LONGITUDE),
  };
}

async function coordenadasDoUsuario(conexao, eu) {
  const resultado = await conexao.execute(
    `SELECT u.localizacao_latitude,
            u.localizacao_longitude,
            r.latitude  AS regiao_latitude,
            r.longitude AS regiao_longitude
       FROM usuario u
       LEFT JOIN regiao_aproximada r ON r.id = u.regiao_id
      WHERE u.id = :eu`,
    { eu },
  );
  const linha = (resultado.rows || [])[0];
  if (!linha) return null;

  const latitude =
    linha.LOCALIZACAO_LATITUDE ?? linha.REGIAO_LATITUDE;
  const longitude =
    linha.LOCALIZACAO_LONGITUDE ?? linha.REGIAO_LONGITUDE;
  if (latitude == null || longitude == null) return null;

  return { latitude: Number(latitude), longitude: Number(longitude) };
}

function calcularAvaliacao(linha) {
  const totalSeed = Number(linha.AVALIACAO_TOTAL || 0);
  const mediaSeed = Number(linha.AVALIACAO_MEDIA || 0);
  const totalReviews = Number(linha.TOTAL_REVIEWS || 0);
  const somaReviews = Number(linha.SOMA_REVIEWS || 0);
  const total = totalSeed + totalReviews;

  if (total <= 0) return { media: 0, total: 0 };

  const soma = mediaSeed * totalSeed + somaReviews;
  return {
    media: Math.round((soma / total) * 10) / 10,
    total,
  };
}

function catalogoDaLinha(linha, coordenadas) {
  const avaliacao = calcularAvaliacao(linha);
  const latitude = Number(linha.LATITUDE);
  const longitude = Number(linha.LONGITUDE);

  return {
    ...localDaLinha(linha),
    descricao: linha.DESCRICAO || null,
    faixaPreco: linha.FAIXA_PRECO || null,
    avaliacaoMedia: avaliacao.media,
    avaliacaoTotal: avaliacao.total,
    distanciaMetros: coordenadas
      ? Math.round(
          haversineMetros(
            coordenadas.latitude,
            coordenadas.longitude,
            latitude,
            longitude,
          ),
        )
      : null,
  };
}

function avaliacaoDaLinha(linha, eu) {
  return {
    id: linha.ID,
    lugarId: linha.LUGAR_ID,
    usuarioId: linha.USUARIO_ID || null,
    autorNome:
      linha.USUARIO_NOME || linha.AUTOR_NOME || 'Usuário do PlaceZ',
    autorUsername: linha.USUARIO_USERNAME || null,
    nota: Number(linha.NOTA),
    comentario: linha.COMENTARIO || null,
    criadoEm: iso(linha.CRIADO_EM),
    atualizadoEm: iso(linha.ATUALIZADO_EM),
    minha: linha.USUARIO_ID === eu,
  };
}

function lerIds(valor, erros) {
  if (!Array.isArray(valor) || valor.length === 0) {
    erros.push({
      campo: 'usuarioIds',
      mensagem: 'Selecione ao menos uma pessoa.',
    });
    return [];
  }

  const ids = [];
  for (const item of valor) {
    const id = Number(item);
    if (!Number.isInteger(id) || id <= 0) {
      erros.push({
        campo: 'usuarioIds',
        mensagem: 'A lista de pessoas contém um usuário inválido.',
      });
      continue;
    }
    if (!ids.includes(id)) ids.push(id);
  }
  if (ids.length > 50) {
    erros.push({
      campo: 'usuarioIds',
      mensagem: 'Use no máximo 50 pessoas por vez.',
    });
  }
  return ids;
}

async function minhasLocalizacao(conexao, eu) {
  const resultado = await conexao.execute(
    `SELECT u.regiao_id,
            u.localizacao_bairro,
            u.localizacao_cidade,
            u.localizacao_latitude,
            u.localizacao_longitude,
            u.localizacao_origem,
            r.nome     AS regiao_nome,
            r.cidade   AS regiao_cidade,
            r.latitude AS regiao_latitude,
            r.longitude AS regiao_longitude
       FROM usuario u
       LEFT JOIN regiao_aproximada r ON r.id = u.regiao_id
      WHERE u.id = :eu`,
    { eu },
  );
  const linha = (resultado.rows || [])[0];
  if (!linha) return { localizacao: null };

  if (linha.LOCALIZACAO_BAIRRO && linha.LOCALIZACAO_LATITUDE != null) {
    return {
      localizacao: {
        bairro: linha.LOCALIZACAO_BAIRRO,
        cidade: linha.LOCALIZACAO_CIDADE,
        latitude: Number(linha.LOCALIZACAO_LATITUDE),
        longitude: Number(linha.LOCALIZACAO_LONGITUDE),
        origem: linha.LOCALIZACAO_ORIGEM || 'MAPA',
        aproximada: true,
      },
    };
  }

  if (linha.REGIAO_ID) {
    return {
      localizacao: {
        bairro: linha.REGIAO_NOME,
        cidade: linha.REGIAO_CIDADE,
        latitude: Number(linha.REGIAO_LATITUDE),
        longitude: Number(linha.REGIAO_LONGITUDE),
        origem: 'REGIAO',
        aproximada: true,
        legado: true,
      },
    };
  }

  return { localizacao: null };
}

// GET /regioes
router.get('/regioes', async (req, res) => {
  try {
    const resultado = await db.executar(
      `SELECT id, nome, cidade
         FROM regiao_aproximada
        ORDER BY cidade, nome`,
    );
    const regioes = (resultado.rows || []).map((linha) => ({
      id: linha.ID,
      nome: linha.NOME,
      cidade: linha.CIDADE,
    }));
    return res.status(200).json({ regioes });
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    console.error('[locais] erro ao listar regiões:', erro);
    return responderErro(
      res,
      500,
      'ERRO_INTERNO',
      'Não foi possível carregar as regiões.',
    );
  }
});

// GET /locais/catalogo?q=
router.get('/locais/catalogo', async (req, res) => {
  const eu = req.usuario.ID;
  const termo = String(req.query.q || '').trim().toLowerCase();
  const filtro = termo
    ? `WHERE LOWER(l.nome) LIKE :termo
          OR LOWER(COALESCE(l.endereco, '')) LIKE :termo
          OR LOWER(COALESCE(l.categoria, '')) LIKE :termo
          OR LOWER(l.cidade) LIKE :termo`
    : '';

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const coordenadas = await coordenadasDoUsuario(conexao, eu);
      const resultado = await conexao.execute(
        `SELECT l.id, l.nome, l.endereco, l.categoria, l.cidade,
                l.latitude, l.longitude, l.descricao, l.faixa_preco,
                l.avaliacao_media, l.avaliacao_total,
                (SELECT COUNT(*)
                   FROM catalogo_lugar_avaliacao a
                  WHERE a.lugar_id = l.id
                    AND a.usuario_id IS NOT NULL) AS total_reviews,
                (SELECT NVL(SUM(a.nota), 0)
                   FROM catalogo_lugar_avaliacao a
                  WHERE a.lugar_id = l.id
                    AND a.usuario_id IS NOT NULL) AS soma_reviews
           FROM catalogo_lugar l
           ${filtro}
          ORDER BY l.nome
          FETCH FIRST 100 ROWS ONLY`,
        termo ? { termo: `%${termo}%` } : {},
      );

      const locais = (resultado.rows || []).map((linha) =>
        catalogoDaLinha(linha, coordenadas),
      );

      if (coordenadas) {
        locais.sort(
          (a, b) =>
            a.distanciaMetros - b.distanciaMetros ||
            b.avaliacaoMedia - a.avaliacaoMedia ||
            a.nome.localeCompare(b.nome, 'pt-BR'),
        );
      } else {
        locais.sort(
          (a, b) =>
            b.avaliacaoMedia - a.avaliacaoMedia ||
            a.nome.localeCompare(b.nome, 'pt-BR'),
        );
      }

      return { locais, temLocalizacao: Boolean(coordenadas) };
    });

    return res.status(200).json(resposta);
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    console.error('[locais] erro no catálogo:', erro);
    return responderErro(
      res,
      500,
      'ERRO_INTERNO',
      'Não foi possível carregar o catálogo de lugares.',
    );
  }
});

// GET /locais/catalogo/:id
router.get('/locais/catalogo/:id', async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);

  if (!Number.isInteger(id) || id <= 0) {
    return responderErro(
      res,
      404,
      'LUGAR_NAO_ENCONTRADO',
      'Lugar não encontrado.',
    );
  }

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const coordenadas = await coordenadasDoUsuario(conexao, eu);
      const lugarRes = await conexao.execute(
        `SELECT l.id, l.nome, l.endereco, l.categoria, l.cidade,
                l.latitude, l.longitude, l.descricao, l.faixa_preco,
                l.avaliacao_media, l.avaliacao_total,
                (SELECT COUNT(*)
                   FROM catalogo_lugar_avaliacao a
                  WHERE a.lugar_id = l.id
                    AND a.usuario_id IS NOT NULL) AS total_reviews,
                (SELECT NVL(SUM(a.nota), 0)
                   FROM catalogo_lugar_avaliacao a
                  WHERE a.lugar_id = l.id
                    AND a.usuario_id IS NOT NULL) AS soma_reviews
           FROM catalogo_lugar l
          WHERE l.id = :id`,
        { id },
      );
      const linha = (lugarRes.rows || [])[0];
      if (!linha) return null;

      const itensRes = await conexao.execute(
        `SELECT nome
           FROM catalogo_lugar_item
          WHERE lugar_id = :id
          ORDER BY ordem, id`,
        { id },
      );

      const avaliacoesRes = await conexao.execute(
        `SELECT a.id, a.lugar_id, a.usuario_id, a.autor_nome,
                a.nota, a.comentario, a.criado_em, a.atualizado_em,
                u.nome AS usuario_nome, u.username AS usuario_username
           FROM catalogo_lugar_avaliacao a
           LEFT JOIN usuario u ON u.id = a.usuario_id
          WHERE a.lugar_id = :id
          ORDER BY a.criado_em DESC, a.id DESC
          FETCH FIRST 50 ROWS ONLY`,
        { id },
      );

      const avaliacoes = (avaliacoesRes.rows || []).map((item) =>
        avaliacaoDaLinha(item, eu),
      );

      return {
        ...catalogoDaLinha(linha, coordenadas),
        itens: (itensRes.rows || []).map((item) => item.NOME),
        avaliacoes,
        minhaAvaliacao: avaliacoes.find((item) => item.minha) || null,
      };
    });

    if (!resposta) {
      return responderErro(
        res,
        404,
        'LUGAR_NAO_ENCONTRADO',
        'Lugar não encontrado.',
      );
    }
    return res.status(200).json({ lugar: resposta });
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    console.error('[locais] erro no detalhe do lugar:', erro);
    return responderErro(
      res,
      500,
      'ERRO_INTERNO',
      'Não foi possível carregar o lugar.',
    );
  }
});

// PUT /locais/catalogo/:id/avaliacao
router.put('/locais/catalogo/:id/avaliacao', async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);
  const corpo = req.body || {};
  const nota = Number(corpo.nota);
  const comentarioBruto =
    corpo.comentario === undefined || corpo.comentario === null
      ? ''
      : String(corpo.comentario).trim();
  const erros = [];

  if (!Number.isInteger(id) || id <= 0) {
    return responderErro(
      res,
      404,
      'LUGAR_NAO_ENCONTRADO',
      'Lugar não encontrado.',
    );
  }
  if (!Number.isInteger(nota) || nota < 1 || nota > 5) {
    erros.push({
      campo: 'nota',
      mensagem: 'Informe uma nota entre 1 e 5 estrelas.',
    });
  }
  if (comentarioBruto.length > 1000) {
    erros.push({
      campo: 'comentario',
      mensagem: 'Use no máximo 1000 caracteres no comentário.',
    });
  }
  if (erros.length) return validacao(res, erros);

  const comentario = comentarioBruto || null;

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const lugarRes = await conexao.execute(
        `SELECT id FROM catalogo_lugar WHERE id = :id`,
        { id },
      );
      if ((lugarRes.rows || []).length === 0) {
        return { erro: { status: 404, codigo: 'LUGAR_NAO_ENCONTRADO' } };
      }

      const existente = await conexao.execute(
        `SELECT id
           FROM catalogo_lugar_avaliacao
          WHERE lugar_id = :id AND usuario_id = :eu`,
        { id, eu },
      );
      const avaliacaoId = (existente.rows || [])[0]?.ID;

      if (avaliacaoId) {
        await conexao.execute(
          `UPDATE catalogo_lugar_avaliacao
              SET nota = :nota,
                  comentario = :comentario,
                  atualizado_em = SYS_EXTRACT_UTC(SYSTIMESTAMP)
            WHERE id = :avaliacaoId`,
          { nota, comentario, avaliacaoId },
        );
      } else {
        await conexao.execute(
          `INSERT INTO catalogo_lugar_avaliacao
             (lugar_id, usuario_id, nota, comentario)
           VALUES (:id, :eu, :nota, :comentario)`,
          { id, eu, nota, comentario },
        );
      }

      const avaliacaoRes = await conexao.execute(
        `SELECT a.id, a.lugar_id, a.usuario_id, a.autor_nome,
                a.nota, a.comentario, a.criado_em, a.atualizado_em,
                u.nome AS usuario_nome, u.username AS usuario_username
           FROM catalogo_lugar_avaliacao a
           LEFT JOIN usuario u ON u.id = a.usuario_id
          WHERE a.lugar_id = :id AND a.usuario_id = :eu`,
        { id, eu },
      );

      const resumo = await conexao.execute(
        `SELECT l.avaliacao_media, l.avaliacao_total,
                (SELECT COUNT(*)
                   FROM catalogo_lugar_avaliacao a
                  WHERE a.lugar_id = l.id
                    AND a.usuario_id IS NOT NULL) AS total_reviews,
                (SELECT NVL(SUM(a.nota), 0)
                   FROM catalogo_lugar_avaliacao a
                  WHERE a.lugar_id = l.id
                    AND a.usuario_id IS NOT NULL) AS soma_reviews
           FROM catalogo_lugar l
          WHERE l.id = :id`,
        { id },
      );

      const avaliacaoLinha = (avaliacaoRes.rows || [])[0];
      const resumoLinha = (resumo.rows || [])[0];
      const avaliacaoCalculada = calcularAvaliacao(resumoLinha || {});
      await conexao.commit();

      return {
        avaliacao: avaliacaoLinha
          ? avaliacaoDaLinha(avaliacaoLinha, eu)
          : null,
        avaliacaoMedia: avaliacaoCalculada.media,
        avaliacaoTotal: avaliacaoCalculada.total,
      };
    });

    if (resposta.erro) {
      return responderErro(
        res,
        resposta.erro.status,
        resposta.erro.codigo,
        'Lugar não encontrado.',
      );
    }
    return res.status(200).json(resposta);
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    console.error('[locais] erro ao avaliar lugar:', erro);
    return responderErro(
      res,
      500,
      'ERRO_INTERNO',
      'Não foi possível salvar sua avaliação.',
    );
  }
});

// DELETE /locais/catalogo/:id/avaliacao
router.delete('/locais/catalogo/:id/avaliacao', async (req, res) => {
  const eu = req.usuario.ID;
  const id = Number(req.params.id);

  if (!Number.isInteger(id) || id <= 0) {
    return responderErro(
      res,
      404,
      'LUGAR_NAO_ENCONTRADO',
      'Lugar não encontrado.',
    );
  }

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const lugarRes = await conexao.execute(
        `SELECT id FROM catalogo_lugar WHERE id = :id`,
        { id },
      );
      if ((lugarRes.rows || []).length === 0) return null;

      await conexao.execute(
        `DELETE FROM catalogo_lugar_avaliacao
          WHERE lugar_id = :id AND usuario_id = :eu`,
        { id, eu },
      );

      const resumo = await conexao.execute(
        `SELECT l.avaliacao_media, l.avaliacao_total,
                (SELECT COUNT(*)
                   FROM catalogo_lugar_avaliacao a
                  WHERE a.lugar_id = l.id
                    AND a.usuario_id IS NOT NULL) AS total_reviews,
                (SELECT NVL(SUM(a.nota), 0)
                   FROM catalogo_lugar_avaliacao a
                  WHERE a.lugar_id = l.id
                    AND a.usuario_id IS NOT NULL) AS soma_reviews
           FROM catalogo_lugar l
          WHERE l.id = :id`,
        { id },
      );
      const resumoLinha = (resumo.rows || [])[0] || {};
      const avaliacaoCalculada = calcularAvaliacao(resumoLinha);
      await conexao.commit();

      return {
        avaliacaoMedia: avaliacaoCalculada.media,
        avaliacaoTotal: avaliacaoCalculada.total,
      };
    });

    if (!resposta) {
      return responderErro(
        res,
        404,
        'LUGAR_NAO_ENCONTRADO',
        'Lugar não encontrado.',
      );
    }
    return res.status(200).json(resposta);
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    console.error('[locais] erro ao remover avaliação:', erro);
    return responderErro(
      res,
      500,
      'ERRO_INTERNO',
      'Não foi possível remover sua avaliação.',
    );
  }
});

// GET /me/localizacao
router.get('/me/localizacao', autenticar, async (req, res) => {
  try {
    const resposta = await db.comConexao((conexao) =>
      minhasLocalizacao(conexao, req.usuario.ID),
    );
    return res.status(200).json(resposta);
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    console.error('[locais] erro ao ler localização:', erro);
    return responderErro(
      res,
      500,
      'ERRO_INTERNO',
      'Não foi possível carregar sua localização.',
    );
  }
});

// PUT /me/localizacao
router.put('/me/localizacao', autenticar, async (req, res) => {
  const corpo = req.body || {};
  const bairro = String(corpo.bairro || '').trim();
  const cidade = String(corpo.cidade || '').trim();
  const latitude = Number(corpo.latitude);
  const longitude = Number(corpo.longitude);
  const origem = String(corpo.origem || 'MAPA').trim().toUpperCase();
  const erros = [];

  if (!bairro || bairro.length > 120) {
    erros.push({
      campo: 'bairro',
      mensagem: 'Informe um bairro entre 1 e 120 caracteres.',
    });
  }
  if (cidade.length > 120) {
    erros.push({
      campo: 'cidade',
      mensagem: 'Use no máximo 120 caracteres para a cidade.',
    });
  }
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    erros.push({ campo: 'latitude', mensagem: 'Informe uma latitude válida.' });
  }
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    erros.push({ campo: 'longitude', mensagem: 'Informe uma longitude válida.' });
  }
  if (!['MAPA', 'GPS', 'BUSCA', 'COORDENADAS'].includes(origem)) {
    erros.push({
      campo: 'origem',
      mensagem: 'Use MAPA, GPS, BUSCA ou COORDENADAS.',
    });
  }
  if (erros.length) return validacao(res, erros);

  // A coordenada armazenada é aproximada (duas casas decimais, ~1 km).
  const latitudeAproximada = Math.round(latitude * 100) / 100;
  const longitudeAproximada = Math.round(longitude * 100) / 100;

  try {
    const resposta = await db.comConexao(async (conexao) => {
      await conexao.execute(
        `UPDATE usuario
            SET localizacao_bairro = :bairro,
                localizacao_cidade = :cidade,
                localizacao_latitude = :latitude,
                localizacao_longitude = :longitude,
                localizacao_origem = :origem,
                localizacao_atualizada_em = SYS_EXTRACT_UTC(SYSTIMESTAMP),
                regiao_id = NULL
          WHERE id = :eu`,
        {
          bairro,
          cidade: cidade || null,
          latitude: latitudeAproximada,
          longitude: longitudeAproximada,
          origem,
          eu: req.usuario.ID,
        },
      );
      const atual = await minhasLocalizacao(conexao, req.usuario.ID);
      await conexao.commit();
      return atual;
    });

    return res.status(200).json(resposta);
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    console.error('[locais] erro ao salvar localização:', erro);
    return responderErro(
      res,
      500,
      'ERRO_INTERNO',
      'Não foi possível salvar sua localização.',
    );
  }
});

// DELETE /me/localizacao
router.delete('/me/localizacao', autenticar, async (req, res) => {
  try {
    await db.executar(
      `UPDATE usuario
          SET regiao_id = NULL,
              localizacao_bairro = NULL,
              localizacao_cidade = NULL,
              localizacao_latitude = NULL,
              localizacao_longitude = NULL,
              localizacao_origem = NULL,
              localizacao_atualizada_em = NULL
        WHERE id = :eu`,
      { eu: req.usuario.ID },
      { autoCommit: true },
    );
    return res.status(200).json({ localizacao: null });
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    console.error('[locais] erro ao remover localização:', erro);
    return responderErro(
      res,
      500,
      'ERRO_INTERNO',
      'Não foi possível remover sua localização.',
    );
  }
});

// POST /locais/sugestoes
router.post('/locais/sugestoes', async (req, res) => {
  const eu = req.usuario.ID;
  const corpo = req.body || {};
  const erros = [];
  const ids = lerIds(corpo.usuarioIds, erros);
  const modo = String(corpo.modo || 'todos').trim().toLowerCase();

  if (!['todos', 'alguns', 'um'].includes(modo)) {
    erros.push({
      campo: 'modo',
      mensagem: 'Use todos, alguns ou um.',
    });
  }
  if (erros.length) return validacao(res, erros);

  try {
    const resposta = await db.comConexao(async (conexao) => {
      const pontos = [];
      const semLocalizacao = [];
      const localizacoesAproximadas = [];

      for (const usuarioId of ids) {
        const resultado = await conexao.execute(
          `SELECT u.id, u.nome, u.regiao_id,
                  u.localizacao_bairro,
                  u.localizacao_cidade,
                  u.localizacao_latitude,
                  u.localizacao_longitude,
                  r.nome     AS regiao_nome,
                  r.cidade   AS regiao_cidade,
                  r.latitude AS regiao_latitude,
                  r.longitude AS regiao_longitude,
                  (SELECT COUNT(*) FROM amizade a
                    WHERE a.status = 'A'
                      AND ((a.solicitante_id = :eu AND a.destinatario_id = u.id)
                        OR (a.destinatario_id = :eu AND a.solicitante_id = u.id)))
                    AS amigos,
                  (SELECT COUNT(*) FROM bloqueio b
                    WHERE (b.bloqueador_id = :eu AND b.bloqueado_id = u.id)
                       OR (b.bloqueador_id = u.id AND b.bloqueado_id = :eu))
                    AS bloqueios
             FROM usuario u
             LEFT JOIN regiao_aproximada r ON r.id = u.regiao_id
            WHERE u.id = :usuarioId`,
          { eu, usuarioId },
        );
        const linha = (resultado.rows || [])[0];
        if (!linha) {
          return {
            validacao: [
              { campo: 'usuarioIds', mensagem: `Usuário ${usuarioId} não encontrado.` },
            ],
          };
        }
        if (
          usuarioId !== eu &&
          (Number(linha.AMIGOS || 0) === 0 || Number(linha.BLOQUEIOS || 0) > 0)
        ) {
          return {
            validacao: [
              {
                campo: 'usuarioIds',
                mensagem: 'Só é possível usar amigos confirmados.',
              },
            ],
          };
        }

        const latitude =
          linha.LOCALIZACAO_LATITUDE ?? linha.REGIAO_LATITUDE;
        const longitude =
          linha.LOCALIZACAO_LONGITUDE ?? linha.REGIAO_LONGITUDE;
        const bairro =
          linha.LOCALIZACAO_BAIRRO || linha.REGIAO_NOME || null;
        const cidade =
          linha.LOCALIZACAO_CIDADE || linha.REGIAO_CIDADE || null;

        if (latitude == null || longitude == null) {
          semLocalizacao.push({ usuarioId, nome: linha.NOME });
          continue;
        }

        pontos.push({
          usuarioId,
          nome: linha.NOME,
          latitude: Number(latitude),
          longitude: Number(longitude),
        });
        localizacoesAproximadas.push({
          usuarioId,
          nome: linha.NOME,
          bairro,
          cidade,
        });
      }

      if (pontos.length === 0) {
        return {
          erro: {
            status: 400,
            codigo: 'SEM_LOCALIZACAO',
            mensagem:
              'Nenhuma das pessoas selecionadas divulgou uma localização aproximada.',
          },
        };
      }

      const catalogo = await conexao.execute(
        `SELECT id, nome, endereco, categoria, cidade, latitude, longitude
           FROM catalogo_lugar`,
      );

      const sugestoes = (catalogo.rows || [])
        .map((linha) => {
          const latitude = Number(linha.LATITUDE);
          const longitude = Number(linha.LONGITUDE);
          const soma = pontos.reduce(
            (total, ponto) =>
              total +
              haversineMetros(
                latitude,
                longitude,
                ponto.latitude,
                ponto.longitude,
              ),
            0,
          );
          return {
            lugar: localDaLinha(linha),
            distanciaMediaMetros: Math.round(soma / pontos.length),
          };
        })
        .sort((a, b) => {
          if (a.distanciaMediaMetros !== b.distanciaMediaMetros) {
            return a.distanciaMediaMetros - b.distanciaMediaMetros;
          }
          return a.lugar.nome.localeCompare(b.lugar.nome);
        })
        .slice(0, 15);

      return {
        sugestoes,
        semLocalizacao,
        localizacoesAproximadas,
        modo,
      };
    });

    if (resposta.erro) {
      return responderErro(
        res,
        resposta.erro.status,
        resposta.erro.codigo,
        resposta.erro.mensagem,
      );
    }
    if (resposta.validacao) return validacao(res, resposta.validacao);
    return res.status(200).json(resposta);
  } catch (erro) {
    if (erro instanceof db.BancoIndisponivelError) return bancoIndisponivel(res);
    console.error('[locais] erro nas sugestões:', erro);
    return responderErro(
      res,
      500,
      'ERRO_INTERNO',
      'Não foi possível calcular as sugestões de local.',
    );
  }
});

module.exports = router;
