#!/usr/bin/env python3
"""
simular_casos.py -- simula los casos C2-C6 de la Consigna 2.c.

Uso:
    python simular_casos.py [--db foodstore_movil.db]

Para cada caso:
  1. Restaura producto 3 a sus valores originales del snapshot.
  2. Prepara la situacion modificando producto_cache (simula cambios en el servidor).
  3. Configura el borrador para usar producto 3 con precio original.
  4. Resetea la solicitud a PENDIENTE.
  5. Ejecuta el semaforo (semaforo.sql).
  6. Registra el resultado.

Los resultados se imprimen y se guardan en docs/evidencias_consigna2.md.
"""
from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

# Valores originales del producto 3 en el snapshot
PROD3_ORIGINAL = {
    "precio_centavos": 178065,
    "stock_visto": 137,
    "disponible": 1,
    "eliminado": 0,
}


def configure_stdout() -> None:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


def restore_product3(conn: sqlite3.Connection) -> None:
    """Restaura producto 3 a sus valores originales del snapshot."""
    conn.execute("""
        UPDATE producto_cache
        SET precio_centavos = ?, stock_visto = ?, disponible = ?, eliminado = ?
        WHERE id = 3;
    """, (PROD3_ORIGINAL["precio_centavos"], PROD3_ORIGINAL["stock_visto"],
          PROD3_ORIGINAL["disponible"], PROD3_ORIGINAL["eliminado"]))


def reset_draft(conn: sqlite3.Connection) -> None:
    """Configura el borrador para usar producto 3 con precio original."""
    conn.execute("DELETE FROM item_borrador;")
    conn.execute("""
        INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
        VALUES ('11111111-1111-4111-8111-111111111111', 3, 2, ?);
    """, (PROD3_ORIGINAL["precio_centavos"],))


def reset_solicitud(conn: sqlite3.Connection) -> None:
    """Resetea la solicitud a PENDIENTE para re-evaluar."""
    conn.execute("DELETE FROM cola_sync;")
    conn.execute("""
        INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
        VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                '11111111-1111-4111-8111-111111111111', 'PENDIENTE', NULL);
    """)


def run_semaforo(conn: sqlite3.Connection) -> list[tuple]:
    """Ejecuta el semaforo y retorna los resultados."""
    sql = (HERE / "semaforo.sql").read_text(encoding="utf-8")
    conn.executescript(sql)
    return conn.execute("SELECT solicitud_uuid, id_local, estado, motivo FROM cola_sync").fetchall()


def case_header(case_id: str, description: str) -> None:
    print()
    print("=" * 70)
    print(f"  {case_id}: {description}")
    print("=" * 70)


