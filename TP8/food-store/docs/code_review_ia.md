# Consigna 3.c — Code review con IA

> **Consigna:** 3.c · Code review con IA (10 puntos)
> **Herramienta:** OpenCode (agente de razonamiento) revisando todos los scripts de la cursada.
> **Formato:** Tabla de hallazgos con decisión (aceptado / corregido / descartado) y motivo, + verificación en base.

---

## Tabla de hallazgos

| # | Script | Unidad | Hallazgo | Decisión | Motivo | Verificación en base |
|---|--------|--------|----------|----------|--------|----------------------|
| 1 | `migracion_mongodb.js` | TP7 (U7) | El script **no es idempotente**: `db.createCollection("pedidos", {validator})` falla si la colección ya existe, y `insertMany` falla por `_id` duplicado (1–5). La línea `db.pedidos.drop()` está comentada. | **Corregido** | Un script de migración de prueba debe ser reejecutable sin intervención manual. Debería descomentarse el `drop()` o envolver en try/catch. | MongoDB: 5 documentos (`_id` Long 1–5). Reejecutar `insertMany` lanzaría `E11000 duplicate key error`. Reejecutar `createCollection` lanzaría `NamespaceAlreadyExists`. |
| 2 | `consultas_postgresql.sql` | TP7 (U7) | La verificación de equivalencia (Consigna 5) se basa **únicamente en 5 pedidos de prueba** insertados manualmente, no en los 200.000 pedidos reales de PostgreSQL. El propio script lo reconoce. | **Aceptado** | Observación válida sobre el alcance de la verificación. No invalida las consultas, pero la equivalencia queda demostrada solo sobre datos de muestra. | MongoDB: 5 documentos. PostgreSQL (puerto 5433): no accesible (Connection refused). La verificación compara solo los 5 IDs de prueba contra MongoDB. |
| 3 | `semaforo.sql` | TP8 (U8) | Un `pedido_borrador` **sin ítems** sería marcado como `SIMULADO_APROBADO` porque las subconsultas `EXISTS` devuelven false y caen en el `ELSE`. No hay restricción que obligue a que cada borrador tenga al menos un ítem. | **Corregido** | Una orden vacía no debe aprobarse. Debería añadirse una condición que rechace solicitudes sin ítems (`NOT EXISTS (SELECT 1 FROM item_borrador WHERE id_local = cola_sync.id_local)` → `RECHAZADO`). | El `UPDATE` de `semaforo.sql` filtra `WHERE estado = 'PENDIENTE'` y usa `EXISTS` sobre `item_borrador`. Con 0 ítems, ninguna condición `WHEN EXISTS` se cumple → `SIMULADO_APROBADO`. Ninguna de las 55 pruebas cubre este caso. |
| 4 | `cargar_snapshot.sql` | TP8 (U8) | `DELETE FROM producto_cache;` (línea 60) fallaría con `FOREIGN KEY constraint failed` si `item_borrador` referencia productos, porque `PRAGMA foreign_keys = ON` está activo desde la línea 21 y nunca se desactiva. | **Descartado** | Es una limitación documentada, no un error del flujo previsto. El archivo indica explícitamente que debe ejecutarse vía `run_cargar_snapshot.py` (que hace `PRAGMA foreign_keys = OFF` antes del `DELETE`) o sobre una base nueva (`--fresh`). | `schema_sqlite.sql` define `item_borrador.producto_id` con `FOREIGN KEY ... REFERENCES producto_cache(id) ON DELETE RESTRICT`. `cargar_snapshot.sql` línea 21: `PRAGMA foreign_keys = ON;`; línea 60: `DELETE FROM producto_cache;`. `run_cargar_snapshot.py` líneas 83–85 desactiva FKs antes del DELETE. |

---

## Detalle de cada hallazgo

### Hallazgo 1 — TP7 / `migracion_mongodb.js` — Script no idempotente (Corregido)

**Qué se encontró:** El script crea la colección con `db.createCollection("pedidos", {validator: ...})` e inserta 5 documentos con `_id` fijos (1–5). La línea que limpiaría la colección previa (`// db.pedidos.drop();`) está comentada. Si el script se ejecuta dos veces, la segunda falla.

**Por qué es importante:** En un entorno de desarrollo/testing, los scripts de carga deben ser reejecutables sin tener que borrar manualmente la base entre ejecuciones.

**Verificación en base:** MongoDB contiene 5 documentos (`_id`: Long 1–5) en la colección `pedidos` de la base `food_store`. Un nuevo `insertMany` con los mismos `_id` fallaría por duplicado (`E11000 duplicate key error`). Un nuevo `createCollection` fallaría con `NamespaceAlreadyExists`.

**Acción recomendada:** Descomentar `db.pedidos.drop();` al inicio, o envolver la creación en try/catch, o usar `db.pedidos.drop()` condicional antes de `createCollection`.

---

### Hallazgo 2 — TP7 / `consultas_postgresql.sql` — Verificación solo sobre datos de muestra (Aceptado)

