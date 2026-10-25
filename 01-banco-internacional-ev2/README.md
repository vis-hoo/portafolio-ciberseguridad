# Banco Internacional - EV2

Infraestructura con cuatro contenedores Docker sobre la red `soc-net`: Oracle Free (base de datos), una aplicación web bancaria con imagen propia (Node.js/Express), OWASP ZAP y Greenbone/OpenVAS. Se realizan escaneos pasivo/activo con ZAP y reconocimiento/completo con OpenVAS, se consolidan hallazgos y se documenta un plan de mitigación.

## Estructura del repositorio

```text
01-banco-internacional-ev2/
├── docker/
│   ├── docker-compose.yml   # Definición única de los 4 servicios
│   ├── oracle/        # Init SQL, esquema banco
│   └── webapp/        # App Node.js/Express + Dockerfile
├── docs/
│   ├── informe/       # Informe EV2 (PDF)
│   ├── evidencias/    # Capturas y verificaciones
│   ├── diagramas/     # Diagramas (topología/ER)
│   ├── resumen-vulnerabilidades.md
│   ├── mitigacion.md
├── scans/             # Reportes ZAP (JSON/HTML) y OpenVAS (XML)
├── scripts/           # run-zap-scans.sh/.ps1, run-openvas-scans.sh, resumir-*.py
└── U2ES2.html         # Diagrama de topología
```

## Levantar el entorno

```bash
docker compose -f docker/docker-compose.yml up -d
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

El archivo `docker/docker-compose.yml` es autocontenido: define los cuatro servicios, los volúmenes y la red, sin `include:`. El servicio `webapp` declara `pull_policy: build`, así que Compose construye la imagen propia en lugar de buscarla en un registro.

La primera vez se descargan las imágenes base (Oracle, ZAP y OpenVAS suman varios GB) y la construcción de la aplicación toma unos minutos.

Accesos:
- Aplicación web: http://localhost:8088
- OWASP ZAP: http://localhost:8080
- OpenVAS/GVM: http://localhost:9392

## Comprobar que responde

En Windows, PowerShell no tiene `curl` real: `curl` es un alias de `Invoke-WebRequest`, que no entiende `-X` ni `-d`. Para probar la aplicación desde la terminal se usa `Invoke-RestMethod`.

```powershell
$cuerpo = @{ username = 'mgonzalez'; password = 'maria2026' } | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:8088/api/login -Method Post `
  -ContentType 'application/json' -Body $cuerpo -SessionVariable sesion

Invoke-RestMethod -Uri http://localhost:8088/api/cliente/cuenta -WebSession $sesion
```

`-SessionVariable` guarda la cookie de sesión en memoria. La segunda llamada necesita esa cookie; un archivo como `/tmp/c.txt` no existe en Windows.

## Escaneos

```bash
./scripts/run-zap-scans.sh ambos
./scripts/run-openvas-scans.sh completo
```

En Windows los scripts de bash no corren. El equivalente para ZAP es `run-zap-scans.ps1`, con los mismos modos `baseline`, `full` y `ambos`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-zap-scans.ps1 baseline
```

`baseline` termina en minutos y basta para una demostración. `full` ejecuta el escaneo activo y puede tardar entre 20 y 60 minutos.

Resumir resultados:
```bash
python3 scripts/resumir-zap.py
python3 scripts/resumir-openvas.py
```

### OpenVAS recién instalado

El volumen `openvas-data` guarda todo el estado de Greenbone. En una instalación nueva ese volumen está vacío, así que la interfaz muestra 0 tareas y 0 reportes aunque el contenedor esté sano. Los XML de `scans/` provienen del equipo donde se hizo el trabajo original.

Para generar un escaneo nuevo, en `http://localhost:9392` con `admin` / `admin`:

1. En `Configuration > Targets`, crear un target con el host `webapp`, que es el nombre del contenedor en la red `soc-net`.
2. En `Scans > Tasks`, crear una tarea con ese target y el perfil `Discovery`.
3. Ejecutar la tarea. El reporte aparece en `Scans > Reports` cuando termina.

OpenVAS no alcanza `localhost:8088`: escanea el servicio por su nombre dentro de la red.

## Documentación

- [Informe final](docs/informe/Informe-EV2.pdf)
- [Resumen de vulnerabilidades](docs/resumen-vulnerabilidades.md)
- [Plan de mitigación](docs/mitigacion.md)
- [Diagrama entidad-relación](docs/diagramas/entidad-relacion.md)
- [Diagrama de topología](U2ES2.html)
