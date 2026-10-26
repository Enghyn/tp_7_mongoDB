# Guía de Reproducción y Replicación — Consignas 1 y 2 (Food Store NoSQL)

> Esta guía está destinada a miembros del equipo que clonen el repositorio y necesiten replicar el entorno de MongoDB y la migración de datos hasta la **Consigna 2** de forma exacta.

---

## 1. Archivos disponibles en el repositorio

Para levantar y replicar el trabajo hecho hasta la Consigna 2, el repositorio incluye:
- `docs/esquema_nosql_pedidos.md`: Documentación y diseño del modelo documental (Consigna 1).
- `migracion_mongodb.js`: Script automatizado para `mongosh` que crea la base de datos, aplica el `$jsonSchema` de validación, inserta los 5 pedidos de prueba con precios históricos y genera los índices.
- `pedidos.json`: Archivo con los 5 documentos en formato JSON nativo de MongoDB (útil para importación visual en MongoDB Compass).

---

## 2. Requisitos previos

- Tener instalado **MongoDB** (MongoDB Community Server).
- Tener instalado **MongoDB Compass** (interfaz gráfica) o **mongosh** (consola de comandos de MongoDB).

---

## 3. Pasos para replicar en tu entorno local

Tienes **dos opciones** equivalentes para replicar los datos, el esquema de validación y los índices en tu MongoDB local:

### Opción A: Mediante la consola `mongosh` (Recomendado y automatizado)
Si tienes acceso a la terminal con `mongosh` instalado, puedes ejecutar el script completo ubicado en la raíz del proyecto:

```bash
mongosh < migracion_mongodb.js
```

O bien, abrir `mongosh` y cargar el archivo:
```javascript
load("migracion_mongodb.js")
```
Esto creará automáticamente la base de datos `food_store`, la colección `pedidos`, insertará los 5 pedidos, aplicará el validador estricto y creará todos los índices de rendimiento.

---

### Opción B: Mediante MongoDB Compass (Interfaz Gráfica)
Si prefieres usar la interfaz visual de MongoDB Compass:

1. Abre **MongoDB Compass** y conéctate a tu instancia local (`mongodb://localhost:27017`).
2. Crea una base de datos llamada **`food_store`** y una colección llamada **`pedidos`**.
3. Haz clic en la pestaña **Add Data** ➔ **Import Data** y selecciona el archivo **`pedidos.json`** ubicado en la raíz del repositorio. Asegúrate de seleccionar el formato **JSON**.
4. Una vez importados los datos, ve a la pestaña **mongosh** (consola integrada en Compass) y pega el siguiente bloque para aplicar las reglas de validación y los índices de rendimiento:

```javascript
// 1. Aplicar validador de esquema
db.runCommand({
  collMod: "pedidos",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "id_cliente", "fecha_pedido", "estado", "forma_pago", "lineas", "monto_total"],
      properties: {
        _id:        { bsonType: "long" },
        id_cliente: { bsonType: "long" },
        fecha_pedido: { bsonType: "date" },
        estado:     { enum: ["PENDIENTE", "CONFIRMADO", "ENTREGADO", "CANCELADO"] },
        forma_pago: { enum: ["EFECTIVO", "TARJETA", "TRANSFERENCIA"] },
        lineas: {
          bsonType: "array",
          minItems: 1,
          items: {
            bsonType: "object",
            required: ["id_producto", "cantidad", "precio_unitario_facturado", "subtotal"],
            properties: {
              id_producto: { bsonType: "long" },
              cantidad:    { bsonType: "int", minimum: 1 },
              precio_unitario_facturado: { bsonType: "decimal", minimum: 0 },
              subtotal:    { bsonType: "decimal", minimum: 0 }
            }
          }
        },
        total_lineas:   { bsonType: "int", minimum: 1 },
        total_unidades: { bsonType: "int", minimum: 1 },
        monto_total:    { bsonType: "decimal", minimum: 0 }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

// 2. Crear los índices de rendimiento
db.pedidos.createIndex({ id_cliente: 1, fecha_pedido: -1 });
db.pedidos.createIndex({ "lineas.id_producto": 1 });
db.pedidos.createIndex({ estado: 1 });
db.pedidos.createIndex({ fecha_pedido: -1 });
db.pedidos.createIndex({ monto_total: -1 });
```

---

## 4. Verificación de la replicación

Para comprobar que todo está correctamente replicado en la máquina del colaborador, ejecuta en `mongosh`:

1. **Verificar documentos migrados (deben ser 5):**
   ```javascript
   use food_store;
   db.pedidos.countDocuments();
   ```
2. **Verificar índices creados (deben aparecer 6 índices):**
   ```javascript
   db.pedidos.getIndexes();
   ```
3. **Verificar validador activo:**
   ```javascript
   db.getCollectionInfos({ name: "pedidos" });
   ```
