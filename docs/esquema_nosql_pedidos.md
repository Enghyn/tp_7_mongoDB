# Esquema NoSQL propuesto — Subconjunto `pedido` + `detalle_pedido`

> Documento de diseño para migrar el subconjunto de pedidos de PostgreSQL (`tp_food_store`) a una colección MongoDB.
> Fuente estructural: `db/schema.sql` (DDL real del proyecto).

---

## 1. Punto de partida: tablas y claves en PostgreSQL

### 1.1 Tabla `pedido`

| Elemento | Definición |
|---|---|
| Clave primaria | `id_pedido BIGINT GENERATED ALWAYS AS IDENTITY` (`pedido_pkey`) |
| Clave foránea | `id_cliente → cliente(id_cliente)` (`fk_pedido_cliente`, `ON DELETE RESTRICT`) |
| Atributos | `fecha_pedido TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP`, `forma_pago forma_pago_enum NOT NULL` |
| Dominio de `forma_pago` | `EFECTIVO`, `TARJETA`, `TRANSFERENCIA` |
| Índice secundario | `idx_pedido_cliente (id_cliente)` |

### 1.2 Tabla `detalle_pedido`

| Elemento | Definición |
|---|---|
| Clave primaria | Compuesta: `(id_pedido, id_producto)` (`pk_detalle_pedido`) |
| Clave foránea 1 | `id_pedido → pedido(id_pedido)` (`fk_detalle_pedido_pedido`, `ON DELETE RESTRICT`) |
| Clave foránea 2 | `id_producto → producto(id_producto)` (`fk_detalle_pedido_producto`, `ON DELETE RESTRICT`) |
| Atributos | `cantidad INTEGER NOT NULL`, `precio_unitario_facturado NUMERIC(10,2) NOT NULL` |
| Restricciones CHECK | `cantidad > 0`, `precio_unitario_facturado >= 0` |
| Índices de apoyo | `idx_detalle_pedido_id_pedido (id_pedido)`, `idx_detalle_pedido_id_producto (id_producto)` |

### 1.3 Relación entre ambas

- **1 pedido → N líneas** (`detalle_pedido`), con cardinalidad acotada: entre 2 y 5 productos por pedido según el volumen de carga del proyecto.
- La línea **no tiene identidad propia**: su identidad es la tupla `(id_pedido, id_producto)`. Esto es clave para el modelado documental: no hace falta inventar un `id_linea`.
- Un `id_producto` aparece **como máximo una vez por pedido** (lo garantiza la PK compuesta).

---

## 2. Decisión de modelado

**Una colección: `pedidos`. Un documento por pedido, con las líneas embebidas en un arreglo.**

Justificación:
1. Las líneas siempre se consultan junto con su pedido y no tienen vida independiente.
2. El arreglo está acotado (2–5 elementos), muy lejos del límite de 16 MB por documento.
3. Insertar/leer un pedido completo es una sola operación atómica (no requiere transacción multi-documento).
4. Se conserva la identidad original: `_id` = `id_pedido`, y `id_cliente` / `id_producto` se mantienen tal cual para poder reconstruir las referencias al esquema relacional.

No se embeben `cliente` ni `producto`: quedan como **referencias por identificador**, ya que el alcance de esta migración es el subconjunto pedidos + líneas.

---

## 3. Esquema de la colección `pedidos`

### 3.1 Campos principales (nivel documento)

| Campo | Tipo BSON | Origen | Obligatorio | Descripción |
|---|---|---|---|---|
| `_id` | `Long` | `pedido.id_pedido` | Sí | Identificador conservado. Se usa el mismo valor que la PK relacional para trazabilidad e idempotencia (`upsert` por `_id`). |
| `id_cliente` | `Long` | `pedido.id_cliente` | Sí | FK conservada como referencia lógica a `cliente`. |
| `fecha_pedido` | `Date` | `pedido.fecha_pedido` | Sí | `TIMESTAMPTZ` → BSON `Date` (UTC). |
| `forma_pago` | `String` (enum) | `pedido.forma_pago` | Sí | Valores permitidos: `EFECTIVO`, `TARJETA`, `TRANSFERENCIA`. |
| `lineas` | `Array<Object>` | `detalle_pedido` | Sí (≥1) | Líneas del pedido; ver 3.2. |
| `total_lineas` | `Int` | Derivado | No | `lineas.length`. Campo calculado en la ETL para evitar `$size` en consultas frecuentes. |
| `total_unidades` | `Int` | Derivado | No | `sum(lineas.cantidad)`. |
| `monto_total` | `Decimal128` | Derivado | No | `sum(lineas.subtotal)`. Se usa `Decimal128` para no perder precisión monetaria (equivalente a `NUMERIC(10,2)`). |

### 3.2 Objetos embebidos: arreglo `lineas`

| Campo | Tipo BSON | Origen | Obligatorio | Descripción |
|---|---|---|---|---|
| `lineas[].id_producto` | `Long` | `detalle_pedido.id_producto` | Sí | FK conservada como referencia lógica a `producto`. Único dentro del arreglo (hereda la PK compuesta). |
| `lineas[].cantidad` | `Int` | `detalle_pedido.cantidad` | Sí | Debe ser `> 0`. |
| `lineas[].precio_unitario_facturado` | `Decimal128` | `detalle_pedido.precio_unitario_facturado` | Sí | Debe ser `>= 0`. |
| `lineas[].subtotal` | `Decimal128` | Derivado | No | `cantidad × precio_unitario_facturado`. Se materializa para evitar recalcular en cada lectura. |

