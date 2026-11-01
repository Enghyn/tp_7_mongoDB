# Consigna 3.b — Plan de mantenimiento

> **Consigna:** 3.b · Plan de mantenimiento (5 puntos)
> **Formato:** Agregado al plan de mantenimiento de la Unidad 6, pocas líneas.

---

## Plan de mantenimiento — Capa de datos Food Store

### 1. ¿Qué se respalda y cómo se prueba la restauración?

| Componente | Qué se respalda | Cómo se prueba la restauración |
|------------|----------------|-------------------------------|
| **PostgreSQL** (servidor) | Base completa `tp_food_store`: esquema + datos (clientes, productos, pedidos, detalles). Backup con `pg_dump` (formato custom o SQL). | Restaurar en un servidor de pruebas (instancia separada) y ejecutar consultas de verificación: `SELECT count(*) FROM pedido`, `SELECT count(*) FROM producto`, `SELECT count(*) FROM cliente`. Comparar contra los valores esperados (200.000 pedidos, 50.000 productos, 20.000 clientes). |
| **MongoDB** (servidor) | Colección `pedidos` (subconjunto migrado). Backup con `mongodump` o exportación JSON. | Restaurar con `mongorestore` y verificar: `db.pedidos.countDocuments()` = 5, `db.pedidos.getIndexes()` = 6 índices, validador `$jsonSchema` activo. |
| **SQLite** (tablet) | Archivo `foodstore_movil.db` completo (esquema + datos: producto_cache, pedido_borrador, item_borrador, cola_sync). Copia del archivo `.db`. | Copiar el archivo a una tablet de prueba, ejecutar `PRAGMA integrity_check;` (debe retornar `ok`), verificar que `producto_cache` tiene datos y que las FK están activas (`PRAGMA foreign_keys = ON`). |

**Frecuencia:** Backup diario de PostgreSQL (automatizado con `pg_dump` + cron/tarea programada). Backup de MongoDB semanal (o tras cada migración). Backup de SQLite por tablet: manual, al finalizar cada jornada de venta (copiar el `.db` a un medio seguro).

---

### 2. Si se restaura un respaldo viejo de PostgreSQL, ¿qué hacen las tablets?

**Escenario:** El servidor se restaura a un estado anterior (por ejemplo, un backup de hace 3 días). Los productos pueden tener stock o precios diferentes a los que la tablet tiene en su snapshot.

**Comportamiento esperado de las tablets:**

1. **Re-sincronización obligatoria:** Al detectar que el servidor se restauró (la tablet compara la fecha del snapshot con la fecha del servidor, o recibe una señal de "resync"), la tablet debe descargar un snapshot nuevo (`v_snapshot_movil` → CSV → `producto_cache`).
2. **Borradores pendientes:** Los borradores en `cola_sync` con estado `PENDIENTE` o `CONFLICTO` deben re-evaluarse contra el nuevo snapshot. El semáforo se re-ejecuta automáticamente.
3. **Conflictos nuevos:** Si el servidor restaurado tiene stock o precios diferentes, los borradores que antes eran `SIMULADO_APROBADO` pueden pasar a `CONFLICTO` o `RECHAZADO`. El vendedor debe resolver cada caso individualmente.
4. **Borradores SIMULADO_APROBADO:** No se envían automáticamente. El vendedor debe re-enviarlos manualmente tras la re-sincronización.
5. **Regla de oro:** La tablet nunca asume que su snapshot es válido tras una restauración del servidor. Siempre re-sincroniza.

**Procedimiento:**
1. Servidor restaurado → notificar a las tablets (o las tablets detectan por fecha de snapshot).
2. Tablet descarga nuevo snapshot → actualiza `producto_cache`.
3. Tablet re-ejecuta semáforo sobre borradores pendientes.
4. Vendedor revisa estados `CONFLICTO` y `RECHAZADO` y decide.

---

### 3. ¿Cada cuánto y quién revisa las solicitudes en CONFLICTO o RECHAZADO?

| Aspecto | Detalle |
|---------|---------|
| **Frecuencia** | Al final de cada jornada de venta (cierre de caja). Adicionalmente, cada vez que se re-sincroniza el catálogo (tras restauración o actualización del servidor). |
| **Responsable** | El **vendedor responsable de la tablet** (usuario opaco, sin datos personales) revisa sus propias solicitudes. El **administrador de Food Store** revisa las solicitudes de todas las tablets en un panel central (consulta sobre `cola_sync` de cada tablet). |
| **Qué se revisa** | Solicitudes en estado `CONFLICTO` (cambio de precio: el vendedor decide si acepta el nuevo precio o cancela) y `RECHAZADO` (stock insuficiente o producto eliminado: el vendedor cancela o modifica la cantidad). |
| **Acción** | `CONFLICTO`: actualizar el precio del borrador y re-enviar → nueva evaluación. `RECHAZADO`: cancelar el borrador o modificar la cantidad y re-enviar. |
| **Registro** | Toda acción (aceptar, cancelar, modificar) se registra en `cola_sync` con el motivo actualizado. No se borran solicitudes; se mantienen como historial. |

---

## Resumen

- **Backup:** PostgreSQL diario (pg_dump), MongoDB semanal, SQLite por tablet al cierre de jornada.
- **Restauración vieja de PostgreSQL:** Las tablets re-sincronizan el catálogo y re-evalúan borradores pendientes. Los `SIMULADO_APROBADO` no se envían automáticamente.
- **Revisión de CONFLICTO/RECHAZADO:** Al cierre de cada jornada, por el vendedor (sus solicitudes) y el administrador (todas las tablets). Toda acción queda registrada.