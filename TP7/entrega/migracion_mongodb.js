/**
 * Script de Migración y Creación (Consigna 2)
 * Base de datos: food_store (o tp_food_store)
 * Colección: pedidos
 * 
 * Este script:
 * 1. Crea la base de datos y la colección `pedidos` con validación `$jsonSchema`.
 * 2. Inserta 5 pedidos de ejemplo con sus líneas embebidas, datos de cliente,
 *    fechas, estado, forma de pago, cantidades y precios históricos (Decimal128).
 * 3. Crea los índices recomendados para optimizar consultas.
 */

use food_store;

// 1. Eliminar colección previa si se desea reiniciar la prueba (opcional)
// db.pedidos.drop();

// 2. Crear colección con validación robusta ($jsonSchema)
db.createCollection("pedidos", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "id_cliente", "fecha_pedido", "estado", "forma_pago", "lineas", "monto_total"],
      properties: {
        _id:        { bsonType: "long", description: "Debe ser Long (equivalente a id_pedido)" },
        id_cliente: { bsonType: "long", description: "Debe ser Long (referencia al cliente)" },
        fecha_pedido: { bsonType: "date", description: "Debe ser fecha UTC" },
        estado:     { enum: ["PENDIENTE", "CONFIRMADO", "ENTREGADO", "CANCELADO"], description: "Estado del pedido" },
        forma_pago: { enum: ["EFECTIVO", "TARJETA", "TRANSFERENCIA"], description: "Forma de pago admitida" },
        lineas: {
          bsonType: "array",
          minItems: 1,
          maxItems: 10,
          description: "Arreglo embebido de líneas de detalle (2 a 5 típicamente)",
          items: {
            bsonType: "object",
            required: ["id_producto", "cantidad", "precio_unitario_facturado", "subtotal"],
            properties: {
              id_producto: { bsonType: "long", description: "Referencia al producto" },
              cantidad:    { bsonType: "int", minimum: 1, description: "Cantidad mayor a cero" },
              precio_unitario_facturado: { bsonType: "decimal", minimum: 0, description: "Precio histórico >= 0" },
              subtotal:    { bsonType: "decimal", minimum: 0, description: "cantidad * precio_unitario_facturado" }
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

print("Colección 'pedidos' creada exitosamente con esquema de validación.");

// 3. Inserción de 5 pedidos migrados/de prueba con datos completos
db.pedidos.insertMany([
  {
    _id: NumberLong(1),
    id_cliente: NumberLong(1),
    fecha_pedido: ISODate("2026-01-10T10:00:00Z"),
    estado: "CONFIRMADO",
    forma_pago: "EFECTIVO",
    lineas: [
      {
        id_producto: NumberLong(1),
        cantidad: 2,
        precio_unitario_facturado: NumberDecimal("500.00"),
        subtotal: NumberDecimal("1000.00")
      },
      {
        id_producto: NumberLong(2),
        cantidad: 1,
        precio_unitario_facturado: NumberDecimal("1200.50"),
        subtotal: NumberDecimal("1200.50")
      }
    ],
    total_lineas: 2,
    total_unidades: 3,
    monto_total: NumberDecimal("2200.50")
  },
  {
    _id: NumberLong(2),
    id_cliente: NumberLong(2),
    fecha_pedido: ISODate("2026-01-11T11:30:00Z"),
    estado: "ENTREGADO",
    forma_pago: "TARJETA",
    lineas: [
      {
        id_producto: NumberLong(3),
        cantidad: 4,
        precio_unitario_facturado: NumberDecimal("350.00"),
        subtotal: NumberDecimal("1400.00")
      }
    ],
    total_lineas: 1,
    total_unidades: 4,
    monto_total: NumberDecimal("1400.00")
  },
  {
    _id: NumberLong(3),
    id_cliente: NumberLong(1),
    fecha_pedido: ISODate("2026-01-12T14:15:00Z"),
    estado: "PENDIENTE",
    forma_pago: "TRANSFERENCIA",
    lineas: [
      {
        id_producto: NumberLong(1),
        cantidad: 1,
        precio_unitario_facturado: NumberDecimal("500.00"),
        subtotal: NumberDecimal("500.00")
      },
      {
        id_producto: NumberLong(4),
        cantidad: 2,
        precio_unitario_facturado: NumberDecimal("850.00"),
        subtotal: NumberDecimal("1700.00")
      },
      {
        id_producto: NumberLong(5),
        cantidad: 1,
        precio_unitario_facturado: NumberDecimal("200.00"),
        subtotal: NumberDecimal("200.00")
      }
    ],
    total_lineas: 3,
    total_unidades: 4,
    monto_total: NumberDecimal("2400.00")
  },
  {
    _id: NumberLong(4),
    id_cliente: NumberLong(3),
    fecha_pedido: ISODate("2026-01-13T16:45:00Z"),
    estado: "CONFIRMADO",
    forma_pago: "EFECTIVO",
    lineas: [
      {
        id_producto: NumberLong(2),
        cantidad: 2,
        precio_unitario_facturado: NumberDecimal("1200.50"),
        subtotal: NumberDecimal("2401.00")
      },
      {
        id_producto: NumberLong(6),
        cantidad: 3,
        precio_unitario_facturado: NumberDecimal("150.00"),
        subtotal: NumberDecimal("450.00")
      }
    ],
    total_lineas: 2,
    total_unidades: 5,
    monto_total: NumberDecimal("2851.00")
  },
  {
    _id: NumberLong(5),
    id_cliente: NumberLong(2),
    fecha_pedido: ISODate("2026-01-14T09:20:00Z"),
    estado: "ENTREGADO",
    forma_pago: "TARJETA",
    lineas: [
      {
        id_producto: NumberLong(5),
        cantidad: 5,
        precio_unitario_facturado: NumberDecimal("200.00"),
        subtotal: NumberDecimal("1000.00")
      },
      {
        id_producto: NumberLong(3),
        cantidad: 2,
        precio_unitario_facturado: NumberDecimal("350.00"),
        subtotal: NumberDecimal("700.00")
      }
    ],
    total_lineas: 2,
    total_unidades: 7,
    monto_total: NumberDecimal("1700.00")
  }
]);

print("Se han insertado 5 pedidos exitosamente.");

// 4. Creación de índices recomendados
db.pedidos.createIndex({ id_cliente: 1, fecha_pedido: -1 });
db.pedidos.createIndex({ "lineas.id_producto": 1 });
db.pedidos.createIndex({ estado: 1 });
db.pedidos.createIndex({ fecha_pedido: -1 });
db.pedidos.createIndex({ monto_total: -1 });

print("Índices creados exitosamente en la colección 'pedidos'.");