### 3.3 Identificadores conservados

| Identificador relacional | Ubicación en el documento | Se conserva |
|---|---|---|
| `pedido.id_pedido` | `_id` | Sí (mismo valor) |
| `pedido.id_cliente` | `id_cliente` | Sí (referencia) |
| `detalle_pedido.id_pedido` | implícito en `_id` | Sí (por contención) |
| `detalle_pedido.id_producto` | `lineas[].id_producto` | Sí (referencia) |
| PK compuesta `(id_pedido, id_producto)` | `_id` + unicidad dentro de `lineas[]` | Sí (regla de validación) |

---

## 4. Validación propuesta (`$jsonSchema`)

```javascript
db.createCollection("pedidos", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "id_cliente", "fecha_pedido", "forma_pago", "lineas"],
      properties: {
        _id:        { bsonType: "long" },
        id_cliente: { bsonType: "long" },
        fecha_pedido: { bsonType: "date" },
        forma_pago: { enum: ["EFECTIVO", "TARJETA", "TRANSFERENCIA"] },
        lineas: {
          bsonType: "array",
          minItems: 1,
          items: {
            bsonType: "object",
            required: ["id_producto", "cantidad", "precio_unitario_facturado"],
            properties: {
              id_producto: { bsonType: "long" },
              cantidad: { bsonType: "int", minimum: 1 },
              precio_unitario_facturado: { bsonType: "decimal", minimum: 0 }
            }
          }
        },
        total_lineas:   { bsonType: "int", minimum: 1 },
        total_unidades: { bsonType: "int", minimum: 1 },
        monto_total:    { bsonType: "decimal", minimum: 0 }
      }
    }
  }
});
```

> La unicidad de `id_producto` dentro de `lineas[]` no se puede expresar con `$jsonSchema`; se garantiza en la ETL (la PK compuesta de origen ya la asegura) o con una validación de aplicación.

---

## 5. Índices recomendados en MongoDB

| Índice | Motivo | Equivalente relacional |
|---|---|---|
| `{ id_cliente: 1, fecha_pedido: -1 }` | Historial de pedidos por cliente, ordenado por fecha | `idx_pedido_cliente` + orden por fecha |
| `{ "lineas.id_producto": 1 }` | Buscar pedidos que contienen un producto (multikey) | `idx_detalle_pedido_id_producto` |
| `{ fecha_pedido: -1 }` | Listados cronológicos globales | — (no existía) |
| `{ monto_total: -1 }` | Rankings por facturación | — (derivado) |

---

## 6. Plantilla de documento (estructura, valores ilustrativos)

```javascript
{
  _id: NumberLong(1),                     // = pedido.id_pedido
  id_cliente: NumberLong(1),              // = pedido.id_cliente
  fecha_pedido: ISODate("2026-01-15T14:32:00Z"),
  forma_pago: "TARJETA",
  lineas: [
    {
      id_producto: NumberLong(2),
      cantidad: 3,
      precio_unitario_facturado: NumberDecimal("1250.00"),
      subtotal: NumberDecimal("3750.00")
    },
    {
      id_producto: NumberLong(17),
      cantidad: 1,
      precio_unitario_facturado: NumberDecimal("899.90"),
      subtotal: NumberDecimal("899.90")
    }
  ],
  total_lineas: 2,
  total_unidades: 4,
  monto_total: NumberDecimal("4649.90")
}
```

> Los valores numéricos de esta plantilla son **ilustrativos**: solo muestran tipos y forma del documento. No provienen de una extracción real (la conexión a `tp_food_store` fue rechazada al momento de redactar este documento).

---

## 7. Estrategia de migración de 5 pedidos

1. **Extracción (PostgreSQL):** tomar 5 `id_pedido` y volcar pedido + líneas en un único resultset agregado (JSON), preservando `id_pedido`, `id_cliente`, `id_producto`, `cantidad`, `precio_unitario_facturado`.
2. **Transformación:** agrupar por `id_pedido`; mapear `id_pedido → _id`, anidar las líneas en `lineas[]`, convertir `NUMERIC → Decimal128`, `TIMESTAMPTZ → Date` (UTC), calcular `subtotal`, `total_lineas`, `total_unidades`, `monto_total`.
3. **Carga (MongoDB):** `insertMany` o `bulkWrite` con `upsert` por `_id`, de modo que una re-ejecución no duplique documentos.
4. **Verificación:** para cada `_id`, comparar contra PostgreSQL:
   - cantidad de líneas = `COUNT(*)` en `detalle_pedido`,
   - `SUM(cantidad)` = `total_unidades`,
   - `SUM(cantidad * precio_unitario_facturado)` = `monto_total`.
5. **Rollback:** al estar identificados por `_id`, basta `deleteMany({ _id: { $in: [...] } })` para revertir la carga de prueba.

---

## 8. Resumen

| Concepto | Resultado |
|---|---|
| Colección | `pedidos` |
| Granularidad | 1 documento = 1 pedido |
| Embebido | `lineas[]` (1:N acotado, 2–5 elementos) |
| Referencias conservadas | `id_cliente`, `lineas[].id_producto` |
| Identidad conservada | `_id = id_pedido` (PK original) |
| Reglas heredadas | `cantidad > 0`, `precio_unitario_facturado >= 0`, `id_producto` único por pedido, ≥1 línea |
| Tipos monetarios | `Decimal128` (equivalente a `NUMERIC(10,2)`) |
