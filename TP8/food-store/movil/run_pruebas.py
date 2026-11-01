#!/usr/bin/env python3
"""
run_pruebas.py — arnés de ejecución de las pruebas SQLite del TP8.

Uso:
    python run_pruebas.py --db foodstore_movil.db --fresh
    python run_pruebas.py --db foodstore_movil.db --schema schema_sqlite.sql --tests pruebas_sqlite.sql

Por qué existe:
    En este entorno no está instalado el CLI de sqlite3. El TP8 permite Python
    para la simulación, así que este arnés ejecuta los .sql y deja evidencia
    legible sin cambiar el contenido de los entregables.

Convenciones del archivo de pruebas:
    -- TEST: nombre          nombre de la prueba
    -- EXPECT_OK             la sentencia debe ejecutarse sin error
    -- EXPECT_ERROR: motivo  la sentencia debe fallar y el mensaje debe contener
                             alguno de los motivos separados por '|'
    -- EXPECT_VALUE: valor   la primera columna de la primera fila debe valer eso
"""

from __future__ import annotations

import argparse
import re
import sqlite3
import sys
from pathlib import Path

MARK_TEST = re.compile(r"^--\s*TEST:\s*(.+?)\s*$")
MARK_VALUE = re.compile(r"^--\s*EXPECT_VALUE:\s*(.*?)\s*$")
MARK_ERROR = re.compile(r"^--\s*EXPECT_ERROR(?::\s*(.*?))?\s*$")
MARK_OK = re.compile(r"^--\s*EXPECT_OK\s*$")


def configure_stdout() -> None:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


def run_schema(conn: sqlite3.Connection, schema_path: Path) -> bool:
    if not schema_path.exists():
        print(f"[WARN] No existe el esquema: {schema_path}")
        print("[WARN] Se ejecutan las pruebas igual para obtener el estado RED.")
        return False
    sql = schema_path.read_text(encoding="utf-8")
    conn.executescript(sql)
    print(f"[OK] Esquema ejecutado: {schema_path}")
    return True


def execute_statement(
    conn: sqlite3.Connection,
    stmt: str,
    test_name: str,
    expectation: str,
    expected_value: str | None,
    expected_error: str | None,
) -> tuple[bool, str, str]:
    try:
        cur = conn.execute(stmt)
        rows = cur.fetchall()

        if expectation == "error":
            return False, test_name, f"se esperaba error pero ejecutó: {compact(stmt)}"

        if expectation == "value":
            actual = rows[0][0] if rows else None
            ok = str(actual) == str(expected_value)
            return ok, test_name, f"esperado={expected_value!r} actual={actual!r}"

        return True, test_name, "OK"

    except Exception as exc:  # noqa: BLE001 — el arnés debe reportar cualquier error
        message = f"{type(exc).__name__}: {exc}"
        if expectation == "error":
            if expected_error:
                needles = [n.strip().lower() for n in expected_error.split("|") if n.strip()]
                if not any(n in message.lower() for n in needles):
                    return (
                        False,
                        test_name,
                        f"error distinto al esperado ({expected_error}): {compact(message)}",
                    )
            return True, test_name, f"error esperado: {compact(message)}"
        return False, test_name, f"error inesperado: {compact(message)}"


def compact(text: str, limit: int = 160) -> str:
    text = " ".join(text.split())
    return text if len(text) <= limit else text[: limit - 3] + "..."


def run_tests(conn: sqlite3.Connection, tests_path: Path) -> tuple[int, int]:
    if not tests_path.exists():
        print(f"[ERROR] No existe el archivo de pruebas: {tests_path}")
        return 0, 1

    lines = tests_path.read_text(encoding="utf-8").splitlines()
    buffer: list[str] = []
    test_name = "(sin nombre)"
    expectation = "ok"
    expected_value: str | None = None
    expected_error: str | None = None
    passed = 0
    failed = 0
    total = 0

    def flush() -> None:
        nonlocal buffer, expectation, expected_value, expected_error, passed, failed, total
        stmt = "\n".join(buffer).strip()
        buffer = []
        if not stmt:
            expectation, expected_value, expected_error = "ok", None, None
            return
        if not sqlite3.complete_statement(stmt):
            buffer = stmt.splitlines()
            return
        total += 1
        ok, name, detail = execute_statement(
            conn, stmt, test_name, expectation, expected_value, expected_error
        )
        status = "PASS" if ok else "FAIL"
        print(f"[{status}] {name} — {detail}")
        if ok:
            passed += 1
        else:
            failed += 1
        expectation, expected_value, expected_error = "ok", None, None

    for line in lines:
        stripped = line.strip()

        match = MARK_TEST.match(stripped)
        if match:
            flush()
            test_name = match.group(1)
            continue

        match = MARK_VALUE.match(stripped)
        if match:
            flush()
            expectation = "value"
            expected_value = match.group(1)
            continue

        match = MARK_ERROR.match(stripped)
        if match:
            flush()
            expectation = "error"
            expected_error = match.group(1) or None
            continue

        if MARK_OK.match(stripped):
            flush()
            expectation = "ok"
            continue

        buffer.append(line)
        candidate = "\n".join(buffer)
        if sqlite3.complete_statement(candidate):
            flush()

    flush()
    return passed, failed


def main() -> int:
    configure_stdout()
    here = Path(__file__).resolve().parent

    parser = argparse.ArgumentParser(description="Ejecuta las pruebas SQLite del TP8.")
    parser.add_argument("--db", default=str(here / "foodstore_movil.db"), help="Archivo SQLite.")
    parser.add_argument("--schema", default=str(here / "schema_sqlite.sql"), help="DDL SQLite.")
    parser.add_argument("--tests", default=str(here / "pruebas_sqlite.sql"), help="Pruebas SQL.")
    parser.add_argument("--fresh", action="store_true", help="Borra la base antes de empezar.")
    args = parser.parse_args()

    db_path = Path(args.db)
    if args.fresh and db_path.exists():
        db_path.unlink()
        print(f"[OK] Base eliminada para empezar de cero: {db_path}")

    conn = sqlite3.connect(db_path)
    conn.isolation_level = None  # autocommit: los BEGIN/COMMIT/ROLLBACK del .sql mandan

    schema_ok = run_schema(conn, Path(args.schema))
    passed, failed = run_tests(conn, Path(args.tests))
    conn.close()

    print()
    print("=" * 72)
    print(f"RESUMEN: {passed} PASS, {failed} FAIL, {passed + failed} pruebas")
    if not schema_ok:
        print("El esquema no se ejecutó: se esperaba un estado RED.")
    print(f"Base resultante: {db_path}")
    print("=" * 72)
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
