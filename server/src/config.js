'use strict';

const path = require('path');

try {
  require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
} catch (_) {
  // dotenv é opcional em ambiente de teste; variáveis do processo continuam válidas.
}

const config = {
  port: Number(process.env.PORT || 3000),
  env: process.env.NODE_ENV || 'development',
  sessionTtlDays: Number(process.env.SESSION_TTL_DAYS || 30),
  bcryptCost: Number(process.env.BCRYPT_COST || 10),
  db: {
    user: process.env.DB_USER || '',
    password: process.env.DB_PASSWORD || '',
    connectString: process.env.DB_CONNECT_STRING || '',
    poolMin: Number(process.env.DB_POOL_MIN || 1),
    poolMax: Number(process.env.DB_POOL_MAX || 4),
  },
};

module.exports = config;
