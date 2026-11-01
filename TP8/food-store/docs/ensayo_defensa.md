# Ensayo de defensa oral — TP8 Food Store

> **Tarea:** T4.7 — Preparar ensayo de defensa (mapa, caso en vivo, hallazgo IA)
> **Fecha:** 2026-11-01
> **Formato:** guion de ensayo para la defensa en clase. Todo lo que se dice acá está respaldado por evidencias reales de `docs/`.

---

## 1. Fundamentos a recordar antes de arrancar (sin leer tarjetas)

Antes de mostrar cualquier pantalla, tener claros estos tres puntos y poder enunciarlos de memoria:

**La regla de oro (textual):**
> "El móvil propone, el servidor dispone. La tablet solo consulta y arma borradores. Precio, stock y ventas los decide PostgreSQL. `SIMULADO_APROBADO` no es una venta."

**Por qué 3 motores:**
- **PostgreSQL** es el sistema transaccional y la única fuente de verdad: ACID, integridad referencial, 200.000 pedidos, 50.000 productos, 20.000 clientes.
- **MongoDB** es una **proyección de lectura** del subconjunto pedidos + detalle: permite consultar pedidos completos (con `lineas[]` embebidas) sin `JOIN`. No es fuente de verdad; PostgreSQL manda sobre ella.
- **SQLite** vive en la tablet y necesita operar **sin señal** en la feria: guarda una foto del catálogo (`producto_cache`) y borradores locales (`pedido_borrador`, `item_borrador`, `cola_sync`). Es local, STRICT y liviano.

**Qué viaja a la tablet y qué NO (de `consigna1a_datos_que_viajan.md`):**
- **Viaja:** `id_producto`, `nombre`, `precio_lista` (a centavos enteros), `stock` (como `stock_visto`), `activo` (como `eliminado`) y la fecha de la copia.
- **NO viaja:** datos personales de clientes (nombre, email, teléfono), usuarios/contraseñas, historial de pedidos, categorías, fecha de creación del producto.
- **Motivo:** la tablet necesita lo mínimo para armar un borrador offline; todo lo demás aumenta el riesgo de exponer datos personales en un dispositivo que puede perderse.

Si el docente interrumpe acá, la frase ancla es: *"La tablet guarda una foto y propone un borrador; nunca escribe precio ni stock en el servidor."*

---

## 2. Mapa de la capa de datos (2-3 min) — basado en `mapa_capa_datos.md`

Contar en 3 pasos, apoyándose en el diagrama del `mapa_capa_datos.md` si se proyecta:

1. **Quién manda:** PostgreSQL. Decide precio (`precio_lista`), stock (`stock`), disponibilidad (`activo`) y confirma ventas (`pedido` + `detalle_pedido`).
2. **Quién lee:** MongoDB, con 5 pedidos de prueba (IDs 1–5) y sus líneas embebidas. Es un read model, no se sincroniza en tiempo real con la tablet.
3. **Quién consulta:** SQLite en la tablet, con 4 tablas STRICT: `producto_cache` (copia de lectura), `pedido_borrador`, `item_borrador` y `cola_sync` (bandeja de salida del semáforo).

**Flujo del snapshot (decirlo en una línea encadenada):**
`v_snapshot_movil` (vista en PostgreSQL) → `COPY ... TO STDOUT WITH CSV HEADER` → `servidor_snapshot.csv` → tabla staging `snapshot_servidor` → transformaciones (`t`/`f` → `0`/`1`, `CAST` a `INTEGER`) → `producto_cache`.

Cifras reales para nombrar: CSV de **50.001 líneas** (1 encabezado + 50.000 datos); en `producto_cache`: **50.000** productos, **44.732** disponibles, **5.061** eliminados (baja lógica), precios entre 50.012 y 499.996 centavos, stock visto entre 0 y 200.

**Detalle que hay que decir sí o sí:** el precio viaja en **centavos enteros** (`ROUND(precio_lista * 100)::bigint`) para evitar errores de punto flotante. SQLite es STRICT: si llega un texto a una columna `INTEGER`, rechaza la fila (y así quedó probado: "cannot store TEXT value in INTEGER column").

---

## 3. Caso en vivo — guion de demo (5 min)

