# Informe EV-2: infraestructura Docker y análisis de vulnerabilidades

**Asignatura:** Gestión de Seguridad de la Información
**Evaluación:** EV-2
**Formato:** APA 6

---

## Resumen

El trabajo monta una infraestructura de cuatro contenedores Docker sobre una red propia: una base de datos Oracle, una aplicación web bancaria construida con una imagen propia, y dos escáneres de vulnerabilidades. La aplicación se comunicó con la base entre contenedores; los escáneres la analizaron desde dentro de la misma red. El resultado se consolidó en una tabla de vulnerabilidades y en un plan de mitigación.

---

## 1. Introducción

La evaluación pide construir una infraestructura con Docker y analizarla con dos herramientas de seguridad distintas. Se eligió un escenario bancario ficticio, Banco Internacional, porque concentra los tres elementos que interesan: datos personales, dinero y dos niveles de privilegio.

El proyecto tiene cuatro contenedores. Dos sostienen el servicio —la base de datos y la aplicación— y dos lo analizan: ZAP para la capa web y OpenVAS para la infraestructura. Los cuatro corren en la red `soc-net`, de modo que se hablan entre sí sin salir al exterior.

---

## 2. Marco conceptual: Docker

Las seis definiciones que pide la evaluación, en el orden en que se usan al levantar el proyecto.

### 2.1 Docker

Docker es una plataforma que empaqueta una aplicación junto con todo lo que necesita para ejecutarse —bibliotecas, variables de entorno, sistema base— dentro de una unidad llamada contenedor. La diferencia con una máquina virtual está en el núcleo: la máquina virtual trae su propio sistema operativo completo, mientras que el contenedor comparte el núcleo del equipo anfitrión y solo carga lo que le falta. Eso lo hace mucho más liviano y rápido de arrancar.

En este proyecto, Docker Desktop sobre Linux entrega el motor y la interfaz de línea de comandos con la que se levantó todo.

### 2.2 Imagen

Una imagen es la plantilla de solo lectura desde la que se crea un contenedor. Contiene el sistema de archivos y la configuración inicial, y no cambia. Cuando se ejecuta una imagen, se agrega una capa de escritura encima y el resultado es un contenedor.

Se usaron cuatro imágenes. Tres vienen de repositorios públicos y una fue construida en el proyecto:

| Imagen | Origen | Tamaño |
|--------|--------|--------|
| `gvenzl/oracle-free:23-slim` | Pública | 2,84 GB |
| `banco-internacional-web:1.0.0` | **Propia** | 261 MB |
| `zaproxy/zap-stable:latest` | Pública | 3,76 GB |
| `immauss/openvas:latest` | Pública | 7,2 GB |

Las imágenes se listan con `docker images`.

### 2.3 Dockerfile

El Dockerfile es el archivo de texto que describe cómo se construye una imagen. Cada instrucción produce una capa: `FROM` elige la base, `COPY` trae archivos, `RUN` ejecuta comandos durante la construcción, `CMD` define qué se ejecuta al arrancar.

El proyecto usa un Dockerfile de dos etapas para la aplicación web, que es el entregable central de la evaluación. Se detalla en la sección 4.

### 2.4 Volumen

Un volumen es un espacio de almacenamiento que vive fuera del ciclo de vida del contenedor. Sin volumen, todo lo que se escribe dentro de un contenedor desaparece cuando el contenedor se elimina. Con volumen, los datos sobreviven a los reinicios y las reconstrucciones.

Se usan dos volúmenes nombrados:

- `docker_oracle-data`: guarda los archivos de la base Oracle. Sin él, cada reinicio borraría el esquema y los datos.
- `docker_openvas-data`: guarda los certificados, la base de Greenbone y el feed de vulnerabilidades. Es importante porque el feed pesa cientos de megabytes y descargarlo de nuevo cada vez sería inviable.

Los volúmenes se listan con `docker volume ls`.

### 2.5 Red en Docker

Una red de Docker conecta contenedores entre sí y les asigna nombres resolubles. Cuando varios contenedores están en la misma red, se encuentran por el nombre del servicio y no por una dirección IP, que puede cambiar.

