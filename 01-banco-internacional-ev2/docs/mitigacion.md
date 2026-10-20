# Plan de mitigación

Cada hallazgo del análisis se corrige en la capa que le corresponde. El orden de la tabla es el orden en que conviene trabajarlos: primero lo que expone datos o permite suplantar a un usuario, después lo que endurece la superficie y al final lo informativo.

Las vulnerabilidades intencionales de la aplicación se listan aquí como **estado inicial**.

## 1. Inyección SQL en el inicio de sesión

**Dónde:** `docker/webapp/src/routes/auth.js`, consulta de login.

**Qué pasa:** el usuario y la contraseña se concatenan directamente en la consulta. Una contraseña como `' OR '1'='1` hace que la condición siempre sea verdadera y devuelve la primera fila de `usuarios`, sin conocer ninguna credencial. Como efecto secundario, autentica a un usuario distinto del solicitado.

**Cómo se corrige:** usar enlaces (binds) en lugar de concatenar.

```sql
SELECT id, username, rol, id_cliente
FROM usuarios
WHERE username = :usuario AND password_hash = :hash
```

En el código de Node esto ya está hecho en el resto de las rutas: todas usan `:parametro`. La ruta de login es la única excepción, y es precisamente donde importa más.

## 2. Contraseñas en texto plano

**Dónde:** tabla `usuarios`, columna `password`.

**Qué pasa:** la base guarda las contraseñas legibles. Cualquiera con acceso de lectura a la tabla —o con una inyección SQL— obtiene las credenciales de todos los usuarios de una vez.

**Cómo se corrige:** guardar un hash con sal. `bcrypt` es la opción habitual en Node. La columna pasa a llamarse `password_hash` y guarda el resultado de `bcrypt.hash(password, 12)`. En el login se compara con `bcrypt.compare`.

**Por qué importa más de lo que parece:** como el cliente también escribe en la base a través de la aplicación, una contraseña reutilizada en otro servicio queda expuesta fuera del ejercicio.

## 3. Sin límite de intentos

**Dónde:** ruta de login.

**Qué pasa:** se puede probar contraseñas sin freno. La combinación con el punto 1 es total: ni siquiera hace falta adivinar.

**Cómo se corrige:** limitar los intentos por usuario y por dirección. `express-rate-limit` cubre el caso básico. Un bloqueo temporal tras varios fallos consecutivos y un registro de los intentos completan la medida.

## 4. Cookie de sesión sin protección

**Dónde:** `docker/webapp/src/server.js`, configuración de `express-session`.

**Qué pasa:** la cookie se emite con `httpOnly: false` y `secure: false`, y el secreto de firma está escrito en el código. Sin `httpOnly`, un script inyectado en la página puede leer la sesión; sin `secure`, la cookie viaja en claro.

**Cómo se corrige:**

```js
app.use(session({
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    secure: true,
    sameSite: 'strict',
    maxAge: 30 * 60 * 1000,
  },
}));
```

El secreto se mueve a una variable de entorno. En un despliegue real, el almacén de sesiones de memoria también se cambia por uno persistente, porque `MemoryStore` pierde las sesiones al reiniciar.

## 5. Cabeceras de seguridad ausentes

**Dónde:** todas las respuestas de la aplicación.

**Qué pasa:** el servidor no envía `Content-Security-Policy`, `X-Frame-Options` ni `X-Content-Type-Options`. Es lo primero que reporta ZAP en el escaneo. Sin `X-Frame-Options`, la página se puede incrustar en un iframe ajeno y quedar expuesta a *clickjacking*.

**Cómo se corrige:** agregar `helmet` al arranque de Express. Con eso llegan las cabeceras, incluida una política de contenido por defecto.

```js
const helmet = require('helmet');
app.use(helmet());
```

## 6. Fuga de información en cabeceras y en la URL

**Dónde:** cabecera `X-Powered-By` y formulario de login.

**Qué pasa:** el servidor declara que corre Express, lo que orienta a quien busca versiones vulnerables. El formulario envía las credenciales por `GET`, así que quedan escritas en la URL y, con ello, en los registros del servidor y en el historial del navegador.

**Cómo se corrige:** desactivar la cabecera con `app.disable('x-powered-by')` —`helmet` ya lo hace— y cambiar el formulario a `POST` con el cuerpo de la petición.

## 7. Consulta de cuenta por identificador de cliente

**Dónde:** `docker/webapp/src/routes/cliente.js`.

**Qué pasa:** el cliente consulta su cuenta con el identificador guardado en la sesión. La consulta está parametrizada, así que no hay inyección, pero conviene dejar constancia de que el aislamiento depende por completo de que el identificador de sesión sea de fiar. Si la sesión se manipula, el aislamiento entre clientes se cae.

**Cómo se corrige:** el punto 4 (cookie firmada, `httpOnly`, `secure`) es justamente lo que sostiene esta frontera. Sin él, el resto del aislamiento no se puede garantizar.

## Prioridad

| # | Vulnerabilidad | Impacto | Esfuerzo | Prioridad |
|---|----------------|---------|----------|-----------|
| 1 | Inyección SQL en login | Alto | Bajo | Inmediata |
| 2 | Contraseñas en texto plano | Alto | Medio | Inmediata |
| 3 | Sin límite de intentos | Medio | Bajo | Alta |
| 4 | Cookie sin `httpOnly`/`secure` | Alto | Bajo | Alta |
| 5 | Cabeceras de seguridad ausentes | Medio | Bajo | Media |
| 6 | Fuga en cabecera y URL | Bajo | Bajo | Media |
| 7 | Confianza en el identificador de sesión | Medio | — | Cubierta por el punto 4 |

Las cuatro primeras se corrigen en la misma sesión de trabajo y resuelven el grueso del riesgo. Las dos siguientes son endurecimiento. La última no es una corrección aparte: se sostiene con la cookie arreglada.
