# Requisitos — Food Store Tablet (Kiro Spec)

> **Proyecto:** Food Store — cierre de la capa de datos
> **Formato:** Notación EARS (Easy Approach to Requirements Syntax)
> **Materia:** Base de Datos II — Tecnicatura Universitaria en Programación

---

## REQ-01 — Detección de cambio de precio

**WHEN** el precio actual del servidor es distinto del precio visto por la tablet
**THE SYSTEM SHALL** marcar la solicitud como CONFLICTO.

**Se prueba con:** C2 (cambio de precio en el servidor → CONFLICTO; al aceptar el nuevo precio → SIMULADO_APROBADO)

---

## REQ-02 — Stock insuficiente

**WHEN** la cantidad solicitada en un borrador supera el stock visto en el servidor
**THE SYSTEM SHALL** marcar la solicitud como RECHAZADO.

**Se prueba con:** C3 (solicitar 200 unidades cuando solo hay 137 en stock → RECHAZADO)

---

## REQ-03 — Producto dado de baja

**WHEN** un producto del borrador fue dado de baja (baja lógica) en el servidor
**THE SYSTEM SHALL** marcar la solicitud como RECHAZADO y conservar la fila en el catálogo local.

**Se prueba con:** C4 (marcar producto como eliminado → RECHAZADO; la fila permanece en producto_cache)

---

## REQ-04 — Idempotencia de solicitudes

**WHEN** se reenvía una solicitud con el mismo `solicitud_uuid`
**THE SYSTEM SHALL** rechazar el duplicado (error de clave primaria) y no reevaluar solicitudes ya procesadas.

**Se prueba con:** C6 (reenviar el mismo UUID → error de PK; repetir la simulación no cambia el estado)

---