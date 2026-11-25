'use strict';

const express = require('express');
const db = require('../db');

const router = express.Router();

router.get('/health', (req, res) => {
  const banco = db.status();
  return res.status(200).json({
    status: 'ok',
    db: banco.disponivel ? 'available' : 'unavailable',
    timestamp: new Date().toISOString(),
  });
});

module.exports = router;
