-- ============================================================================
-- schema_sqlite.sql — Consigna 1.b
-- Base de la tablet: Food Store en la feria
--
-- Requisitos:
--   - SQLite 3.37+ (tablas STRICT).
--   - PRAGMA foreign_keys = ON; al inicio (se aplica por conexión).
--   - Precios en centavos (entero, no negativo).
--   - Booleanos lógicos como 0/1.
--   - Sin datos personales reales: usuario es un identificador opaco.
--
-- Ejecución:
--   python run_pruebas.py --db foodstore_movil.db --fresh
--   sqlite3 foodstore_movil.db < schema_sqlite.sql
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- 1. producto_cache
--    Copia de lectura del catálogo. La tablet NUNCA escribe esta tabla en el
--    servidor: solo guarda la foto que vino en el snapshot.
-- ----------------------------------------------------------------------------
CREATE TABLE producto_cache (
    id                INTEGER PRIMARY KEY,
    nombre            TEXT    NOT NULL
                              CHECK (length(trim(nombre)) > 0),
    precio_centavos   INTEGER NOT NULL
                              CHECK (precio_centavos >= 0),
    stock_visto       INTEGER NOT NULL
                              CHECK (stock_visto >= 0),
    disponible        INTEGER NOT NULL
                              CHECK (disponible IN (0, 1)),
    eliminado         INTEGER NOT NULL
                              CHECK (eliminado IN (0, 1)),
    fecha_copia       TEXT    NOT NULL
                              CHECK (fecha_copia GLOB '????-??-??*'),

    -- Un producto no puede estar disponible y eliminado a la vez.
    CHECK (NOT (disponible = 1 AND eliminado = 1))
) STRICT;

-- ----------------------------------------------------------------------------
-- 2. pedido_borrador
--    Borrador local. No es una venta: todavía no existe en PostgreSQL.
-- ----------------------------------------------------------------------------
CREATE TABLE pedido_borrador (
    id_local    TEXT PRIMARY KEY
                     CHECK (id_local GLOB '????????-????-????-????-????????????'),
    usuario     TEXT NOT NULL
                     CHECK (length(trim(usuario)) > 0
                            AND usuario NOT LIKE '%@%'),
    forma_pago  TEXT NOT NULL
                     CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    fecha       TEXT NOT NULL
                     CHECK (fecha GLOB '????-??-??*')
) STRICT;

-- ----------------------------------------------------------------------------
-- 3. item_borrador
--    Líneas del borrador. Un producto aparece como máximo una vez por
--    borrador (misma lógica que la PK compuesta de detalle_pedido).
-- ----------------------------------------------------------------------------
CREATE TABLE item_borrador (
    id_local                TEXT    NOT NULL,
    producto_id             INTEGER NOT NULL,
    cantidad                INTEGER NOT NULL
                                    CHECK (cantidad > 0),
    precio_centavos_visto   INTEGER NOT NULL
                                    CHECK (precio_centavos_visto >= 0),

    PRIMARY KEY (id_local, producto_id),

    FOREIGN KEY (id_local)
        REFERENCES pedido_borrador (id_local)
        ON DELETE CASCADE,

    FOREIGN KEY (producto_id)
        REFERENCES producto_cache (id)
        ON DELETE RESTRICT
) STRICT;

-- ----------------------------------------------------------------------------
-- 4. cola_sync
--    Bandeja de salida local. La PK solicitud_uuid es la clave de idempotencia:
--    reenviar la misma solicitud falla y no se duplica.
-- ----------------------------------------------------------------------------
CREATE TABLE cola_sync (
    solicitud_uuid  TEXT PRIMARY KEY
                         CHECK (solicitud_uuid GLOB '????????-????-????-????-????????????'),
    id_local        TEXT NOT NULL,
    estado          TEXT NOT NULL
                         CHECK (estado IN ('PENDIENTE', 'CONFLICTO',
                                           'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo          TEXT,

    FOREIGN KEY (id_local)
        REFERENCES pedido_borrador (id_local)
        ON DELETE RESTRICT,

    -- Todo estado ya evaluado debe explicar el motivo.
    CHECK (estado = 'PENDIENTE'
           OR (motivo IS NOT NULL AND length(trim(motivo)) > 0))
) STRICT;

-- ----------------------------------------------------------------------------
-- 5. Índices de apoyo
-- ----------------------------------------------------------------------------
CREATE INDEX idx_producto_cache_disponible
    ON producto_cache (disponible, eliminado);

CREATE INDEX idx_item_borrador_producto
    ON item_borrador (producto_id);

CREATE INDEX idx_cola_sync_estado
    ON cola_sync (estado);

CREATE INDEX idx_cola_sync_id_local
    ON cola_sync (id_local);
