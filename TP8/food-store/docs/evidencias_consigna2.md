# Evidencias — Consigna 2 (Sincronizar y resolver)

> **Fecha de ejecución:** 2026-11-01
> **Base SQLite:** `movil/foodstore_movil.db`
> **Base PostgreSQL:** `tp_food_store` (puerto 5433, 50.000 productos)

---

## 2.a — La instantánea

### Vista en PostgreSQL

Archivo: `docs/v_snapshot_movil.sql`

```sql
CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT
    p.id_producto                                          AS id,
    p.nombre                                               AS nombre,
    (ROUND(p.precio_lista * 100))::bigint                  AS precio_centavos,
    p.stock                                                AS stock_visto,
    CASE WHEN (p.stock > 0 AND p.activo = TRUE)
         THEN TRUE ELSE FALSE END                           AS disponible,
    CASE WHEN (p.activo = FALSE)
         THEN TRUE ELSE FALSE END                           AS eliminado,
    CURRENT_TIMESTAMP                                      AS fecha_copia
FROM producto p;
```

La vista se creó y verificó mediante el modo single-user de PostgreSQL (`postgres --single`), que devolvió **50.000 filas** sin errores.

### Exportación a CSV

Comando (psql, modo single-user equivalente):
```sql
COPY (SELECT * FROM v_snapshot_movil) TO STDOUT WITH CSV HEADER;
```

Resultado: `movil/servidor_snapshot.csv` — **50.001 líneas** (1 encabezado + 50.000 datos).

### Carga en SQLite

Comando ejecutado:
```powershell
python run_cargar_snapshot.py --db foodstore_movil.db --csv servidor_snapshot.csv
```

Salida:
```
[OK] Tabla staging `snapshot_servidor` creada/limpiada.
[OK] Importadas 50000 filas en snapshot_servidor.
[OK] producto_cache cargado desde snapshot_servidor.

============================================================
EVIDENCIA DE CARGA - Consigna 2.a
============================================================
  Total productos en producto_cache : 50000
  Disponibles (disp=1, elim=0)     : 44732
  Eliminados (baja logica)         : 5061
  Rango de precios (centavos)      : 50012 - 499996
  Rango de stock visto             : 0 - 200
  Filas en snapshot_servidor       : 50000
============================================================
```

Transformaciones aplicadas (booleanos `t`/`f` → `0`/`1`):
- `disponible`: `'t'/'true'/'1'` → `1`, resto → `0`
- `eliminado`: `'t'/'true'/'1'` → `1`, resto → `0`
- `precio_centavos`, `stock_visto`, `id`: `CAST(... AS INTEGER)`

---

## 2.b — El semáforo

Archivo: `movil/semaforo.sql`

Reglas implementadas:
- **RECHAZADO** (Rojo): producto inexistente, no disponible, dado de baja, o stock insuficiente.
- **CONFLICTO** (Amarillo): no hay rojo, pero cambió algún precio (`precio_centavos_visto <> precio_centavos`).
- **SIMULADO_APROBADO** (Verde): todo coincide.

Solo se evalúan solicitudes en estado `PENDIENTE` (idempotencia).

### Resultado de prueba inicial

Con el borrador de prueba (producto 1 × 2 a 50.000 centavos + producto 2 × 1 a 120.050 centavos):

```
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'RECHAZADO', 'Producto no disponible')
```

Motivo: el producto 2 tiene `disponible = 0` y `stock_visto = 0` en el snapshot real.

---

## 2.c — Los casos

Comando ejecutado:
```powershell
python simular_casos.py --db foodstore_movil.db
```

### C2 — Cambio de precio en el servidor

| Paso | Acción | Resultado |
|------|--------|-----------|
| 1 | Subir precio del producto 3 de 178065 → 190000 centavos (simula cambio en servidor) | **CONFLICTO** — Cambio de precio detectado |
| 2 | Cliente acepta → actualiza `precio_centavos_visto` del borrador a 190000 | **SIMULADO_APROBADO** — Todo coincide |

**Explicación:** El semáforo detecta que el precio visto por la tablet (178065) difiere del precio actual del servidor (190000), generando CONFLICTO. Al actualizar el borrador con el nuevo precio, la siguiente evaluación da SIMULADO_APROBADO.

### C3 — Más unidades de las que quedan en stock

| Paso | Acción | Resultado |
|------|--------|-----------|
| 1 | Solicitar 200 unidades del producto 3 (stock disponible: 137) | **RECHAZADO** — Stock insuficiente |