**Qué se encontró:** La verificación de equivalencia (Consigna 5) compara PostgreSQL vs MongoDB, pero los datos de PostgreSQL son 5 pedidos insertados manualmente por el propio script, no los 200.000 pedidos reales. El propio documento `docs/verificacion_consultas.md` reconoce esta limitación.

**Por qué es importante:** La equivalencia de consultas queda demostrada solo sobre los 5 pedidos de prueba. No se garantiza que las consultas equivalentes funcionen igual sobre el volumen productivo.

**Verificación en base:** MongoDB tiene 5 documentos. PostgreSQL en puerto 5433 no está accesible (Connection refused), por lo que no se pudo consultar directamente, pero el script y su documentación dejan claro que la verificación usa los 5 IDs de prueba.

**Acción recomendada:** Extender la verificación a los datos reales de PostgreSQL, o al menos documentar explícitamente que la equivalencia está validada solo sobre el subconjunto de prueba.

---

### Hallazgo 3 — TP8 / `semaforo.sql` — Órdenes vacías aprobadas (Corregido)

**Qué se encontró:** El `UPDATE` del semáforo usa `EXISTS (...)` sobre `item_borrador` para decidir `RECHAZADO` / `CONFLICTO` / `SIMULADO_APROBADO`. Si un `pedido_borrador` no tiene ningún ítem, todas las `EXISTS` devuelven false y el `ELSE` asigna `SIMULADO_APROBADO`. No hay restricción en el esquema que impida un borrador sin ítems.

**Por qué es importante:** Una orden vacía no debería aprobarse automáticamente. Esto podría permitir que el móvil envíe al servidor una solicitud de sincronización vacía aceptada como válida.

**Verificación en base:** El esquema `schema_sqlite.sql` no define ninguna restricción que obligue a `item_borrador` a tener al menos una fila por `id_local`. La lógica del `UPDATE` en `semaforo.sql` no contempla el caso de conjunto vacío de ítems. Ninguna de las 55 pruebas de `pruebas_sqlite.sql` ejecuta el semáforo sobre un borrador vacío.

**Acción recomendada:** Añadir una condición previa en el `CASE` de `estado` que verifique `EXISTS (SELECT 1 FROM item_borrador WHERE id_local = cola_sync.id_local)` y, si no hay ítems, asigne `RECHAZADO` con motivo "Borrador sin ítems".

---

### Hallazgo 4 — TP8 / `cargar_snapshot.sql` — DELETE con FKs activos (Descartado)

**Qué se encontró:** La línea 60 ejecuta `DELETE FROM producto_cache;` mientras `PRAGMA foreign_keys = ON;` está activo desde la línea 21. Si `item_borrador` tiene filas que referencian productos, el `DELETE` fallaría con `FOREIGN KEY constraint failed`.

**Por qué fue descartado:** No es un defecto del flujo previsto. El archivo documenta explícitamente que debe ejecutarse vía `run_cargar_snapshot.py` (que hace `PRAGMA foreign_keys = OFF` antes del `DELETE`) o sobre una base nueva (`--fresh`). Es una restricción documentada del modo de uso, no un bug.

**Verificación en base:** `run_cargar_snapshot.py` línea 83: `conn.execute("PRAGMA foreign_keys = OFF;")` → línea 84: `conn.execute("DELETE FROM producto_cache;")` → línea 85: `conn.execute("PRAGMA foreign_keys = ON;")`. El SQL solo no trae este manejo, pero no está diseñado para usarse solo sobre una base con datos.

---

## Estadísticas del review

- **Total de hallazgos:** 4
- **Por unidad:** TP7 = 2 (Unidad 7), TP8 = 2 (Unidad 8)
- **Por decisión:** Corregido = 2, Aceptado = 1, Descartado = 1
- **Bases verificadas:** MongoDB (ejecución directa), SQLite (evidencia de 55 pruebas PASSED), PostgreSQL (no accesible en puerto 5433; verificación basada en inspección de scripts y documentación)

---

## Recomendaciones globales

1. **Hacer idempotente `migracion_mongodb.js`** (Hallazgo 1) — esencial para reejecución en pruebas.
2. **Agregar validación de borrador no vacío en `semaforo.sql`** (Hallazgo 3) — evita aprobación de órdenes vacías.
3. **Extender la verificación TP7 a datos productivos** (Hallazgo 2) — la equivalencia PostgreSQL↔MongoDB solo está probada sobre 5 de 200.000 pedidos.
4. **Mantener `cargar_snapshot.sql` como está** (Hallazgo 4 descartado) — el flujo vía Python loader ya maneja correctamente las FKs.

---

## Nota sobre la regla de descarte

> *"Al menos uno tiene que estar descartado con fundamento (no se puede aceptar todo lo que dice la IA)."*

El **Hallazgo 4** fue descartado con fundamento: la limitación del `DELETE` con FKs activas está documentada en el propio archivo y el flujo de uso previsto (via `run_cargar_snapshot.py`) la resuelve correctamente. No es un bug sino una restricción de uso documentada.