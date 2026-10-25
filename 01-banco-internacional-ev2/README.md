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
├── scripts/           # run-zap-scans.sh, run-openvas-scans.sh, resumir-*.py
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

## Escaneos

```bash
./scripts/run-zap-scans.sh ambos
./scripts/run-openvas-scans.sh completo
```

Resumir resultados:
```bash
python3 scripts/resumir-zap.py
python3 scripts/resumir-openvas.py
```

## Documentación

- [Informe final](docs/informe/Informe-EV2.pdf)
- [Resumen de vulnerabilidades](docs/resumen-vulnerabilidades.md)
- [Plan de mitigación](docs/mitigacion.md)
- [Diagrama entidad-relación](docs/diagramas/entidad-relacion.md)
- [Diagrama de topología](U2ES2.html)