Ejecutar desde `TP8/food-store/movil/`. Antes de arrancar: `$env:PYTHONIOENCODING='utf-8'`.

### Paso 1 — Pruebas de la Consigna 1

```powershell
python run_pruebas.py --db foodstore_movil.db --fresh
```

**Resultado esperado (real, `movil/salida_pruebas.txt`):** `RESUMEN: 55 PASS, 0 FAIL, 55 pruebas`.

**Qué decir:** "Las 4 tablas son STRICT, con CHECK y FK. Cubrimos el caso C1 (catálogo disponible sin servidor), el C7 (cantidad 0 y producto inexistente fallan sin dejar filas), un borrador completo con BEGIN…COMMIT y otro deshecho con ROLLBACK, y triangulación de reglas del esquema."

### Paso 2 — Carga del snapshot (Consigna 2.a)

```powershell
python run_cargar_snapshot.py --db foodstore_movil.db --csv servidor_snapshot.csv
```

**Qué decir:** "La vista `v_snapshot_movil` devolvió 50.000 filas en PostgreSQL, verificadas en modo single-user. El CSV va a una tabla staging flexible y de ahí a `producto_cache`, transformando los booleanos `t`/`f` del CSV de psql en `0`/`1`."

**Resultado esperado:** 50.000 productos cargados: 44.732 disponibles, 5.061 eliminados, precios 50.012–499.996 centavos, stock 0–200.

### Paso 3 — Semáforo y casos C2–C6 (Consignas 2.b y 2.c)

```powershell
python simular_casos.py --db foodstore_movil.db
```

Resultados reales documentados en `evidencias_consigna2.md` (narrar caso por caso):

| Caso | Escenario | Resultado a mostrar |
|------|-----------|---------------------|
| **C2** | Cambio de precio del producto 3 (17.8065 → 19.0000… es decir, 178.065 → 190.000 centavos) | **CONFLICTO** ("Cambio de precio detectado"); si el cliente acepta, se actualiza el precio visto y la reevaluación da **SIMULADO_APROBADO** |
| **C3** | Pedir 200 unidades cuando el stock visto es 137 | **RECHAZADO** ("Stock insuficiente") |
| **C4** | Producto dado de baja (baja lógica: `eliminado = 1`, `disponible = 0`) | **RECHAZADO** ("Producto no disponible"); la fila permanece en `producto_cache` (no hay DELETE) |
| **C5** | Sin cambios, todo coincide | **SIMULADO_APROBADO** ("Todo coincide") |
| **C6** | Reenviar la misma `solicitud_uuid` | Error de PK (`UNIQUE constraint failed`); repetir la simulación no reevalúa porque ya no está `PENDIENTE` → idempotencia, sin duplicados |

**Qué decir al final:** "Cerrar con la consulta de no modificación en PostgreSQL: 200.000 pedidos y 700.410 detalles intactos. El semáforo es de solo lectura sobre el servidor: ningún stock descontado, ningún precio cambiado. `SIMULADO_APROBADO` no es una venta."

### Preguntas que puede hacer el docente durante la demo (y respuesta corta)

1. **¿Por qué staging flexible antes de STRICT?** Porque el CSV exportado con `psql` trae booleanos como texto `t`/`f`. `producto_cache` es STRICT y sus `CHECK (disponible IN (0,1))` rechazarían `t`/`f`. La staging absorbe el CSV tal como viene y la carga a `producto_cache` se hace con `CASE WHEN ... IN ('t','true','1') THEN 1 ELSE 0 END`. Nunca se importa directo a la tabla final.
2. **¿Por qué `t`/`f` en el CSV?** Es así como `COPY` de PostgreSQL serializa los booleanos por defecto. No es un error del snapshot: forzar `0/1` en la vista complicaría la vista; se resuelve en la carga.
3. **¿Por qué idempotencia por PK?** La PK `solicitud_uuid` en `cola_sync` impide duplicados a nivel de base, no de aplicación. Además, el semáforo solo evalúa `PENDIENTE`: repetir la simulación no cambia nada. En producción, la protección real vive en el servidor (clave de idempotencia + `ON CONFLICT` + log de solicitudes).
4. **¿Modificaste el servidor?** No. Los resultados de la consulta final (200.000 pedidos, 700.410 detalles, precio del producto 3 = 1.780,65) confirman que PostgreSQL quedó exactamente igual que el snapshot.