**Explicación:** La cantidad solicitada (200) supera el stock visto en el servidor (137). El semáforo detecta `cantidad > stock_visto` y rechaza la solicitud.

### C4 — Producto dado de baja (baja lógica)

| Paso | Acción | Resultado |
|------|--------|-----------|
| 1 | Marcar producto 3 como eliminado (`eliminado = 1`, `disponible = 0`) | **RECHAZADO** — Producto no disponible |
| 2 | Verificar que el producto sigue en `producto_cache` | Sí — baja lógica, no se borró |

**Explicación:** Al marcar el producto como eliminado, el semáforo detecta `disponible = 0` y rechaza. La fila permanece en `producto_cache` (baja lógica, no DELETE), coherente con la regla "el móvil propone, el servidor dispone".

### C5 — Sin cambios (todo coincide)

| Paso | Acción | Resultado |
|------|--------|-----------|
| 1 | Sin modificaciones en `producto_cache` ni en el borrador | **SIMULADO_APROBADO** — Todo coincide |

**Explicación:** Todos los precios y stocks coinciden entre el borrador y el snapshot. No hay conflictos ni rechazos.

### C6 — Reenviar la misma solicitud (idempotencia)

| Paso | Acción | Resultado |
|------|--------|-----------|
| 1 | Intentar insertar la misma `solicitud_uuid` de nuevo | **OK** — error de PK (`UNIQUE constraint failed`) |
| 2 | Repetir la simulación (solicitud ya no está PENDIENTE) | **SIMULADO_APROBADO** — sin cambios, sin duplicados |

**Explicación:** La PK `solicitud_uuid` impide duplicados. Al re-ejecutar el semáforo, la solicitud ya no está `PENDIENTE`, por lo que no se reevalúa (idempotencia). En un sistema real, la protección viviría del lado servidor: clave de idempotencia única + `ON CONFLICT` + log de solicitudes (parada 8 del apunte).

---

## Consulta final de no modificación (PostgreSQL) — RESULTADOS REALES

Comando ejecutado (modo single-user de PostgreSQL, base `tp_food_store`):

```sql
SELECT count(*) AS total_pedidos FROM pedido;
SELECT count(*) AS total_detalles FROM detalle_pedido;
SELECT id_producto, stock, activo, precio_lista FROM producto WHERE id_producto IN (1, 2, 3);
```

### Resultados obtenidos

| Consulta | Resultado |
|----------|-----------|
| Total pedidos | **200.000** |
| Total detalles | **700.410** |
| Producto 1: stock / activo / precio | 91 / f (false) / 589.96 |
| Producto 2: stock / activo / precio | 0 / t (true) / 4208.34 |
| Producto 3: stock / activo / precio | 137 / t (true) / 1780.65 |

### Verificación de correspondencia con el snapshot

| PostgreSQL | Snapshot (producto_cache) | Coincide |
|------------|---------------------------|----------|
| Producto 1: stock=91, activo=f, precio=589.96 | stock_visto=91, eliminado=1, precio_centavos=58996 | ✅ |
| Producto 2: stock=0, activo=t, precio=4208.34 | stock_visto=0, disponible=0, precio_centavos=420834 | ✅ |
| Producto 3: stock=137, activo=t, precio=1780.65 | stock_visto=137, disponible=1, precio_centavos=178065 | ✅ |

### Conclusión

La simulación (semáforo) es de **solo lectura** sobre PostgreSQL. Los valores de stock, precios y estado de los productos en PostgreSQL son idénticos a los del snapshot cargado en SQLite. Ninguna venta se confirmó, ningún stock se descontó y ningún precio se modificó en el servidor como resultado de la simulación. `SIMULADO_APROBADO` no es una venta.

---

## Archivos generados

| Archivo | Consigna | Descripción |
|---------|----------|-------------|
| `docs/v_snapshot_movil.sql` | 2.a | Vista PostgreSQL para exportar el catálogo |
| `movil/servidor_snapshot.csv` | 2.a | CSV exportado (50.000 filas + encabezado) |
| `movil/cargar_snapshot.sql` | 2.a | SQL para crear staging y cargar producto_cache |
| `movil/run_cargar_snapshot.py` | 2.a | Arnés Python para cargar el snapshot |
| `movil/semaforo.sql` | 2.b | Semáforo de sincronización |
| `movil/simular_casos.py` | 2.c | Simulación de casos C2-C6 |
| `docs/evidencias_consigna2.md` | 2.a-2.c | Este documento |