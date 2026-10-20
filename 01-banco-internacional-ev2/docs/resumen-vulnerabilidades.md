# Resumen de vulnerabilidades

Tabla consolidada de los hallazgos de las dos herramientas. Cada fila indica qué escáner la detectó y en qué contenedor.

Los reportes crudos están en `scans/`:

- `zap-baseline.json` y `zap-baseline.html` — escáner pasivo de ZAP.
- `zap-full.json` y `zap-full.html` — escáner activo de ZAP.
- `openvas-rapido.xml` — escáner de reconocimiento de OpenVAS.
- `openvas-completo.xml` — escáner completo de OpenVAS.

## Hallazgos de OWASP ZAP

ZAP corrió dos escáneres sobre la aplicación, en `http://webapp:8088` desde dentro de la red `soc-net`. Se manejó por su API (rastreo, escaneo activo y exportación del reporte) porque los scripts `zap-baseline.py` y `zap-full-scan.py` levantan su propia instancia de ZAP y chocan con el demonio que ya corre en el contenedor.

### Escáner 1: pasivo (`zap-baseline.json`)

Rastrea la aplicación y revisa las respuestas sin lanzar ataques. Detectó **7 tipos de alerta** en 20 instancias.

| Riesgo | Alerta | Instancias | CWE |
|--------|--------|-----------:|-----|
| Media | Content Security Policy (CSP) Header Not Set | 4 | 693 |
| Media | Missing Anti-clickjacking Header | 4 | 1021 |
| Media | CSP: Failure to Define Directive with No Fallback | 2 | 693 |
| Baja | Server Leaks Information via "X-Powered-By" Header | 5 | 497 |
| Baja | X-Content-Type-Options Header Missing | 5 | 693 |
| Informativa | Information Disclosure - Sensitive Information in URL | 2 | 598 |
| Informativa | Authentication Request Identified | 1 | — |

### Escáner 2: activo (`zap-full.json`)

Repite el rastreo y agrega un escaneo activo: envía cargas de ataque para confirmar las vulnerabilidades. Procesó 797 solicitudes y sumó una alerta a las del escáner pasivo.

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

### Lo que el escáner automático no vio

El escaneo activo **no reportó la inyección SQL del inicio de sesión**, y esa vulnerabilidad existe: se comprueba enviando la contraseña `' OR '1'='1`, que autentica como la primera fila de la tabla sin conocer ninguna credencial.

ZAP no la detecta porque el formulario de login entrega las credenciales como JSON y el conjunto de reglas por defecto no ataca ese formato sin configuración adicional. Es un buen recordatorio de que un escáner automático no reemplaza la revisión manual: cubre lo que ya conoce y deja pasar lo que no.


## Hallazgos de OpenVAS

OpenVAS corre dos escáneres contra `webapp` desde dentro de la red `soc-net`. Se maneja por GMP (Greenbone Management Protocol) sobre el socket interno de `gvmd`, con `gvm-cli` ejecutado como el usuario `gvm`. El reconocimiento de la aplicación lo hace OpenVAS a nivel de red y servicio: no inspecciona el código, sino que identifica qué está expuesto y lo cruza con el catálogo de vulnerabilidades conocidas.

### Escáner 1: reconocimiento (`openvas-rapido.xml`)

Perfil **Discovery** sobre los 5836 puertos TCP asignados por IANA. Duró 72 segundos y devolvió 8 hallazgos.

| Nivel | Sev. | Puerto | Hallazgo |
|-------|-----:|--------|----------|
| Baja | 2.1 | general/icmp | ICMP Timestamp Reply Information Disclosure |
| Informativa | 0.0 | 8088/tcp | Express Detection (HTTP) |
| Informativa | 0.0 | 8088/tcp | Services |
| Informativa | 0.0 | general/tcp | Hostname Determination Reporting |
| Informativa | 0.0 | general/tcp | OS Detection Consolidation and Reporting |
| Informativa | 0.0 | general/tcp | Traceroute |

