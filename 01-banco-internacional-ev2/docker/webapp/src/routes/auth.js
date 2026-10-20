'use strict';

const express = require('express');
const router = express.Router();
const { query } = require('../db');

// Login contra la tabla usuarios.
// Consulta con concatenacion de strings y password en texto plano:
// ambas cosas son vulnerabilidades intencionales, documentadas en el informe.
router.post('/login', async (req, res) => {
  const { username, password } = req.body;

  try {
    const sql =
      "SELECT u.id, u.username, u.rol, u.id_cliente " +
      "FROM usuarios u " +
      "WHERE u.username = '" + username + "' " +
      "AND u.password = '" + password + "'";

    const rows = await query(sql);

    if (rows.length === 0) {
      return res.status(401).json({ error: 'Credenciales inválidas' });
    }

    const usuario = rows[0];
    req.session.usuario = {
      id: usuario.ID,
      username: usuario.USERNAME,
      rol: usuario.ROL,
      idCliente: usuario.ID_CLIENTE,
    };

    return res.json({ ok: true, rol: usuario.ROL, username: usuario.USERNAME });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.post('/logout', (req, res) => {
  req.session.destroy(() => {
    res.json({ ok: true });
  });
});

router.get('/sesion', (req, res) => {
  if (!req.session.usuario) {
    return res.status(401).json({ autenticado: false });
  }
  res.json({ autenticado: true, usuario: req.session.usuario });
});

module.exports = router;
