# Ejecutar SOSNET en Supabase

Esta guía prepara el proyecto para un proyecto Supabase real. **No afirma que
Supabase ya esté configurado**: en este entorno no hay credenciales de un
proyecto remoto, por lo que las pruebas se hicieron en PostgreSQL 17 local con
el mismo modelo de roles y claims.

Para el despliegue completo del backend en Render y el frontend en Vercel,
seguir [`DEPLOY.md`](../../DEPLOY.md). Esta guía cubre solo la base Supabase.

## 1. Crear el proyecto

1. Crear un proyecto en <https://supabase.com>.
2. Guardar la contraseña del usuario administrador de la base.
3. Abrir **SQL Editor**.

## 2. Ejecutar los scripts en orden

Ejecutar, uno por uno, desde `database/`:

```text
00_schemas.sql
01_tables.sql
02_indexes.sql
03_functions.sql
04_procedures.sql
05_triggers.sql
06_views.sql
07_roles.sql
08_policies.sql
09_seed.sql
```

Notas:

- `07_roles.sql` crea `sosnet_api` y `sosnet_reporte` como roles `NOLOGIN` y
  reutiliza los roles `anon`, `authenticated` y `service_role` que ya existen
  en Supabase.
- No ejecutar `10_local_dev_roles.sh` en Supabase; es exclusivo de Docker local.
- No ejecutar `database/legacy/mysql/`; es la referencia histórica de MySQL.
- Los scripts usan `security_invoker` en las vistas, disponible en PostgreSQL
  15 o superior (Supabase usa 15/17).

## 3. Contraseña del rol de la API

En **SQL Editor**:

```sql
ALTER ROLE sosnet_api WITH LOGIN PASSWORD 'UNA_CLAVE_LARGA_Y_UNICA';
```

La aplicación no debe conectar como `postgres` ni usar la `service_role key`.
El rol `sosnet_api` no es superusuario, no tiene `BYPASSRLS` y no puede crear
tablas.

## 4. Cadena de conexión para Flask

En `backend/.env`:

```dotenv
DATABASE_URL=postgresql+psycopg://sosnet_api.[PROJECT-REF]:UNA_CLAVE_LARGA_Y_UNICA@[POOLER-HOST]:5432/postgres?sslmode=require
AUTO_CREATE_TABLES=false
```

- Copiar el host desde **Connect → Session pooler**; no componerlo a mano.
- En el shared pooler, un rol personalizado usa `sosnet_api.[PROJECT-REF]`.
- Usar **Session pooler** (puerto 5432) o conexión directa.
- No usar el puerto 6543 de transaction pooler para una app Flask persistente
  sin revisar el soporte de prepared statements.
- Percent-encode la contraseña si contiene `@`, `:`, `/`, `?`, `#` o espacios.
- `SECRET_KEY` y `JWT_SECRET_KEY` deben ser valores propios y distintos.

## 5. Verificación

Ejecutar `database/supabase/verify.sql` en **SQL Editor** o comprobar:

```sql
SELECT count(*) FROM pg_tables
WHERE schemaname IN ('public','auditoria'); -- 8

SELECT count(*) FROM pg_policies
WHERE schemaname IN ('public','auditoria'); -- 28

SELECT count(*) FROM public.usuarios;       -- 3 (seed)
SELECT count(*) FROM public.solicitudes_sos; -- 0 en una instalación nueva
```

Después, desde Flask:

```text
GET http://localhost:5000/api/health
```

Debe responder `{"database":"connected",...}`. Luego probar login y el flujo
público de SOS.

## 6. Supabase Auth (opcional)

La aplicación mantiene el JWT de Flask; no se activó Supabase Auth para no
duplicar identidades. Si el equipo decide usarlo:

1. Crear el usuario en **Authentication > Users**.
2. Asociarlo a `public.usuarios`:

   ```sql
   UPDATE public.usuarios
   SET supabase_uid = 'UID_DE_AUTH_USERS'
   WHERE correo = 'operador@sosnet.local';
   ```

3. Asignar el rol funcional en `app_metadata` (el usuario no puede editar este
   campo por sí mismo):

   ```sql
   UPDATE auth.users
   SET raw_app_meta_data =
       COALESCE(raw_app_meta_data, '{}'::jsonb) || '{"role":"operador"}'::jsonb
   WHERE id = 'UID_DE_AUTH_USERS';
   ```

4. Volver a iniciar sesión para que el JWT incluya `app_metadata.role`.

Las políticas RLS de `authenticated` leen `request.jwt.claims`. Sin el claim
`app_metadata.role`, el usuario puede leer su perfil pero no las emergencias;
esto es intencional (denegar por defecto).

## 7. Seguridad aplicada

- `anon` no lee tablas ni ejecuta procedimientos de escritura; el formulario
  público de SOS pasa por Flask, que aplica el límite de 30/minuto.
- `sosnet_api` no puede leer `usuarios.contrasena`; el login la obtiene con
  `fn_login_usuario`, `SECURITY DEFINER` y solo para ese rol.
- El logout incrementa `usuarios.token_version`; los JWT anteriores dejan de
  ser válidos.
- `sosnet_reporte` puede leer agregados e historial, pero no `usuarios` ni
  hashes.
- No se debe subir `.env` al repositorio ni exponer la `service_role key`.
