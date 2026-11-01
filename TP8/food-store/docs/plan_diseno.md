# Plan de diseño — TP8 Food Store (Unidad 8)

> **Materia:** Base de Datos II — Tecnicatura Universitaria en Programación
> **Proyecto:** Food Store — cierre de la capa de datos (PostgreSQL + MongoDB + SQLite)
> **Alcance de este documento:** decisiones de diseño y orden de trabajo. No reemplaza el informe final.

---

## 1. Objetivo

Construir la base de la tablet en SQLite, simular la sincronización contra PostgreSQL con un semáforo y cerrar la capa de datos del proyecto con un mapa de los tres motores, un plan de mantenimiento y una revisión con IA.

**Regla de oro:** el móvil propone, el servidor dispone. La tablet solo consulta y arma borradores; precio, stock y ventas los decide PostgreSQL. `SIMULADO_APROBADO` **no** es una venta.

---

## 2. Continuidad con el TP7

| Elemento del TP7 | Uso en TP8 |
|---|---|
| Esquema PostgreSQL real (`TP8/schema.sql`) | Fuente de verdad para `v_snapshot_movil` y `producto_cache`. |
| Colección `pedidos` con `lineas[]` embebidas | Tercer motor del mapa 3.a. |
| 5 pedidos y productos 1–6 (`migracion_mongodb.js` / `pedidos.json`) | Semilla de continuidad para la copia de pruebas y los casos C2–C6. |
| `consultas_mongodb.js` y `consultas_postgresql.sql` | Material del code review 3.c. |
| Conclusión TP7 (PostgreSQL fuente de verdad) | Fundamento de la regla de oro. |

TP8 **no** modifica la migración a MongoDB: la usa como motor de lectura y como objeto de revisión.

---

## 3. Decisiones de diseño

### 3.1 Qué datos viajan a la tablet

Solo el catálogo mínimo necesario para armar un borrador sin señal:

- **Viajan:** `id_producto`, `nombre`, `precio_lista` (convertido a centavos), `stock`, `activo` (como `eliminado`) y la fecha de copia.
- **No viajan:** datos de cliente (nombre, email, teléfono), usuarios/contraseñas, historial de pedidos, categorías y cualquier dato personal.
- **Fuente de verdad:** PostgreSQL. La tablet guarda una **copia de lectura**; nunca escribe precio ni stock en el servidor.

### 3.2 Mapeo PostgreSQL → SQLite

| PostgreSQL | SQLite (`producto_cache`) | Regla |
|---|---|---|
| `id_producto` | `id` | Se conserva el identificador. |
| `nombre` | `nombre` | Texto no vacío. |
| `precio_lista NUMERIC(10,2)` | `precio_centavos INTEGER` | `ROUND(precio_lista * 100)::bigint`; nunca float. |
| `stock INTEGER` | `stock_visto INTEGER` | Solo lectura; `>= 0`. |
| `stock > 0 AND activo` | `disponible INTEGER` | `0` o `1`. |
| `NOT activo` | `eliminado INTEGER` | `0` o `1` (baja lógica). |
| fecha de exportación | `fecha_copia TEXT` | ISO 8601. |

### 3.3 Snapshot y booleanos `t/f`

`v_snapshot_movil` se exporta a CSV con `psql`. En ese CSV los booleanos salen como `t`/`f`, por lo que:

1. `snapshot_servidor` es una tabla **staging** (tipos flexibles).
2. `producto_cache` se carga con `CASE WHEN ... IN ('t','true','1') THEN 1 ELSE 0 END`.
3. Nunca se importa directo a `producto_cache`, porque sus `CHECK (disponible IN (0,1))` rechazarían `t`/`f`.

### 3.4 Semáforo e idempotencia

- Solo se evalúan solicitudes en estado `PENDIENTE`.
- **Rojo → `RECHAZADO`:** producto inexistente, no disponible, eliminado o stock insuficiente.
- **Amarillo → `CONFLICTO`:** no hay rojo, pero cambió algún precio.
- **Verde → `SIMULADO_APROBADO`:** todo coincide.
- Repetir la simulación no reevalúa: las solicitudes ya no están `PENDIENTE`.
- La PK de `cola_sync` (`solicitud_uuid`) impide duplicados. En un sistema real la protección vive del lado servidor (clave de idempotencia única + `ON CONFLICT` + log de solicitudes).

### 3.5 Ejecución sin `sqlite3` CLI

En este entorno no está instalado el CLI de SQLite, pero sí Python 3.14 con SQLite 3.50.4 (soporta `STRICT`). Por eso:

- Los entregables son **SQL puro** (`schema_sqlite.sql`, `pruebas_sqlite.sql`, `semaforo.sql`).
- Se incluye `movil/run_pruebas.py` como arnés de ejecución y evidencia (TP8 permite Python para la simulación).
- `PRAGMA foreign_keys = ON` se ejecuta en **cada conexión**; el arnés lo garantiza.

---

## 4. Estructura de la entrega

