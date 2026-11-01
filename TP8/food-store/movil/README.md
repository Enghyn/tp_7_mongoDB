# Móvil — base de la tablet (SQLite)

## Archivos

| Archivo | Qué es |
|---|---|
| `schema_sqlite.sql` | DDL de las 4 tablas `STRICT` + `PRAGMA foreign_keys = ON;` (Consigna 1.b). |
| `pruebas_sqlite.sql` | Pruebas de la Consigna 1.c: C1, C7, `BEGIN`/`COMMIT`, `ROLLBACK` y triangulación. |
| `run_pruebas.py` | Arnés de ejecución (Python + SQLite). No reemplaza los `.sql`: los ejecuta. |
| `foodstore_movil.db` | Base generada por el arnés. Se puede regenerar con `--fresh`. |
| `salida_pruebas.txt` | Salida completa de la última ejecución (evidencia). |

## Cómo ejecutar

Desde esta carpeta:

```powershell
$env:PYTHONIOENCODING='utf-8'
python run_pruebas.py --db foodstore_movil.db --fresh
```

Resultado esperado:

```text
RESUMEN: 55 PASS, 0 FAIL, 55 pruebas
```

Si tenés el CLI de SQLite instalado, también podés ejecutar los `.sql` directamente:

```bash
sqlite3 foodstore_movil.db < schema_sqlite.sql
sqlite3 foodstore_movil.db < pruebas_sqlite.sql
```

> `schema_sqlite.sql` está pensado para una base **nueva**. Si la base ya existe, borrala o usá `--fresh`.

## Regla de conexión

`PRAGMA foreign_keys = ON;` **no se guarda en el archivo**: se aplica por conexión. Cualquier cliente que abra `foodstore_movil.db` debe ejecutarlo antes de escribir. El arnés lo hace por vos.

## Qué cubren las pruebas

- **C1:** consulta del catálogo disponible (`disponible = 1 AND eliminado = 0`) sin conectarse al servidor.
- **C7:** cantidad `0` y producto inexistente fallan por `CHECK` y `FOREIGN KEY`, sin dejar filas nuevas.
- **Transacciones:** un borrador completo con `BEGIN … COMMIT` y otro deshecho con `ROLLBACK`.
- **Triangulación:** precio negativo, texto en columna `INTEGER` (STRICT), `disponible`/`eliminado` inválidos, forma de pago inválida, usuario con email, UUID inválido, ítem duplicado, FK inexistente, estado de cola inválido, estado final sin motivo y UUID de solicitud repetido (avance de C6).
