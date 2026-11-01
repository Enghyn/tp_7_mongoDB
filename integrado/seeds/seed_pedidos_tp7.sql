-- ----------------------------------------------------------------------------
-- Siembra de los 5 pedidos del TP7 en PostgreSQL (pedidos.json → SQL)
-- Reconstruye clientes 1-3, los 5 pedidos y su detalle, tal como están
-- embebidos en la colección `pedidos` de MongoDB (migracion_mongodb.js).
-- Ejecutar desde la raíz del proyecto:
--   psql -h localhost -U postgres -d tp_food_store -v ON_ERROR_STOP=1 \
--        -f integrado/seeds/seed_pedidos_tp7.sql
-- ----------------------------------------------------------------------------

BEGIN;

-- 1. Clientes referenciados por los pedidos (datos sintéticos, no personales)
INSERT INTO cliente (id_cliente, nombre, email)
OVERRIDING SYSTEM VALUE
VALUES (1, 'Cliente Uno',  'cliente1@example.test'),
       (2, 'Cliente Dos',  'cliente2@example.test'),
       (3, 'Cliente Tres', 'cliente3@example.test');

-- 2. Pedidos (id, cliente, fecha, forma de pago) tal como en pedidos.json
INSERT INTO pedido (id_pedido, id_cliente, fecha_pedido, forma_pago)
OVERRIDING SYSTEM VALUE
VALUES (1, 1, '2026-01-10T10:00:00Z', 'EFECTIVO'),
       (2, 2, '2026-01-11T11:30:00Z', 'TARJETA'),
       (3, 1, '2026-01-12T14:15:00Z', 'TRANSFERENCIA'),
       (4, 3, '2026-01-13T16:45:00Z', 'EFECTIVO'),
       (5, 2, '2026-01-14T09:20:00Z', 'TARJETA');

-- 3. Detalle de cada pedido (precio_unitario_facturado = precio histórico)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario_facturado)
VALUES
    -- Pedido 1: productos 1 y 2
    (1, 1, 2, 500.00), (1, 2, 1, 1200.50),
    -- Pedido 2: producto 3
    (2, 3, 4, 350.00),
    -- Pedido 3: productos 1, 4 y 5
    (3, 1, 1, 500.00), (3, 4, 2, 850.00), (3, 5, 1, 200.00),
    -- Pedido 4: productos 2 y 6
    (4, 2, 2, 1200.50), (4, 6, 3, 150.00),
    -- Pedido 5: productos 5 y 3
    (5, 5, 5, 200.00), (5, 3, 2, 350.00);

-- 4. Re-sincronizar secuencias
SELECT setval(pg_get_serial_sequence('cliente', 'id_cliente'),
              COALESCE((SELECT max(id_cliente) FROM cliente), 1));
SELECT setval(pg_get_serial_sequence('pedido', 'id_pedido'),
              COALESCE((SELECT max(id_pedido) FROM pedido), 1));

COMMIT;

-- 5. Evidencia esperada:
--    SELECT count(*) FROM cliente;         -- 3
--    SELECT count(*) FROM pedido;          -- 5
--    SELECT count(*) FROM detalle_pedido;  -- 10
