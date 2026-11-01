-- ============================================================================
-- v_snapshot_movil.sql — Consigna 2.a
-- Vista de PostgreSQL que exporta el catálogo mínimo para la tablet.
-- Se ejecuta en la base tp_food_store (PostgreSQL de pruebas).
-- ============================================================================

-- Nota: en este entorno el servidor PostgreSQL multi-usuario crashea al
-- recibir conexiones (error 0xC0000142, DLL init failed en Windows). La vista
-- se creó y verificó mediante el modo single-user (--single) de postgres.exe,
-- que devolvió 50.000 filas sin errores.

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

-- Exportación (psql):
--   \copy (SELECT * FROM v_snapshot_movil) TO 'servidor_snapshot.csv' CSV HEADER
--
-- En este proyecto el CSV se generó con:
--   COPY (SELECT * FROM v_snapshot_movil) TO STDOUT WITH CSV HEADER;
-- y se filtró el encabezado "backend>" que agrega el modo single-user.
--
-- Resultado: 50.000 filas + encabezado → movil/servidor_snapshot.csv