El proyecto define una red de puente llamada `soc-net`. Los cuatro contenedores están conectados a ella. Gracias a eso, la aplicación se conecta a la base con la cadena `oracle:1521/FREEPDB1` —`oracle` es el nombre del contenedor, no una IP— y los escáneres alcanzan la aplicación en `http://webapp:8088`.

Las redes se listan con `docker network ls` y se inspeccionan con `docker network inspect`.

### 2.6 Docker Compose

Docker Compose es la herramienta que permite describir varios contenedores en un archivo YAML y levantarlos con un solo comando. En vez de escribir un `docker run` largo por cada contenedor, se declaran los servicios, las redes y los volúmenes, y se ejecuta `docker compose up`.

El proyecto sigue el diagrama de la evaluación: cada contenedor tiene su propio `docker-compose.yml`, y en la raíz hay uno que los reúne a los cuatro mediante la instrucción `include`. Así se puede levantar todo junto con un comando, o un contenedor suelto cuando conviene.

---

## 3. Arquitectura

Cuatro contenedores sobre una red propia. Dos sostienen el servicio y dos lo analizan.

| Contenedor | Imagen | Puerto | Rol |
|------------|--------|--------|-----|
| `banco-oracle` | `gvenzl/oracle-free:23-slim` | 1521 | Base de datos, esquema `banco` |
| `banco-webapp` | `banco-internacional-web:1.0.0` | 8088 | Aplicación web, imagen propia |
| `banco-zap` | `zaproxy/zap-stable:latest` | 8080 | Escáner web |
| `banco-openvas` | `immauss/openvas:latest` | 9392 | Escáner de infraestructura |

Los cuatro están conectados a la red de puente `soc-net`. La aplicación se conecta a la base con la cadena `oracle:1521/FREEPDB1`: `oracle` es el nombre del contenedor, que la red resuelve a una dirección IP. Los escáneres alcanzan la aplicación en `http://webapp:8088`. Ninguno de los dos necesita una dirección IP fija; el nombre del servicio basta.

La red se verifica con `docker network inspect soc-net`, que muestra los cuatro contenedores conectados y la dirección que recibió cada uno. La comunicación interna se comprueba resolviendo un nombre desde dentro de un contenedor: `docker exec banco-webapp node -e "require('dns').lookup('oracle', ...)"` devuelve la dirección de la base.

_(insertar captura: `docs/evidencias/fase-4-orquestacion.txt` y `docs/evidencias/fase-4-conectividad.txt`)_

## 4. La imagen propia

La evaluación pide una imagen construida con Dockerfile para la aplicación. Es `banco-internacional-web:1.0.0`, y ocupa 261 MB.

El Dockerfile usa dos etapas. La primera instala las dependencias; la segunda copia solo lo necesario y arma la imagen final. La ventaja es que el resultado no carga las herramientas de compilación ni los archivos temporales de la instalación.

**Etapa 1 — dependencias.** Parte de `node:22-alpine` y ejecuta `npm install --omit=dev`. Al copiar primero solo `package.json` y después el resto, la caché de capas se conserva: mientras no cambie la lista de dependencias, esta etapa no se repite.

**Etapa 2 — imagen final.** Vuelve a partir de `node:22-alpine`, copia los `node_modules` de la etapa anterior y el código. Agrega las etiquetas `LABEL`, que quedan visibles con `docker inspect`, y define el `HEALTHCHECK` que consulta `/api/health` cada 30 segundos.

Dos decisiones merecen mención. La primera: la imagen corre como el usuario `node`, que viene en la imagen base, no como `root`. Si alguien logra ejecutar código dentro del contenedor, no lo hace con privilegios de administrador. La segunda: el `HEALTHCHECK` le da a Docker una forma de saber si la aplicación está viva, y es lo que permite que `docker ps` muestre `healthy` en lugar de solo `Up`.

La imagen se construye con:

```
docker build -t banco-internacional-web:1.0.0 docker/webapp
```

_(insertar captura del build y de `docker image inspect`)_


---

## 5. La aplicación

Banco Internacional es una aplicación bancaria ficticia con dos roles. Un **cliente** consulta su cuenta y hace depósitos y retiros. Un **ejecutivo** administra clientes, préstamos, movimientos y condiciones de préstamo.

