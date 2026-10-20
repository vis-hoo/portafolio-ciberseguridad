'use strict';

const express = require('express');
const router = express.Router();
const { query } = require('../db');

// ------------------------------------------------------------
// Clientes: listar, ver, crear, actualizar, borrar
// ------------------------------------------------------------

router.get('/clientes', async (req, res) => {
  try {
    const rows = await query(
      'SELECT c.id, c.nombre, c.apellido, c.dni, c.email, ' +
        'c.fecha_nacimiento, cu.numero_cuenta, cu.saldo ' +
        'FROM clientes c ' +
        'LEFT JOIN cuentas cu ON cu.id_cliente = c.id ' +
        'ORDER BY c.id'
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/clientes/:id', async (req, res) => {
  try {
    const rows = await query(
      'SELECT id, nombre, apellido, dni, email, fecha_nacimiento ' +
        'FROM clientes WHERE id = :id',
      [req.params.id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Cliente no encontrado' });
    }
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/clientes', async (req, res) => {
  const { nombre, apellido, dni, email, fecha_nacimiento } = req.body;
  const oracledb = require('oracledb');
  const { getConnection } = require('../db');
  const conn = await getConnection();
  try {
    const result = await conn.execute(
      'INSERT INTO clientes (nombre, apellido, dni, email, fecha_nacimiento) ' +
        "VALUES (:nombre, :apellido, :dni, :email, TO_DATE(:fn, 'YYYY-MM-DD')) " +
        'RETURNING id INTO :id',
      {
        nombre,
        apellido,
        dni,
        email,
        fn: fecha_nacimiento,
        id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
      },
      { autoCommit: true }
    );
    res.status(201).json({ ok: true, id: result.outBinds.id[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  } finally {
    await conn.close();
  }
});

router.put('/clientes/:id', async (req, res) => {
  const { nombre, apellido, email } = req.body;
  try {
    await query(
      'UPDATE clientes SET nombre = :nombre, apellido = :apellido, ' +
        'email = :email WHERE id = :id',
      [nombre, apellido, email, req.params.id]
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/clientes/:id', async (req, res) => {
  try {
    await query('DELETE FROM clientes WHERE id = :id', [req.params.id]);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ------------------------------------------------------------
// Prestamos: listar, crear, actualizar condiciones, borrar
// ------------------------------------------------------------

router.get('/prestamos', async (req, res) => {
  try {
    const rows = await query(
      'SELECT p.id, p.id_cliente, c.nombre, c.apellido, p.monto, p.tasa, ' +
        'p.plazo_meses, p.estado, p.condiciones, p.fecha ' +
        'FROM prestamos p JOIN clientes c ON c.id = p.id_cliente ' +
        'ORDER BY p.id'
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/prestamos', async (req, res) => {
  const { id_cliente, monto, tasa, plazo_meses, condiciones } = req.body;
  try {
    await query(
      'INSERT INTO prestamos (id_cliente, monto, tasa, plazo_meses, ' +
        'condiciones) VALUES (:idc, :monto, :tasa, :plazo, :cond)',
      [id_cliente, monto, tasa, plazo_meses, condiciones || null]
    );
    res.status(201).json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/prestamos/:id', async (req, res) => {
  const { monto, tasa, estado, condiciones } = req.body;
  try {
    await query(
      'UPDATE prestamos SET monto = :monto, tasa = :tasa, ' +
        'estado = :estado, condiciones = :cond WHERE id = :id',
      [monto, tasa, estado, condiciones, req.params.id]
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/prestamos/:id', async (req, res) => {
  try {
    await query('DELETE FROM prestamos WHERE id = :id', [req.params.id]);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ------------------------------------------------------------
// Movimientos: listar todos, registrar uno manual
// ------------------------------------------------------------

router.get('/movimientos', async (req, res) => {
  try {
    const rows = await query(
      'SELECT m.id, c.numero_cuenta, cl.nombre, cl.apellido, m.tipo, ' +
        'm.monto, m.descripcion, m.fecha ' +
        'FROM movimientos m ' +
        'JOIN cuentas c ON c.id = m.id_cuenta ' +
        'JOIN clientes cl ON cl.id = c.id_cliente ' +
        'ORDER BY m.fecha DESC'
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/movimientos', async (req, res) => {
  const { id_cuenta, tipo, monto, descripcion } = req.body;
  const valor = parseFloat(monto);
  const signo = tipo === 'deposito' ? valor : -valor;

  try {
    await query(
      'UPDATE cuentas SET saldo = saldo + :signo WHERE id = :id',
      [signo, id_cuenta]
    );
    await query(
      'INSERT INTO movimientos (id_cuenta, tipo, monto, descripcion) ' +
        'VALUES (:idc, :tipo, :monto, :descrip)',
      [id_cuenta, tipo, valor, descripcion || null]
    );
    res.status(201).json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
