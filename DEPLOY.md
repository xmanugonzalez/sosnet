# Despliegue de SOSNET en Vercel + Render + Supabase

Guía para publicar el proyecto usando GitHub como repositorio, Vercel para el
frontend, Render para la API Flask y Supabase como PostgreSQL gestionado.

```text
GitHub
 ├── Render  → Flask + gunicorn  ──► Supabase PostgreSQL
 └── Vercel  → React + Vite
```

> GitHub Pages no puede ejecutar Flask. El backend necesita Render, Railway,
> Fly.io o un servidor equivalente. Esta guía usa Render porque tiene plan
> gratuito y se conecta directamente al repositorio.

## 1. Supabase

1. Crear un proyecto en <https://supabase.com>.
2. Guardar el `project-ref` y la contraseña de la base.
3. Abrir **SQL Editor** y ejecutar, en orden, desde `database/`:

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

   - En una instalación nueva **no** hace falta ejecutar
     `migrations/002_seguridad_reportes.sql`; los scripts ya incluyen las
     correcciones.
   - No ejecutar `database/legacy/mysql/`.
   - No ejecutar `10_local_dev_roles.sh`; es solo para Docker local.

4. Definir la contraseña del rol de la API:

   ```sql
   ALTER ROLE sosnet_api WITH LOGIN PASSWORD 'UNA_CLAVE_LARGA_Y_UNICA';
   ```

   Si el SQL Editor no permite crear roles, crear `sosnet_api` desde
   **Database → Roles** y volver a ejecutar los grants de `07_roles.sql`.

5. Ejecutar `database/supabase/verify.sql` en SQL Editor. Debe mostrar 8 tablas,
   RLS activo, 28 rutinas, 28 políticas y `api_puede_leer_hash = false`.

6. Cambiar las contraseñas demo desde la aplicación después del primer acceso.

### Cadena de conexión

Usar **Connect → Session pooler** (IPv4, puerto 5432). El host se copia del
dashboard; no se compone a mano.

```dotenv
DATABASE_URL=postgresql+psycopg://sosnet_api.[PROJECT-REF]:CLAVE_URL_ENCODED@[POOLER-HOST]:5432/postgres?sslmode=require
```

- En el shared pooler, un rol personalizado usa `sosnet_api.[PROJECT-REF]`.
- No usar el puerto `6543` (transaction pooler): la app usa `SET LOCAL` y
  prepared statements. El session pooler `5432` es el adecuado.
- La conexión directa (`db.[PROJECT-REF].supabase.co:5432`) requiere IPv6 o el
  add-on IPv4; si el host no tiene IPv6, usar el session pooler.
- Percent-encode la contraseña si contiene `@`, `:`, `/`, `?`, `#` o espacios.
- `SECRET_KEY` y `JWT_SECRET_KEY` deben ser valores propios y distintos.

## 2. Backend en Render

El repositorio incluye `render.yaml` en la raíz. La opción más simple es crear
un **Blueprint** desde Render:

1. Render Dashboard → **New → Blueprint**.
2. Conectar el repositorio de GitHub y la rama `main`.
3. Render leerá `render.yaml` y creará el servicio `sosnet-api`.
4. Completar las variables que piden valor:
   - `DATABASE_URL`: cadena de Supabase del paso anterior.
   - `CORS_ORIGINS`: se puede dejar para después y actualizar cuando Vercel
     entregue la URL. Si Render exige un valor, usar `http://localhost:1010`
     temporalmente y cambiarlo luego.
5. `SECRET_KEY` y `JWT_SECRET_KEY` se generan automáticamente y son distintas.
6. Esperar el deploy y abrir:

   ```text
   https://TU-BACKEND.onrender.com/api/health
   ```

   Debe responder `{"database":"connected","status":"ok",...}`.

### Opción manual (sin Blueprint)

Si no se usa `render.yaml`, crear **New → Web Service** con:

- Repositorio: el de SOSNET.
- Branch: `main`.
- Root Directory: `backend`.
- Runtime: Python 3.12.
- Build Command: `pip install --upgrade pip && pip install -r requirements.txt`.
- Start Command:
  `gunicorn --bind 0.0.0.0:$PORT --workers 2 --threads 4 run:app`.
- Health Check Path: `/api/health`.
- Plan: Free.

Variables de entorno del backend:

| Variable | Valor |
|---|---|
| `DATABASE_URL` | cadena de Supabase con `sslmode=require` |
| `SECRET_KEY` | secreto aleatorio largo |
| `JWT_SECRET_KEY` | secreto aleatorio distinto |
| `FLASK_DEBUG` | `false` |
| `AUTO_CREATE_TABLES` | `false` |
| `CORS_ORIGINS` | `https://TU-FRONTEND.vercel.app` |
| `RATELIMIT_ENABLED` | `true` |
| `SOS_RETENTION_DAYS` | `90` |
| `SERIAL_ENABLED` | `false` |
| `PYTHON_VERSION` | `3.12.7` (si se usa runtime Python) |

