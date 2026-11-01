# Consigna 3.a — Mapa de la capa de datos

> **Consigna:** 3.a · Mapa de la capa de datos (5 puntos)
> **Formato:** Tabla o dibujo con los tres motores, qué guarda cada uno y quién manda.

---

## Tabla de la capa de datos

| Motor | Tipo | Qué guarda | Quién manda (fuente de verdad) | Alcance en Food Store |
|-------|------|-----------|-------------------------------|----------------------|
| **PostgreSQL** (servidor) | Relacional, ACID | Clientes, categorías, productos (catálogo completo con precio, stock, activo), pedidos, detalles de pedido. Todas las ventas confirmadas. | **PostgreSQL manda sobre TODO.** Precio, stock, ventas, clientes, productos. Es la única fuente de verdad. | Sistema transaccional completo. Base de pruebas: `tp_food_store` (200.000 pedidos, 50.000 productos, 20.000 clientes). |
| **MongoDB** (servidor) | Documental (NoSQL) | Colección `pedidos`: documentos con pedido + líneas embebidas (`lineas[]`), precios históricos (`Decimal128`), totales calculados. | **PostgreSQL manda.** MongoDB es una **proyección de lectura** (read model) del subconjunto pedidos + detalle. No es fuente de verdad. | Subconjunto migrado: 5 pedidos de prueba (IDs 1–5) con sus líneas. Usado para consultas de pedidos completos sin JOIN. |
| **SQLite** (tablet/móvil) | Relacional local (STRICT) | `producto_cache`: copia de lectura del catálogo (id, nombre, precio en centavos, stock visto, disponible, eliminado, fecha de copia). `pedido_borrador`: borradores locales. `item_borrador`: líneas del borrador. `cola_sync`: bandeja de salida con estado del semáforo. | **PostgreSQL manda.** SQLite solo guarda una **foto (snapshot)** y **borradores**. Nunca escribe precio ni stock en el servidor. | Tablet en la feria sin señal. Catálogo mínimo (50.000 productos del snapshot). Borradores pendientes de sincronización. |

---

## Diagrama de flujo de datos

```
┌─────────────────────────────────────────────────────────────────────┐
│                        POSTGRESQL (servidor)                        │
│  Fuente de verdad: clientes, productos, pedidos, ventas, stock       │
│  - precio_lista, stock, activo (catálogo)                           │
│  - pedido + detalle_pedido (ventas confirmadas)                     │
│  - 200.000 pedidos, 50.000 productos, 20.000 clientes               │
└──────────┬──────────────────────────────┬───────────────────────────┘
           │                              │
           │  Snapshot (v_snapshot_movil)  │  Migración parcial (ETL)
           │  → CSV → SQLite              │  → pedidos + lineas[]
           │                              │
           ▼                              ▼
┌──────────────────────┐    ┌──────────────────────────────┐
│   SQLITE (tablet)    │    │   MONGODB (servidor)         │
│                      │    │                              │
│  producto_cache:     │    │  Colección pedidos:          │
│  - id, nombre        │    │  - _id (= id_pedido)         │
│  - precio_centavos   │    │  - id_cliente (ref)          │
│  - stock_visto       │    │  - fecha_pedido, estado      │
│  - disponible        │    │  - forma_pago                │
│  - eliminado         │    │  - lineas[] (embebidas)      │
│  - fecha_copia       │    │  - total_lineas, monto_total │
│                      │    │                              │
│  pedido_borrador:    │    │  Uso: consultas de pedidos   │
│  - borradores locales│    │  completos sin JOIN           │
│                      │    │                              │
│  cola_sync:          │    │  NO es fuente de verdad:     │
│  - semáforo          │    │  es proyección de lectura    │
│  - PENDIENTE/CONFLICTO│   │                              │
│  - RECHAZADO/APROBADO│    │                              │
└──────────────────────┘    └──────────────────────────────┘
```

---

## Regla de oro

> **El móvil propone, el servidor dispone.** La tablet solo consulta y arma borradores. Precio, stock y ventas los decide PostgreSQL. `SIMULADO_APROBADO` **no** es una venta.

### Qué manda cada motor

| Dato | Fuente de verdad | Copia/Proyección |
|------|-----------------|------------------|
| Precio de lista (`precio_lista`) | PostgreSQL (`producto.precio_lista`) | SQLite (`producto_cache.precio_centavos`, visto) |
| Stock (`stock`) | PostgreSQL (`producto.stock`) | SQLite (`producto_cache.stock_visto`, foto) |
| Disponibilidad (`activo`) | PostgreSQL (`producto.activo`) | SQLite (`producto_cache.disponible` / `eliminado`) |
| Pedidos y ventas | PostgreSQL (`pedido` + `detalle_pedido`) | MongoDB (`pedidos` con `lineas[]` embebidas) |
| Borradores de venta | SQLite (`pedido_borrador`) | **No existe en el servidor** hasta que se confirme |
| Catálogo (nombres, categorías) | PostgreSQL (`producto`, `categoria`) | MongoDB (solo referencias por ID) |

### Flujo de sincronización

1. **PostgreSQL → SQLite**: Exportación periódica del catálogo via `v_snapshot_movil` → CSV → `snapshot_servidor` → `producto_cache`. La tablet recibe una **foto** del catálogo.
2. **SQLite → (intento) PostgreSQL**: La tablet envía borradores via `cola_sync`. El semáforo evalúa si el borrador puede aprobarse (`SIMULADO_APROBADO`) o tiene conflictos/rechazos. **Nunca se escribe en PostgreSQL desde la tablet.**
3. **PostgreSQL → MongoDB**: Migración parcial (ETL) del subconjunto `pedido` + `detalle_pedido` a la colección `pedidos`. MongoDB es una proyección de lectura, no se sincroniza en tiempo real.

---

## Notas

- La tablet **nunca** cambia el stock ni el precio del servidor.
- `SIMULADO_APROBADO` es una simulación, **no** es una venta confirmada.
- Si se restaura un respaldo viejo de PostgreSQL, las tablets deben re-sincronizar el catálogo (ver plan de mantenimiento, Consigna 3.b).
- MongoDB no participa en la sincronización con la tablet; es un motor independiente de lectura.