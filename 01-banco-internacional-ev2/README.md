# Banco Internacional EV-2

Cuatro contenedores Docker que levantan una aplicación bancaria ficticia y dos escáneres de vulnerabilidades. Es el trabajo de la Evaluación 2 de Gestión de Seguridad de la Información.

## Qué resuelve

La evaluación pide tres cosas: que los contenedores se comuniquen entre sí, una imagen propia construida con Dockerfile para la aplicación web, y un análisis de vulnerabilidades hecho con dos herramientas distintas.

## Arquitectura

Tres de los cuatro contenedores son la infraestructura y el cuarto es una herramienta de escaneo por cada tipo de análisis.

| Contenedor | Puerto | Rol |
|------------|--------|-----|
| oracle | 1521 | Base de datos Oracle, esquema `banco` |
| webapp | 8088 | Aplicación web bancaria, imagen propia |
| zap | 8080 | Escáner de vulnerabilidades web |
| openvas | 9392 | Escáner de vulnerabilidades de infraestructura |

Los cuatro viven en la red `soc-net`. El diagrama de la topología está en `U2ES2.html`.

## La aplicación

Banco Internacional es un banco ficticio con dos tipos de usuario. El cliente entra y ve su saldo, sus movimientos y sus préstamos, y puede depositar o retirar. El ejecutivo ve a todos los clientes y puede crear, editar y borrar clientes, préstamos y movimientos.

La aplicación guarda a propósito varias vulnerabilidades, porque el objetivo de la evaluación es encontrarlas y proponer cómo corregirlas. Cada una queda registrada en el informe como estado inicial, antes de la mitigación.

## Cómo está organizado el proyecto

`docker/` guarda los Dockerfile y los archivos compose, con uno por contenedor más uno en la raíz que levanta todo. `docs/` reúne el informe, la tabla de vulnerabilidades, el plan de mitigación y las capturas de pantalla. `scans/` contiene los reportes que producen los escáneres. `scripts/` tiene la automatización de los escaneos.

## Estado

En desarrollo.
