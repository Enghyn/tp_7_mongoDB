# Entrega — Trabajo Práctico Unidad 7: Food Store NoSQL

> **Materia:** Base de Datos II — NoSQL y nuevas formas de almacenamiento  
> **Carrera:** Tecnicatura Universitaria en Programación  
> **Proyecto:** Food Store (`tp_food_store` en PostgreSQL → migración parcial a MongoDB)

---

## Estructura de la entrega

```
entrega/
├── README.md                          ← Este archivo
├── INFORME.pdf                        ← Informe de hasta 5 páginas (agregar manualmente)
├── consultas_mongodb.js               ← Adjunto requerido: consultas MongoDB (Consigna 4)
├── consultas_postgresql.sql           ← Adjunto requerido: consultas PostgreSQL (Consigna 5)
├── migracion_mongodb.js               ← Script de creación y migración (Consigna 2)
├── pedidos.json                       ← Datos migrados en formato JSON nativo (Consigna 2)
└── docs/
    ├── schema.sql                     ← Esquema relacional original (PostgreSQL)
    ├── esquema_nosql_pedidos.md       ← Diseño del modelo documental (Consignas 1 y 3)
    ├── guia_migracion.md              ← Guía de replicación para colaboradores
    ├── verificacion_consultas.md      ← Tabla de verificación y evidencias (Consigna 5)
    ├── consigna6_ia.md               ← Consulta a IA y respuesta (Consigna 6)
    └── consigna7_conclusion.md       ← Contraste y conclusión (Consigna 7)
```

---

## Archivos adjuntos requeridos por el enunciado

El PDF del enunciado solicita como adjuntos:
1. **`consultas_mongodb.js`** — Instrucciones ejecutadas en MongoDB (4 consultas: a, b, c, d).
2. **`consultas_postgresql.sql`** — Instrucciones equivalentes en PostgreSQL (consultas b y c) + datos de prueba.

Ambos archivos se encuentran en la raíz de esta carpeta.

---

## Evidencias incluidas en el informe (PDF)

El informe de hasta 5 páginas debe contener:
1. **Descripción sintética del modelo** → ver `docs/esquema_nosql_pedidos.md` (secciones 1-3 y 9).
2. **Evidencias de la colección y consultas** → ver `migracion_mongodb.js`, `consultas_mongodb.js` y `docs/verificacion_consultas.md` (sección 4).
3. **Tabla de verificación** → ver `docs/verificacion_consultas.md` (sección 2).
4. **Contraste de afirmaciones de IA** → ver `docs/consigna6_ia.md` y `docs/consigna7_conclusion.md`.
5. **Conclusión** → ver `docs/consigna7_conclusion.md` (conclusión de 123 palabras).

---

## Replicación del entorno (para el evaluador)

Para replicar la base de datos MongoDB y verificar los resultados:

1. Instalar MongoDB Community Server + MongoDB Compass (o mongosh).
2. Ejecutar: `mongosh < migracion_mongodb.js` (crea DB, colección, datos, validador e índices).
   - Alternativa gráfica: importar `pedidos.json` en Compass y aplicar validador/índices (ver `docs/guia_migracion.md`).
3. Ejecutar las consultas: `mongosh < consultas_mongodb.js`.
4. Para PostgreSQL: ejecutar `consultas_postgresql.sql` en una base con el esquema de `docs/schema.sql`.

---

## Mapeo de consignas a archivos

| Consigna | Archivo(s) | Estado |
|----------|-----------|--------|
| 1 — Modelo documental | `docs/esquema_nosql_pedidos.md` (secciones 1-3) | ✅ |
| 2 — Creación y migración | `migracion_mongodb.js`, `pedidos.json` | ✅ |
| 3 — Reglas de integridad y justificación | `docs/esquema_nosql_pedidos.md` (sección 9) | ✅ |
| 4 — Consultas MongoDB | `consultas_mongodb.js` | ✅ |
| 5 — Consultas PostgreSQL + verificación | `consultas_postgresql.sql`, `docs/verificacion_consultas.md` | ✅ |
| 6 — Evaluación de IA | `docs/consigna6_ia.md` | ✅ |
| 7 — Contraste y conclusión | `docs/consigna7_conclusion.md` | ✅ |

---

## Notas

- No se incluyen datos personales reales.
- No se incluyen imágenes decorativas ni transcripciones extensas de conversaciones.
- Los identificadores se conservaron del esquema original (`id_pedido` → `_id`).
- Los precios históricos se almacenan como `Decimal128` (equivalente a `NUMERIC(10,2)`).
- La conclusión del informe (≤200 palabras) se encuentra en `docs/consigna7_conclusion.md` (123 palabras).
