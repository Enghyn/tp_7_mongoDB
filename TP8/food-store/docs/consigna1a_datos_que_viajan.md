# Consigna 1.a — Qué datos viajan a la tablet

> **Consigna:** tabla corta con las columnas de producto que viajan a la tablet y las que no viajan, dos o tres oraciones sobre por qué y quién es la fuente de verdad.

## Tabla de decisión

| Dato | ¿Viaja? | Cómo se guarda en SQLite | Motivo |
|---|---|---|---|
| `producto.id_producto` | **Sí** | `producto_cache.id` | Es la identidad que permite relacionar el borrador con el catálogo. Se conserva el ID original. |
| `producto.nombre` | **Sí** | `producto_cache.nombre` | La tablet necesita mostrar el producto al vendedor. |
| `producto.precio_lista` | **Sí** | `producto_cache.precio_centavos` | Se convierte a centavos enteros (`ROUND(precio_lista * 100)`) para evitar errores de punto flotante. Es solo un **precio visto**, no el precio oficial. |
| `producto.stock` | **Sí** | `producto_cache.stock_visto` | La tablet necesita saber si “parece” haber stock para armar el borrador. Es una foto del momento, no una reserva. |
| `producto.activo` | **Sí** | `producto_cache.eliminado` | Permite aplicar la baja lógica: si el producto fue dado de baja, el borrador no debe poder enviarse. |
| `producto.id_categoria` | **No** | — | La tablet no arma reportes ni navega por categorías; no aporta a la venta. |
| `categoria.nombre` | **No** | — | Dato de catálogo administrativo, no operativo para el vendedor. |
| `cliente.nombre`, `email`, `telefono` | **No** | — | Son datos personales. La tablet no los necesita para armar un borrador y la regla del TP8 prohíbe datos reales en SQLite. |
| `pedido` / `detalle_pedido` históricos | **No** | — | La tablet no consulta ventas cerradas ni confirma ventas; solo arma borradores. |
| Usuarios y contraseñas | **No** | — | Nunca viajan credenciales ni datos de autenticación. El borrador usa un identificador opaco de vendedor. |
| `producto.fecha_creacion` | **No** | — | No es necesaria para la operación de venta. |
| Fecha de la copia | **Sí** | `producto_cache.fecha_copia` | Permite saber qué tan vieja es la foto y detectar que hay que resincronizar. |

## Justificación

La tablet viaja a la feria sin señal, por lo que necesita una **copia mínima y de solo lectura** del catálogo: identificación, nombre, precio visto y stock visto. No viajan datos de clientes, usuarios ni historial de ventas porque no son necesarios para armar un borrador y aumentarían el riesgo de exponer datos personales en un dispositivo que puede perderse.

**La fuente de verdad es PostgreSQL.** La tablet nunca decide el precio ni el stock: solo guarda una foto (`snapshot`) y propone un borrador. El servidor es quien valida el precio, el stock y confirma (o no) la venta; por eso `SIMULADO_APROBADO` no es una venta y la tablet jamás escribe sobre PostgreSQL.