El acceso es simple a propósito: el login entrega usuario y contraseña, y la aplicación abre una sesión que dura lo que dure la visita. Esa simplicidad es parte del ejercicio, porque la sección 8 documenta lo que deja abierto.

### Roles y alcance

El servidor decide qué puede hacer cada rol antes de atender la petición. Cada grupo de rutas pasa por un control distinto:

```
app.use('/api', authRoutes);                                          // público
app.use('/api/cliente', requiereSesion, clienteRoutes);              // cualquier sesión
app.use('/api/ejecutivo', requiereRol('ejecutivo'), ejecutivoRoutes); // solo ejecutivo
```

Un cliente que intente llamar a una ruta de ejecutivo recibe una negativa del servidor, no de la interfaz. La comprobación ocurre en el backend, donde debe estar.

### Funcionalidad

**Cliente.** Ve una sola cuenta, con su saldo, sus movimientos y sus préstamos. Registra depósitos y retiros. La cuenta se consulta con el identificador que quedó en su sesión, así que la consulta siempre devuelve la suya: no hay forma de pedir la cuenta de otro por la interfaz.

| Ruta | Método | Qué hace |
|------|--------|----------|
| `/api/cliente/cuenta` | GET | Saldo y datos de la cuenta |
| `/api/cliente/movimientos` | GET | Historial de movimientos |
| `/api/cliente/prestamos` | GET | Préstamos vigentes |
| `/api/cliente/operacion` | POST | Depósito o retiro |

**Ejecutivo.** Tiene control completo sobre las entidades del banco: crear, leer, actualizar y eliminar clientes, préstamos y movimientos.

| Ruta | Método | Qué hace |
|------|--------|----------|
| `/api/ejecutivo/clientes` | GET, POST | Lista y crea clientes |
| `/api/ejecutivo/clientes/:id` | GET, PUT, DELETE | Consulta, actualiza y elimina |
| `/api/ejecutivo/prestamos` | GET, POST | Lista y crea préstamos |
| `/api/ejecutivo/prestamos/:id` | PUT, DELETE | Actualiza y elimina |
| `/api/ejecutivo/movimientos` | GET, POST | Lista y registra movimientos |

### Modelo de datos

Cinco tablas en el esquema `banco` de Oracle. Un cliente tiene una sola cuenta, relacionadas por clave foránea.

_(insertar diagrama del modelo: `clientes`, `cuentas`, `prestamos`, `movimientos`, `usuarios`)_

### Capturas

_(insertar capturas: landing, login, panel cliente y panel ejecutivo — `docs/evidencias/01-landing.png`, `02-login.png`, `05-panel-cliente.png`, `06-panel-ejecutivo.png`)_


---

## 6. Escaneo con OWASP ZAP

OWASP ZAP es un escáner de aplicaciones web: navega el sitio, observa las respuestas y, en el modo activo, intenta ataques contra los parámetros que encuentra. Corre en el contenedor `banco-zap` y ataca `http://webapp:8088` desde dentro de la red.

Se usaron dos escáneres. El primero es pasivo: rastrea y observa, sin atacar. El segundo es activo: además del rastreo, envía cargas diseñadas para provocar fallos.

### Escáner 1: pasivo

Rastreó la aplicación, encontró las páginas públicas y el formulario de login, y revisó las respuestas. Reportó **7 tipos de alerta** en 20 instancias.

| Riesgo | Alerta | Instancias | CWE |
|--------|--------|-----------:|-----|
| Media | Content Security Policy (CSP) Header Not Set | 4 | 693 |
| Media | Missing Anti-clickjacking Header | 4 | 1021 |
| Media | CSP: Failure to Define Directive with No Fallback | 2 | 693 |
| Baja | Server Leaks Information via "X-Powered-By" Header | 5 | 497 |
| Baja | X-Content-Type-Options Header Missing | 5 | 693 |
| Informativa | Information Disclosure - Sensitive Information in URL | 2 | 598 |
| Informativa | Authentication Request Identified | 1 | — |

