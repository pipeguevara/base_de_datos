# Vipricon ltda — Base de datos (PostgreSQL)

Base de datos de la gestión de guardias de seguridad de **Vipricon ltda**: clientes, contratos, sedes, vigilantes,
asignaciones (turnos), novedades, asistencia, ausencias, usuarios y auditoría de contratos.
Proyecto de Bases de datos relacionales, UFPSO.

## Contenido

| Archivo | Qué hace |
|---|---|
| `01_vipricon_ddl_postgres.sql` | Esquema completo: 14 tablas, llaves, restricciones (`CHECK`, `EXCLUDE`), índices, 6 funciones y 8 triggers |
| `02_poblar_vipricon.sql` | Primer lote de datos sintéticos como sentencias `INSERT`, en una sola transacción |
| `03_cargar_csv_copy.sql` | Carga definitiva con `\copy` desde `data/` (14 CSV). Reemplaza a `02` + `04` |
| `04_correccion_datos.sql` | Correcciones de 5 filas halladas en la revisión crítica del primer lote (idempotente) |
| `data/01_…14_*.csv` | Una tabla por archivo, numerados en el orden de carga (padres antes que hijos) |
| `data/vipricon_datos.xlsx` | Las mismas 14 tablas en un libro de Excel, una hoja por tabla |

## Cómo montarla

Requiere PostgreSQL 14 o superior (probado en 18) y permiso para crear las extensiones `btree_gist` y `unaccent`.
Los comandos se ejecutan desde la carpeta raíz del repositorio.

**Opción A — carga con COPY desde los CSV (recomendada)**

```bash
createdb vipricon
psql -d vipricon -v ON_ERROR_STOP=1 -f 01_vipricon_ddl_postgres.sql
psql -d vipricon -v ON_ERROR_STOP=1 -f 03_cargar_csv_copy.sql
```

**Opción B — carga con INSERT**

```bash
createdb vipricon
psql -d vipricon -v ON_ERROR_STOP=1 -f 01_vipricon_ddl_postgres.sql
psql -d vipricon -v ON_ERROR_STOP=1 -f 02_poblar_vipricon.sql
psql -d vipricon -v ON_ERROR_STOP=1 -f 04_correccion_datos.sql
```

Ambas dejan la base idéntica. Cada script de carga va en una transacción: si algo falla, no queda ningún dato a medias.
También se puede cargar cada CSV con *Import/Export* de pgAdmin, en el orden de los números del nombre.

## Cantidades

| Tabla | Filas | Tabla | Filas |
|---|---|---|---|
| `customer` | 100 | `type_document` | 3 |
| `contract` | 50 | `nolvelty_type` | 6 |
| `employ` | 50 | `location` | 100 |
| `asig_service` | 1000 | `news_log` | 150 |
| `attendance` | 200 | `absence` | 25 |
| `app_user` | 100 | `refresh_token` | 150 |
| `contract_audit` | 60 (la llenan los triggers) | `admin_invite` | 8 |

## Notas

- **`contract_audit`:** el trigger la llena al insertar contratos (50 filas `I`) y al registrar la fecha de fin de 10
  contratos (10 filas `U`). Es de solo agregar: no admite `UPDATE`, `DELETE` ni `TRUNCATE`. Al cargar con `COPY` se apaga
  el trigger de `contract` mientras se carga, para no duplicar esas filas.
- **Datos coherentes con las reglas del negocio:**
  - ningún vigilante tiene dos turnos a la vez (R2);
  - los turnos vigentes son solo de vigilantes activos (R6);
  - no hay turnos en días con novedad vigente (R11);
  - cada turno cae dentro de la vigencia de su contrato.
- **Sin borrado físico:** `employ` y `asig_service` tienen un trigger que impide el `DELETE`; se desactivan con `status`.
- **Usuarios:** los 100 `app_user` tienen un hash BCrypt distinto. Las contraseñas en claro no están en este repositorio.
- **Datos ficticios:** nombres, documentos, correos y teléfonos son inventados.
- **Ids explícitos:** se cargan con valor fijo para que las llaves foráneas sean deterministas; al final se ajustan las
  secuencias, así que los `INSERT` nuevos siguen sin choques.

## Consultas de ejemplo

```sql
-- Turnos por vigilante activo
SELECT e.first_name, e.last_name, count(*) AS turnos
FROM asig_service a JOIN employ e ON e.employ_id = a.employ_employ_id
WHERE e.status = 1
GROUP BY e.employ_id ORDER BY turnos DESC LIMIT 10;

-- Marcaciones tardías por contrato
SELECT s.contract_contract_id, count(*) FILTER (WHERE a.punctuality = 'LATE') AS tardias, count(*) AS marcaciones
FROM attendance a JOIN asig_service s ON s.assignment_id = a.asig_service_assignment_id
GROUP BY s.contract_contract_id HAVING count(*) FILTER (WHERE a.punctuality = 'LATE') > 0
ORDER BY tardias DESC;

-- Historial de cambios de un contrato
SELECT audit_id, action, changed_fields, changed_at
FROM contract_audit WHERE contract_id = 1 ORDER BY changed_at, audit_id;
```
