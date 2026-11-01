# Consigna 6 — Uso de IA para comparar tecnologías (PostgreSQL vs MongoDB)

> Documento que registra la interacción con una herramienta de IA solicitada en la **Consigna 6** del TP de Bases de Datos II (Food Store). Se incluye el prompt exacto enviado y la respuesta completa obtenida.

---

## 1. Referencia a la consigna

- **Consigna:** 6 — Uso de IA (comparación de tecnologías para el subconjunto de pedidos).
- **Proyecto:** Food Store (`tp_food_store` en PostgreSQL, migración parcial a MongoDB).
- **Subconjunto evaluado:** `pedido` + `detalle_pedido` (pedidos y sus líneas de detalle).
- **Objetivo:** determinar cuál tecnología (PostgreSQL o MongoDB) es más adecuada para almacenar y consultar este subconjunto, considerando el patrón de acceso (lectura completa del pedido) y las restricciones de coherencia (cantidad > 0, precio_unitario_facturado >= 0, valores históricos).

---

## 2. Herramienta de IA utilizada

Se utilizó un **asistente de IA invocado como subagente** (agente de codificación con capacidades de razonamiento) para generar la comparación técnica entre PostgreSQL y MongoDB aplicada al modelo de datos del proyecto Food Store. La respuesta se obtuvo en una única interacción (prompt → respuesta) y se transcribe íntegramente en la sección 4.

---

## 3. Prompt enviado a la IA (texto exacto)

> Compara PostgreSQL y MongoDB respecto del almacenamiento y la consulta de pedidos de Food Store. El modelo actual tiene tablas relacionales: pedido (id_pedido, id_cliente, fecha_pedido, forma_pago) y detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario_facturado) con clave primaria compuesta (id_pedido, id_producto). Los pedidos se acceden frecuentemente de forma completa (pedido + todas sus líneas de detalle). Es necesario conservar la coherencia de cantidades (cantidad > 0) y precios (precio_unitario_facturado >= 0, valores históricos). ¿Cuál tecnología es más adecuada para este subconjunto?

---

## 4. Respuesta completa de la IA

### Comparación PostgreSQL vs MongoDB — subconjunto `pedido` + `detalle_pedido` (Food Store)

#### 4.1 Resumen ejecutivo

Para este subconjunto, **PostgreSQL sigue siendo la opción más adecuada** como fuente de verdad, mientras que **MongoDB es una excelente opción como modelo de lectura (read model) optimizado para el patrón de acceso "pedido completo"**. La decisión no es excluyente: lo más razonable en un contexto real es un enfoque híbrido (PostgreSQL como sistema transaccional, MongoDB como proyección de lectura), pero si se debe elegir una sola tecnología para este subconjunto con los requisitos de coherencia indicados, **PostgreSQL es la recomendación principal** y MongoDB la alternativa cuando el patrón de lectura completa domine y se acepte mover parte de la integridad a la aplicación.

#### 4.2 Modelo de datos y ajuste al patrón de acceso

**PostgreSQL (relacional, normalizado)**

- `pedido` y `detalle_pedido` son dos tablas con relación 1:N y PK compuesta `(id_pedido, id_producto)`.
- Leer un pedido completo requiere un `JOIN` (o dos consultas) y reensamblar en aplicación las líneas dentro del pedido.
- El modelo es canónico y evita duplicación: cliente y producto se referencian por FK; los precios históricos se conservan en `detalle_pedido.precio_unitario_facturado` sin tocar `producto.precio`.

**MongoDB (documental, desnormalizado)**

- Un documento por pedido, con `lineas[]` embebido. Leer el pedido completo es una sola operación (`findOne` por `_id`), sin JOIN ni reensamblado.
- El arreglo está acotado (2–5 líneas por pedido), muy lejos del límite de 16 MB por documento, por lo que el embebido es seguro y eficiente.
- Las referencias a `cliente` y `producto` se conservan como identificadores (`id_cliente`, `lineas[].id_producto`), manteniendo la trazabilidad con el esquema relacional.

**Veredicto parcial:** MongoDB se ajusta mejor al patrón de lectura frecuente "pedido completo"; PostgreSQL se ajusta mejor a la normalización y a la integridad referencial.

#### 4.3 Coherencia de cantidades y precios

Requisito: `cantidad > 0` y `precio_unitario_facturado >= 0`, más valores históricos.

**PostgreSQL**

- Las restricciones se declaran de forma declarativa y se hacen cumplir en el motor: `CHECK (cantidad > 0)`, `CHECK (precio_unitario_facturado >= 0)`.
- Son inmutables respecto al tipo de dato `NUMERIC(10,2)`, que preserva precisión monetaria exacta (sin errores de punto flotante).
- La FK `id_producto → producto` y `id_cliente → cliente` con `ON DELETE RESTRICT` garantizan que no se creen líneas huérfanas ni pedidos con cliente inexistente.
- La PK compuesta `(id_pedido, id_producto)` garantiza que un producto aparezca como máximo una vez por pedido, a nivel de motor.

**MongoDB**

- La validación se implementa con `$jsonSchema` (validador de colección) y/o validación en la aplicación. Permite `minimum: 1` para `cantidad` y `minimum: 0` para `precio_unitario_facturado`, y tipos `int` / `decimal` (Decimal128).
- `Decimal128` es el equivalente a `NUMERIC` y conserva la precisión monetaria; es la elección correcta para precios históricos.
- La unicidad de `id_producto` dentro de `lineas[]` **no** se puede expresar con `$jsonSchema`; debe garantizarse en la ETL o en la aplicación (la PK compuesta de origen ya la asegura).
- No hay FK nativas: la integridad referencial con `cliente` y `producto` queda como convención lógica, validada por la aplicación o por procesos de sincronización.
- La validación `$jsonSchema` es opcional y puede desactivarse (`validationLevel`/`validationAction`), por lo que depende de la disciplina operativa.

