-- ============================================================================
-- integrado/verificar_postgresql.sql — Verificación de lectura de tp_food_store
-- Fecha de ejecución de referencia: 2026-11-01
-- Cómo correrlo (PowerShell, desde la raíz del proyecto):
--   $env:PGPASSWORD='postgres'
--   & 'C:\Program Files\PostgreSQL\16\bin\psql.exe' -h localhost -p 5432 -U postgres `
--       -d tp_food_store -f integrado/verificar_postgresql.sql
-- Solo SELECT: no modifica nada.
-- ============================================================================

\echo '=== Conteos generales ==='
SELECT 'cliente'        AS tabla, count(*) AS filas FROM cliente
UNION ALL
SELECT 'categoria',                count(*) FROM categoria
UNION ALL
SELECT 'producto',                 count(*) FROM producto
UNION ALL
SELECT 'producto_activo',          count(*) FROM producto WHERE activo
UNION ALL
SELECT 'producto_eliminado',       count(*) FROM producto WHERE NOT activo
UNION ALL
SELECT 'pedido',                   count(*) FROM pedido
UNION ALL
SELECT 'detalle_pedido',           count(*) FROM detalle_pedido
ORDER BY 1;

\echo '=== Distribucion de pedidos por forma de pago ==='
SELECT forma_pago, count(*) AS pedidos
FROM pedido
GROUP BY forma_pago
ORDER BY forma_pago;

\echo '=== Indices en pedido, producto y (referencia) categorias ==='
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('pedido', 'producto')
ORDER BY tablename, indexname;

\echo '=== Muestra de productos del snapshot (primeros 5 por id) ==='
SELECT id_producto, nombre, precio_lista, stock, activo
FROM producto
ORDER BY id_producto
LIMIT 5;

\echo '=== Verificacion completa ==='
