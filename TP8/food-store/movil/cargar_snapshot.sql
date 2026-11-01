-- ============================================================================
-- cargar_snapshot.sql — Consigna 2.a
-- Crea la tabla staging `snapshot_servidor` e importa el CSV exportado desde
-- PostgreSQL. Luego carga `producto_cache` con las transformaciones necesarias
-- (booleanos t/f → 0/1, tipos estrictos).
--
-- Flujo:
--   1. Crear `snapshot_servidor` (staging, tipos flexibles).
--   2. Importar servidor_snapshot.csv en snapshot_servidor.
--   3. Cargar producto_cache desde snapshot_servidor con CASE WHEN.
--
-- Ejecución en este entorno (sin CLI sqlite3):
--   python run_cargar_snapshot.py
--   (o manualmente con el arnés run_pruebas.py adaptado)
--
-- Ejecución con CLI sqlite3:
--   sqlite3 foodstore_movil.db < cargar_snapshot.sql
--   .import --csv --skip 1 servidor_snapshot.csv snapshot_servidor
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- 1. Tabla staging: snapshot_servidor
--    Tipos flexibles para absorber los booleanos t/f del CSV de psql.
--    NO tiene CHECK ni STRICT: es una zona de aterrizaje.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS snapshot_servidor (
    id              TEXT,
    nombre          TEXT,
    precio_centavos TEXT,
    stock_visto     TEXT,
    disponible      TEXT,   -- 't' / 'f' en el CSV de psql
    eliminado       TEXT,   -- 't' / 'f' en el CSV de psql
    fecha_copia     TEXT
);

-- Limpieza para re-ejecución idempotente
DELETE FROM snapshot_servidor;

-- ----------------------------------------------------------------------------
-- 2. Importación del CSV
--    Con CLI sqlite3:
--      .mode csv
--      .import --skip 1 servidor_snapshot.csv snapshot_servidor
--    En este entorno (sin CLI) se usa run_cargar_snapshot.py.
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- 3. Carga de producto_cache desde snapshot_servidor
--    Transformaciones:
--      - disponible: 't'/'true'/'1' → 1, resto → 0
--      - eliminado:  't'/'true'/'1' → 1, resto → 0
--      - precio_centavos: CAST a INTEGER (ya viene en centavos desde la vista)
--      - stock_visto:     CAST a INTEGER
--      - id:             CAST a INTEGER
-- ----------------------------------------------------------------------------

-- Limpieza para re-ejecución idempotente
DELETE FROM producto_cache;

INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
SELECT
    CAST(s.id AS INTEGER)                                        AS id,
    s.nombre                                                     AS nombre,
    CAST(s.precio_centavos AS INTEGER)                           AS precio_centavos,
    CAST(s.stock_visto AS INTEGER)                               AS stock_visto,
    CASE WHEN LOWER(TRIM(s.disponible)) IN ('t', 'true', '1') THEN 1 ELSE 0 END AS disponible,
    CASE WHEN LOWER(TRIM(s.eliminado))  IN ('t', 'true', '1') THEN 1 ELSE 0 END AS eliminado,
    s.fecha_copia                                                AS fecha_copia
FROM snapshot_servidor s
WHERE s.id IS NOT NULL AND TRIM(s.id) <> '';

-- ----------------------------------------------------------------------------
-- 4. Verificación post-carga
-- ----------------------------------------------------------------------------
-- SELECT count(*) AS total_productos FROM producto_cache;
-- SELECT count(*) AS disponibles FROM producto_cache WHERE disponible = 1 AND eliminado = 0;
-- SELECT count(*) AS eliminados FROM producto_cache WHERE eliminado = 1;
-- SELECT min(precio_centavos), max(precio_centavos) FROM producto_cache;