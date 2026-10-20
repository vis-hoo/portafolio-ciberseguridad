'use strict';

const path = require('path');
const express = require('express');
const session = require('express-session');

const db = require('./db');
const authRoutes = require('./routes/auth');
const clienteRoutes = require('./routes/cliente');
const ejecutivoRoutes = require('./routes/ejecutivo');

const app = express();
const PORT = process.env.PORT || 8088;

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Sesion con secreto fijo y cookie sin flags de seguridad.
// Vulnerabilidad intencional: documentada en el informe de mitigacion.
app.use(
  session({
    secret: 'banco-internacional-secreto',
    resave: false,
    saveUninitialized: false,
    cookie: { httpOnly: false, secure: false },
  })
);

// ------------------------------------------------------------
// Middleware de autorizacion
// ------------------------------------------------------------

function requiereSesion(req, res, next) {
  if (!req.session.usuario) {
    return res.status(401).json({ error: 'No autenticado' });
  }
  next();
}

function requiereRol(rol) {
  return (req, res, next) => {
    if (!req.session.usuario || req.session.usuario.rol !== rol) {
      return res.status(403).json({ error: 'Sin permiso' });
    }
    next();
  };
}

// ------------------------------------------------------------
// API
// ------------------------------------------------------------

app.use('/api', authRoutes);
app.use('/api/cliente', requiereSesion, clienteRoutes);
app.use('/api/ejecutivo', requiereRol('ejecutivo'), ejecutivoRoutes);

app.get('/api/health', (req, res) => {
  res.json({ ok: true, servicio: 'banco-internacional-web' });
});

// ------------------------------------------------------------
// Frontend estatico
// ------------------------------------------------------------

app.use(express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/login', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'login.html'));
});

app.get('/cliente', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'cliente.html'));
});

app.get('/ejecutivo', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'ejecutivo.html'));
});

// ------------------------------------------------------------
// Arranque
// ------------------------------------------------------------

async function start() {
  try {
    await db.init();
    console.log('Pool de conexiones a Oracle creado');
  } catch (err) {
    console.error('Error al conectar con Oracle:', err.message);
    process.exit(1);
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log('Banco Internacional escuchando en el puerto ' + PORT);
  });
}

start();
