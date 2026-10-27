-- ============================================================================
-- TRABAJO PRÁCTICO UNIDAD 7 - FOOD STORE
-- Parte 2: Consultas de verificación en PostgreSQL (Consigna 5)
-- ============================================================================

-- Consulta 1 (Equivalente a 4b): Filtrar pedidos por estado 'ENTREGADO'
SELECT 
    id_pedido, 
    estado
FROM pedido
WHERE estado = 'ENTREGADO'
ORDER BY id_pedido ASC;

-- Consulta 2 (Equivalente a 4c): Buscar pedidos que contengan el producto con ID 1
SELECT DISTINCT 
    p.id_pedido
FROM pedido p
INNER JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
WHERE dp.id_producto = 1 
  AND p.id_pedido IN (101, 102, 103, 104, 105)
ORDER BY p.id_pedido ASC;