# Banco Internacional EV-2

Cuatro contenedores Docker que levantan una aplicación bancaria ficticia y dos escáneres de vulnerabilidades. Es la Evaluación 2 de Gestión de Seguridad de la Información.

## Qué hay que demostrar

La evaluación pide tres cosas: que los contenedores se comuniquen entre sí, una imagen propia construida con Dockerfile para la aplicación web, y un análisis de vulnerabilidades hecho con dos herramientas distintas. Cada herramienta entrega dos escáneres y dos reportes.

## Los cuatro contenedores

Dos sostienen el servicio y dos lo analizan.

| Contenedor | Puerto | Rol |
|------------|--------|-----|
| oracle | 1521 | Base de datos Oracle, esquema `banco` |
| webapp | 8088 | Aplicación web bancaria, imagen propia |
| zap | 8080 | Escáner de vulnerabilidades web |
| openvas | 9392 | Escáner de vulnerabilidades de infraestructura |

Los cuatro están conectados a la red `soc-net`, así que se encuentran por el nombre del servicio y no por una dirección IP. La aplicación usa la cadena `oracle:1521/FREEPDB1`, y los escáneres llaman a `http://webapp:8088`. El diagrama de la topología es `U2ES2.html`.

## La aplicación

Banco Internacional tiene dos tipos de usuario. El cliente entra y ve su saldo, sus movimientos y sus préstamos, y puede depositar o retirar. El ejecutivo ve a todos los clientes y maneja clientes, préstamos y movimientos de principio a fin.

Las credenciales de prueba están en `docker/oracle/init/`, que es donde se cargan los datos iniciales.

La aplicación guarda a propósito varias vulnerabilidades, porque el trabajo consiste en encontrarlas y proponer cómo corregirlas. Cada una queda anotada en el informe como estado inicial, antes de la mitigación.

## Organización

```
docker/          Dockerfile y archivos compose, uno por contenedor más el de la raíz
  oracle/        base de datos y datos iniciales
  webapp/        aplicación e imagen propia
  zap/           escáner web
  openvas/       escáner de infraestructura
docs/            informe, tabla de vulnerabilidades, plan de mitigación y capturas
  informe/       informe en formato APA 6
  evidencias/    capturas de pantalla y registros de verificación
scans/           reportes que producen los escáneres
scripts/         automatización de los escaneos
```

## Cómo levantarlo

```bash
docker compose -f docker/docker-compose.yml up -d
```

La primera vez, Oracle tarda alrededor de 40 segundos en quedar listo. Los cuatro contenedores aparecen como `healthy` cuando todo está en marcha:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

Los escaneos se lanzan por separado:

```bash
./scripts/run-zap-scans.sh ambos          # pasivo y activo
./scripts/run-openvas-scans.sh completo   # reconocimiento y completo
```

Los reportes quedan en `scans/`. Para leerlos en tabla, `scripts/resumir-zap.py` y `scripts/resumir-openvas.py`.

## Los escaneos

ZAP ataca la capa web: rastrea el sitio y, en modo activo, prueba los parámetros que encuentra. OpenVAS mira la infraestructura: qué puertos están abiertos, qué servicios corren y qué vulnerabilidades conocidas les corresponden.

Los cuatro reportes están en `scans/`:

| Reporte | Escáner |
|---------|---------|
| `zap-baseline.json` / `.html` | ZAP pasivo |
| `zap-full.json` / `.html` | ZAP activo |
| `openvas-rapido.xml` | OpenVAS reconocimiento |
| `openvas-completo.xml` | OpenVAS completo |

El hallazgo más grave del trabajo no salió de ninguno de los cuatro. La inyección SQL del login la encontró la revisión manual del código. ZAP no la reporta porque el login envía las credenciales como JSON y el conjunto de reglas por defecto no ataca ese formato. Está documentado en `docs/resumen-vulnerabilidades.md`.

## Documentación

- `docs/informe/informe.md`: el informe completo.
- `docs/resumen-vulnerabilidades.md`: la tabla consolidada de hallazgos.
- `docs/mitigacion.md`: cómo se corrige cada uno.
- `docs/demo-y-traslado.md`: cómo llevar la infraestructura a otro equipo y qué mostrar en la demo.

## Entorno

Desarrollado con Docker Desktop 29.9.1 sobre Fedora. La aplicación corre en Node.js 22 con Express y `oracledb` en modo thin, sin cliente de Oracle.
