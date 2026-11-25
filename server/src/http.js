'use strict';

function envelopeErro(code, message, details) {
  const erro = { code, message };
  if (details !== undefined) erro.details = details;
  return { error: erro };
}

function responderErro(res, status, code, message, details) {
  return res.status(status).json(envelopeErro(code, message, details));
}

function bancoIndisponivel(res) {
  return responderErro(
    res,
    503,
    'BANCO_INDISPONIVEL',
    'O banco de dados está indisponível. Tente novamente em instantes.',
  );
}

function validacao(res, details) {
  return responderErro(res, 400, 'VALIDACAO', 'Dados inválidos.', details);
}

module.exports = {
  envelopeErro,
  responderErro,
  bancoIndisponivel,
  validacao,
};
