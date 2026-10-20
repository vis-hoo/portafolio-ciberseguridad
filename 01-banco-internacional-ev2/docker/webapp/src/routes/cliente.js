'use strict';

const express = require('express');
const router = express.Router();
const { getConnection, query } = require('../db');

// ------------------------------------------------------------
// Cliente: sus propios datos
// ------------------------------------------------------------

// Saldo de la cuenta del cliente autenticado.
router.get('/cuenta', async (req, res) => {
  const idCliente = req.session.usuario.idCliente;
  try {
    const rows = await query(
      'SELECT id, numero_cuenta, tipo, saldo, fecha_apertura ' +
        'FROM cuentas WHERE id_cliente = :id',
      [idCliente]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Cuenta no encontrada' });
    }
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Movimientos de la cuenta del cliente autenticado.
router.get('/movimientos', async (req, res) => {
  const idCliente = req.session.usuario.idCliente;
  try {
    const rows = await query(
      'SELECT m.id, m.tipo, m.monto, m.descripcion, m.fecha ' +
        'FROM movimientos m ' +
        'JOIN cuentas c ON c.id = m.id_cuenta ' +
        'WHERE c.id_cliente = :id ORDER BY m.fecha DESC',
      [idCliente]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Prestamos del cliente autenticado.
router.get('/prestamos', async (req, res) => {
  const idCliente = req.session.usuario.idCliente;
  try {
    const rows = await query(
      'SELECT id, monto, tasa, plazo_meses, estado, condiciones, fecha ' +
        'FROM prestamos WHERE id_cliente = :id ORDER BY fecha DESC',
      [idCliente]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ------------------------------------------------------------
// Cliente: deposito y retiro
// ------------------------------------------------------------

// Deposito o retiro sobre la cuenta del cliente autenticado.
router.post('/operacion', async (req, res) => {
  const idCliente = req.session.usuario.idCliente;
  const { tipo, monto, descripcion } = req.body;

  if (tipo !== 'deposito' && tipo !== 'retiro') {
    return res.status(400).json({ error: 'Tipo invalido' });
  }

  const valor = parseFloat(monto);
  if (isNaN(valor) || valor <= 0) {
    return res.status(400).json({ error: 'Monto invalido' });
  }

  const conn = await getConnection();
  try {
    const cuenta = await conn.execute(
      'SELECT id, saldo FROM cuentas WHERE id_cliente = :id FOR UPDATE',
      [idCliente]
    );

    if (cuenta.rows.length === 0) {
      return res.status(404).json({ error: 'Cuenta no encontrada' });
    }

    const cuentaId = cuenta.rows[0].ID;
    const saldoActual = cuenta.rows[0].SALDO;
    const saldoNuevo =
      tipo === 'deposito' ? saldoActual + valor : saldoActual - valor;

    if (tipo === 'retiro' && saldoNuevo < 0) {
      return res.status(400).json({ error: 'Saldo insuficiente' });
    }

    await conn.execute(
      'UPDATE cuentas SET saldo = :saldo WHERE id = :id',
      [saldoNuevo, cuentaId],
      { autoCommit: false }
    );

    await conn.execute(
      'INSERT INTO movimientos (id_cuenta, tipo, monto, descripcion) ' +
        'VALUES (:cuenta, :tipo, :monto, :descrip)',
      [cuentaId, tipo, valor, descripcion || null],
      { autoCommit: false }
    );

    await conn.commit();
    res.json({ ok: true, saldo: saldoNuevo });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ error: err.message });
  } finally {
    await conn.close();
  }
});

module.exports = router;
