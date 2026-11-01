# integrado/ — TP7 + TP8 unificados (Food Store)

> **Materia:** Base de Datos II — Tecnicatura Universitaria en Programación
> **Carpeta de integración:** reúne los artefactos de los dos TPs (PostgreSQL + MongoDB de la Unidad 7, y la tablet SQLite del TP8) en un único lugar, con el orden exacto para crear todo **desde cero** — orden validado el **2026-11-01** en esta misma máquina.

> **Regla de oro del proyecto:** *El móvil propone, el servidor dispone. La tablet solo consulta y arma borradores. Precio, stock y ventas los decide PostgreSQL. `SIMULADO_APROBADO` no es una venta.*

---

## 0. Requisitos e infraestructura

| Motor | Versión | Dónde | Rol |
|---|---|---|---|
| PostgreSQL | **16** (16.15) | servicio Windows en `localhost:5432` | Servidor, **fuente de verdad** |
| MongoDB | **9.0** | servicio `MongoDB` en `localhost:27017` | Proyección de lectura (pedidos embebidos) |
| SQLite | bundled con Python | `TP8/food-store/movil/foodstore_movil.db` | Tablet: cache + borradores + cola de sync |
| Python | 3.12+ (probado con 3.12.10) | en `PATH` | Arneses de SQLite y de pruebas |
| mongosh | 2.14.1 (instalar con `npm install -g mongosh` si falta) | en `PATH` | Ejecutar scripts JS contra MongoDB |
| `sqlite3` CLI | **no instalado** en esta máquina | — | Todo SQLite se hace con Python |

Contraseña de PostgreSQL usada en esta máquina: `postgres` (exportarla en PowerShell con `$env:PGPASSWORD='postgres'`).

En esta máquina `psql` NO está en el `PATH`; se lo invoca con la ruta completa:

```powershell
$psql = 'C:\Program Files\PostgreSQL\16\bin\psql.exe'
```

---

## 1. Paso 1 — PostgreSQL: crear la base y cargar el esquema

```powershell
# 1.0 Asegurar el servicio corriendo (multi-usuario, puerto 5432).
#     El crash 0xC0000142 de reportes anteriores NO se reproduce (2026-11-01).

$env:PGPASSWORD='postgres'

# 1.1 Crear la base si no existe
& $psql -h localhost -p 5432 -U postgres -c "CREATE DATABASE tp_food_store;"

# 1.2 Cargar el esquema (correr desde la RAIZ del proyecto)
& $psql -h localhost -p 5432 -U postgres -d tp_food_store -v ON_ERROR_STOP=1 -f integrado/schema_postgresql.sql
```

El esquema crea: `enum forma_pago_enum`, tablas `cliente`, `categoria`, `producto`, `pedido`, `detalle_pedido` y los índices `idx_pedido_cliente` e `idx_producto_categoria_activo` (parcial).

---

## 2. Paso 2 — Siembra (los 2 seeds de `seeds/`)

> **¿Por qué siembran y por qué esta data?**
> La data histórica de los **200.000 pedidos / 50.000 productos / 20.000 clientes** NO existe en esta máquina (la base preexistente `foodstore_tp2` estaba vacía). El plan de diseño del TP8 (`TP8/food-store/docs/plan_diseno.md` §7, punto 4) ya preveía esta alternativa: sembrar una **copia chica auditable** con (a) el catálogo completo del snapshot y (b) los 5 pedidos del TP7.
> El CSV `TP8/food-store/movil/servidor_snapshot.csv` —exportado de `v_snapshot_movil`— es el **dataset maestro compartido**: es exactamente el mismo archivo que la tablet cargó en `producto_cache` (50.000 filas), con lo cual PostgreSQL, el CSV y SQLite quedan **coherentes entre sí**.

```powershell
# 2.1 Catálogo: producto + categoria desde el CSV del snapshot
#     (correr desde la RAIZ: el \copy usa la ruta relativa TP8/food-store/movil/...)
& $psql -h localhost -p 5432 -U postgres -d tp_food_store -v ON_ERROR_STOP=1 `
    -f integrado/seeds/cargar_producto_desde_snapshot.sql

# 2.2 Los 5 pedidos del TP7 (pedidos.json) reconstruidos como filas
& $psql -h localhost -p 5432 -U postgres -d tp_food_store -v ON_ERROR_STOP=1 `
    -f integrado/seeds/seed_pedidos_tp7.sql
```

**Resultados esperados reales (verificados 2026-11-01):**

| Seed | Tabla | Filas |
|---|---|---|
| 2.1 | `categoria` | **10** |
| 2.1 | `producto` | **50.000** (activos **44.939**, eliminados **5.061**) |
| 2.2 | `cliente` | **3** |
| 2.2 | `pedido` | **5** |
| 2.2 | `detalle_pedido` | **10** |

