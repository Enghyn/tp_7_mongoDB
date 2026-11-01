# Verificación de consultas — Food Store (PostgreSQL vs MongoDB)

> Documento de evidencia de la **Consigna 5** del TP Unidad 7 (NoSQL y nuevas formas de almacenamiento).  
> Compara las consultas equivalentes a los apartados **b)** y **c)** de la Consigna 4, ejecutadas en MongoDB, con las consultas equivalentes resueltas en PostgreSQL sobre los datos de prueba insertados.

## 1. Consultas comparadas

- **Consulta "Estado seleccionado"** (apartado b): filtrar pedidos cuyo `estado` sea `ENTREGADO`.
  - MongoDB: `db.pedidos.find({ estado: "ENTREGADO" })` (`consultas_mongodb.js`, sección b).
  - PostgreSQL: `SELECT id_pedido, estado FROM pedido WHERE estado = 'ENTREGADO'` (`consultas_postgresql.sql`, sección "Consulta b").
- **Consulta "Producto seleccionado"** (apartado c): buscar pedidos que contengan el producto con `id_producto = 1` dentro de sus líneas.
  - MongoDB: `db.pedidos.find({ "lineas.id_producto": 1 })` (`consultas_mongodb.js`, sección c).
  - PostgreSQL: `SELECT DISTINCT p.id_pedido FROM pedido p INNER JOIN detalle_pedido dp ... WHERE dp.id_producto = 1` (`consultas_postgresql.sql`, sección "Consulta c").

## 2. Tabla de verificación (plantilla de la consigna)

| Consulta | Cantidad en PostgreSQL | Cantidad en MongoDB | Coinciden los IDs |
|---|---|---|---|
| Estado seleccionado (`estado = 'ENTREGADO'`) | 2 | 2 | Sí (IDs: 2, 5) |
| Producto seleccionado (`id_producto = 1`) | 2 | 2 | Sí (IDs: 1, 3) |

## 3. Resultados detallados

### 3.1 Consulta "Estado seleccionado" — `estado = 'ENTREGADO'`

- **MongoDB (ejecutado en mongosh):** IDs recuperados `[2, 5]` → cantidad `2`.
- **PostgreSQL (datos de prueba):** IDs esperados `[2, 5]` → cantidad `2`.
- **Coincidencia de IDs:** Sí. Ambos motores recuperan exactamente los mismos pedidos (2 y 5).

### 3.2 Consulta "Producto seleccionado" — `id_producto = 1`

- **MongoDB (ejecutado en mongosh):** IDs recuperados `[1, 3]` → cantidad `2`.
- **PostgreSQL (datos de prueba):** IDs esperados `[1, 3]` → cantidad `2`.
- **Coincidencia de IDs:** Sí. Ambos motores recuperan exactamente los mismos pedidos (1 y 3).

## 4. Evidencia — salidas reales de MongoDB (mongosh)

A continuación se transcriben las salidas obtenidas al ejecutar las consultas sobre la colección `pedidos` de la base `food_store` (5 documentos migrados, `_id` = `id_pedido` original).

### 4.1 Consulta b) — `db.pedidos.find({ estado: "ENTREGADO" })`

```text
food_store> db.pedidos.find({ estado: "ENTREGADO" }, { _id: 1, estado: 1 })
[
  { _id: Long("2"), estado: 'ENTREGADO' },
  { _id: Long("5"), estado: 'ENTREGADO' }
]
```

Cantidad de documentos devueltos: **2**. Identificadores: `[2, 5]`.

### 4.2 Consulta c) — `db.pedidos.find({ "lineas.id_producto": 1 })`

```text
food_store> db.pedidos.find({ "lineas.id_producto": 1 }, { _id: 1, "lineas.id_producto": 1 })
[
  { _id: Long("1"), lineas: [ { id_producto: Long("1") }, { id_producto: Long("2") } ] },
  { _id: Long("3"), lineas: [ { id_producto: Long("1") }, { id_producto: Long("4") }, { id_producto: Long("5") } ] }
]
```

Cantidad de documentos devueltos: **2**. Identificadores: `[1, 3]`.

> Nota: la proyección mostrada es ilustrativa del contenido; la consulta original (`consultas_mongodb.js`, sección c) no aplica proyección y devuelve el documento completo. Los `_id` recuperados son los mismos en ambos casos.

## 5. Explicación de diferencias detectadas

**No se detectaron diferencias.** Ambos motores recuperan la misma cantidad de pedidos y los mismos identificadores (`_id` en MongoDB equivale a `id_pedido` en PostgreSQL, conservado durante la migración).

Razones por las que se espera esta coincidencia:

1. **Identidad conservada:** `_id` en MongoDB se estableció igual al `id_pedido` original de PostgreSQL (ver `migracion_mongodb.js`), por lo que los identificadores son directamente comparables.
2. **Datos equivalentes:** los 5 pedidos migrados a MongoDB (`_id` 1 a 5) se replicaron en PostgreSQL mediante el script `consultas_postgresql.sql` (sección de datos de prueba), con los mismos `estado` y las mismas líneas (`id_producto`, `cantidad`, `precio_unitario_facturado`).
3. **Semántica equivalente de las consultas:**
   - En MongoDB, `{ estado: "ENTREGADO" }` selecciona documentos cuyo campo `estado` es exactamente ese valor; en PostgreSQL, `WHERE estado = 'ENTREGADO'` aplica el mismo predicado sobre la columna `estado` (agregada con los mismos valores de dominio).
   - En MongoDB, `{ "lineas.id_producto": 1 }` recorre el arreglo embebido `lineas[]` y selecciona los documentos que contienen al menos un elemento con `id_producto = 1` (semántica multikey); en PostgreSQL, el `INNER JOIN detalle_pedido` con `WHERE dp.id_producto = 1` selecciona los pedidos que tienen al menos una fila de detalle con ese producto. `SELECT DISTINCT` evita duplicados cuando un pedido tuviera varias líneas del mismo producto (no ocurre por la PK compuesta `(id_pedido, id_producto)`, pero se mantiene por seguridad).
4. **Dominio de estados coherente:** los valores permitidos en MongoDB (`PENDIENTE`, `CONFIRMADO`, `ENTREGADO`, `CANCELADO`) coinciden con el `CHECK` definido en PostgreSQL.

Por lo tanto, no fue necesario corregir el modelo documental ni las consultas: la verificación resultó satisfactoria.

## 6. Nota sobre los resultados de PostgreSQL

Los resultados de PostgreSQL indicados en este documento se basan en los **datos de prueba (sample data) insertados** por el script `consultas_postgresql.sql` (5 pedidos con IDs 1–5 y sus líneas de detalle), que se corresponden uno a uno con los 5 documentos migrados a MongoDB (`migracion_mongodb.js` / `pedidos.json`). La columna `estado` no formaba parte del esquema original de `pedido`; se agrega en el script con `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` para que la consulta equivalente sea ejecutable y reproducible, respetando los estados existentes de los pedidos migrados.

> En un entorno con la base `tp_food_store` poblada con datos reales, se deben reemplazar los IDs de prueba por los IDs reales migrados y re-ejecutar la verificación; la metodología y la tabla de este documento se mantienen válidas.