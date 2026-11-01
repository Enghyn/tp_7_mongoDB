# Evidencias — Consigna 1 (base de la tablet)

> **Fecha de ejecución:** 2026-11-01
> **Base generada:** `movil/foodstore_movil.db` (49.152 bytes)
> **Salida completa:** `movil/salida_pruebas.txt`

## Comando ejecutado

```powershell
cd TP8/food-store/movil
$env:PYTHONIOENCODING='utf-8'
python run_pruebas.py --db foodstore_movil.db --fresh
```

> En este entorno no está instalado el CLI de `sqlite3`; el arnés `run_pruebas.py` usa Python 3.14 + SQLite 3.50.4 (soporta `STRICT`). El TP8 permite Python para la simulación. Los entregables siguen siendo SQL puro.

## Resultado

```text
RESUMEN: 55 PASS, 0 FAIL, 55 pruebas
Base resultante: foodstore_movil.db
```

## Extractos relevantes

### Esquema y reglas activas

```text
[PASS] 00 PRAGMA foreign_keys activo — esperado='1' actual=1
[PASS] 01 Existen las cuatro tablas — esperado='4' actual=4
[PASS] 02 producto_cache tiene las siete columnas mínimas — esperado='7' actual=7
[PASS] 03 Las cuatro tablas son STRICT — esperado='4' actual=4
[PASS] 04 item_borrador tiene dos claves foráneas — esperado='2' actual=2
[PASS] 05 cola_sync tiene una clave foránea — esperado='1' actual=1
```

### Caso C1 — catálogo disponible sin servidor

```text
[PASS] 08 C1 devuelve solo productos disponibles y no eliminados — esperado='5' actual=5
[PASS] 09 C1 devuelve los nombres esperados en orden — esperado='Agua 500ml,Alfajor,Gaseosa 1.5L,Pan artesanal,Queso 500g' actual='Agua 500ml,Alfajor,Gaseosa 1.5L,Pan artesanal,Queso 500g'
[PASS] 10 C1 excluye el producto sin stock y el dado de baja — esperado='0' actual=0
```

### Borrador completo con BEGIN … COMMIT

```text
[PASS] 12 Insertar pedido_borrador — OK
[PASS] 13 Insertar primer ítem del borrador — OK
[PASS] 14 Insertar segundo ítem del borrador — OK
[PASS] 15 Insertar la solicitud en la cola (PENDIENTE, sin motivo) — OK
[PASS] 16 Confirmar la transacción — OK
[PASS] 17 Quedó un borrador — esperado='1' actual=1
[PASS] 18 Quedaron dos ítems — esperado='2' actual=2
[PASS] 19 Quedó una solicitud en la cola — esperado='1' actual=1
[PASS] 20 Total del borrador en centavos = 2.200,50 — esperado='220050' actual=220050
```

### Operación deshecha con ROLLBACK

```text
[PASS] 22 Insertar un segundo borrador (se deshace) — OK
[PASS] 23 Insertar un ítem del segundo borrador (se deshace) — OK
[PASS] 24 Insertar la solicitud del segundo borrador (se deshace) — OK
[PASS] 25 Deshacer la transacción — OK
[PASS] 26 Sigue habiendo un solo borrador — esperado='1' actual=1
[PASS] 27 Siguen habiendo dos ítems — esperado='2' actual=2
[PASS] 28 Sigue habiendo una sola solicitud — esperado='1' actual=1
```

### Caso C7 — cantidad 0 y producto inexistente

```text
[PASS] 30 C7 cantidad 0 debe fallar por CHECK — error esperado: IntegrityError: CHECK constraint failed: cantidad > 0
[PASS] 31 C7 producto inexistente debe fallar por FK — error esperado: IntegrityError: FOREIGN KEY constraint failed
[PASS] 32 C7 cerrar transacción de prueba — OK
[PASS] 33 C7 no dejó filas nuevas: siguen dos ítems — esperado='2' actual=2
[PASS] 34 C7 no dejó filas nuevas en el borrador 1 — esperado='2' actual=2
```

### Triangulación adicional (reglas del esquema)

```text
[PASS] 35 Precio negativo debe fallar — error esperado: CHECK constraint failed: precio_centavos >= 0
[PASS] 36 Precio con texto debe fallar por STRICT — error esperado: cannot store TEXT value in INTEGER column producto_cache.precio_centavos
[PASS] 37 disponible y eliminado no pueden ser 1 a la vez — error esperado: CHECK constraint failed: NOT (disponible = 1 AND eliminado = 1)
[PASS] 38 disponible fuera de 0/1 debe fallar — error esperado: CHECK constraint failed: disponible IN (0, 1)
[PASS] 40 Forma de pago inválida debe fallar — error esperado: CHECK constraint failed: forma_pago IN (...)
[PASS] 41 Usuario con email debe fallar — error esperado: CHECK constraint failed: ... usuario NOT LIKE '%@%'
[PASS] 42 id_local que no es UUID debe fallar — error esperado: CHECK constraint failed: id_local GLOB ...
[PASS] 44 Ítem duplicado debe fallar por PK — error esperado: UNIQUE constraint failed: item_borrador.id_local, item_borrador.producto_id
[PASS] 45 Ítem de un borrador inexistente debe fallar por FK — error esperado: FOREIGN KEY constraint failed
[PASS] 49 Estado inválido en cola_sync debe fallar — error esperado: CHECK constraint failed: estado IN (...)
[PASS] 50 Estado final sin motivo debe fallar — error esperado: CHECK constraint failed: estado = 'PENDIENTE' OR (...)
[PASS] 51 Reenviar el mismo solicitud_uuid debe fallar por PK (C6) — error esperado: UNIQUE constraint failed: cola_sync.solicitud_uuid
```

## Estado final de la base

```text
producto_cache     : 7 filas
pedido_borrador    : 1 fila
item_borrador      : 2 filas
cola_sync          : 1 fila
```

Borrador de ejemplo (continuidad con el pedido 1 del TP7):

```text
id_local   = 11111111-1111-4111-8111-111111111111
usuario    = vendedor1
forma_pago = EFECTIVO
items      = 2 x Agua 500ml ($500,00) + 1 x Pan artesanal ($1.200,50)
total      = 220050 centavos = $2.200,50
cola_sync  = PENDIENTE (sin motivo todavía)
```

## Nota importante: `PRAGMA foreign_keys` es por conexión

`PRAGMA foreign_keys = ON;` **no queda guardado en el archivo**. Cada conexión nueva debe ejecutarlo antes de escribir. El arnés lo hace al ejecutar `schema_sqlite.sql` en la misma conexión (por eso la prueba 00 da `1`). Si se abre la base con otro cliente, hay que ejecutar el PRAGMA primero:

```sql
PRAGMA foreign_keys = ON;
```

Esta decisión está documentada en `docs/plan_diseno.md` (§3.5) y se repetirá en el README de la entrega.