---

## 3. Paso 3 — MongoDB: migración de los pedidos

```powershell
# 3.1 Si mongosh no está instalado:
npm install -g mongosh

# 3.2 Correr la migración — IMPORTANTE: POR STDIN, no con --file
Get-Content -Raw migracion_mongodb.js | mongosh "mongodb://localhost:27017" --quiet
```

> **¿Por qué stdin y no `--file`?** `mongosh` compila los archivos cargados con `--file` en **modo JS estricto**, donde `use food_store;` (instrucción shell, no JS) es un `SyntaxError`. Enviando el script **por stdin** corre en modo shell interactivo y `use` funciona. Es la misma forma de ejecución que documenta el README original (`mongosh < migracion_mongodb.js`). El script se corre **sin modificar**, tal como fue entregado.

**Resultados esperados reales (verificados 2026-11-01):**

- Base `food_store`, colección `pedidos` con **5 documentos** (estados: `CONFIRMADO:2`, `ENTREGADO:2`, `PENDIENTE:1`).
- **Validator `$jsonSchema` presente**, `validationLevel: strict`.
- **6 índices**: `_id_`, `id_cliente_1_fecha_pedido_-1`, `lineas.id_producto_1`, `estado_1`, `fecha_pedido_-1`, `monto_total_-1`.
- Pedido `_id: 3` → cliente 1, estado `PENDIENTE`, monto `2400.00`, **3 líneas** embebidas.

---

## 4. Paso 4 — SQLite (tablet)

Todos los arneses corren desde `TP8/food-store/movil/`:

```powershell
cd TP8\food-store\movil

# 4.1 Esquema + pruebas (crea la base y valida C1/C7/COMMIT/ROLLBACK)
python run_pruebas.py --db foodstore_movil.db --fresh
# Esperado: 55 PASS, 0 FAIL

# 4.2 Cargar el snapshot del catálogo (el mismo CSV que PostgreSQL sembró)
python run_cargar_snapshot.py --db foodstore_movil.db --csv servidor_snapshot.csv
# Esperado: producto_cache = 50.000

# 4.3 Semáforo de sincronización (no hay CLI sqlite3: se ejecuta con Python,
#     ver run_pruebas.py como referencia; semaforo.sql es el SQL)

# 4.4 Casos C2-C6 y consulta final de no modificación
python simular_casos.py --db foodstore_movil.db
```

Evidencias de estas corridas: `TP8/food-store/docs/evidencias_consigna1.md` (55/0) y `movil/salida_pruebas.txt`.

Estado verificado de la base tablet (2026-11-01): `producto_cache=50000`, `pedido_borrador=1`, `item_borrador=1`, `cola_sync=1` (estado `SIMULADO_APROBADO`). `SIMULADO_APROBADO` **no es una venta**: el vendedor aprobaría la venta desde la app, y en un sistema real el pedido confirmado viajaría a PostgreSQL.

---

## 5. Paso 5 — Verificación global (los 3 motores)

```powershell
# 5.1 PostgreSQL (solo SELECT: conteos + índices + muestra)
$env:PGPASSWORD='postgres'
& $psql -h localhost -p 5432 -U postgres -d tp_food_store -f integrado/verificar_postgresql.sql

# 5.2 MongoDB (por stdin, mismo motivo que el Paso 3)
Get-Content -Raw integrado/verificar_mongodb.js | mongosh "mongodb://localhost:27017" --quiet

# 5.3 SQLite (desde la RAIZ del proyecto; el arnés abre TP8/food-store/movil/foodstore_movil.db)
python integrado/verificar_sqlite.py
```

Salidas reales de las tres corridas: `integrado/evidencias/` (`verificar_postgresql_2026-11-01.txt`, `verificar_mongodb_2026-11-01.txt`, `verificar_sqlite_2026-11-01.txt`).

También hay consultas de práctica de Unidad 7 reutilizables: `consultas_postgresql.sql` (botones b/c en SQL) y `consultas_mongodb.js` (equivalentes en MongoDB), con su comparación documentada en `docs_tp7/verificacion_consultas.md`.

---

## 6. Cómo se conectan los 3 motores

