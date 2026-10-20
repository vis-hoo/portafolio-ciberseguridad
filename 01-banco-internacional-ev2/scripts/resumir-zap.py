#!/usr/bin/env python3
"""
Resume los reportes JSON de OWASP ZAP en una tabla legible.

Uso:
    python3 scripts/resumir-zap.py scans/zap-baseline.json
    python3 scripts/resumir-zap.py scans/*.json
"""

import json
import sys
from pathlib import Path

RIESGO = {
    "3": "Alta",
    "2": "Media",
    "1": "Baja",
    "0": "Informativa",
}


def resumir(ruta: Path) -> list[dict]:
    datos = json.loads(ruta.read_text(encoding="utf-8"))
    filas = []
    for sitio in datos.get("site", []):
        for alerta in sitio.get("alerts", []):
            filas.append(
                {
                    "riesgo": RIESGO.get(alerta.get("riskcode", "0"), "?"),
                    "codigo": alerta.get("riskcode", "0"),
                    "nombre": alerta.get("alert", ""),
                    "confianza": alerta.get("confidence", ""),
                    "instancias": len(alerta.get("instances", [])),
                    "cwe": alerta.get("cweid", ""),
                    "solucion": (alerta.get("solution") or "").strip(),
                }
            )
    # Orden por severidad descendente y luego por cantidad de instancias.
    filas.sort(key=lambda f: (-int(f["codigo"]), -f["instancias"]))
    return filas


def main():
    rutas = [Path(a) for a in sys.argv[1:]]
    if not rutas:
        print(__doc__)
        sys.exit(1)

    for ruta in rutas:
        if not ruta.exists():
            print(f"No existe: {ruta}")
            continue

        filas = resumir(ruta)
        print(f"\n=== {ruta.name} ===")
        print(f"Tipos de alerta: {len(filas)}")

        conteo = {}
        for f in filas:
            conteo[f["riesgo"]] = conteo.get(f["riesgo"], 0) + 1
        for nivel in ("Alta", "Media", "Baja", "Informativa"):
            if nivel in conteo:
                print(f"  {nivel}: {conteo[nivel]}")

        print()
        print(f"{'Riesgo':<12} {'Alerta':<52} {'Inst.':>5}  CWE")
        print("-" * 82)
        for f in filas:
            nombre = f["nombre"][:50]
            print(f"{f['riesgo']:<12} {nombre:<52} {f['instancias']:>5}  {f['cwe']}")


if __name__ == "__main__":
    main()
