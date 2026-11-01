-- ============================================================================
-- pruebas_sqlite.sql — Consigna 1.c
-- Base: foodstore_movil.db (SQLite 3.37+)
--
-- Ejecución recomendada:
--   python run_pruebas.py --db foodstore_movil.db --fresh
--
-- También se puede ejecutar con el CLI de SQLite:
--   sqlite3 foodstore_movil.db < pruebas_sqlite.sql
--   (las pruebas con -- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value muestran el error y continúan)
--
-- Convenciones del arnés run_pruebas.py:
--   -- TEST: nombre        → nombre de la prueba
--   -- EXPECT_OK           → la sentencia debe ejecutarse sin error
--   -- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value        → la sentencia debe fallar (CHECK, FK, PK o STRICT)
--   -- EXPECT_VALUE: valor → la primera columna de la primera fila debe valer eso
-- ============================================================================

-- ============================================================================
-- BLOQUE 0 — El esquema está cargado y las reglas están activas
-- ============================================================================

-- TEST: 00 PRAGMA foreign_keys activo
-- EXPECT_VALUE: 1
PRAGMA foreign_keys;

-- TEST: 01 Existen las cuatro tablas
-- EXPECT_VALUE: 4
SELECT COUNT(*)
FROM sqlite_master
WHERE type = 'table'
  AND name IN ('producto_cache', 'pedido_borrador', 'item_borrador', 'cola_sync');

-- TEST: 02 producto_cache tiene las siete columnas mínimas
-- EXPECT_VALUE: 7
SELECT COUNT(*)
FROM pragma_table_info('producto_cache')
WHERE name IN ('id', 'nombre', 'precio_centavos', 'stock_visto',
               'disponible', 'eliminado', 'fecha_copia');

-- TEST: 03 Las cuatro tablas son STRICT
-- EXPECT_VALUE: 4
SELECT COUNT(*)
FROM pragma_table_list
WHERE name IN ('producto_cache', 'pedido_borrador', 'item_borrador', 'cola_sync')
  AND strict = 1;

-- TEST: 04 item_borrador tiene dos claves foráneas
-- EXPECT_VALUE: 2
SELECT COUNT(*) FROM pragma_foreign_key_list('item_borrador');

-- TEST: 05 cola_sync tiene una clave foránea
-- EXPECT_VALUE: 1
SELECT COUNT(*) FROM pragma_foreign_key_list('cola_sync');

-- ============================================================================
-- BLOQUE 1 — Semilla del catálogo (simula la carga del snapshot)
-- Productos 1..7: mismos precios que los pedidos del TP7 donde aplica.
-- ============================================================================

-- TEST: 06 Cargar catálogo de prueba
-- EXPECT_OK
INSERT INTO producto_cache
    (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
VALUES
    (1, 'Agua 500ml',             50000, 10, 1, 0, '2026-11-01T10:00:00-03:00'),
    (2, 'Pan artesanal',         120050,  5, 1, 0, '2026-11-01T10:00:00-03:00'),
    (3, 'Gaseosa 1.5L',           35000,  8, 1, 0, '2026-11-01T10:00:00-03:00'),
    (4, 'Queso 500g',             85000,  3, 1, 0, '2026-11-01T10:00:00-03:00'),
    (5, 'Yerba 1kg',              20000,  0, 0, 0, '2026-11-01T10:00:00-03:00'),
    (6, 'Alfajor',                15000, 20, 1, 0, '2026-11-01T10:00:00-03:00'),
    (7, 'Producto dado de baja',  30000,  0, 0, 1, '2026-11-01T10:00:00-03:00');

-- TEST: 07 El catálogo completo tiene siete productos
-- EXPECT_VALUE: 7
SELECT COUNT(*) FROM producto_cache;

-- ============================================================================
-- BLOQUE 2 — Caso C1: consulta del catálogo disponible sin servidor
-- ============================================================================

-- TEST: 08 C1 devuelve solo productos disponibles y no eliminados
-- EXPECT_VALUE: 5
SELECT COUNT(*)
FROM producto_cache
WHERE disponible = 1
  AND eliminado = 0;

-- TEST: 09 C1 devuelve los nombres esperados en orden
-- EXPECT_VALUE: Agua 500ml,Alfajor,Gaseosa 1.5L,Pan artesanal,Queso 500g
SELECT group_concat(nombre, ',')
FROM (
    SELECT nombre
    FROM producto_cache
    WHERE disponible = 1
      AND eliminado = 0
    ORDER BY nombre
);

-- TEST: 10 C1 excluye el producto sin stock y el dado de baja
-- EXPECT_VALUE: 0
SELECT COUNT(*)
FROM producto_cache
WHERE (id = 5 OR id = 7)
  AND disponible = 1
  AND eliminado = 0;

-- ============================================================================
-- BLOQUE 3 — Borrador completo con BEGIN ... COMMIT
-- Pedido 1 del TP7: 2 x Agua ($500,00) + 1 x Pan ($1.200,50) = $2.200,50
-- ============================================================================

-- TEST: 11 Abrir transacción del borrador
-- EXPECT_OK
BEGIN;

-- TEST: 12 Insertar pedido_borrador
-- EXPECT_OK
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('11111111-1111-4111-8111-111111111111',
        'vendedor1',
        'EFECTIVO',
        '2026-11-01T10:05:00-03:00');

-- TEST: 13 Insertar primer ítem del borrador
-- EXPECT_OK
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('11111111-1111-4111-8111-111111111111', 1, 2, 50000);

-- TEST: 14 Insertar segundo ítem del borrador
-- EXPECT_OK
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('11111111-1111-4111-8111-111111111111', 2, 1, 120050);

-- TEST: 15 Insertar la solicitud en la cola (PENDIENTE, sin motivo)
-- EXPECT_OK
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        '11111111-1111-4111-8111-111111111111',
        'PENDIENTE',
        NULL);

