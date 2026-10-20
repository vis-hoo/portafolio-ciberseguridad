#!/usr/bin/env bash
# ============================================================
# Banco Internacional EV-2 - escaneos con OpenVAS (Greenbone)
#
# OpenVAS no acepta ordenes por HTTP simple: se maneja con GMP
# (Greenbone Management Protocol) sobre el socket interno de
# gvmd. El cliente es gvm-cli, que debe ejecutarse como el
# usuario gvm dentro del contenedor.
#
#   Escaner 1 - rapido  : perfil "Discovery" (Fast and shallow).
#                         Reconoce servicios y puertos.
#   Escaner 2 - completo: perfil "Full and fast". Prueba cada
#                         servicio contra el feed de vulnerabilidades.
#
# Uso:  ./scripts/run-openvas-scans.sh [rapido|completo|ambos]
# ============================================================

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SALIDA="$RAIZ/scans"
CONTENEDOR="banco-openvas"
SOCKET="/run/gvmd/gvmd.sock"
USUARIO="admin"
CLAVE="admin"

# Los dos objetivos del escaneo: la aplicacion y la base de datos.
OBJETIVO_WEB="webapp"
OBJETIVO_DB="oracle"

modo="${1:-ambos}"

mkdir -p "$SALIDA"

# Envia una orden GMP y devuelve la respuesta XML.
gmp() {
  docker exec -u gvm "$CONTENEDOR" gvm-cli \
    --socketpath "$SOCKET" --protocol GMP \
    --gmp-username "$USUARIO" --gmp-password "$CLAVE" \
    socket --xml "$1" 2>/dev/null
}

# Extrae el primer valor de una etiqueta del XML.
extraer() {
  python3 -c '
import sys, re
texto = sys.stdin.read()
etiqueta = sys.argv[1]
m = re.search(r"<%s>([^<]*)</%s>" % (etiqueta, etiqueta), texto)
print(m.group(1) if m else "")
' "$1"
}

# Obtiene el UUID del perfil de escaneo por su nombre.
uuid_perfil() {
  gmp "<get_configs/>" | python3 -c '
import sys, re
texto = sys.stdin.read()
nombre = sys.argv[1]
for bloque in re.findall(r"<config id=\"([^\"]+)\">(.*?)</config>", texto, re.S):
    if "<name>%s</name>" % nombre in bloque[1]:
        print(bloque[0]); break
' "$1"
}

comprobar_openvas() {
  if ! docker ps --format '{{.Names}}' | grep -qx "$CONTENEDOR"; then
    echo "ERROR: el contenedor $CONTENEDOR no esta en ejecucion."
    exit 1
  fi
  if ! gmp "<get_version/>" | grep -q "<version>"; then
    echo "ERROR: gvmd no responde por el socket $SOCKET."
    echo "En el primer arranque, OpenVAS debe restaurar la base y"
    echo "sincronizar el feed: revisa 'docker logs $CONTENEDOR'."
    exit 1
  fi
  echo "OpenVAS operativo: $(gmp '<get_version/>' | extraer version)"
}

# Crea un objetivo de escaneo y devuelve su UUID.
crear_objetivo() {
  local nombre="$1" host="$2"
  local existente
  existente="$(gmp "<get_targets/>" | python3 -c '
import sys, re
texto = sys.stdin.read()
nombre = sys.argv[1]
for bloque in re.findall(r"<target id=\"([^\"]+)\">(.*?)</target>", texto, re.S):
    if "<name>%s</name>" % nombre in bloque[1]:
        print(bloque[0]); break
' "$nombre")"

  if [ -n "$existente" ]; then
    echo "$existente"
    return
  fi

  gmp "<create_target><name>$nombre</name><hosts>$host</hosts></create_target>" | extraer id
}

# Lanza una tarea de escaneo y espera a que termine.
# Devuelve el UUID del reporte.
lanzar_y_esperar() {
  local nombre="$1" host="$2" perfil="$3" etiqueta="$4"

  local objetivo perfil_id
  objetivo="$(crear_objetivo "$nombre" "$host")"
  perfil_id="$(uuid_perfil "$perfil")"

  if [ -z "$perfil_id" ]; then
    echo "ERROR: no se encontro el perfil '$perfil'."; exit 1
  fi

  echo "  Objetivo: $nombre ($host)"
  echo "  Perfil:   $perfil"

  local tarea
  tarea="$(gmp "<create_task><name>$nombre</name><target id=\"$objetivo\"/><config id=\"$perfil_id\"/></create_task>" | extraer id)"

  echo "  Tarea creada: $tarea"
  echo "  Lanzando escaneo..."
  local reporte
  reporte="$(gmp "<start_task task_id=\"$tarea\"/>" | extraer report_id)"

  # Espera: el escaneo completo puede tardar bastante.
  local inicio=$SECONDS limite="${5:-10800}"
  while true; do
    local estado
    estado="$(gmp "<get_tasks task_id=\"$tarea\"/>" | python3 -c '
import sys, re
t = sys.stdin.read()
m = re.search(r"<status>([^<]*)</status>", t)
print(m.group(1) if m else "?")
')"
    echo "  Estado: $estado (${SECONDS}s)"
    case "$estado" in
      Done) break ;;
      Stopped|Interrupted|*Error*) echo "  El escaneo termino con estado $estado"; break ;;
    esac
    if [ $((SECONDS - inicio)) -gt "$limite" ]; then
      echo "  Tiempo agotado; se usa el reporte parcial."
      break
    fi
    sleep 30
  done

  echo "$reporte"
}

esperar_reporte() {
  # Algunas versiones necesitan unos segundos para consolidar el reporte.
  sleep 10
}

comprobar_openvas

case "$modo" in
  rapido|completo|ambos) ;;
  *) echo "Uso: $0 [rapido|completo|ambos]"; exit 1 ;;
esac

if [ "$modo" = "rapido" ] || [ "$modo" = "ambos" ]; then
  echo
  echo "=== Escaner 1: rapido (Discovery) ==="
  r1="$(lanzar_y_esperar "EV2-Rapido-Web" "$OBJETIVO_WEB" "Discovery" "rapido" | tail -1)"
  esperar_reporte
  gmp "<get_reports report_id=\"$r1\" format_id=\"a994b278-1f62-11e1-96ac-406186ea4fc5\"/>" > "$SALIDA/openvas-rapido.xml"
  echo "  Reporte 1 escrito: scans/openvas-rapido.xml"
fi

if [ "$modo" = "completo" ] || [ "$modo" = "ambos" ]; then
  echo
  echo "=== Escaner 2: completo (Full and fast) ==="
  r2="$(lanzar_y_esperar "EV2-Completo-Web" "$OBJETIVO_WEB" "Full and fast" "completo" | tail -1)"
  esperar_reporte
  gmp "<get_reports report_id=\"$r2\" format_id=\"a994b278-1f62-11e1-96ac-406186ea4fc5\"/>" > "$SALIDA/openvas-completo.xml"
  echo "  Reporte 2 escrito: scans/openvas-completo.xml"
fi

echo
echo "Escaneos terminados. Reportes en $SALIDA"