El backend usa `gunicorn`; no se debe desplegar con el servidor de desarrollo de
Flask. El `Dockerfile` también arranca con gunicorn si se elige la opción Docker.

## 3. Frontend en Vercel

1. Vercel → **New Project** → importar el repositorio.
2. Configurar:
   - Root Directory: `frontend`.
   - Framework Preset: Vite.
   - Build Command: `npm run build`.
   - Output Directory: `dist`.
3. Agregar la variable de entorno:

   ```dotenv
   VITE_API_URL=https://TU-BACKEND.onrender.com/api
   ```

   Debe incluir `/api` y no terminar en `/`. Vercel la aplica en tiempo de
   build; si cambia la URL del backend, hay que redeployar el frontend.

4. `frontend/vercel.json` ya incluye el rewrite de SPA para que `/admin` y
   `/sos` funcionen al recargar.
5. Desplegar y abrir la URL de Vercel.
6. Volver a Render, actualizar `CORS_ORIGINS` con la URL exacta de Vercel y
   redeployar el backend.

### Netlify (alternativa)

- Base directory: `frontend`.
- Build: `npm run build`.
- Publish: `dist`.
- Variable `VITE_API_URL` igual que en Vercel.
- Agregar `frontend/public/_redirects` con:

  ```text
  /* /index.html 200
  ```

## 4. Orden recomendado

1. Supabase: scripts y verificación.
2. Render: backend y `/api/health`.
3. Vercel: frontend y `VITE_API_URL`.
4. Render: `CORS_ORIGINS` con el dominio de Vercel y redeploy.
5. Pruebas de aceptación.

## 5. Pruebas de aceptación

1. `GET /api/health` → `200`, `database: connected`.
2. Abrir la URL de Vercel y entrar a `/admin`.
3. Login con `admin@sosnet.local` / `AdminDemo123` y cambiar la contraseña.
4. Crear una solicitud desde `/sos`.
5. Verla en el panel, cambiar estado y consultar el historial.
6. Cerrar sesión: el token anterior debe devolver `401` en `/api/auth/me`.
7. Abrir `/admin` directamente y recargar: debe cargar la SPA.
8. Ejecutar `database/supabase/verify.sql` en Supabase.

## 6. Migrar los datos locales a Supabase (opcional)

Si se quieren conservar las solicitudes que ya están en MySQL local, ejecutar el
migrador antes de usar la app en producción. Usar un rol administrador de
Supabase, no `sosnet_api`:

```powershell
backend\.venv\Scripts\python.exe database\migrations\migrate_mysql_to_postgres.py `
  --mysql-url "mysql+pymysql://sosnet:sosnet_dev@127.0.0.1:3306/sosnet?charset=utf8mb4" `
  --target-url "postgresql+psycopg://postgres.[PROJECT-REF]:CLAVE@[POOLER-HOST]:5432/postgres?sslmode=require"
```

El migrador es idempotente. Después de migrar, la app sigue conectando con
`sosnet_api`. Si es una instalación nueva, no hace falta.

## 7. Limitaciones del plan gratuito

- Render Free puede dormir el servicio; la primera petición tarda en despertar.
- Supabase Free puede pausar el proyecto por inactividad.
- El backend en la nube **no puede leer el puerto USB del ESP32**. Para el
  hardware real hace falta un gateway local que reenvíe el serial a la API o
  ejecutar Flask en la computadora conectada al receptor. La web funciona con
  `/sos`.
- El rate limit de Flask está en memoria y es por worker. Para el alcance
  académico es suficiente; para producción estricta se puede usar Redis.
- No subir `.env` al repositorio. Configurar los secretos en Render y Vercel.
- No usar la `service_role key` de Supabase en el backend ni en React. La app
  usa `sosnet_api`, que respeta RLS.

## 8. Problemas comunes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `503 insecure_config` | `SECRET_KEY`/`JWT_SECRET_KEY` de ejemplo o iguales | Definir secretos distintos en Render y redeploy. |
| `tenant/user not found` en Supabase | Usuario del pooler sin `.[PROJECT-REF]` o host inventado | Copiar el host de Connect y usar `sosnet_api.[PROJECT-REF]`. |
| CORS bloqueado | `CORS_ORIGINS` no coincide con Vercel | Poner el origen exacto, sin `/` final, y redeployar Render. |
| `/admin` da 404 en Vercel | Falta el rewrite de SPA | Usar `frontend/vercel.json` y redeployar. |
| La app no conecta a Supabase | Contraseña con caracteres especiales sin encodear | Percent-encode la contraseña o usar una contraseña alfanumérica larga. |
| `too many connections` | Demasiados workers/conexiones | Usar 2 workers y el pool por defecto; revisar el límite del proyecto. |
| La API no ve datos | Contexto RLS ausente | La app fija `app.current_user_id`/`app.current_role`; no conectar con `postgres` desde la app. |
