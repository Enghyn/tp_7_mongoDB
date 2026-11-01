# Tareas — Food Store Tablet (Kiro Spec)

> **Proyecto:** Food Store — cierre de la capa de datos
> **Formato:** Lista de tareas breve (Kiro)

---

## Fase 1 — Base de la tablet (Consigna 1)

- [x] T1.1: Definir qué datos viajan a la tablet (tabla de decisión + justificación)
- [x] T1.2: Crear `schema_sqlite.sql` con 4 tablas STRICT + CHECK + FK
- [x] T1.3: Escribir `pruebas_sqlite.sql` (C1, C7, BEGIN/COMMIT, ROLLBACK)
- [x] T1.4: Ejecutar pruebas con `run_pruebas.py` → 55 PASS, 0 FAIL

## Fase 2 — Sincronización (Consigna 2)

- [x] T2.1: Crear vista `v_snapshot_movil` en PostgreSQL
- [x] T2.2: Exportar vista a CSV (`servidor_snapshot.csv`, 50.000 filas)
- [x] T2.3: Crear tabla staging `snapshot_servidor` + cargar `producto_cache`
- [x] T2.4: Escribir `semaforo.sql` (RECHAZADO / CONFLICTO / SIMULADO_APROBADO)
- [x] T2.5: Preparar casos C2–C6 y documentar resultados
- [x] T2.6: Ejecutar consulta final de no modificación en PostgreSQL

## Fase 3 — Integración y revisión (Consigna 3)

- [x] T3.1: Crear mapa de la capa de datos (3 motores, quién manda)
- [x] T3.2: Redactar plan de mantenimiento (backup, restauración, revisión)
- [x] T3.3: Realizar code review con IA (4 hallazgos, ≥1 descartado)

## Fase 4 — Kiro, bitácora y defensa (Consigna 4)

- [x] T4.1: Escribir `requirements.md` con 4 requisitos EARS + casos de prueba
- [x] T4.2: Escribir `design.md` (arquitectura, componentes, flujo)
- [x] T4.3: Escribir `tasks.md` (lista de tareas por fase)
- [x] T4.4: Escribir `bitacora_ia.md` (≥3 entradas, ≥1 descartado)
- [x] T4.5: Crear `DUIA.md` (declaración de uso de IA)
- [x] T4.6: Escribir `README.md` (orden para crear todo desde cero)
- [x] T4.7: Preparar ensayo de defensa (mapa, caso en vivo, hallazgo IA)

---

## Generación de código

El esquema SQLite (`schema_sqlite.sql`) y la simulación (`semaforo.sql`, `simular_casos.py`) se generaron con OpenCode a partir de estas tareas y los requisitos EARS definidos en `requirements.md`.