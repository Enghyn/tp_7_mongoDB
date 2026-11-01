-- ----------------------------------------------------------------------------
-- Siembra de `producto` + `categoria` en tp_food_store
-- Fuente: TP8/food-store/movil/servidor_snapshot.csv (exportado de v_snapshot_movil)
-- Este es el MISMO dataset que la tablet ya cargó en producto_cache (50.000 filas),
-- así que PostgreSQL, el CSV y SQLite quedan coherentes entre sí.
--
-- Ejecutar desde la raíz del proyecto (tp_7_mongoDB-main):
--   psql -h localhost -U postgres -d tp_food_store -v ON_ERROR_STOP=1 \
--        -f integrado/seeds/cargar_producto_desde_snapshot.sql
-- (rutas relativas a la raíz del proyecto)
-- ----------------------------------------------------------------------------

BEGIN;

-- 1. Staging con tipos flexibles (el CSV trae booleanos t/f y texto)
DROP TABLE IF EXISTS staging_producto;
CREATE TABLE staging_producto (
    id             BIGINT,
    nombre         TEXT,
    precio_centavos BIGINT,
    stock_visto    INTEGER,
    disponible     TEXT,
    eliminado      TEXT,
    fecha_copia    TEXT
);

\copy staging_producto FROM 'TP8/food-store/movil/servidor_snapshot.csv' CSV HEADER

-- 2. Categorías derivadas del patrón "Producto CatN-x" del snapshot
INSERT INTO categoria (id_categoria, nombre)
OVERRIDING SYSTEM VALUE
SELECT DISTINCT t.cat_num, 'Categoría ' || t.cat_num
FROM (
    SELECT CAST(substring(nombre FROM 'Cat[0-9]+-[0-9]+') AS text) AS cat_tag,
           CAST(substring(substring(nombre FROM 'Cat[0-9]+-[0-9]+') FROM '[0-9]+') AS int) AS cat_num
    FROM staging_producto
) t
ORDER BY 1;

-- 3. Carga de producto con las reglas del TP8 (plan_diseno.md §3.2-3.3):
--    precio_lista  = precio_centavos / 100  (nunca float en el lado tablet;
--        acá NUMERIC(10,2) es el tipo nativo del servidor)
--    stock         = stock_visto
--    activo        = NOT eliminado  (baja lógica; equivalente a eliminar la semántica t/f del CSV)
INSERT INTO producto (id_producto, id_categoria, nombre, precio_lista, stock, activo)
OVERRIDING SYSTEM VALUE
SELECT s.id,
       CAST(substring(substring(s.nombre FROM 'Cat[0-9]+-[0-9]+') FROM '[0-9]+') AS int),
       s.nombre,
       s.precio_centavos::numeric / 100,
       s.stock_visto,
       s.eliminado NOT IN ('t', 'true', '1')
FROM staging_producto s;

-- 4. Re-sincronizar las secuencias identidad tras la carga con id explícito
SELECT setval(pg_get_serial_sequence('categoria', 'id_categoria'),
              COALESCE((SELECT max(id_categoria) FROM categoria), 1));
SELECT setval(pg_get_serial_sequence('producto', 'id_producto'),
              COALESCE((SELECT max(id_producto) FROM producto), 1));

DROP TABLE staging_producto;

COMMIT;

-- 5. Evidencia esperada:
--    SELECT count(*) FROM categoria;                 -- según cantidad de CatN del CSV
--    SELECT count(*) FROM producto;                  -- 50000
--    SELECT count(*) FROM producto WHERE activo;     -- 44939 (50000 - 5061 eliminados)
--    SELECT count(*) FROM producto WHERE NOT activo; -- 5061
