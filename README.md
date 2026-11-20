# SOSNET

SOSNET es una plataforma web para registrar y gestionar solicitudes de
emergencia. El formulario público está hecho en React y envía las solicitudes a
una API Flask, que las guarda en PostgreSQL local y las muestra en el panel de
la central.

## Arquitectura

```text
React + Vite  ◀── HTTP/JSON ──  Flask + JWT  ──  PostgreSQL local
   /sos                            /api                Docker
   /admin
```

- `public`: tablas y objetos de aplicación.
- `auditoria`: historial de estados y actividad.
- `reportes`: vistas y funciones administrativas.
- La API usa JWT propio de Flask y RLS de PostgreSQL.
- Todo el sistema funciona en la computadora local; no requiere servicios en la
  nube ni hardware externo.

La documentación de la base, con el detalle de los ocho requisitos académicos,
está en [`database/README.md`](database/README.md). Los ejemplos SQL están en
[`database/examples/ejemplos_requisitos.sql`](database/examples/ejemplos_requisitos.sql).

## Requisitos

- Node.js 20 o superior y npm.
- Docker Desktop iniciado con contenedores Linux, o Docker Engine con Docker
  Compose v2 en Linux.
- Python 3.11 o superior. El arranque automático lo usa cuando el backend no está
  en Docker.
- Internet para descargar dependencias e imágenes la primera vez.

No se necesita hardware externo.

## Inicio local con un solo comando

```powershell
git clone https://github.com/xmanugonzalez/sosnet.git
cd sosnet
npm run dev
```

El comando:

1. Crea los `.env` que falten desde sus ejemplos.
2. Genera `SECRET_KEY` y `JWT_SECRET_KEY` aleatorias y distintas si faltan o son
   valores de ejemplo.
3. Instala las dependencias del frontend y del backend.
4. Inicia PostgreSQL 17 con Docker y aplica `database/00_schemas.sql` …
   `database/09_seed.sql` en un volumen nuevo.
5. Inicia Flask en `http://127.0.0.1:5000`.
6. Inicia Vite en `http://localhost:1010`.

- Frontend: `http://localhost:1010`.
- API: `http://localhost:5000/api/health`.
- `Ctrl+C` detiene Flask y Vite. PostgreSQL sigue activo; para detenerlo:
  `npm run db:stop` (los datos se conservan).

Si el backend Docker `sosnet-backend` ya está en ejecución, el script lo reutiliza
y no necesita Python. Para construirlo:

```powershell
docker compose up -d --build backend
npm run dev
```

Los puertos 5432 y 1010 deben estar libres. El puerto 5000 puede estar ocupado
por el backend Docker reutilizado; si no hay backend, se usa para Flask local.

## Base de datos local

- Motor: PostgreSQL 17 en Docker.
- Esquema: `database/00_schemas.sql` a `database/09_seed.sql`.
- Datos iniciales:
  - 5 tipos de emergencia.
  - Dispositivo `FORMULARIO-SOS`.
  - `operador@sosnet.local` / `OperadorDemo123` — operador.
  - `admin@sosnet.local` / `AdminDemo123` — administrador.
  - Usuario interno `sistema`, inactivo y sin acceso.
- Tablas: `usuarios`, `tipos_emergencia`, `dispositivos`,
  `solicitudes_sos`, `registros_comunicacion`, `configuracion_central`,
  `auditoria.historial_estados` y `auditoria.actividad`.
- Vistas: `reportes.vw_solicitudes_detalladas`,
  `reportes.vw_solicitudes_por_tipo`, `reportes.vw_historial_solicitudes`,
  `reportes.vw_actividad_usuarios`, `reportes.vw_estadisticas_emergencias` y
  `reportes.vw_resumen_dispositivos`.

> Cambia las contraseñas demo antes de una presentación real. Para cambios de
> esquema usa un archivo nuevo en `database/migrations/` o recrea el volumen
> `postgres_data`; no edites una base con datos sin respaldo.

## Backend

Con Docker:

```powershell
docker compose up -d --build backend
docker compose logs -f backend
```

Sin Docker:

```powershell
Set-Location backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
Copy-Item .env.example .env
flask --app run.py run --debug
```

Comprobar la API en `http://localhost:5000/api/health`.

Variables relevantes de `backend/.env`:

- `DATABASE_URL`: PostgreSQL local.
- `AUTO_CREATE_TABLES=false`: el esquema se crea con los scripts SQL.
- `SECRET_KEY` y `JWT_SECRET_KEY`: obligatorias y distintas en producción.
- `JWT_ACCESS_TOKEN_HOURS`: duración del token, por defecto 8.
- `CORS_ORIGINS`: por defecto `http://localhost:1010,http://localhost:5173`.
- `SOS_RETENTION_DAYS`: retención de solicitudes, por defecto 90.
- `RATELIMIT_ENABLED`: límites de login y envío público de SOS.

