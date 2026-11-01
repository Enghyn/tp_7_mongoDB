# DUIA — Declaración de Uso de IA

> **Proyecto:** Food Store — cierre de la capa de datos (TP8)
> **Materia:** Base de Datos II — Tecnicatura Universitaria en Programación

---

## Declaración de Uso de Inteligencia Artificial

Los integrantes del equipo declaran que utilizaron herramientas de Inteligencia Artificial (OpenCode, agente de razonamiento) como apoyo durante el desarrollo del Trabajo Práctico 8, en los siguientes aspectos:

1. **Diseño de esquemas:** Generación inicial de la estructura de tablas SQLite (`schema_sqlite.sql`) y la vista `v_snapshot_movil` en PostgreSQL, posteriormente revisadas y ajustadas manualmente.

2. **Generación de código:** Scripts de carga (`run_cargar_snapshot.py`), simulación de casos (`simular_casos.py`) y semáforo (`semaforo.sql`), generados con asistencia de IA y verificados mediante ejecución real.

3. **Code review:** Revisión automatizada de scripts de TP7 y TP8 con identificación de hallazgos, documentada en `docs/code_review_ia.md`. Al menos un hallazgo fue descartado con fundamento (no se aceptó todo lo propuesto por la IA).

4. **Documentación:** Redacción de documentos técnicos (mapa de la capa de datos, plan de mantenimiento, bitácora) con asistencia de IA, revisados y validados por el equipo.

## Compromiso

- Todo código generado con IA fue **leído, comprendido y probado** antes de su ejecución.
- Todo lo que no se puede explicar en la defensa **cuenta como no hecho**.
- No se utilizaron datos personales reales en ninguna consulta a la IA.
- La bitácora de IA (`bitacora_ia.md`) documenta qué se aceptó, qué se descartó y por qué, para cada interacción relevante.

## Herramientas utilizadas

- **OpenCode** (agente de razonamiento) — generación de código, diseño de esquemas, code review, documentación.
- **Modelo:** Beam Free (opencode-go / beam-free) para consultas y razonamiento.

---

*Declaración firmada por los integrantes del equipo.*