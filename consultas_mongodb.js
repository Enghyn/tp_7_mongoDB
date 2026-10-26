// ==========================================
// TRABAJO PRÁCTICO UNIDAD 7 - FOOD STORE
// Consigna 4: Consultas MongoDB
// ==========================================

// a) Mostrar todos los pedidos, incluyendo su identificador y estado
db.pedidos.find(
  {},
  { _id: 1, estado: 1 }
);

// b) Filtrar pedidos por un estado que exista en los datos migrados
db.pedidos.find(
  { estado: "ENTREGADO" }
);

// c) Buscar pedidos que contengan un producto determinado dentro del arreglo de líneas
db.pedidos.find(
  { "lineas.id_producto": 1 }
);

// d) Buscar pedidos cuyo total sea superior a un importe elegido ($1500)
// Umbral elegido: $1500 (separa compras pequeñas de tickets de consumo mayor)
db.pedidos.find(
  { monto_total: { $gt: 1500 } }
);