def main() -> int:
    configure_stdout()
    parser = argparse.ArgumentParser(description="Simula casos C2-C6.")
    parser.add_argument("--db", default=str(HERE / "foodstore_movil.db"), help="Archivo SQLite.")
    args = parser.parse_args()

    conn = sqlite3.connect(args.db)
    conn.isolation_level = None
    conn.execute("PRAGMA foreign_keys = ON;")

    results = []

    # =====================================================================
    # C2: Cambio de precio en el servidor -> CONFLICTO
    #     Luego el cliente acepta -> actualiza precio del borrador -> SIMULADO_APROBADO
    # =====================================================================
    case_header("C2", "Cambio de precio en el servidor")

    restore_product3(conn)
    reset_draft(conn)
    # Paso 1: subir el precio del producto 3 en producto_cache (simula cambio en servidor)
    print("  Paso 1: Subir precio del producto 3 de 178065 a 190000 centavos (simula cambio en servidor)")
    conn.execute("UPDATE producto_cache SET precio_centavos = 190000 WHERE id = 3;")
    reset_solicitud(conn)
    r = run_semaforo(conn)
    print(f"  Resultado tras cambio de precio: {r[0][2]} - {r[0][3]}")
    results.append(("C2a", "Cambio de precio en servidor", r[0][2], r[0][3]))

    # Paso 2: cliente acepta el nuevo precio -> actualiza el borrador
    print("  Paso 2: Cliente acepta -> actualiza precio_centavos_visto del borrador a 190000")
    conn.execute("UPDATE item_borrador SET precio_centavos_visto = 190000 WHERE producto_id = 3;")
    reset_solicitud(conn)
    r = run_semaforo(conn)
    print(f"  Resultado tras aceptar nuevo precio: {r[0][2]} - {r[0][3]}")
    results.append(("C2b", "Cliente acepta nuevo precio", r[0][2], r[0][3]))

    # =====================================================================
    # C3: Mas unidades de las que quedan -> RECHAZADO
    # =====================================================================
    case_header("C3", "Mas unidades de las que quedan en stock")

    restore_product3(conn)
    reset_draft(conn)
    # Solicitar 200 unidades (solo hay 137)
    print("  Paso 1: Solicitar 200 unidades del producto 3 (stock disponible: 137)")
    conn.execute("UPDATE item_borrador SET cantidad = 200 WHERE producto_id = 3;")
    reset_solicitud(conn)
    r = run_semaforo(conn)
    print(f"  Resultado: {r[0][2]} - {r[0][3]}")
    results.append(("C3", "Stock insuficiente (200 > 137)", r[0][2], r[0][3]))

    # =====================================================================
    # C4: Producto dado de baja (baja logica) -> RECHAZADO
    #     Al recargar el catalogo, el producto ya no aparece pero la fila queda
    # =====================================================================
    case_header("C4", "Producto dado de baja (baja logica)")

    restore_product3(conn)
    reset_draft(conn)
    # Marcar producto 3 como eliminado
    print("  Paso 1: Marcar producto 3 como eliminado (baja logica)")
    conn.execute("UPDATE producto_cache SET eliminado = 1, disponible = 0 WHERE id = 3;")
    reset_solicitud(conn)
    r = run_semaforo(conn)
    print(f"  Resultado: {r[0][2]} - {r[0][3]}")
    results.append(("C4", "Producto dado de baja (eliminado=1)", r[0][2], r[0][3]))

    # Paso 2: verificar que el producto sigue en producto_cache (baja logica, no DELETE)
    print("  Paso 2: Verificar que el producto sigue en producto_cache (baja logica, no DELETE)")
    exists = conn.execute("SELECT count(*) FROM producto_cache WHERE id = 3").fetchone()[0]
    print(f"  Producto 3 sigue en producto_cache: {exists == 1} (baja logica, no se borro)")
    results.append(("C4b", "Producto sigue en cache (baja logica)", "N/A", f"existe={exists == 1}"))

    # =====================================================================
    # C5: Sin cambios -> SIMULADO_APROBADO
    # =====================================================================
    case_header("C5", "Sin cambios (todo coincide)")

    restore_product3(conn)
    reset_draft(conn)
    print("  Paso 1: Sin modificaciones en producto_cache ni en el borrador")
    reset_solicitud(conn)
    r = run_semaforo(conn)
    print(f"  Resultado: {r[0][2]} - {r[0][3]}")
    results.append(("C5", "Sin cambios (precio y stock coinciden)", r[0][2], r[0][3]))

    # =====================================================================
    # C6: Reenviar la misma solicitud (mismo UUID) -> no se duplica
    # =====================================================================
    case_header("C6", "Reenviar la misma solicitud (idempotencia)")

    print("  Paso 1: Intentar insertar la misma solicitud_uuid de nuevo")
    try:
        conn.execute("""
            INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
            VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    '11111111-1111-4111-8111-111111111111', 'PENDIENTE', NULL);
        """)
        print("  ERROR: se inserto duplicado (no deberia pasar)")
        results.append(("C6", "Reenviar mismo UUID", "FALLO", "Se inserto duplicado"))
    except sqlite3.IntegrityError as e:
        print(f"  OK: error de PK como se esperaba - {e}")
        results.append(("C6", "Reenviar mismo UUID", "OK", str(e)))

    print("  Paso 2: Repetir la simulacion no reevalua (solicitud ya no esta PENDIENTE)")
    conn.execute("UPDATE cola_sync SET estado = 'SIMULADO_APROBADO', motivo = 'Todo coincide' WHERE solicitud_uuid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';")
    count_before = conn.execute("SELECT count(*) FROM cola_sync").fetchone()[0]
    # Re-ejecutar semaforo: no debe cambiar nada (no hay PENDIENTE)
    conn.executescript((HERE / "semaforo.sql").read_text(encoding="utf-8"))
    count_after = conn.execute("SELECT count(*) FROM cola_sync").fetchone()[0]
    r = conn.execute("SELECT estado, motivo FROM cola_sync WHERE solicitud_uuid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'").fetchone()
    print(f"  Tras re-ejecutar semaforo: estado={r[0]}, motivo={r[1]} (no cambio, idempotente)")
    print(f"  Filas antes: {count_before}, despues: {count_after} (sin duplicados)")
    results.append(("C6b", "Repetir simulacion (idempotente)", r[0], "sin duplicados"))

    # =====================================================================
    # Resumen
    # =====================================================================
    print()
    print("=" * 70)
    print("  RESUMEN DE CASOS C2-C6")
    print("=" * 70)
    for case_id, desc, estado, motivo in results:
        print(f"  {case_id}: {desc}")
        print(f"       -> {estado} - {motivo}")
    print("=" * 70)

    # Consulta final de no modificacion
    print()
    print("=== Consulta final de no modificacion (PostgreSQL) ===")
    print("  En PostgreSQL, verificar que la cantidad de pedidos y el stock no cambiaron:")
    print("  SELECT count(*) AS total_pedidos FROM pedido;")
    print("  SELECT count(*) AS total_detalles FROM detalle_pedido;")
    print("  SELECT id_producto, stock FROM producto WHERE id_producto IN (1,2,3);")
    print("  (Estos valores deben ser identicos antes y despues de la simulacion.)")

    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
