#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
integrado/verificar_sqlite.py — Arnés de verificación de la tablet (SQLite).

Abre la base TP8/food-store/movil/foodstore_movil.db en modo solo lectura,
muestra los conteos de producto_cache / pedido_borrador / item_borrador /
cola_sync (por estado) y corrobora la integridad de la base.

Cómo correrlo (desde la raíz del proyecto):
    python integrado/verificar_sqlite.py

Solo lectura: no modifica nada.
"""

import sqlite3
from pathlib import Path

# Ruta de la base de la tablet, relativa a la raíz del proyecto
RUTA_BD = Path("TP8") / "food-store" / "movil" / "foodstore_movil.db"


def consultar_conteo(con, sql, parametros=()):
    return con.execute(sql, parametros).fetchone()[0]


def main():
    if not RUTA_BD.exists():
        raise SystemExit(f"No se encontro la base: {RUTA_BD} (correr desde la raiz del proyecto)")

    con = sqlite3.connect(f"file:{RUTA_BD.as_posix()}?mode=ro", uri=True)
    con.execute("PRAGMA foreign_keys = ON;")

    producto = consultar_conteo(con, "SELECT count(*) FROM producto_cache")
    borradores = consultar_conteo(con, "SELECT count(*) FROM pedido_borrador")
    items = consultar_conteo(con, "SELECT count(*) FROM item_borrador")
    cola = consultar_conteo(con, "SELECT count(*) FROM cola_sync")
    integridad = con.execute("PRAGMA integrity_check;").fetchall()
    fk = con.execute("PRAGMA foreign_key_check;").fetchall()

    print(f"Base: {RUTA_BD}")
    print(f"producto_cache : {producto}")
    print(f"pedido_borrador: {borradores}")
    print(f"item_borrador  : {items}")
    print(f"cola_sync      : {cola}")

    print("cola_sync por estado:")
    filas = con.execute(
        "SELECT estado, count(*) FROM cola_sync GROUP BY estado ORDER BY estado"
    ).fetchall()
    if filas:
        for estado, n in filas:
            print(f"  {estado}: {n}")
    else:
        print("  (vacia)")

    ok = len(integridad) == 1 and integridad[0][0] == "ok"
    print(f"integrity_check : {'ok' if ok else integridad}")

    if fk:
        print(f"foreign_key_check: HAY INCONSISTENCIAS ({len(fk)})")
    else:
        print("foreign_key_check: ok")

    con.close()


if __name__ == "__main__":
    main()
