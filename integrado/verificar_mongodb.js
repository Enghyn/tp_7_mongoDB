// Verificación de la migración (modo JS estricto, sin `use`)
const dbi = db.getSiblingDB("food_store");
print("Base: " + dbi.getName());
print("pedidos=" + dbi.pedidos.countDocuments());

const estados = dbi.pedidos.aggregate([
  { $group: { _id: "$estado", n: { $sum: 1 } } },
  { $sort: { _id: 1 } }
]).toArray().map(e => e._id + ":" + e.n);
print("estados=" + estados.join(" | "));

const info = dbi.getCollectionInfos({ name: "pedidos" })[0];
const val = info && info.options && info.options.validator;
print("validator=" + (val ? "presente ($jsonSchema)" : "AUSENTE"));
print("validationLevel=" + ((info.options && info.options.validationLevel) || "strict"));

const idx = dbi.pedidos.getIndexes();
print("indices=" + idx.length + " [" + idx.map(i => i.name).join(", ") + "]");

const p3 = dbi.pedidos.findOne({ _id: 3 });
print("pedido_3: cliente=" + p3.id_cliente + " estado=" + p3.estado + " monto=" + p3.monto_total + " lineas=" + p3.lineas.length);
