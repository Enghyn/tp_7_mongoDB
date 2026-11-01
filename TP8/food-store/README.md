# Food Store — Tablet (TP8)

> **Materia:** Base de Datos II — Tecnicatura Universitaria en Programación
> **Proyecto:** Food Store — cierre de la capa de datos (PostgreSQL + MongoDB + SQLite)

---

## Orden para crear todo desde cero

### 1. PostgreSQL (servidor — fuente de verdad)

```bash
# 1.1 Instalar PostgreSQL 16+ y crear la base
psql -U postgres -c "CREATE DATABASE tp_food_store;"

# 1.2 Ejecutar el esquema
psql -U postgres -d tp_food_store -f ../../schema.sql

# 1.3 (Opcional) Cargar datos de prueba (200.000 pedidos, 50.000 productos, 20.000 clientes)
#     O usar la base existente en localhost:5433
```

### 2. MongoDB (servidor — proyección de lectura)

```bash
# 2.1 Instalar MongoDB Community Server
# 2.2 Ejecutar el script de migración
mongosh < ../../migracion_mongodb.js
# Crea base food_store, colección pedidos con validación, 5 pedidos, índices
```

### 3. SQLite (tablet)

```bash
cd movil

# 3.1 Crear la base y ejecutar el esquema
python run_pruebas.py --db foodstore_movil.db --fresh
# Resultado esperado: 55 PASS, 0 FAIL

# 3.2 Cargar el snapshot del catálogo desde PostgreSQL
#     (requiere servidor_snapshot.csv exportado de PostgreSQL)
python run_cargar_snapshot.py --db foodstore_movil.db --csv servidor_snapshot.csv
# Resultado esperado: 50.000 productos cargados

# 3.3 Ejecutar el semáforo
sqlite3 foodstore_movil.db < semaforo.sql
# (o via Python: ver run_pruebas.py como referencia)

# 3.4 Simular casos C2-C6
python simular_casos.py --db foodstore_movil.db
```

### 4. Verificación

```bash
# 4.1 Verificar que la base SQLite tiene los datos correctos
python -c "
import sqlite3
conn = sqlite3.connect('foodstore_movil.db')
conn.execute('PRAGMA foreign_keys = ON;')
print('producto_cache:', conn.execute('SELECT count(*) FROM producto_cache').fetchone()[0])
print('pedido_borrador:', conn.execute('SELECT count(*) FROM pedido_borrador').fetchone()[0])
print('item_borrador:', conn.execute('SELECT count(*) FROM item_borrador').fetchone()[0])
print('cola_sync:', conn.execute('SELECT count(*) FROM cola_sync').fetchone()[0])
conn.close()
"

# 4.2 Verificar PostgreSQL (modo single-user si el multi-usuario crashea)
# psql -h localhost -p 5433 -U postgres -d tp_food_store -c "SELECT count(*) FROM pedido;"
# Esperado: 200000
```

---

## Estructura del proyecto

```
food-store/
├── README.md                          ← Este archivo
├── movil/
│   ├── schema_sqlite.sql              ← Esquema SQLite (4 tablas STRICT)
│   ├── pruebas_sqlite.sql             ← Pruebas (55 tests)
│   ├── semaforo.sql                   ← Semáforo de sincronización
│   ├── cargar_snapshot.sql            ← SQL de carga de snapshot
│   ├── servidor_snapshot.csv          ← CSV exportado de PostgreSQL
│   ├── run_pruebas.py                 ← Arnés de pruebas
│   ├── run_cargar_snapshot.py         ← Arnés de carga
│   ├── simular_casos.py               ← Simulación de casos
│   ├── foodstore_movil.db             ← Base SQLite generada
│   └── README.md                      ← Cómo ejecutar las pruebas
├── docs/
│   ├── informe.pdf                    ← Informe (máx. 6 páginas)
│   ├── kiro/
│   │   ├── requirements.md            ← 4 requisitos EARS
│   │   ├── design.md                  ← Diseño breve
│   │   └── tasks.md                   ← Tareas por fase
│   ├── evidencias_consigna1.md        ← Evidencias Consigna 1
│   ├── evidencias_consigna2.md        ← Evidencias Consigna 2
│   ├── mapa_capa_datos.md             ← Mapa de la capa de datos
│   ├── plan_mantenimiento.md          ← Plan de mantenimiento
│   ├── code_review_ia.md              ← Code review con IA
│   ├── v_snapshot_movil.sql           ← Vista PostgreSQL
│   ├── consigna1a_datos_que_viajan.md ← Datos que viajan
│   └── plan_diseno.md                 ← Plan de diseño
├── bitacora_ia.md                     ← Bitácora de IA (≥3 entradas)
└── DUIA.md                            ← Declaración de uso de IA
```

---

## Regla de oro

> El móvil propone, el servidor dispone. La tablet solo consulta y arma borradores. Precio, stock y ventas los decide PostgreSQL. `SIMULADO_APROBADO` no es una venta.

---

## Notas importantes

1. **PostgreSQL:** El servidor multi-usuario crashea en este entorno Windows (error 0xC0000142). Se usa modo single-user (`postgres --single`) para ejecutar SQL. La contraseña fue reseteada a `'postgres'`.
2. **SQLite:** No hay CLI de `sqlite3` instalado. Se usa Python 3.14 + SQLite 3.50.4 (soporta STRICT).
3. **MongoDB:** La base `food_store` tiene la colección `pedidos` con 5 documentos de prueba y validador `$jsonSchema`.
4. **Datos personales:** No se usan datos personales reales en SQLite ni en las consultas a la IA.
5. **SIMULADO_APROBADO:** No es una venta. El vendedor debe enviar manualmente tras la simulación.

---

*Food Store — Base de Datos II — Tecnicatura Universitaria en Programación*