# Evidencias — Fase 9: Integración TP7 + TP8 (carpeta `integrado/`)

> **Fecha de ejecución:** 2026-11-01
> **PostgreSQL:** 16.15, servicio multi-usuario en `localhost:5432`, base `tp_food_store`, password `postgres`
> **MongoDB:** 9.0, servicio `MongoDB` en `localhost:27017`, base `food_store`, mongosh 2.14.1
> **SQLite (tablet):** `TP8/food-store/movil/foodstore_movil.db`, Python 3.12.10 (sin CLI `sqlite3`)

---

## 1. Qué se ejecutó hoy (2026-11-01), paso a paso

### 1.1 PostgreSQL — reconstrucción de la base `tp_food_store`

La base `tp_food_store` **no existía** en esta instancia de PostgreSQL (la copia preexistente `foodstore_tp2` estaba vacía). Se reconstruyó desde cero con el orden que documenta `integrado/README.md`:

```powershell
$env:PGPASSWORD='postgres'
$psql = 'C:\Program Files\PostgreSQL\16\bin\psql.exe'

& $psql -h localhost -p 5432 -U postgres -c "CREATE DATABASE tp_food_store;"
& $psql -h localhost -p 5432 -U postgres -d tp_food_store -v ON_ERROR_STOP=1 -f TP8/schema.sql
& $psql -h localhost -p 5432 -U postgres -d tp_food_store -v ON_ERROR_STOP=1 -f integrado/seeds/cargar_producto_desde_snapshot.sql
& $psql -h localhost -p 5432 -U postgres -d tp_food_store -v ON_ERROR_STOP=1 -f integrado/seeds/seed_pedidos_tp7.sql
```

Ambos seeds guardan la **coherencia entre motores**: el CSV `TP8/food-store/movil/servidor_snapshot.csv` (exportado de `v_snapshot_movil`) es el mismo dataset que la tablet ya cargó en `producto_cache`, y los 5 pedidos son los de `pedidos.json` del TP7. Este enfoque es el que el plan de diseño (`TP8/food-store/docs/plan_diseno.md` §7, punto 4) ya preveía como copia chica auditable cuando no está disponible la data histórica de 200.000 pedidos.

### 1.2 MongoDB — re-ejecución de la migración

`mongosh` no estaba instalado en el entorno; se instaló a nivel global y se corrió la migración **por stdin** (con `--file` el modo JS estricto rechaza el `use food_store;` del script con `SyntaxError`, por eso stdin es el único modo que funciona con el script sin modificarlo):

```powershell
npm install -g mongosh          # Version instalada: 2.14.1
Get-Content -Raw migracion_mongodb.js | mongosh "mongodb://localhost:27017" --quiet
```

La salida de mongosh incluye líneas de prompt intercaladas con el resultado (ruido normal del modo interactivo); los datos de verificación salieron completos. La base `food_store` estaba vacía desde la instalación del servicio, por lo que la migración creó la colección con validator y documentos desde cero.

### 1.3 SQLite — verificación de la tablet (sin re-generar)

La base `foodstore_movil.db` quedó ya verificada hoy con los arneses del TP8 (`run_pruebas.py --fresh`: **55 PASS / 0 FAIL**; `run_cargar_snapshot.py`: 50.000 productos; `simular_casos.py`: C2–C6; evidencia en `TP8/food-store/docs/evidencias_consigna1.md`). En esta fase se corrió el nuevo arnés **de solo lectura** `integrado/verificar_sqlite.py`.

### 1.4 Verificación global (los 3 motores)

```powershell
# PostgreSQL (solo SELECT)
& $psql -h localhost -p 5432 -U postgres -d tp_food_store -f integrado/verificar_postgresql.sql

# MongoDB (stdin)
Get-Content -Raw integrado/verificar_mongodb.js | mongosh "mongodb://localhost:27017" --quiet

# SQLite tablet (solo lectura)
python integrado/verificar_sqlite.py
```

Salidas completas guardadas en `integrado/evidencias/` con fecha 2026-11-01.

---

## 2. Resultados reales de cada verificación

### 2.1 PostgreSQL (`integrado/evidencias/verificar_postgresql_2026-11-01.txt`)

| Tabla / métrica | Filas |
|---|---|
| `cliente` | **3** |
| `categoria` | **10** |
| `producto` | **50.000** |
| `producto activos` | **44.939** |
| `producto eliminados` (baja lógica) | **5.061** |
| `pedido` | **5** |
| `detalle_pedido` | **10** |

Distribución de forma de pago: `EFECTIVO:2`, `TARJETA:2`, `TRANSFERENCIA:1`.

Índices vistos en `pg_indexes` (sobre `pedido` y `producto`): `pedido_pkey`, `idx_pedido_cliente`, `producto_pkey`, `producto_nombre_key`, `idx_producto_categoria_activo` (parcial `WHERE activo = true`).

