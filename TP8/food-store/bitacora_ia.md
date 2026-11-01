# Bitácora de IA — Food Store Tablet (TP8)

> **Proyecto:** Food Store — cierre de la capa de datos
> **Materia:** Base de Datos II — Tecnicatura Universitaria en Programación

---

## Entrada 1 — Diseño del esquema SQLite (schema_sqlite.sql)

**Qué le pedí a la IA:**
> "Diseña un esquema SQLite para una tablet que necesita una copia de lectura del catálogo de productos (id, nombre, precio en centavos, stock visto, disponible, eliminado, fecha de copia) y tablas para borradores de venta (pedido_borrador, item_borrador, cola_sync). Las tablas deben ser STRICT, con CHECK constraints y claves foráneas. El precio debe ser entero en centavos (no float). Los booleanos deben ser 0/1."

**Qué acepté:**
- Las 4 tablas STRICT con sus columnas mínimas.
- Los CHECK constraints para `precio_centavos >= 0`, `disponible IN (0,1)`, `eliminado IN (0,1)`, `cantidad > 0`, `forma_pago IN (...)`.
- La clave foránea de `item_borrador` a `producto_cache` y `pedido_borrador`.
- La PK compuesta `(id_local, producto_id)` en `item_borrador`.

**Qué descarté y por qué:**
- Descarté la propuesta de usar `REAL` para el precio (la IA sugirió `REAL` por defecto). Lo descarté porque el enunciado exige precios en centavos enteros para evitar errores de punto flotante. Se usó `INTEGER` con centavos.
- Descarté la sugerencia de usar `TEXT` para los booleanos. Se usó `INTEGER` con CHECK `IN (0,1)`.

**Verificación en base:** 55/55 pruebas PASS en `salida_pruebas.txt`. Los CHECK constraints se verificaron con casos de error (precio negativo, disponible=2, forma de pago inválida, etc.).

---

## Entrada 2 — Lógica del semáforo (semaforo.sql)

**Qué le pedí a la IA:**
> "Escribe una consulta SQL para SQLite que evalúe cada solicitud PENDIENTE en cola_sync comparándola con producto_cache. Si algún producto no existe, no está disponible, fue dado de baja o no alcanza el stock → RECHAZADO. Si no hay rechazo pero cambió algún precio → CONFLICTO. Si todo coincide → SIMULADO_APROBADO. Solo evaluar solicitudes PENDIENTE."

**Qué acepté:**
- La estructura del `UPDATE` con `CASE` y subconsultas `EXISTS`.
- La lógica de prioridad: RECHAZADO > CONFLICTO > SIMULADO_APROBADO.
- El filtro `WHERE estado = 'PENDIENTE'` para idempotencia.

**Qué descarté y por qué:**
- Descarté la sugerencia de usar un `JOIN` directo entre `cola_sync` e `item_borrador` sin subconsultas. La IA propuso una consulta con `GROUP BY` y `HAVING`, pero era más compleja y difícil de leer. Se mantuvo la estructura con `EXISTS` anidados por claridad.
- Descarté la sugerencia de agregar un estado `ERROR` para casos no contemplados. El enunciado solo define 4 estados: PENDIENTE, CONFLICTO, RECHAZADO, SIMULADO_APROBADO.

**Verificación en base:** Se ejecutó `semaforo.sql` sobre la base de prueba. Resultado: la solicitud de prueba se marcó como `RECHAZADO` — `Producto no disponible` (correcto, porque el producto 2 tiene `disponible = 0` y `stock_visto = 0` en el snapshot real). Los casos C2–C6 se simularon con `simular_casos.py`: todos los resultados coinciden con lo esperado (CONFLICTO, RECHAZADO, SIMULADO_APROBADO, idempotencia).

---

## Entrada 3 — Migración de datos y carga de snapshot (run_cargar_snapshot.py)

**Qué le pedí a la IA:**
> "Escribe un script Python que: 1) cree una tabla staging `snapshot_servidor` en SQLite con tipos flexibles, 2) importe un CSV exportado de PostgreSQL (con booleanos t/f) en esa tabla, 3) cargue `producto_cache` desde la staging con transformaciones (t/f → 0/1, CAST a INTEGER), 4) muestre evidencia de la carga."

**Qué acepté:**
- El uso de `csv.DictReader` para leer el CSV.
- Las transformaciones con `CASE WHEN LOWER(TRIM(...)) IN ('t','true','1')`.
- La evidencia impresa (conteos, rangos, primeras filas).

**Qué descarté y por qué:**
- Descarté la sugerencia de usar `pandas` para la importación. El entorno no tiene pandas instalado y el TP permite Python estándar. Se usó `csv` del stdlib.
- Descarté la sugerencia de crear la tabla staging con tipos STRICT. La tabla `snapshot_servidor` debe ser flexible (staging) para absorber los booleanos `t`/`f` del CSV de psql. Solo `producto_cache` es STRICT.
- Descarté la sugerencia de no desactivar las FKs durante el `DELETE FROM producto_cache`. La IA propuso usar `ON DELETE CASCADE` en `item_borrador`, pero el esquema original usa `ON DELETE RESTRICT` (más seguro). Se resolvió desactivando FKs temporalmente en el script Python.

**Verificación en base:** Se ejecutó `run_cargar_snapshot.py` sobre `foodstore_movil.db`. Resultado: 50.000 filas importadas en `snapshot_servidor`, 50.000 productos cargados en `producto_cache`. Disponibles: 44.732, eliminados: 5.061. Los primeros 5 productos coinciden con el snapshot de PostgreSQL (verificado contra `v_snapshot_movil`).

---

## Entrada 4 — Code review de scripts (code_review_ia.md, Consigna 3.c)

**Qué le pedí a la IA:**
> "Revisa los scripts de la cursada (TP7 y TP8) y produce una tabla de hallazgos con decisión (aceptado/corregido/descartado), motivo y verificación en base. Al menos un hallazgo debe estar descartado con fundamento."

**Qué acepté:**
- Hallazgo 1 (`migracion_mongodb.js` no idempotente): Aceptado como válido. El script falla al reejecutarse.
- Hallazgo 2 (`consultas_postgresql.sql` solo sobre datos de prueba): Aceptado como observación válida.
- Hallazgo 3 (`semaforo.sql` aprueba órdenes vacías): Aceptado como válido. Es un caso no contemplado.

**Qué descarté y por qué:**
- Descarté el Hallazgo 4 (`cargar_snapshot.sql` DELETE con FKs activas): La IA lo señaló como potencial bug, pero lo descarté porque el flujo previsto (via `run_cargar_snapshot.py`) ya maneja las FKs correctamente desactivándolas temporalmente. El archivo SQL no está diseñado para ejecutarse directamente sobre una base con datos. Es una restricción de uso documentada, no un bug.

**Verificación en base:** Los hallazgos 1 y 2 se verificaron contra MongoDB (5 documentos, `_id` 1–5). El hallazgo 3 se verificó contra el esquema SQLite (no hay restricción que impida borrador vacío, ninguna de las 55 pruebas cubre el caso). El hallazgo 4 se verificó contra `run_cargar_snapshot.py` (líneas 83–85 desactivan FKs antes del DELETE).