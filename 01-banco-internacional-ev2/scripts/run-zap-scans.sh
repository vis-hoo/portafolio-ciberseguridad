#!/usr/bin/env bash
# ============================================================
# Banco Internacional EV-2 - escaneos con OWASP ZAP
#
# ZAP corre como demonio dentro de su contenedor y expone su API
# en el puerto 8080. Estos escaneos se manejan por API en vez de
# con los scripts zap-baseline.py / zap-full-scan.py, porque esos
# scripts levantan su propia instancia de ZAP y chocan con el
# demonio que ya esta corriendo en el contenedor.
#
#   Escaner 1 - baseline : rastreo (spider) + reglas pasivas. Rapido.
#   Escaner 2 - full     : rastreo + escaneo activo completo. Lento.
#
# Uso:  ./scripts/run-zap-scans.sh [baseline|full|ambos]
# ============================================================

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SALIDA="$RAIZ/scans"
API="http://127.0.0.1:8080"
OBJETIVO="http://webapp:8088"

modo="${1:-ambos}"

mkdir -p "$SALIDA"

# Espera a que una clave del API llegue a 100 por ciento.
esperar_progreso() {
  local clave="$1" etiqueta="$2" limite="${3:-3600}"
  local inicio=$SECONDS
  while true; do
    local valor
    valor="$(curl -s "$API/JSON/$clave" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("status",0))')"
    echo "  $etiqueta: ${valor}%"
    if [ "$valor" -ge 100 ]; then break; fi
    if [ $((SECONDS - inicio)) -gt "$limite" ]; then
      echo "  Tiempo agotado esperando $etiqueta"; break
    fi
    sleep 10
  done
}

# Espera a que el demonio este operativo.
esperar_zap() {
  local inicio=$SECONDS
  while true; do
    if curl -sf "$API/JSON/core/view/version/" >/dev/null 2>&1; then return 0; fi
    if [ $((SECONDS - inicio)) -gt 120 ]; then
      echo "ERROR: ZAP no responde en $API"; exit 1
    fi
    sleep 5
  done
}

# Exporta un reporte en JSON y en HTML.
exportar() {
  local nombre="$1"
  curl -s "$API/OTHER/core/other/jsonreport/" > "$SALIDA/$nombre.json"
  curl -s "$API/OTHER/core/other/htmlreport/" > "$SALIDA/$nombre.html"
  echo "  Reporte escrito: scans/$nombre.json y scans/$nombre.html"
}

# ------------------------------------------------------------
# Escaner 1: baseline
# Rastreo pasivo de la aplicacion y revision de las reglas
# pasivas. No lanza ataques: solo observa las respuestas.
# ------------------------------------------------------------
baseline() {
  echo
  echo "=== Escaner 1: baseline contra $OBJETIVO ==="
  curl -s "$API/JSON/core/action/newSession/?name=baseline&overwrite=true" >/dev/null

  echo "  Iniciando rastreo..."
  curl -s "$API/JSON/spider/action/scan/?url=$OBJETIVO&recurse=true&maxChildren=10" >/dev/null
  esperar_progreso "spider/view/status/" "rastreo" 900

  echo "  Esperando reglas pasivas..."
  sleep 15

  exportar "zap-baseline"
}

# ------------------------------------------------------------
# Escaner 2: full
# Rastreo completo y escaneo activo: envia cargas de ataque
# para confirmar las vulnerabilidades. Tarda mucho mas.
# ------------------------------------------------------------
full() {
  echo
  echo "=== Escaner 2: full contra $OBJETIVO ==="
  echo "  Este escaneo puede tardar entre 20 y 60 minutos."
  curl -s "$API/JSON/core/action/newSession/?name=full&overwrite=true" >/dev/null

  echo "  Iniciando rastreo..."
  curl -s "$API/JSON/spider/action/scan/?url=$OBJETIVO&recurse=true&maxChildren=20" >/dev/null
  esperar_progreso "spider/view/status/" "rastreo" 1800

  echo "  Iniciando escaneo activo..."
  curl -s "$API/JSON/ascan/action/scan/?url=$OBJETIVO&recurse=true&inScopeOnly=false" >/dev/null
  esperar_progreso "ascan/view/status/" "escaneo activo" 5400

  echo "  Esperando reglas pasivas..."
  sleep 20

  exportar "zap-full"
}

esperar_zap
echo "ZAP operativo: $(curl -s "$API/JSON/core/view/version/")"

case "$modo" in
  baseline) baseline ;;
  full)     full ;;
  ambos)    baseline; full ;;
  *) echo "Uso: $0 [baseline|full|ambos]"; exit 1 ;;
esac

echo
echo "Escaneos terminados. Reportes en $SALIDA"
