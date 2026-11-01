# Consigna 7 — Contraste de afirmaciones de IA con documentación oficial y resultados de laboratorio

## Afirmación 1 (IA, sección 4.3 de `consigna6_ia.md`)

> "La unicidad de `id_producto` dentro de `lineas[]` no se puede expresar con `$jsonSchema`; debe garantizarse en la ETL o en la aplicación (la PK compuesta de origen ya la asegura)."

### Contraste con documentación oficial (MongoDB)

Según la documentación oficial de MongoDB, `$jsonSchema` **no** soporta restricciones de unicidad de propiedades dentro de arreglos de objetos. El operador `uniqueItems` solo aplica a arreglos simples de valores escalares, no a la unicidad de un campo (p. ej. `id_producto`) dentro de objetos embebidos. Por lo tanto, no es posible declarar "no se repite `id_producto` en `lineas[]`" mediante el validador de colección.

### Contraste con resultado de laboratorio

En `migracion_mongodb.js`, el validador `$jsonSchema` de la colección `pedidos` **no** incluye ninguna restricción de unicidad para `id_producto` dentro de `lineas[]` (solo `bsonType`, `minimum`, etc.). Esto confirma la afirmación de la IA: la unicidad debe garantizarse en la ETL/aplicación.

---

## Afirmación 2 (IA, sección 4.3 de `consigna6_ia.md`)

> "PostgreSQL tiene restricciones CHECK nativas que se aplican en el motor: `CHECK (cantidad > 0)`, `CHECK (precio_unitario_facturado >= 0)`."

### Contraste con documentación oficial / `schema.sql`

El esquema relacional define restricciones nombradas a nivel de motor:
- `CONSTRAINT chk_detalle_cantidad_positiva CHECK (cantidad > 0)`
- `CONSTRAINT chk_detalle_precio_facturado_positivo CHECK (precio_unitario_facturado >= 0)`

Estas restricciones son obligatorias y se aplican en el motor de PostgreSQL, sin posibilidad de desactivarlas por configuración de colección.

### Contraste con resultado de laboratorio

En MongoDB, el equivalente es `$jsonSchema` con `minimum: 1` para `cantidad` y `minimum: 0` para `precio_unitario_facturado` (ver `migracion_mongodb.js`). Esta validación es **opcional** y puede desactivarse (`validationLevel`/`validationAction`), por lo que depende de la disciplina operativa. Esto confirma que las restricciones CHECK de PostgreSQL son más robustas (obligatorias, a nivel de motor) que `$jsonSchema` (opcional, a nivel de colección).

---

## Conclusión

Se recomienda combinar tecnologías: mantener PostgreSQL como fuente de verdad transaccional y utilizar MongoDB como proyección de lectura del subconjunto de pedidos. Criterio 1 — Integridad declarativa: PostgreSQL aplica restricciones CHECK y FK a nivel de motor de forma obligatoria, mientras que MongoDB depende de validación opcional ($jsonSchema) y de la disciplina de la aplicación para garantizar unicidad dentro de arreglos. Criterio 2 — Patrón de acceso: MongoDB optimiza la lectura completa del pedido (un documento, sin JOIN ni reensamblado), lo que beneficia el patrón de acceso frecuente "pedido + líneas". La migración parcial documentada (colección pedidos con líneas embebidas, Decimal128 e índices multikey) es viable siempre que PostgreSQL siga siendo la fuente de verdad y se mantenga la sincronización entre ambos motores.

> Conteo de palabras de la conclusión: 123
