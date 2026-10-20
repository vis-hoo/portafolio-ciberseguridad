'use strict';

const oracledb = require('oracledb');

// Modo thin: no requiere el cliente Oracle instalado en la imagen.
oracledb.outFormat = oracledb.OUT_FORMAT_OBJECT;

const poolConfig = {
  user: process.env.DB_USER || 'banco',
  password: process.env.DB_PASSWORD || 'banco2026',
  connectString:
    process.env.DB_CONNECT_STRING || 'oracle:1521/FREEPDB1',
  poolMin: 1,
  poolMax: 8,
  poolIncrement: 1,
};

let pool;

async function init() {
  pool = await oracledb.createPool(poolConfig);
  return pool;
}

async function getConnection() {
  if (!pool) {
    await init();
  }
  return pool.getConnection();
}

async function query(sql, binds = []) {
  const conn = await getConnection();
  try {
    const result = await conn.execute(sql, binds, { autoCommit: true });
    return result.rows;
  } finally {
    await conn.close();
  }
}

module.exports = { init, getConnection, query };
