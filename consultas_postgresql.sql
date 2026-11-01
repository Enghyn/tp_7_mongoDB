-- ============================================================================
-- TRABAJO PRÁCTICO UNIDAD 7 - FOOD STORE
-- Parte 2: Consultas de verificación en PostgreSQL (Consigna 5)
-- Equivalente a las consultas b) y c) de MongoDB (Consigna 4)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Nota sobre la columna `estado`
-- El esquema original (schema.sql) de la tabla `pedido` no incluye `estado`
-- (solo fecha_pedido y forma_pago). La consigna del TP indica que se
-- "respetarán los ... estados existentes", por lo que se asume que el equipo
-- ya cuenta con esta columna en su PostgreSQL. Para que este script sea
-- autocontenido y ejecutable, se agrega la columna si no existe (sentencia
-- inocua si ya está presente).
-- ----------------------------------------------------------------------------
ALTER TABLE pedido
    ADD COLUMN IF NOT EXISTS estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE'
    CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'ENTREGADO', 'CANCELADO'));

-- ============================================================================
-- Datos de prueba (sample data) equivalentes a los 5 pedidos migrados a MongoDB
-- IDs conservados: 1, 2, 3, 4, 5 (mismo valor que _id en MongoDB)
-- ============================================================================
-- Limpieza opcional de los datos de prueba (descomentar para reiniciar):
-- DELETE FROM detalle_pedido WHERE id_pedido IN (1, 2, 3, 4, 5);
-- DELETE FROM pedido WHERE id_pedido IN (1, 2, 3, 4, 5);

-- Insertar pedidos (se fuerza id_pedido por ser columna IDENTITY)
INSERT INTO pedido (id_pedido, id_cliente, fecha_pedido, forma_pago, estado)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, TIMESTAMPTZ '2026-01-10T10:00:00Z', 'EFECTIVO',       'CONFIRMADO'),
    (2, 2, TIMESTAMPTZ '2026-01-11T11:30:00Z', 'TARJETA',         'ENTREGADO'),
    (3, 1, TIMESTAMPTZ '2026-01-12T14:15:00Z', 'TRANSFERENCIA',   'PENDIENTE'),
    (4, 3, TIMESTAMPTZ '2026-01-13T16:45:00Z', 'EFECTIVO',       'CONFIRMADO'),
    (5, 2, TIMESTAMPTZ '2026-01-14T09:20:00Z', 'TARJETA',         'ENTREGADO')
ON CONFLICT (id_pedido) DO NOTHING;

-- Insertar líneas de detalle (id_producto, cantidad, precio_unitario_facturado)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario_facturado)
VALUES
    (1, 1, 2, 500.00),
    (1, 2, 1, 1200.50),
    (2, 3, 4, 350.00),
    (3, 1, 1, 500.00),
    (3, 4, 2, 850.00),
    (3, 5, 1, 200.00),
    (4, 2, 2, 1200.50),
    (4, 6, 3, 150.00),
    (5, 5, 5, 200.00),
    (5, 3, 2, 350.00)
ON CONFLICT (id_pedido, id_producto) DO NOTHING;

-- Sincronizar la secuencia de id_pedido para futuras inserciones (opcional)
SELECT setval(pg_get_serial_sequence('pedido', 'id_pedido'),
              COALESCE((SELECT MAX(id_pedido) FROM pedido), 1));

-- ============================================================================
-- Consulta b (Equivalente a 4b): Filtrar pedidos por estado 'ENTREGADO'
-- Resultado esperado: pedidos 2 y 5
-- ============================================================================
SELECT
    id_pedido,
    estado
FROM pedido
WHERE estado = 'ENTREGADO'
ORDER BY id_pedido ASC;

-- ============================================================================
-- Consulta c (Equivalente a 4c): Buscar pedidos que contengan el producto con ID 1
-- Resultado esperado: pedidos 1 y 3
-- ============================================================================
SELECT DISTINCT
    p.id_pedido
FROM pedido p
INNER JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
WHERE dp.id_producto = 1
  AND p.id_pedido IN (1, 2, 3, 4, 5)
ORDER BY p.id_pedido ASC;

-- ============================================================================
-- VERIFICACIÓN DE RESULTADOS (Consigna 5)
-- Comparación con MongoDB sobre los 5 pedidos migrados (_id = id_pedido).
-- ============================================================================
-- Consulta b) — Filtrar pedidos por estado = 'ENTREGADO'
--   Resultado esperado (PostgreSQL): IDs [2, 5]  → cantidad 2
--   Resultado MongoDB (ejecutado):    IDs [2, 5]  → cantidad 2
--   Coinciden los IDs: Sí
--   Salida mongosh:
--     db.pedidos.find({ estado: "ENTREGADO" }, { _id: 1, estado: 1 })
--     [ { _id: Long("2"), estado: 'ENTREGADO' },
--       { _id: Long("5"), estado: 'ENTREGADO' } ]
--
-- Consulta c) — Buscar pedidos que contengan el producto con id_producto = 1
--   Resultado esperado (PostgreSQL): IDs [1, 3]  → cantidad 2
--   Resultado MongoDB (ejecutado):    IDs [1, 3]  → cantidad 2
--   Coinciden los IDs: Sí
--   Salida mongosh:
--     db.pedidos.find({ "lineas.id_producto": 1 }, { _id: 1 })
--     [ { _id: Long("1") }, { _id: Long("3") } ]
--
-- Tabla de verificación (plantilla de la consigna):
-- | Consulta               | Cantidad en PostgreSQL | Cantidad en MongoDB | Coinciden los IDs |
-- | Estado seleccionado    | 2                      | 2                   | Sí (IDs: 2, 5)   |
-- | Producto seleccionado  | 2                      | 2                   | Sí (IDs: 1, 3)   |
--
-- Conclusión: no se detectaron diferencias. La identidad se conserva (_id = id_pedido),
-- los datos de prueba coinciden con los documentos migrados y la semántica de las
-- consultas es equivalente (predicado sobre estado / recorrido multikey del arreglo
-- embebido lineas[] vs. INNER JOIN detalle_pedido). No fue necesario corregir el
-- modelo ni las consultas. Ver detalle en docs/verificacion_consultas.md.