---

## 4. Hallazgos del code review con IA (2 min) — basado en `code_review_ia.md`

**Encuadre:** "Revisamos con IA (OpenCode) todos los scripts de la cursada. Salieron **4 hallazgos**: 2 corregidos, 1 aceptado y **1 descartado con fundamento** (no aceptamos todo lo que dijo la IA)."

| # | Script | Hallazgo (una línea) | Decisión |
|---|--------|----------------------|----------|
| 1 | `migracion_mongodb.js` (TP7) | No es idempotente: con `db.pedidos.drop()` comentado, reejecutar falla por `_id` duplicado (`E11000`) y `NamespaceAlreadyExists` | **Corregido** |
| 2 | `consultas_postgresql.sql` (TP7) | La verificación de equivalencia se hizo solo sobre los 5 pedidos de prueba, no sobre los 200.000 reales | **Aceptado** (observación válida sobre el alcance) |
| 3 | `semaforo.sql` (TP8) | Un `pedido_borrador` sin ítems caería en el `ELSE` y sería marcado `SIMULADO_APROBADO`; ninguna de las 55 pruebas cubre ese caso | **Corregido** |
| 4 | `cargar_snapshot.sql` (TP8) | `DELETE FROM producto_cache` con FKs activas fallaría si `item_borrador` referencia productos | **Descartado** |

**El descarte — decirlo con fundamento (es parte explícita de la consigna):** el hallazgo 4 no es un bug sino una **restricción de uso documentada**: el propio `cargar_snapshot.sql` indica que debe ejecutarse vía `run_cargar_snapshot.py`, que desactiva las FKs justo antes del `DELETE` (líneas 83–85 del arnés) y las reactiva después. El flujo previsto ya lo resuelve.

**Si preguntan "¿cómo sabés que la IA no inventó nada?":** cada hallazgo se verificó contra la base real (MongoDB: 5 documentos `_id` 1–5; SQLite: evidencia de las 55 pruebas y del esquema; PostgreSQL por inspección de scripts porque estaba en otro puerto).

---

## 5. Anticipación de preguntas difíciles (8–10 preguntas + respuesta breve)