La autenticación usa JWT con tokens de 8 horas. El frontend los guarda en
`sessionStorage` y los envía como `Authorization: Bearer <token>`. Los permisos
se validan en el backend en cada solicitud y RLS actúa como segunda capa. El
logout incrementa `usuarios.token_version`, por lo que los tokens anteriores
dejan de ser válidos.

Para eliminar solicitudes antiguas y sus registros asociados:

```powershell
docker compose exec backend flask --app run.py purge-old-sos --days 90 --dry-run
docker compose exec backend flask --app run.py purge-old-sos --days 90
```

## Frontend

```powershell
Set-Location frontend
npm install
Copy-Item .env.example .env
npm run dev
```

Abrir `http://localhost:1010`. Vite redirige `/api` al backend durante el
desarrollo local.

- `http://localhost:1010/` y `/sos` — formulario SOS público.
- `http://localhost:1010/admin` y `/admin/*` — acceso del equipo y dashboard.
- Ruta desconocida — “Página no encontrada” con enlace al formulario.

La pantalla de acceso solicita correo y contraseña. El servidor valida la cuenta
y determina su rol desde `public.usuarios`. El panel de administración permite
crear cuentas, activarlas o desactivarlas, guardar la configuración de la central
y consultar la auditoría.

### API

- `POST /api/auth/login` — inicia sesión. Campos: `identifier` (correo o
  usuario), `password`, `role` opcional (`operador` o `admin`).
- `GET /api/auth/me` — devuelve la cuenta autenticada.
- `POST /api/auth/logout` — registra el cierre e invalida el token anterior.
- `GET /api/emergencies` — últimas 100 solicitudes; requiere JWT.
- `POST /api/emergencies` — público, limitado a 30/minuto.
- `PATCH /api/emergencies/<id>` — actualiza `status` o `priority`; requiere JWT.
- `GET /api/emergencies/<id>/history` — historial con operador y observación;
  requiere JWT.
- `GET /api/reports/summary` — resumen desde vistas y funciones de reporte;
  requiere JWT.
- `GET/POST/PATCH /api/users` — administración de cuentas; solo administradores.
- `GET /api/settings` — configuración; requiere JWT.
- `PUT /api/settings` — actualiza nombre y ubicación; solo administradores.
- `GET /api/activity` — últimas 100 entradas de auditoría; solo administradores.

Cada solicitud crea una fila en `solicitudes_sos` y su comunicación. Cada cambio
de estado genera historial y actividad mediante triggers. El formulario envía
la ubicación escrita; si el navegador agrega coordenadas GPS, se guardan como
texto dentro de `ubicacion`.

Ejemplo de envío público:

```http
POST /api/emergencies
Content-Type: application/json

{
  "emergency_type": "Inundación",
  "device_id": "FORMULARIO-SOS",
  "reporter_name": "María González",
  "location": "Barrio San Francisco",
  "people": 3,
  "priority": "alta",
  "message": "El agua sube rápido"
}
```

## Estructura

```text
sosnet/
├── backend/             API Flask, JWT, modelos y pruebas
├── database/            Esquema PostgreSQL local, pruebas y migraciones
│   ├── examples/        Ejemplos SQL de los ocho requisitos
│   ├── legacy/mysql/    Esquema MySQL histórico conservado
│   ├── migrations/      Migrador MySQL → PostgreSQL y migración 003
│   └── tests/           Pruebas SQL y runner de integración
├── frontend/            React, Vite y Tailwind CSS
├── scripts/             Arranque automático del entorno local
├── docker-compose.yml   PostgreSQL y backend de desarrollo
└── .env.example         Configuración de los contenedores
```

## Pruebas

```powershell
npm run db:test
```

Crea un PostgreSQL aislado en el puerto 55432, ejecuta las pruebas SQL y luego
`pytest` contra Flask + RLS. Resultado esperado: todas las pruebas SQL en verde y
38 pruebas de backend aprobadas.

También se puede ejecutar por partes:

```powershell
Set-Location backend
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\python.exe -m ruff check app tests
```

```powershell
npm --prefix frontend run lint
```

## Migración desde MySQL

El sistema anterior está en `database/legacy/mysql/`. El migrador
`database/migrations/migrate_mysql_to_postgres.py` copia los datos de forma
idempotente, remapea IDs y omite los nodos de hardware de la versión anterior.
Instrucciones completas en
[`database/migrations/README.md`](database/migrations/README.md).

## Seguridad

- Contraseñas con hash scrypt; nunca texto plano.
- JWT de Flask; los tokens se invalidan al hacer logout.
- `sosnet_api` no puede leer `usuarios.contrasena`; solo la función de login,
  `SECURITY DEFINER`, accede al hash.
- RLS protege solicitudes, usuarios, historial y actividad.
- No se usan claves de servicios externos: todo corre en local.

No se deben confirmar emergencias únicamente por haber recibido el mensaje: la
central registra cada cambio de estado con el operador responsable y conserva la
auditoría de accesos y administración. La retención se controla con
`purge-old-sos`.
