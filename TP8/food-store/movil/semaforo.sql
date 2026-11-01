-- ============================================================================
-- semaforo.sql — Consigna 2.b
-- Semáforo de sincronización: compara cada solicitud PENDIENTE con el
-- snapshot del servidor (producto_cache) y guarda en cola_sync el estado
-- y el motivo.
--
-- Regla de oro: el móvil propone, el servidor dispone. SIMULADO_APROBADO
-- NO es una venta. Solo se evalúan solicitudes PENDIENTE (idempotencia).
--
-- Estados:
--   RECHAZADO        → algún producto no existe, no está disponible,
--                      fue dado de baja o no alcanza el stock.
--   CONFLICTO        → no hay rojo, pero cambió algún precio.
--   SIMULADO_APROBADO → todo coincide.
--
-- Ejecución:
--   sqlite3 foodstore_movil.db < semaforo.sql
--   (o via run_pruebas.py adaptado)
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- Semáforo principal: actualiza cola_sync para solicitudes PENDIENTE.
-- Para cada solicitud, se evalúan todos sus ítems contra producto_cache.
-- ----------------------------------------------------------------------------

UPDATE cola_sync
SET
    estado = (
        SELECT CASE
            -- ROJO: algún ítem tiene problema de existencia/disponibilidad/stock
            WHEN EXISTS (
                SELECT 1
                FROM item_borrador i
                LEFT JOIN producto_cache p ON p.id = i.producto_id
                WHERE i.id_local = cola_sync.id_local
                  AND (
                      p.id IS NULL                          -- producto no existe
                      OR p.disponible = 0                   -- no disponible
                      OR p.eliminado = 1                    -- dado de baja
                      OR i.cantidad > p.stock_visto         -- stock insuficiente
                  )
            ) THEN 'RECHAZADO'

            -- AMARILLO: no hay rojo, pero cambió algún precio
            WHEN EXISTS (
                SELECT 1
                FROM item_borrador i
                JOIN producto_cache p ON p.id = i.producto_id
                WHERE i.id_local = cola_sync.id_local
                  AND i.precio_centavos_visto <> p.precio_centavos
            ) THEN 'CONFLICTO'

            -- VERDE: todo coincide
            ELSE 'SIMULADO_APROBADO'
        END
    ),
    motivo = (
        SELECT CASE
            -- Motivo para RECHAZADO
            WHEN EXISTS (
                SELECT 1
                FROM item_borrador i
                LEFT JOIN producto_cache p ON p.id = i.producto_id
                WHERE i.id_local = cola_sync.id_local
                  AND p.id IS NULL
            ) THEN 'Producto inexistente en el catálogo'

            WHEN EXISTS (
                SELECT 1
                FROM item_borrador i
                JOIN producto_cache p ON p.id = i.producto_id
                WHERE i.id_local = cola_sync.id_local
                  AND p.disponible = 0
            ) THEN 'Producto no disponible'

            WHEN EXISTS (
                SELECT 1
                FROM item_borrador i
                JOIN producto_cache p ON p.id = i.producto_id
                WHERE i.id_local = cola_sync.id_local
                  AND p.eliminado = 1
            ) THEN 'Producto dado de baja (baja lógica)'

            WHEN EXISTS (
                SELECT 1
                FROM item_borrador i
                JOIN producto_cache p ON p.id = i.producto_id
                WHERE i.id_local = cola_sync.id_local
                  AND i.cantidad > p.stock_visto
            ) THEN 'Stock insuficiente'

            -- Motivo para CONFLICTO
            WHEN EXISTS (
                SELECT 1
                FROM item_borrador i
                JOIN producto_cache p ON p.id = i.producto_id
                WHERE i.id_local = cola_sync.id_local
                  AND i.precio_centavos_visto <> p.precio_centavos
            ) THEN 'Cambio de precio detectado'

            -- Motivo para SIMULADO_APROBADO
            ELSE 'Todo coincide: stock y precio sin cambios'
        END
    )
WHERE estado = 'PENDIENTE';

-- ----------------------------------------------------------------------------
-- Consulta de verificación post-semáforo
-- ----------------------------------------------------------------------------
-- SELECT solicitud_uuid, id_local, estado, motivo FROM cola_sync;