Muestra del catálogo (coherente con la tablet): `id_producto 1 = "Producto Cat1-1", precio 589.96, stock 91, activo=f`; `id 2` activo con stock 0, etc.

### 2.2 MongoDB (`integrado/evidencias/verificar_mongodb_2026-11-01.txt`)

```text
Base: food_store
pedidos=5
estados=CONFIRMADO:2 | ENTREGADO:2 | PENDIENTE:1
validator=presente ($jsonSchema)
validationLevel=strict
indices=6 [_id_, id_cliente_1_fecha_pedido_-1, lineas.id_producto_1,
           estado_1, fecha_pedido_-1, monto_total_-1]
pedido_3: cliente=1 estado=PENDIENTE monto=2400.00 lineas=3
```

### 2.3 SQLite tablet (`integrado/evidencias/verificar_sqlite_2026-11-01.txt`)

```text
Base: TP8\food-store\movil\foodstore_movil.db
producto_cache : 50000
pedido_borrador: 1
item_borrador  : 1
cola_sync      : 1
cola_sync por estado:
  SIMULADO_APROBADO: 1
integrity_check : ok
foreign_key_check: ok
```

Pruebas SQL del TP8 (evidencia en `docs/evidencias_consigna1.md`): **55 PASS / 0 FAIL**.

---

## 3. Coherencia entre motores

| Punto de coherencia | PostgreSQL (servidor) | tablet (SQLite) | MongoDB (proyección de lectura) |
|---|---|---|---|
| Identificador de producto | `producto.id_producto` | `producto_cache.id` | `pedidos.lineas[].id_producto` |
| Catálogo | 50.000 filas (del CSV del snapshot) | 50.000 filas en `producto_cache` (mismo CSV) | — (no cachea catálogo) |
| Precio | `precio_lista NUMERIC(10,2)` (ej.: `589.96`) | `precio_centavos` en **enteros** (`58996`); conversión `centavos/100`, nunca float en tablet | `monto_total` como decimales (ej.: `2400.00`) |
| Baja lógica | `activo = FALSE` (5.061 eliminados) | flag `eliminado` del snapshot (`t/f`) | — |
| Pedidos TP7 | filas normalizadas `pedido` + `detalle_pedido` (5 + 10) | — (la tablet solo arma y aprueba borradores) | 5 documentos con `lineas[]` embebidas, mismos ids y montos |
| Ventas | **las decide PostgreSQL** | `SIMULADO_APROBADO` ≠ venta (1 fila en `cola_sync`) | crea `pedidos` tras la confirmación del flujo en un sistema real |

Verificación cruzada de los 5 pedidos: los montos de `pedidos.json` coinciden con `pedido`/`detalle_pedido` en PostgreSQL y con los documentos `pedidos` en MongoDB (pedido `_id:3`, cliente 1, `PENDIENTE`, monto `2400.00`, 3 líneas embebidas).

---

## 4. Qué NO se pudo verificar / recuperar

- La **data histórica de 200.000 pedidos / 50.000 productos / 20.000 clientes** del proyecto Food Store no existe en esta máquina (no hay dump ni acceso a la copia original; la base `foodstore_tp2` preexistente estaba vacía). En su lugar se sembró la **copia chica auditable** prevista por `plan_diseno.md` §7 (punto 4): catálogo completo del snapshot (50.000 productos) + los 5 pedidos del TP7.
- El port 5433 que menciona el README del TP8 para la base con "todos los datos" no se usó hoy: la instancia activa es el servicio en **5432** y queda como única fuente de verdad vigente de esta réplica.
- No se corrió `run_cargar_snapshot.py` / `simular_casos.py` en esta fase (ya corridos hoy sobre la misma base, evidencia en `evidencias_consigna1.md`); el nuevo arnés `verificar_sqlite.py` es de solo lectura y confirma el estado final.

## 5. Variables de entorno y decisiones de hoy

| Decisión | Detalle |
|---|---|
| Servicio PostgreSQL | El servicio multi-usuario `postgresql-x64-16` quedó **funcionando en 5432** con password `postgres`. El crash `0xC0000142` de corrimientos anteriores **ya no se reproduce**; el modo single-user (`postgres --single`) queda como fallback documentado en el README del TP8. |
| `psql` en PATH | No disponible; se usa la ruta completa `C:\Program Files\PostgreSQL\16\bin\psql.exe`. Password se pasa con `$env:PGPASSWORD='postgres'`. |
| mongosh | Instalado globalmente con `npm install -g mongosh` (v2.14.1). Los scripts se corren **por stdin**: `Get-Content -Raw script.js | mongosh "mongodb://localhost:27017" --quiet`. **No** con `--file`: en ese modo el script con `use food_store;` da `SyntaxError` (JS estricto). |
| Python | 3.12.10. Todo lo de SQLite funciona con `sqlite3` estándar; no hay CLI `sqlite3` en el entorno. |