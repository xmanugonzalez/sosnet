# Migración MySQL → PostgreSQL local

`migrate_mysql_to_postgres.py` copia los datos de SOSNET desde MySQL 8 al
esquema PostgreSQL implementado en `database/`.

## Requisitos

- Python 3.11+ con `SQLAlchemy`, `PyMySQL` y `psycopg[binary]`.
  El entorno de desarrollo (`backend/.venv`) ya los instala con
  `backend/requirements-dev.txt`.
- Esquema PostgreSQL creado con `00_schemas.sql` a `08_policies.sql`.
- La base destino puede tener ya el seed (`09_seed.sql`); el migrador remapea
  IDs por claves naturales y no duplica.

## Modo seguro (sin escribir)

```powershell
backend\.venv\Scripts\python.exe database\migrations\migrate_mysql_to_postgres.py `
  --dry-run `
  --mysql-url "mysql+pymysql://sosnet:sosnet_dev@127.0.0.1:3306/sosnet?charset=utf8mb4" `
  --target-url "postgresql+psycopg://sosnet_admin:CLAVE@127.0.0.1:5432/sosnet"
```

## Migración real

```powershell
backend\.venv\Scripts\python.exe database\migrations\migrate_mysql_to_postgres.py `
  --mysql-url "mysql+pymysql://sosnet:sosnet_dev@127.0.0.1:3306/sosnet?charset=utf8mb4" `
  --target-url "postgresql+psycopg://sosnet_admin:CLAVE@127.0.0.1:5432/sosnet"
```

En PostgreSQL local usa el usuario administrador del proyecto solo para esta
operación (`sosnet_admin` o un rol con permisos de escritura). Después, la
aplicación debe conectar con `sosnet_api`.

## Qué copia

- `Usuarios` → `public.usuarios` (incluye correo/activo/último acceso si existen).
- `TiposEmergencia` → `public.tipos_emergencia`.
- `Dispositivos` → `public.dispositivos` (se omiten los nodos de hardware de la
  versión anterior).
- `ConfiguracionCentral` → `public.configuracion_central`.
- `SolicitudesSOS` → `public.solicitudes_sos`.
- `RegistrosComunicacion` → `public.registros_comunicacion`.
- `HistorialEstados` → `auditoria.historial_estados`.
- `Actividad` → `auditoria.actividad`.

El modo `app.migration_mode` evita que el trigger de historial duplique filas.
Al final se ajustan las secuencias `IDENTITY` y se comprueba que no haya
referencias huérfanas.

## Limitaciones

- Las columnas de latitud/longitud nunca existieron en el esquema MySQL: el
  sistema las guarda como texto dentro de `ubicacion`, igual que antes.
- Si una solicitud antigua apunta a un tipo/dispositivo inexistente, se usa
  `Otra` / `FORMULARIO-SOS` como respaldo y se informa en la validación final.
- No se migran hashes desde otro algoritmo: se copian tal cual y werkzeug sigue
  validándolos.

## Migración 002 · seguridad de sesiones y reportes

Si la base ya existía antes de las correcciones de auditoría, aplicar una vez:

```powershell
docker exec -i sosnet-postgres psql -U sosnet_admin -d sosnet `
  -v ON_ERROR_STOP=1 `
  -f /docker-entrypoint-initdb.d/migrations/002_seguridad_reportes.sql
```

La migración:

- Agrega `usuarios.token_version` para invalidar JWT en logout.
- Crea `fn_usuario_directorio` y corrige `fn_historial_solicitud` para que RLS
  no oculte cambios de otros usuarios.
- Crea `sp_logout_usuario`.
- Revoca el `EXECUTE` público de `sp_registrar_solicitud`; solo queda para
  `sosnet_api`.
- Aplica grants por columna para impedir la lectura de `usuarios.contrasena`.
- Habilita el historial para `sosnet_reporte`.

En una instalación nueva, los scripts `00`–`09` ya incluyen estos cambios y este
archivo no es necesario.

## Migración 003 · quitar dispositivos de hardware

Si la base ya existía con los dispositivos de hardware anteriores, aplicar una
vez:

```powershell
docker exec -i sosnet-postgres psql -U sosnet_admin -d sosnet `
  -v ON_ERROR_STOP=1 `
  -f /docker-entrypoint-initdb.d/migrations/003_quitar_hardware.sql
```

La migración elimina los dispositivos no referenciados con tipos anteriores,
deja la restricción en `web`/`desconocido` y actualiza
`sp_registrar_dispositivo`. Si un dispositivo de hardware está referenciado por
una solicitud, la migración se detiene para no perder trazabilidad.

En una instalación nueva, el seed `09_seed.sql` solo crea `FORMULARIO-SOS` y no
es necesario aplicar esta migración.

## Migración 004 · renombrar identidad externa

Para bases creadas antes de la limpieza, renombra la columna y la función de
identidad externa:

```powershell
docker exec -i sosnet-postgres psql -U sosnet_admin -d sosnet `
  -v ON_ERROR_STOP=1 `
  -f /docker-entrypoint-initdb.d/migrations/004_renombrar_uid_externo.sql
```

La migración es idempotente: renombra `supabase_uid` a `external_uid` y
`fn_usuario_supabase_actual` a `fn_usuario_externo_actual` si todavía existen.
En una instalación nueva no es necesario aplicarla.
