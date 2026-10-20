# Banco Internacional — EV-2

Infraestructura de 4 contenedores Docker para el análisis de vulnerabilidades de una aplicación web bancaria, como parte de la Evaluación 2 de Gestión de Seguridad de la Información.

## Objetivo

- Comunicar 4 contenedores en una red Docker (`soc-net`).
- Crear una imagen propia para la aplicación web (Dockerfile).
- Analizar vulnerabilidades con dos herramientas: OWASP ZAP y OpenVAS.

## Arquitectura

| Contenedor | Puerto | Rol |
|------------|--------|-----|
| `oracle` | 1521 | Base de datos Oracle (esquema `banco`) |
| `webapp` | 8088 | Aplicación web bancaria (imagen propia) |
| `zap` | 8080 | Escáner de vulnerabilidades web |
| `openvas` | 9392 | Escáner de vulnerabilidades de infraestructura |

Red: `soc-net`. Diagrama: [`U2ES2.html`](U2ES2.html).

## Aplicación

Banco ficticio **Banco Internacional** con dos roles:

- **Cliente**: consulta su saldo, movimientos y préstamos; realiza depósitos y retiros.
- **Ejecutivo**: CRUD completo sobre clientes, préstamos y movimientos.

Vulnerabilidades intencionales, documentadas como "estado antes de mitigar".

## Estructura

```
01-banco-internacional-ev2/
├── docker/          # Dockerfiles y compose (raíz + uno por contenedor)
├── docs/            # informe, tabla de vulnerabilidades, mitigación, evidencias
├── scans/           # reportes de escáneres
├── scripts/         # automatización de escáneres
└── U2ES2.html       # diagrama de la arquitectura
```

## Estado

En desarrollo. Ver fases en el plan de ejecución.