-- TEST: 16 Confirmar la transacción
-- EXPECT_OK
COMMIT;

-- TEST: 17 Quedó un borrador
-- EXPECT_VALUE: 1
SELECT COUNT(*) FROM pedido_borrador;

-- TEST: 18 Quedaron dos ítems
-- EXPECT_VALUE: 2
SELECT COUNT(*) FROM item_borrador;

-- TEST: 19 Quedó una solicitud en la cola
-- EXPECT_VALUE: 1
SELECT COUNT(*) FROM cola_sync;

-- TEST: 20 Total del borrador en centavos = 2.200,50
-- EXPECT_VALUE: 220050
SELECT SUM(cantidad * precio_centavos_visto)
FROM item_borrador
WHERE id_local = '11111111-1111-4111-8111-111111111111';

-- ============================================================================
-- BLOQUE 4 — Operación deshecha con ROLLBACK
-- ============================================================================

-- TEST: 21 Abrir transacción que se va a deshacer
-- EXPECT_OK
BEGIN;

-- TEST: 22 Insertar un segundo borrador (se deshace)
-- EXPECT_OK
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('22222222-2222-4222-8222-222222222222',
        'vendedor2',
        'TARJETA',
        '2026-11-01T10:10:00-03:00');

-- TEST: 23 Insertar un ítem del segundo borrador (se deshace)
-- EXPECT_OK
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('22222222-2222-4222-8222-222222222222', 3, 1, 35000);

-- TEST: 24 Insertar la solicitud del segundo borrador (se deshace)
-- EXPECT_OK
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        '22222222-2222-4222-8222-222222222222',
        'PENDIENTE',
        NULL);

-- TEST: 25 Deshacer la transacción
-- EXPECT_OK
ROLLBACK;

-- TEST: 26 Sigue habiendo un solo borrador
-- EXPECT_VALUE: 1
SELECT COUNT(*) FROM pedido_borrador;

-- TEST: 27 Siguen habiendo dos ítems
-- EXPECT_VALUE: 2
SELECT COUNT(*) FROM item_borrador;

-- TEST: 28 Sigue habiendo una sola solicitud
-- EXPECT_VALUE: 1
SELECT COUNT(*) FROM cola_sync;

-- ============================================================================
-- BLOQUE 5 — Caso C7: cantidad 0 y producto inexistente
-- Ambos deben fallar y no dejar filas nuevas.
-- ============================================================================

-- TEST: 29 C7 abrir transacción de prueba
-- EXPECT_OK
BEGIN;

-- TEST: 30 C7 cantidad 0 debe fallar por CHECK
-- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('11111111-1111-4111-8111-111111111111', 3, 0, 35000);

-- TEST: 31 C7 producto inexistente debe fallar por FK
-- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('11111111-1111-4111-8111-111111111111', 999, 1, 1000);

-- TEST: 32 C7 cerrar transacción de prueba
-- EXPECT_OK
ROLLBACK;

-- TEST: 33 C7 no dejó filas nuevas: siguen dos ítems
-- EXPECT_VALUE: 2
SELECT COUNT(*) FROM item_borrador;

-- TEST: 34 C7 no dejó filas nuevas en el borrador 1
-- EXPECT_VALUE: 2
SELECT COUNT(*)
FROM item_borrador
WHERE id_local = '11111111-1111-4111-8111-111111111111';

-- ============================================================================
-- BLOQUE 6 — Triangulación: reglas de producto_cache
-- ============================================================================

