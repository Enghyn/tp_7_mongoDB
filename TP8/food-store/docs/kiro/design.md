# Diseño — Food Store Tablet (Kiro Spec)

> **Proyecto:** Food Store — cierre de la capa de datos
> **Formato:** Diseño breve (Kiro)

---

## Arquitectura

Tres motores de base de datos con roles bien definidos:

1. **PostgreSQL** (servidor) — Fuente de verdad. Almacena clientes, productos, pedidos, ventas. Precio, stock y ventas los decide PostgreSQL.
2. **MongoDB** (servidor) — Proyección de lectura del subconjunto pedidos + detalle. Colección `pedidos` con líneas embebidas (`lineas[]`).
3. **SQLite** (tablet) — Copia de lectura del catálogo (`producto_cache`) + borradores locales (`pedido_borrador`, `item_borrador`) + bandeja de salida (`cola_sync`).

## Componentes principales

### Vista `v_snapshot_movil` (PostgreSQL)
Exporta el catálogo mínimo para la tablet: id, nombre, precio en centavos, stock visto, disponible, eliminado, fecha de copia. Se exporta a CSV y se importa en SQLite como `snapshot_servidor` (staging), luego se carga en `producto_cache` con transformaciones (booleanos t/f → 0/1).

### Semáforo (SQLite)
Compara cada solicitud PENDIENTE en `cola_sync` contra `producto_cache`:
- **RECHAZADO** (rojo): producto inexistente, no disponible, dado de baja, o stock insuficiente.
- **CONFLICTO** (amarillo): no hay rojo, pero cambió algún precio.
- **SIMULADO_APROBADO** (verde): todo coincide.

Solo evalúa solicitudes PENDIENTE (idempotencia). No modifica PostgreSQL.

### Tablas SQLite (STRICT)
- `producto_cache`: copia de lectura del catálogo (7 columnas, CHECK constraints).
- `pedido_borrador`: borradores locales (UUID, usuario, forma de pago, fecha).
- `item_borrador`: líneas del borrador (FK a pedido_borrador y producto_cache, cantidad > 0).
- `cola_sync`: bandeja de salida (PK solicitud_uuid, estado, motivo).

## Flujo de sincronización

1. PostgreSQL → CSV → SQLite (snapshot del catálogo, solo lectura).
2. Tablet arma borrador → cola_sync (PENDIENTE).
3. Semáforo evalúa contra snapshot → RECHAZADO / CONFLICTO / SIMULADO_APROBADO.
4. SIMULADO_APROBADO no es una venta: el vendedor debe enviar manualmente.

## Regla de oro
El móvil propone, el servidor dispone. La tablet nunca cambia stock ni precio del servidor.