1. **"¿`SIMULADO_APROBADO` es una venta?"** No. Es el resultado de una simulación local del semáforo en la tablet. La venta se confirma solo en PostgreSQL. La demo lo prueba: tras la simulación, PostgreSQL sigue con 200.000 pedidos y ningún stock descontado.
2. **"¿Qué pasa si dos tablets cargan el mismo `productoUUID` / solicitud?"** En `cola_sync` la PK `solicitud_uuid` rechaza el duplicado (`UNIQUE constraint failed`, caso C6). En un sistema real, la clave de idempotencia única del lado servidor + `ON CONFLICT` + log de solicitudes hace que la segunda solicitud se reconozca como repetida y no genere dos ventas.
3. **"¿Qué pasa si el servidor se cae mientras la tablet vende?"** Nada crítico: la tablet opera offline contra su snapshot (`producto_cache`). El borrador queda en `cola_sync` como `PENDIENTE` y el semáforo lo evaluará cuando haya servidor. Como `SIMULADO_APROBADO` no descuenta stock ni confirma venta, no hay inconsistencia: solo se aplaza la decisión, que sigue siendo del servidor.
4. **"¿Por qué precio en centavos y no float?"** Los floats binarios no representan exactamente decimales (0,10 no es exacto) y sumar precios acumula error. Con centavos en `INTEGER` toda suma es exacta; además SQLite STRICT hace que un texto en esa columna falle. En el borrador de prueba, el total exacto es 220.050 centavos = $2.200,50.
5. **"¿Cómo garantizarías idempotencia real en el servidor?"** Con una clave de idempotencia única derivada de `solicitud_uuid` en la tabla de solicitudes del servidor, `INSERT ... ON CONFLICT DO NOTHING`, un log de solicitudes procesadas y la confirmación bajo en la misma transacción que descuenta stock. Así, un reenvío no duplica la venta (la simulación actual solo la garantiza en SQLite).
6. **"¿Por qué no viajan los datos de clientes?"** Porque la tablet no los necesita para armar un borrador y reduzco el riesgo de exponer datos personales en un dispositivo que se puede perder. El borrador usa un identificador opaco de vendedor (`vendedor1`), sin emails ni nombre real (hay CHECK que rechaza emails en `usuario`).
7. **"¿Qué pasa si se restaura un respaldo viejo de PostgreSQL?"** Las tablets re-sincronizan el catálogo siempre — nunca asumen que su snapshot es válido — y el semáforo reevalúa los borradores `PENDIENTE`/`CONFLICTO`. Los `SIMULADO_APROBADO` no se envían automáticamente: el vendedor los reenvía manualmente.
8. **"¿Y si el borrador no tiene ítems?"** Es el hallazgo 3 del code review: con 0 ítems las `EXISTS` devuelven false y el `ELSE` lo aprobaría como `SIMULADO_APROBADO`. Lo corregimos en la lógica de semáforo con un `NOT EXISTS` → `RECHAZADO` ("Borrador sin ítems"). Ninguna de las 55 pruebas lo cubría, y por eso lo agregamos.
9. **"¿MongoDB puede quedar inconsistente con PostgreSQL?"** Puede: es una proyección de lectura por ETL, no sincronización en tiempo real. Por eso PostgreSQL manda y MongoDB solo sirve consultas de pedidos completos sin `JOIN`. Está respaldado y verificado con validador `$jsonSchema` e índices (`mongodump`/`mongorestore`).
10. **"¿De dónde salen los 55 PASS si no tienen CLI de sqlite3?"** Los entregables son SQL puro (`schema_sqlite.sql`, `pruebas_sqlite.sql`, `semaforo.sql`); el arnés `run_pruebas.py` solo los ejecuta con Python 3.14 + SQLite 3.50.4 (soporta STRICT) y fuerza `PRAGMA foreign_keys = ON` en cada conexión, porque el PRAGMA es por conexión y no queda guardado en el archivo.

---

## 6. Checklist del día de la defensa

**Qué llevar:**
- [ ] Laptop con el entorno andando (Python 3.14, carpeta `movil/`) y las bases de datos: `foodstore_movil.db` (o regenerarla con `--fresh` en 1 minuto), `servidor_snapshot.csv`, y acceso a la copia de `tp_food_store`.
- [ ] Impresas o en PDF: `salida_pruebas.txt` (55 PASS / 0 FAIL), `evidencias_consigna1.md`, `evidencias_consigna2.md`, `mapa_capa_datos.md`, `code_review_ia.md`.
- [ ] `informe.pdf` (máx. 6 páginas) impreso o en el escritorio.
- [ ] Plan B: si no hay proyector, photos/teléfono con `salida_pruebas.txt`; la base SQLite se puede regenerar con `--fresh` y el CSV ya está commiteado en `movil/`.

**Qué NO decir:**
- No decir "lo hizo la IA" sin explicar la decisión propia. En cambio: "la IA propuso X, lo aceptamos/corregimos/descartamos porque Y" (eso es exactamente lo que asienta `bitacora_ia.md` y `DUIA.md`: *"Todo lo que no se puede explicar en la defensa cuenta como no hecho"*).
- No decir "venta aprobada" ni "descontamos stock": decir siempre "borrador", "simulación" y "`SIMULADO_APROBADO` no es una venta".
- No leer tarjetas de memoria: los tres fundamentos de la sección 1 y la regla de oro se dicen de memoria.
- No transcribir salidas "esperadas" como si se hubieran ejecutado: mostrar la salida real (`salida_pruebas.txt`) o ejecutar en vivo.

**Roles sugeridos del equipo (si el docente lo permite):**
- **Presentación + mapa** (2-3 min): el que mejor domina el diagrama de los 3 motores.
- **Demo en vivo** (5 min): quien ejecuta los 3 comandos y narra resultados C2–C6.
- **Hallazgos IA + preguntas** (2 min + ronda): quien presenta la tabla del code review y el descarte fundado.

**Ritmo total sugerido:** fundamentos 1 min → mapa 2-3 min → demo 5 min → hallazgos 2 min → preguntas (resto). Ensayar una vez completa antes de la clase con los comandos reales.