El escáner reconoce el servicio: encuentra el puerto 8088 abierto y lo identifica como Express sobre HTTP. Eso ya es información útil desde el punto de vista del atacante, porque acota la superficie y nombra la tecnología. Los demás hallazgos son registros de cómo OpenVAS llegó al objetivo.

### Escáner 2: completo (`openvas-completo.xml`)

Perfil **Full and fast** sobre todos los TCP y los 100 UDP más comunes de Nmap. Duró 6 minutos 11 segundos y devolvió 10 hallazgos. Aquí sí aparece lo que el reconocimiento solo insinuaba.

| Nivel | Sev. | Puerto | Hallazgo |
|-------|-----:|--------|----------|
| Media | 4.8 | 8088/tcp | Cleartext Transmission of Sensitive Information via HTTP |
| Informativa | 0.0 | 8088/tcp | Express Detection (HTTP) |
| Informativa | 0.0 | 8088/tcp | Allowed HTTP Methods Enumeration |
| Informativa | 0.0 | 8088/tcp | HTTP Security Headers Detection |
| Informativa | 0.0 | general/CPE-T | CPE Inventory |
| Informativa | 0.0 | general/tcp | Hostname Determination Reporting |

El hallazgo de severidad media es el que importa: OpenVAS identificó el campo `password` del formulario de login y confirmó que viaja por HTTP sin cifrar. Cita las dos rutas del formulario, `/Login` y `/login`, y señala el campo por nombre. Es la misma debilidad que ZAP reporta como *Sensitive Information in URL*, vista desde el otro lado: ZAP la ve en la URL, OpenVAS la ve en el transporte.

Los demás hallazgos confirman el reconocimiento. OpenVAS enumera los métodos HTTP que acepta el servidor y detecta las cabeceras de seguridad que faltan, que coincide con lo que ZAP reporta por su cuenta. Que dos herramientas independientes lleguen al mismo punto refuerza el hallazgo.

## Tabla consolidada

Los hallazgos de las dos herramientas, ordenados por severidad. La columna *Detectado por* distingue lo que encontró un escáner de lo que encontró la revisión manual.

| # | Vulnerabilidad | Severidad | Detectado por | Contenedor |
|---|----------------|-----------|---------------|------------|
| 1 | Inyección SQL en el login (salta autenticación) | Alta | Revisión manual | webapp |
| 2 | Contraseñas en texto plano en la tabla `usuarios` | Alta | Revisión manual | oracle |
| 3 | Credenciales enviadas por HTTP sin cifrar | Media | OpenVAS (4.8) y ZAP | webapp |
| 4 | Credenciales en la URL del formulario (`GET`) | Media | ZAP | webapp |
| 5 | Cookie de sesión sin `httpOnly` ni `secure` | Media | Revisión manual | webapp |
| 6 | Sin límite de intentos en el login | Media | Revisión manual | webapp |
| 7 | `Content-Security-Policy` ausente | Media | ZAP (CWE 693) | webapp |
| 8 | `X-Frame-Options` ausente (clickjacking) | Media | ZAP (CWE 1021) | webapp |
| 9 | Secreto de sesión escrito en el código | Media | Revisión manual | webapp |
| 10 | ICMP Timestamp Reply Information Disclosure | Baja | OpenVAS (2.1) | webapp |
| 11 | `X-Content-Type-Options` ausente | Baja | ZAP (CWE 693) | webapp |
| 12 | Cabecera `X-Powered-By` revela Express | Baja | ZAP (CWE 497) | webapp |
| 13 | Portafolio de servicios expuesto (Express en 8088) | Informativa | OpenVAS | webapp |

Trece hallazgos en total. Los escáneres automáticos, entre los dos y con cuatro corridas, detectaron ocho: cinco solo ZAP, dos solo OpenVAS y uno los dos. La revisión manual del código aportó los cinco restantes. La inyección SQL, que es la más grave, no aparece en ningún reporte de escáner.

La tabla muestra además la ventaja de usar dos herramientas. ZAP mira la capa web y encuentra las cabeceras y la URL. OpenVAS mira el transporte y el servicio, y encuentra el HTTP sin cifrar. Las dos coinciden en dos puntos, y esa coincidencia vale más que cualquiera de los dos por separado.