```
TP8/food-store/
├── README.md                      ← orden para crear todo desde cero (consigna 4.c)
├── movil/
│   ├── schema_sqlite.sql          ← consigna 1.b
│   ├── pruebas_sqlite.sql         ← consigna 1.c
│   ├── semaforo.sql               ← consigna 2.b (o simulador.py)
│   ├── servidor_snapshot.csv      ← consigna 2.a
│   ├── foodstore_movil.db         ← base generada
│   ├── salida_pruebas.txt         ← evidencia de la ejecución
│   ├── run_pruebas.py             ← arnés de ejecución (extra, permitido)
│   └── README.md                  ← cómo ejecutar las pruebas
└── docs/
    ├── plan_diseno.md             ← este documento
    ├── consigna1a_datos_que_viajan.md
    ├── evidencias_consigna1.md    ← salida real de las pruebas
    ├── informe.pdf                ← se arma aparte
    ├── kiro/
    │   ├── requirements.md        ← 4 requisitos EARS (consigna 4.a)
    │   ├── design.md
    │   └── tasks.md
    ├── bitacora_ia.md             ← consigna 4.b
    └── DUIA.md
```

El esquema PostgreSQL de referencia es `TP8/schema.sql` (copia fiel del proyecto Food Store). Al cerrar la entrega se copia a `food-store/db/schema.sql` para que el zip sea autocontenido.

---

## 5. Orden de implementación

| Fase | Consigna | Entregable | Depende de PostgreSQL | Estado |
|---|---|---|---|---|
| 1 | 1.a | Tabla de datos que viajan + justificación | No | ✅ |
| 2 | 1.b | `schema_sqlite.sql` con 4 tablas `STRICT` | No | ✅ |
| 3 | 1.c | `pruebas_sqlite.sql` (C1, C7, COMMIT/ROLLBACK) | No | ✅ 55/55 |
| 4 | 2.a | `v_snapshot_movil` + CSV + carga de `producto_cache` | **Sí** | ✅ |
| 5 | 2.b | `semaforo.sql` | Parcial (se prueba con CSV sintético) | ✅ |
| 6 | 2.c | Casos C2–C6 + consulta final de no modificación | **Sí** | ✅ |
| 7 | 3.a-3.c | Mapa, mantenimiento y code review | Parcial | ✅ |
| 8 | 4.a-4.c | Kiro, bitácora, DUIA, README y defensa | No | ✅ |
| 9 | Integración | Unificar TP7 + TP8 (carpeta `integrado/` en la raíz del workspace) | No | ✅ |

Mientras no haya acceso a PostgreSQL se avanza con las fases 1–3, 5 (con CSV sintético) y 8. Las fases 4 y 6 se completan cuando esté disponible la copia de pruebas.

**Estado al 2026-11-01:** Consigna 1 completa. `schema_sqlite.sql` y `pruebas_sqlite.sql` ejecutados con `run_pruebas.py` sobre `foodstore_movil.db`: **55 PASS, 0 FAIL**. Evidencia en `docs/evidencias_consigna1.md` y `movil/salida_pruebas.txt`.

**Estado integración (2026-11-01):** carpeta raíz `integrado/` creada con cuestionarios PostgreSQL + MongoDB + SQLite verificados (seeds de producto+categoría y de los 5 pedidos del TP7 ya corridos; salidas reales en `integrado/evidencias/`, evidencia en `integrado/docs/evidencia_integracion.md`).

---

## 6. Criterios de aceptación de la Consigna 1

- [x] `schema_sqlite.sql` empieza con `PRAGMA foreign_keys = ON;`.
- [x] Las 4 tablas son `STRICT`.
- [x] `producto_cache` tiene precio en centavos entero y no negativo; `disponible`/`eliminado` solo `0` o `1`.
- [x] `pedido_borrador.forma_pago` solo admite `EFECTIVO`, `TARJETA`, `TRANSFERENCIA`.
- [x] `item_borrador` tiene FK a `pedido_borrador` y a `producto_cache`; `cantidad > 0`.
- [x] `cola_sync` tiene PK `solicitud_uuid` y estado limitado a `PENDIENTE`, `CONFLICTO`, `RECHAZADO`, `SIMULADO_APROBADO`.
- [x] `pruebas_sqlite.sql` demuestra un borrador completo con `BEGIN`/`COMMIT` y una operación deshecha con `ROLLBACK`.
- [x] Caso C1: el catálogo disponible se consulta sin servidor.
- [x] Caso C7: cantidad `0` y producto inexistente fallan y no dejan filas nuevas.

---

## 7. Pendientes y riesgos

1. **Acceso a PostgreSQL:** el servidor 17.11 está corriendo en `localhost:5432`, pero pide contraseña. Se necesita para la fase 4 y 6.
2. **Apunte de la Unidad 8:** no está en el repo; la definición exacta de `v_snapshot_movil` (parada 5) se confirmará con el apunte. Mientras tanto se usa la forma deducida de las columnas de `producto_cache`.
3. ~~**`INFORME.pdf`:** se arma aparte, según indicación del equipo.~~ **Resuelto (2026-11-01):** el informe quedó listo en `docs/informe.pdf` (5 páginas, dentro del máximo de 6), con fuente en `docs/informe.md` y `docs/informe.html`, más el ensayo de defensa en `docs/ensayo_defensa.md`.
4. **Datos de prueba:** se usará una copia chica y auditable (productos 1–7 y los 5 pedidos del TP7) para que los casos C2–C6 sean reproducibles.
5. **Evidencias:** todas las salidas deben ser reales; no se transcriben resultados “esperados” como si se hubieran ejecutado (debilidad detectada en el TP7).
