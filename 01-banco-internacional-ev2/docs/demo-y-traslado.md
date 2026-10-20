# Guía de demo y traslado al notebook

El proyecto se desarrolló en el PC de escritorio y se presenta en un notebook. Esta guía cubre las dos cosas: cómo mover la infraestructura y cómo mostrarla en 2 a 5 minutos.

## Por qué hay que trasladar algo

El notebook podría bajar las imágenes por su cuenta, pero son grandes y la descarga depende de la red del día. Más seguro es llevarlas.

| Imagen | Tamaño |
|--------|-------:|
| `immauss/openvas:latest` | 7,2 GB |
| `zaproxy/zap-stable:latest` | 3,76 GB |
| `gvenzl/oracle-free:23-slim` | 2,84 GB |
| `banco-internacional-web:1.0.0` | 261 MB |

En total, alrededor de 14 GB. La imagen de la aplicación es la única que no se puede volver a bajar, porque es propia: se construye en el proyecto, pero conviene trasladarla igual para no depender del build en plena presentación.

## Opción A: traslado por archivo (recomendada)

Se exportan las cuatro imágenes a archivos y se copian al notebook.

```bash
# En el PC de escritorio
mkdir -p /tmp/ev2-imagenes
docker save gvenzl/oracle-free:23-slim | gzip > /tmp/ev2-imagenes/oracle.tgz
docker save banco-internacional-web:1.0.0 | gzip > /tmp/ev2-imagenes/webapp.tgz
docker save zaproxy/zap-stable:latest | gzip > /tmp/ev2-imagenes/zap.tgz
docker save immauss/openvas:latest | gzip > /tmp/ev2-imagenes/openvas.tgz
```

Los cuatro archivos van a una unidad USB o se copian por la red. En el notebook:

```bash
# En el notebook
docker load < oracle.tgz
docker load < webapp.tgz
docker load < zap.tgz
docker load < openvas.tgz
```

Con las imágenes cargadas, el proyecto se levanta con un comando desde la copia del repositorio:

```bash
git clone https://github.com/vis-hoo/portafolio-ciberseguridad.git
cd portafolio-ciberseguridad/01-banco-internacional-ev2
docker compose -f docker/docker-compose.yml up -d
```

**Antes de salir de casa, en el notebook:** levantar la infraestructura una vez y dejarla inicializada. Oracle tarda alrededor de 40 segundos en quedar `healthy` la primera vez, y OpenVAS necesita procesar su feed. Si el volumen ya existe, los arranques siguientes son mucho más rápidos. Lo más seguro es llevar también los volúmenes:

```bash
# En el PC de escritorio: respaldar los volumenes
docker run --rm -v docker_oracle-data:/datos -v /tmp/ev2-imagenes:/destino alpine \
  tar czf /destino/oracle-data.tgz -C /datos .
docker run --rm -v docker_openvas-data:/datos -v /tmp/ev2-imagenes:/destino alpine \
  tar czf /destino/openvas-data.tgz -C /datos .

# En el notebook: restaurarlos antes del primer arranque
docker volume create docker_oracle-data
docker volume create docker_openvas-data
docker run --rm -v docker_oracle-data:/datos -v /tmp/ev2-imagenes:/origen alpine \
  tar xzf /origen/oracle-data.tgz -C /datos
docker run --rm -v docker_openvas-data:/datos -v /tmp/ev2-imagenes:/origen alpine \
  tar xzf /origen/openvas-data.tgz -C /datos
```

## Opción B: build en el notebook

Si se prefiere no trasladar archivos, la única imagen que hay que construir es la de la aplicación. Las otras tres se bajan con `docker compose pull`. Funciona bien si el notebook tiene buena conexión.

```bash
docker compose -f docker/docker-compose.yml pull
docker build -t banco-internacional-web:1.0.0 docker/webapp
docker compose -f docker/docker-compose.yml up -d
```

## Verificar que quedó bien

Antes de la presentación, un chequeo rápido:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

Los cuatro contenedores deben aparecer como `(healthy)`. Si alguno no lo está, revisar su registro:

```bash
docker logs banco-oracle --tail 20
docker logs banco-openvas --tail 20
```

## Guion de la demo (2 a 5 minutos)

La demo tiene que mostrar tres cosas: los contenedores conectados, la aplicación funcionando y los escáneres. El guion va en ese orden.

### 0:00 — La infraestructura (40 segundos)

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

Los cuatro contenedores con sus puertos. Decir que son dos de servicio y dos de análisis, y que la imagen de la aplicación es propia.

```bash
docker network inspect soc-net --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{"\n"}}{{end}}'
```

Mostrar los cuatro en la misma red. Es la respuesta al requisito de comunicación entre contenedores.

### 0:30 — La aplicación (1 minuto)

Abrir `http://localhost:8088` en el navegador: la landing. Entrar como cliente (`mgonzalez` / `maria2026`) y mostrar el saldo, los movimientos y los préstamos. Registrar un depósito y mostrar que el saldo cambia.

Salir y entrar como ejecutivo (`ejecutivo` / `gerencia2026`). Mostrar la lista de clientes y editar uno. Es la parte que demuestra el CRUD completo.

### 1:30 — La vulnerabilidad (45 segundos)

Este es el momento que conviene no saltarse, porque conecta la aplicación con el análisis.

```bash
curl -s -X POST http://localhost:8088/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"ejecutivo","password":"'\'' OR '\''1'\''='\''1"}'
```

La respuesta autentica sin credenciales. Explicar que además devuelve un usuario distinto del pedido. Es el hallazgo que ningún escáner encontró.

### 2:15 — Los escáneres (1 minuto 30)

ZAP: abrir el reporte `scans/zap-full.html` en el navegador. Mostrar la tabla de alertas: las cabeceras ausentes y las fugas de información. Mencionar que corrió dos escáneres, uno pasivo y uno activo.

OpenVAS: abrir `http://localhost:9392` y entrar con `admin` / `admin`. Mostrar el reporte del escáner de reconocimiento. Mencionar que encontró el servicio Express y el puerto 8088.

### 3:45 — Cierre (30 segundos)

Los reportes están en `scans/`, la tabla consolidada en `docs/resumen-vulnerabilidades.md` y el plan de mitigación en `docs/mitigacion.md`. Cerrar con la idea central: el escáner automático cubre lo que sabe cubrir, y el hallazgo más grave apareció en la revisión manual.

## Ensayo

Vale la pena ensayar el guion una vez completa, cronometrado. Los puntos que suelen fallar son los tiempos de arranque: si los contenedores no están levantados antes de empezar, la espera se come la demo. Dejarlos corriendo y verificar `docker ps` justo antes.
