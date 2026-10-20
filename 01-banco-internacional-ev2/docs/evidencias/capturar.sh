#!/usr/bin/env bash
# Captura de pantalla de una URL con Chrome headless.
# Uso: ./docs/evidencias/capturar.sh <url> <salida.png> [ancho] [alto]
#
# Requiere Chrome/Chromium. Si no esta en el sistema, se puede
# apuntar CHROME_PATH al binario descargado con:
#   npx @puppeteer/browsers install chrome@stable --path /tmp/chrome

set -euo pipefail

URL="${1:?Uso: capturar.sh <url> <salida.png> [ancho] [alto]}"
SALIDA="${2:?Falta el archivo de salida}"
ANCHO="${3:-1440}"
ALTO="${4:-900}"

CHROME="${CHROME_PATH:-}"
if [ -z "$CHROME" ]; then
  for c in chromium chromium-browser google-chrome google-chrome-stable; do
    if command -v "$c" >/dev/null 2>&1; then CHROME="$(command -v "$c")"; break; fi
  done
fi

if [ -z "$CHROME" ] || [ ! -x "$CHROME" ]; then
  echo "ERROR: no se encontro Chrome/Chromium. Define CHROME_PATH." >&2
  exit 1
fi

directorio="$(dirname "$SALIDA")"
mkdir -p "$directorio"
perfil="$(mktemp -d)"

"$CHROME" \
  --headless=new \
  --no-sandbox \
  --disable-gpu \
  --hide-scrollbars \
  --user-data-dir="$perfil" \
  --window-size="${ANCHO},${ALTO}" \
  --screenshot="$SALIDA" \
  --virtual-time-budget=6000 \
  "$URL" >/dev/null 2>&1

rm -rf "$perfil"

if [ -f "$SALIDA" ]; then
  echo "Captura guardada: $SALIDA"
else
  echo "ERROR: no se genero la captura." >&2
  exit 1
fi