El patrón es claro: la aplicación no envía las cabeceras de seguridad que los navegadores esperan. Sin `Content-Security-Policy`, no hay una política que limite qué scripts pueden ejecutarse. Sin `X-Frame-Options`, la página se puede incrustar en un iframe ajeno. Sin `X-Content-Type-Options`, el navegador puede interpretar un archivo como un tipo distinto del declarado. Ninguna es una brecha por sí sola, pero las tres juntas ensanchan la superficie.

Las dos alertas informativas apuntan a lo mismo desde otro ángulo: el servidor declara que corre Express, y las credenciales viajan en la URL del formulario, donde quedan registradas.

### Escáner 2: activo

Repitió el rastreo, procesó **797 solicitudes** y sumó una alerta: *User Agent Fuzzer*, que revela que la aplicación responde distinto ante ciertos agentes de usuario.

| Riesgo | Alerta | Instancias | CWE |
|--------|--------|-----------:|-----|
| Media | Content Security Policy (CSP) Header Not Set | 4 | 693 |
| Media | Missing Anti-clickjacking Header | 4 | 1021 |
| Media | CSP: Failure to Define Directive with No Fallback | 2 | 693 |
| Baja | Server Leaks Information via "X-Powered-By" Header | 5 | 497 |
| Baja | X-Content-Type-Options Header Missing | 5 | 693 |
| Informativa | User Agent Fuzzer | 5 | — |
| Informativa | Information Disclosure - Sensitive Information in URL | 2 | 598 |
| Informativa | Authentication Request Identified | 1 | — |

### El límite del escáner automático

El escaneo activo **no detectó la inyección SQL del inicio de sesión**, y esa vulnerabilidad existe: al enviar la contraseña `' OR '1'='1` la aplicación autentica como la primera fila de la tabla `usuarios`, sin conocer ninguna credencial.

```
$ curl -s -X POST http://127.0.0.1:8088/api/login \
    -H 'Content-Type: application/json' \
    -d '{"username":"ejecutivo","password":"'\'' OR '\''1'\''='\''1"}'
{"ok":true,"rol":"cliente","username":"mgonzalez"}
```

El resultado es doble. Por un lado, el atacante entra sin credenciales. Por otro, entra como un usuario distinto del que pidió: envió `ejecutivo` y la aplicación le respondió `cliente`. La inyección no solo salta la autenticación, sino que devuelve la primera fila que encuentra.

ZAP no la ve porque el login entrega las credenciales en el cuerpo de la petición como JSON, y el conjunto de reglas por defecto no ataca ese formato sin configuración adicional. Vale la pena subrayarlo: un escáner automático es tan bueno como las reglas que trae. Cubre lo que ya conoce y deja pasar lo que no. Por eso el hallazgo más grave del trabajo lo encontró la revisión manual, no la herramienta.

_(insertar capturas: reporte HTML de ZAP y la petición con la inyección — `scans/zap-full.html`)_


---

## 7. Escaneo con OpenVAS

_(pendiente: resultados del escaneo completo)_

---

## 8. Tabla de vulnerabilidades

_(pendiente: consolidado)_

---

## 9. Plan de mitigación

Cada hallazgo se corrige en la capa que le corresponde, no donde se detectó. Que ZAP reporte una cabecera ausente no significa que el problema esté en el escáner: está en la configuración del servidor. El plan completo está en `docs/mitigacion.md`; aquí va lo esencial y el orden en que conviene trabajarlo.

Las correcciones se agrupan en dos bloques. El primero resuelve el riesgo real; el segundo endurece la superficie.

**Bloque 1 — riesgo real.**

1. **Inyección SQL en el login.** La consulta se arma concatenando los datos del formulario. La corrección es usar enlaces en la consulta, como ya se hace en el resto de las rutas: `WHERE username = :usuario AND password_hash = :hash`. Es un cambio de una línea y elimina el problema de raíz: el motor trata los valores como datos, no como instrucciones.

2. **Contraseñas en texto plano.** Hoy la tabla `usuarios` guarda las contraseñas legibles. Cualquiera con acceso de lectura —o con la inyección del punto anterior— obtiene todas las credenciales de golpe. Se corrige guardando un hash con `bcrypt` y comparando con `bcrypt.compare` en el login.