```text
                                        ┌──────────────────────┐
                                        │  PostgreSQL 16 :5432 │
                                        │  tp_food_store       │
                                        │  (FUENTE DE VERDAD)  │
                                        │  producto 50.000     │
                                        │  pedido 5 / detalle 10│
                                        └──────────┬───────────┘
                                                   │  vista
                                                   ▼
                                        v_snapshot_movil
                                                   │  exportación
                                                   ▼
                              servidor_snapshot.csv  (dataset maestro compartido)
                                                   │  staging + carga
                             ┌─────────────────────┤
                             │ (servidor)          │ (tablet)
                             ▼                     ▼
                    producto (SQL)        ┌────────────────────────┐
                                          │ SQLite (tablet)        │
                                          │ producto_cache 50.000  │
                                          │ pedido_borrador 1      │
                                          │ item_borrador 1        │
                                          │ semaforo.sql           │
                                          │ cola_sync 1            │
                                          └───────────┬────────────┘
                                                      │  SIMULADO_APROBADO ≠ venta
                                                      ▼  (en un sistema real: sync)
                                                  pedidos a PostgreSQL
                                          ┌────────────────────────┐
                                          │ MongoDB 9 :27017       │
                                          │ food_store.pedidos     │
                                          │ 5 docs, lineas[]       │
                                          │ (proyección de lectura)│
                                          └────────────────────────┘
```

Puntos clave de coherencia:

- **Mismo identificador:** `id_producto` en PostgreSQL ↔ `id` en `producto_cache` (SQLite) ↔ `lineas[].id_producto` en MongoDB.
- **Precios:** la tablet ve **centavos** (`precio_centavos`, enteros); el servidor usa `NUMERIC(10,2)` (`precio_lista`). La conversión es `centavos / 100` y **nunca** float en el lado tablet.
- **Los 5 pedidos del TP7** existen en ambos lados: como filas normalizadas en PostgreSQL (`pedido`+`detalle_pedido`) y como documentos con `lineas[]` embebidas en MongoDB.

---

## 7. Mapa de documentos de TP7 y TP8

| Documento | Ubicación | Qué aporta al integrado |
|---|---|---|
| `schema.sql` | `TP8/` (copia: `integrado/schema_postgresql.sql`) | DDL del servidor: 5 tablas + enum + índices (Paso 1) |
| `esquema_nosql_pedidos.md` | `integrado/docs_tp7/` | Diseño del esquema NoSQL: pedido embebido con `lineas[]` (justifica `migracion_mongodb.js`) |
| `guia_migracion.md` | `integrado/docs_tp7/` | Guía de replicación del entorno MongoDB hasta la Consigna 2 (base del Paso 3) |
| `verificacion_consultas.md` | `integrado/docs_tp7/` | Comparación consultas equivalentes PostgreSQL ↔ MongoDB (Consigna 5) |
| `consigna6_ia.md` / `consigna7_conclusion.md` | `integrado/docs_tp7/` | Comparación IA de PostgreSQL vs MongoDB y contraste con documentación oficial |
| `migracion_mongodb.js`, `consultas_*.js/.sql`, `pedidos.json` | raíz del proyecto (idénticos en TP7/entrega; copias en `integrado/`) | Scripts operativos y dataset de los 5 pedidos |
| `v_snapshot_movil.sql` | `TP8/food-store/docs/` | Vista PostgreSQL que alimenta el CSV (conexión servidor → tablet) |
| `plan_diseno.md` | `TP8/food-store/docs/` | Plan de fases del TP8; §7 prevé la copia chica auditable sembrada en el Paso 2 |
| `evidencias_consigna1.md`, `movil/salida_pruebas.txt` | `TP8/food-store/docs/` | Evidencias de las 55 pruebas SQLite (Paso 4) |
| `evidencia_integracion.md` | `integrado/docs/` | Evidencia de la fase 9 de integración (esta corrida, 2026-11-01) |

## 8. Contenido de esta carpeta

```text
integrado/
├── README.md                             ← este documento
├── schema_postgresql.sql                 ← copia de TP8/schema.sql con encabezado
├── migracion_mongodb.js                  ← copia del script de migración
├── pedidos.json                          ← copia del dataset de 5 pedidos
├── consultas_postgresql.sql              ← copia de consultas (Consigna 5)
├── consultas_mongodb.js                  ← copia de consultas (Consigna 4 b/c)
├── verificar_postgresql.sql              ← arnés de verificación PostgreSQL (solo lectura)
├── verificar_sqlite.py                   ← arnés de verificación SQLite tablet (solo lectura)
├── verificar_mongodb.js                  ← arnés de verificación MongoDB (solo lectura)
├── seeds/
│   ├── cargar_producto_desde_snapshot.sql ← siembra producto+categoria desde el CSV
│   └── seed_pedidos_tp7.sql               ← siembra de los 5 pedidos del TP7
├── docs_tp7/                             ← los 5 documentos md del TP7 (copia)
├── docs/
│   └── evidencia_integracion.md          ← evidencia de la fase 9
└── evidencias/                           ← salidas reales de los 3 arneses (2026-11-01)
```