**Veredicto parcial:** PostgreSQL gana en integridad declarativa y referencial; MongoDB puede cubrir las restricciones de rango y tipo, pero con más esfuerzo y menor garantía estructural (especialmente la unicidad dentro del arreglo y las FK).

#### 4.4 Transacciones y consistencia

**PostgreSQL**

- Transacciones ACID completas y maduras. Insertar un pedido con N líneas es una transacción multi-tabla nativa, con rollback automático ante cualquier fallo.
- Concurrencia controlada por MVCC; aislamiento configurable (`READ COMMITTED`, `SERIALIZABLE`, etc.).
- Ideal cuando la coherencia de cantidades y precios es crítica y no se puede tolerar un estado intermedio.

**MongoDB**

- Soporta transacciones multi-documento desde la versión 4.0 (replica set) y 4.2 (sharded clusters), por lo que es posible insertar pedido + líneas de forma atómica.
- Sin embargo, en el modelo propuesto (un documento por pedido con líneas embebidas) **no se necesita transacción multi-documento**: la inserción del documento completo es atómica por definición. Esta es una de las principales ventajas del embebido.
- Las transacciones en MongoDB tienen mayor overhead y restricciones (límite de tiempo, tamaño de documento, impacto en rendimiento) que en PostgreSQL, por lo que conviene evitarlas cuando el embebido las elimina.

**Veredicto parcial:** Empate favorable a MongoDB en este caso concreto, porque el embebido elimina la necesidad de transacción multi-documento para la inserción/lectura del pedido completo. PostgreSQL sigue siendo superior para transacciones que involucren múltiples entidades (pedido + cliente + stock + pago).

#### 4.5 Rendimiento y consultas

**PostgreSQL**

- Consulta típica: `SELECT ... FROM pedido JOIN detalle_pedido ... WHERE id_pedido = ?`. Con PK e índices, es eficiente, pero implica JOIN y reensamblado.
- Bueno para reportes agregados (facturación por cliente, productos más vendidos) con SQL estándar y optimizador maduro.
- Escala verticalmente muy bien; el particionamiento y el sharding son posibles pero más complejos.

**MongoDB**

- Lectura del pedido completo en una sola operación de disco, sin JOIN: latencia predeciblemente baja.
- Índices multikey (`lineas.id_producto`) permiten buscar pedidos que contienen un producto con buen rendimiento.
- Agregaciones con `$lookup` (equivalente a JOIN) son posibles pero menos eficientes y expresivas que SQL para reportes complejos.
- Escala horizontal (sharding) de forma nativa, útil si el volumen de pedidos crece mucho.

**Veredicto parcial:** MongoDB gana en lectura de pedido completo (patrón dominante del subconjunto); PostgreSQL gana en consultas analíticas/ad-hoc y reportes.

#### 4.6 Valores históricos (precio_unitario_facturado)

Ambas tecnologías conservan correctamente los precios históricos porque el precio se almacena en la línea del pedido en el momento de la compra, no se deriva del catálogo actual:

- PostgreSQL: `NUMERIC(10,2)` en `detalle_pedido`, inmutable por diseño.
- MongoDB: `Decimal128` en `lineas[].precio_unitario_facturado`, inmutable dentro del documento.

No hay diferencia funcional aquí; la diferencia es de precisión y ergonomía (SQL `NUMERIC` vs BSON `Decimal128`), ambas adecuadas.

#### 4.7 Conclusión y recomendación

- Si el subconjunto se mantiene **dentro del sistema transaccional principal** (Food Store completo, con clientes, productos, stock, pagos), **PostgreSQL es más adecuado**: la integridad referencial, las restricciones CHECK y las transacciones multi-entidad son requisitos duros y PostgreSQL los resuelve de forma declarativa y robusta.
- Si el foco es **optimizar el patrón de lectura "pedido completo"** (por ejemplo, una vista de "mis pedidos", un API de consulta de alto tráfico, o un read model en una arquitectura CQRS), **MongoDB es más adecuado**: un documento por pedido elimina JOINs y reensamblado, y el embebido hace atómica la lectura/escritura sin transacciones multi-documento.
- **Recomendación para este TP:** mantener PostgreSQL como fuente de verdad (integridad de cantidades, precios y referencias) y usar MongoDB como proyección de lectura del subconjunto de pedidos (colección `pedidos` con líneas embebidas), aplicando `$jsonSchema` con `minimum` para `cantidad` y `precio_unitario_facturado`, `Decimal128` para montos, e índices multikey para búsquedas por producto. Esta es exactamente la migración parcial documentada en `docs/esquema_nosql_pedidos.md`.

---

## 5. Nota sobre el modelo utilizado

- **Modelo / proveedor:** Beam Free (proveedor `opencode-go`, modelo `beam-free`), invocado como asistente de IA mediante subagente.
- La respuesta se generó en una única interacción a partir del prompt de la sección 3, sin herramientas externas adicionales ni acceso a la base de datos; el razonamiento se basa en el conocimiento general del modelo sobre PostgreSQL y MongoDB y en el contexto del modelo de datos descrito en el prompt.

---

*Documento generado para la Consigna 6 del TP de Bases de Datos II — Food Store.*