-- TEST: 35 Precio negativo debe fallar
-- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value
INSERT INTO producto_cache
    (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
VALUES (8, 'Producto inválido', -1, 1, 1, 0, '2026-11-01T10:00:00-03:00');

-- TEST: 36 Precio con texto debe fallar por STRICT
-- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value
INSERT INTO producto_cache
    (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
VALUES (8, 'Producto inválido', 'abc', 1, 1, 0, '2026-11-01T10:00:00-03:00');

-- TEST: 37 disponible y eliminado no pueden ser 1 a la vez
-- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value
INSERT INTO producto_cache
    (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
VALUES (8, 'Producto inválido', 1000, 1, 1, 1, '2026-11-01T10:00:00-03:00');

-- TEST: 38 disponible fuera de 0/1 debe fallar
-- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value
INSERT INTO producto_cache
    (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
VALUES (8, 'Producto inválido', 1000, 1, 2, 0, '2026-11-01T10:00:00-03:00');

-- TEST: 39 Sigue habiendo siete productos
-- EXPECT_VALUE: 7
SELECT COUNT(*) FROM producto_cache;

-- ============================================================================
-- BLOQUE 7 — Triangulación: reglas de pedido_borrador
-- ============================================================================

-- TEST: 40 Forma de pago inválida debe fallar
-- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('33333333-3333-4333-8333-333333333333',
        'vendedor3',
        'BITCOIN',
        '2026-11-01T10:15:00-03:00');

-- TEST: 41 Usuario con email debe fallar (no viajan datos personales)
-- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('33333333-3333-4333-8333-333333333333',
        'persona@ejemplo.com',
        'EFECTIVO',
        '2026-11-01T10:15:00-03:00');

-- TEST: 42 id_local que no es UUID debe fallar
-- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('abc',
        'vendedor3',
        'EFECTIVO',
        '2026-11-01T10:15:00-03:00');

-- TEST: 43 Sigue habiendo un solo borrador
-- EXPECT_VALUE: 1
SELECT COUNT(*) FROM pedido_borrador;

-- ============================================================================
-- BLOQUE 8 — Triangulación: ítems duplicados y FK
-- ============================================================================

-- TEST: 44 Ítem duplicado (mismo borrador y producto) debe fallar por PK
-- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('11111111-1111-4111-8111-111111111111', 1, 1, 50000);

-- TEST: 45 Ítem de un borrador inexistente debe fallar por FK
-- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('99999999-9999-4999-8999-999999999999', 1, 1, 50000);

-- TEST: 46 Siguen habiendo dos ítems
-- EXPECT_VALUE: 2
SELECT COUNT(*) FROM item_borrador;

-- ============================================================================
-- BLOQUE 9 — Triangulación: cola_sync e idempotencia (avance de C6)
-- ============================================================================

-- TEST: 47 Abrir transacción de pruebas de cola
-- EXPECT_OK
BEGIN;

-- TEST: 48 Crear un borrador válido para las pruebas de cola
-- EXPECT_OK
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('33333333-3333-4333-8333-333333333333',
        'vendedor3',
        'TRANSFERENCIA',
        '2026-11-01T10:20:00-03:00');

-- TEST: 49 Estado inválido en cola_sync debe fallar
-- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        '33333333-3333-4333-8333-333333333333',
        'ENVIADO',
        'Estado que no existe');

-- TEST: 50 Estado final sin motivo debe fallar
-- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        '33333333-3333-4333-8333-333333333333',
        'CONFLICTO',
        NULL);

-- TEST: 51 Reenviar el mismo solicitud_uuid debe fallar por PK (C6)
-- EXPECT_ERROR: CHECK|FOREIGN KEY|UNIQUE|TEXT value
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        '33333333-3333-4333-8333-333333333333',
        'PENDIENTE',
        NULL);

-- TEST: 52 Cerrar transacción de pruebas de cola
-- EXPECT_OK
ROLLBACK;

-- TEST: 53 Sigue habiendo una sola solicitud en la cola
-- EXPECT_VALUE: 1
SELECT COUNT(*) FROM cola_sync;

-- ============================================================================
-- BLOQUE 10 — Estado final de la base
-- ============================================================================

-- TEST: 54 Estado final: 7 productos, 1 borrador, 2 ítems, 1 solicitud
-- EXPECT_VALUE: 7,1,2,1
SELECT
    (SELECT COUNT(*) FROM producto_cache) || ',' ||
    (SELECT COUNT(*) FROM pedido_borrador) || ',' ||
    (SELECT COUNT(*) FROM item_borrador) || ',' ||
    (SELECT COUNT(*) FROM cola_sync);