3. **Sin límite de intentos.** Se puede probar contraseñas sin freno. Se corrige limitando los intentos por usuario y por origen con `express-rate-limit`, más un bloqueo temporal tras varios fallos.

4. **Cookie de sesión desprotegida.** La cookie se emite con `httpOnly: false` y el secreto de firma está escrito en el código. El primer valor permite que un script inyectado lea la sesión; el segundo permite falsificarla. Se corrige con `httpOnly: true`, `secure: true`, `sameSite: 'strict'` y el secreto en una variable de entorno.

**Bloque 2 — endurecimiento.**

5. **Cabeceras de seguridad.** Se agrega `helmet` al arranque de Express, que trae `Content-Security-Policy`, `X-Frame-Options` y `X-Content-Type-Options` con valores por defecto razonables.

6. **Fuga de información.** Se desactiva la cabecera `X-Powered-By` —`helmet` ya lo hace— y el formulario de login pasa de `GET` a `POST`, para que las credenciales no queden en la URL.

| # | Vulnerabilidad | Impacto | Esfuerzo | Prioridad |
|---|----------------|---------|----------|-----------|
| 1 | Inyección SQL en login | Alto | Bajo | Inmediata |
| 2 | Contraseñas en texto plano | Alto | Medio | Inmediata |
| 3 | Sin límite de intentos | Medio | Bajo | Alta |
| 4 | Cookie sin `httpOnly`/`secure` | Alto | Bajo | Alta |
| 5 | Cabeceras de seguridad ausentes | Medio | Bajo | Media |
| 6 | Fuga en cabecera y URL | Bajo | Bajo | Media |

Las cuatro primeras se corrigen en una misma sesión de trabajo y resuelven el grueso del riesgo. El punto 4 merece una nota: además de proteger la cookie, sostiene el aislamiento entre clientes. Hoy ese aislamiento depende de que el identificador de sesión sea de fiar; si la sesión se puede manipular, la frontera entre una cuenta y otra se cae. No es un problema aparte, es una consecuencia del punto 4.

---

## 10. Conclusiones

El trabajo montó una infraestructura de cuatro contenedores sobre una red propia y la analizó con dos herramientas. Las dos partes funcionan: los contenedores se comunican entre sí por nombre, la aplicación corre desde una imagen construida en el proyecto, y los dos escáneres alcanzan la aplicación desde dentro de la misma red.

Tres cosas quedaron claras al hacerlo.

**La primera: la red es lo que hace posible el resto.** Sin `soc-net`, la aplicación tendría que buscar la base por una dirección IP que cambia, y los escáneres no tendrían a quién apuntar. Los nombres de servicio convierten una configuración frágil en una estable.

**La segunda: una imagen propia no es solo empaquetar.** El Dockerfile de dos etapas, el usuario sin privilegios y el `HEALTHCHECK` son decisiones que afectan a la seguridad y a la operación. Que el contenedor corra como `node` y no como `root` no cambia nada mientras todo va bien, y lo cambia todo cuando algo va mal.

**La tercera, y la más importante: el escáner automático no encontró el fallo más grave.** ZAP reportó cabeceras ausentes y fugas de información, todas reales, todas de severidad media o baja. La inyección SQL del login, que permite entrar sin credenciales, no apareció en el reporte. La encontró la revisión manual del código. Esto no descalifica a ZAP: lo ubica. Un escáner prueba lo que sabe probar, y por eso se configura y se complementa, no se delega.

El plan de mitigación cierra los hallazgos en dos bloques. Las cuatro correcciones del primero son pequeñas y resuelven el grueso del riesgo. La lección que queda es que el orden importa más que la cantidad: arreglar la inyección y las contraseñas vale más que sumar veinte cabeceras.

---

## Referencias

Greenbone Networks. (2026). *Greenbone Management Protocol (GMP)*. https://greenbone.github.io/docs/latest/

OWASP Foundation. (2026). *OWASP ZAP*. https://www.zaproxy.org/docs/

Docker Inc. (2026). *Docker documentation*. https://docs.docker.com/

Oracle. (2026). *Node.js and Oracle Database*. https://node-oracledb.readthedocs.io/

OWASP Foundation. (2021). *OWASP Top 10:2021*. https://owasp.org/Top10/

