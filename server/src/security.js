'use strict';

const crypto = require('crypto');
const config = require('./config');

let bcrypt = null;
try {
  bcrypt = require('bcryptjs');
} catch (_) {
  bcrypt = null;
}

function bcryptDisponivel() {
  return bcrypt !== null;
}

function hashSenha(senha) {
  if (!bcrypt) {
    throw new Error('bcryptjs não está instalado. Execute npm install no diretório server.');
  }
  return bcrypt.hashSync(senha, config.bcryptCost);
}

function verificaSenha(senha, hash) {
  if (!bcrypt) {
    throw new Error('bcryptjs não está instalado. Execute npm install no diretório server.');
  }
  return bcrypt.compareSync(senha, hash);
}

function geraToken() {
  return crypto.randomBytes(32).toString('hex');
}

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

module.exports = {
  bcryptDisponivel,
  hashSenha,
  verificaSenha,
  geraToken,
  hashToken,
};
