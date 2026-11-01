#!/usr/bin/env python3
"""
run_cargar_snapshot.py — carga el snapshot de PostgreSQL en SQLite (Consigna 2.a).

Uso:
    python run_cargar_snapshot.py [--db foodstore_movil.db] [--csv servidor_snapshot.csv]

Que hace:
    1. Crea la tabla staging `snapshot_servidor` (tipos flexibles).
    2. Importa el CSV (servidor_snapshot.csv) en snapshot_servidor.
    3. Carga producto_cache desde snapshot_servidor con las transformaciones
       (booleanos t/f -> 0/1, CAST a INTEGER, etc.).
    4. Muestra evidencia de la carga.

No requiere el CLI de sqlite3: usa Python 3 + sqlite3 (built-in).
"""
from __future__ import annotations

import argparse
import csv
import sqlite3
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def configure_stdout() -> None:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


def main() -> int:
    configure_stdout()
    parser = argparse.ArgumentParser(description="Carga el snapshot de PostgreSQL en SQLite.")
    parser.add_argument("--db", default=str(HERE / "foodstore_movil.db"), help="Archivo SQLite.")
    parser.add_argument("--csv", default=str(HERE / "servidor_snapshot.csv"), help="CSV exportado desde PostgreSQL.")
    args = parser.parse_args()

    db_path = Path(args.db)
    csv_path = Path(args.csv)

    if not csv_path.exists():
        print(f"[ERROR] No existe el CSV: {csv_path}")
        return 1

    conn = sqlite3.connect(db_path)
    conn.isolation_level = None  # autocommit
    conn.execute("PRAGMA foreign_keys = ON;")

    # 1. Crear tabla staging
    conn.execute("""
        CREATE TABLE IF NOT EXISTS snapshot_servidor (
            id              TEXT,
            nombre          TEXT,
            precio_centavos TEXT,
            stock_visto     TEXT,
            disponible      TEXT,
            eliminado       TEXT,
            fecha_copia     TEXT
        );
    """)
    conn.execute("DELETE FROM snapshot_servidor;")
    print("[OK] Tabla staging `snapshot_servidor` creada/limpiada.")

    # 2. Importar CSV
    with csv_path.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    conn.executemany(
        """INSERT INTO snapshot_servidor
           (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        [(r["id"], r["nombre"], r["precio_centavos"], r["stock_visto"],
          r["disponible"], r["eliminado"], r["fecha_copia"]) for r in rows],
    )
    print(f"[OK] Importadas {len(rows)} filas en snapshot_servidor.")

    # 3. Cargar producto_cache
    conn.execute("PRAGMA foreign_keys = OFF;")
    conn.execute("DELETE FROM producto_cache;")
    conn.execute("PRAGMA foreign_keys = ON;")
    conn.execute("""
        INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
        SELECT
            CAST(s.id AS INTEGER),
            s.nombre,
            CAST(s.precio_centavos AS INTEGER),
            CAST(s.stock_visto AS INTEGER),
            CASE WHEN LOWER(TRIM(s.disponible)) IN ('t','true','1') THEN 1 ELSE 0 END,
            CASE WHEN LOWER(TRIM(s.eliminado))  IN ('t','true','1') THEN 1 ELSE 0 END,
            s.fecha_copia
        FROM snapshot_servidor s
        WHERE s.id IS NOT NULL AND TRIM(s.id) <> '';
    """)
    print("[OK] producto_cache cargado desde snapshot_servidor.")

    # 4. Evidencia
    cur = conn.execute("SELECT COUNT(*) FROM producto_cache;")
    total = cur.fetchone()[0]
    cur = conn.execute("SELECT COUNT(*) FROM producto_cache WHERE disponible = 1 AND eliminado = 0;")
    disponibles = cur.fetchone()[0]
    cur = conn.execute("SELECT COUNT(*) FROM producto_cache WHERE eliminado = 1;")
    eliminados = cur.fetchone()[0]
    cur = conn.execute("SELECT MIN(precio_centavos), MAX(precio_centavos) FROM producto_cache;")
    min_p, max_p = cur.fetchone()
    cur = conn.execute("SELECT MIN(stock_visto), MAX(stock_visto) FROM producto_cache;")
    min_s, max_s = cur.fetchone()

    print()
    print("=" * 60)
    print("EVIDENCIA DE CARGA - Consigna 2.a")
    print("=" * 60)
    print(f"  Total productos en producto_cache : {total}")
    print(f"  Disponibles (disp=1, elim=0)     : {disponibles}")
    print(f"  Eliminados (baja logica)         : {eliminados}")
    print(f"  Rango de precios (centavos)      : {min_p} - {max_p}")
    print(f"  Rango de stock visto             : {min_s} - {max_s}")
    print(f"  Filas en snapshot_servidor       : {len(rows)}")
    print("=" * 60)

    print()
    print("Primeras 5 filas de producto_cache:")
    for row in conn.execute("SELECT id, nombre, precio_centavos, stock_visto, disponible, eliminado FROM producto_cache ORDER BY id LIMIT 5;"):
        print(f"  {row}")

    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
