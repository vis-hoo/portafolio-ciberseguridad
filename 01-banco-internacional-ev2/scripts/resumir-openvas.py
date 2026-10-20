#!/usr/bin/env python3
"""
Resume un reporte XML de OpenVAS (Greenbone) en una tabla legible.

Los reportes se exportan con gmp-cli y la opcion details="1", que es
la que incluye el bloque <results> con los hallazgos. Sin esa opcion,
get_reports solo devuelve los metadatos del reporte.

Uso:
    python3 scripts/resumir-openvas.py scans/openvas-rapido.xml
    python3 scripts/resumir-openvas.py scans/openvas-*.xml
"""

import re
import sys
from pathlib import Path

# Greenbone entrega el nivel como texto en <threat>.
NIVEL = {
    "Critical": "Crítica",
    "High": "Alta",
    "Medium": "Media",
    "Low": "Baja",
    "Log": "Informativa",
    "Debug": "Informativa",
}


def campo(bloque: str, etiqueta: str) -> str:
    m = re.search(r"<%s>([^<]*)</%s>" % (etiqueta, etiqueta), bloque)
    return m.group(1).strip() if m else ""


def resumir(ruta: Path) -> dict:
    xml = ruta.read_text(encoding="utf-8", errors="ignore")

    inicio = campo(xml, "scan_start")
    termino = campo(xml, "scan_end")
    nombre_tarea = ""
    m = re.search(r"<task id=\"[^\"]+\"><name>([^<]*)</name></task>", xml)
    if m:
        nombre_tarea = m.group(1)

    resultados = []
    for m in re.finditer(r"<result id=\"[^\"]+\">(.*?)</result>", xml, re.S):
        b = m.group(1)
        resultados.append(
            {
                "nivel": NIVEL.get(campo(b, "threat"), campo(b, "threat") or "?"),
                "severidad": campo(b, "severity") or "0.0",
                "nombre": campo(b, "name"),
                "host": campo(b, "host") or "(sin host)",
                "puerto": campo(b, "port") or "-",
                "cve": campo(b, "cve") or "",
            }
        )

    # Orden por severidad descendente.
    resultados.sort(key=lambda r: -float(r["severidad"] or 0))

    return {
        "tarea": nombre_tarea,
        "inicio": inicio,
        "termino": termino,
        "resultados": resultados,
    }


def main():
    rutas = [Path(a) for a in sys.argv[1:]]
    if not rutas:
        print(__doc__)
        sys.exit(1)

    for ruta in rutas:
        if not ruta.exists():
            print(f"No existe: {ruta}")
            continue

        datos = resumir(ruta)
        res = datos["resultados"]

        print(f"\n=== {ruta.name} ===")
        if datos["tarea"]:
            print(f"Tarea:   {datos['tarea']}")
        if datos["inicio"]:
            print(f"Inicio:  {datos['inicio']}")
            print(f"Termino: {datos['termino']}")

        conteo = {}
        for r in res:
            conteo[r["nivel"]] = conteo.get(r["nivel"], 0) + 1
        print(f"Hallazgos: {len(res)}")
        for nivel in ("Crítica", "Alta", "Media", "Baja", "Informativa"):
            if nivel in conteo:
                print(f"  {nivel}: {conteo[nivel]}")

        print()
        print(f"{'Nivel':<12} {'Sev.':>5}  {'Puerto':<14} {'Hallazgo':<48} CVE")
        print("-" * 100)
        for r in res:
            print(
                f"{r['nivel']:<12} {r['severidad']:>5}  {r['puerto'][:14]:<14} "
                f"{r['nombre'][:48]:<48} {r['cve']}"
            )


if __name__ == "__main__":
    main()
