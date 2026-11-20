# SOSNET

SOSNET recibe solicitudes de emergencia mediante una red local de ESP32 con
ESP-NOW. Un ESP32 receptor entrega cada alerta por USB/serial a una API Flask,
que la almacena en PostgreSQL (local o Supabase) y la expone a una interfaz
React.

## Arquitectura

```text
Celular / botón SOS → ESP32 emisor → ESP-NOW → ESP32 receptor
                                                    │ USB serial (JSON)
                                                    ▼
React + Vite ◀── HTTP/JSON ── Flask + JWT ── SQLAlchemy/psycopg ── PostgreSQL
                                                                  (Supabase)
```

- `public`: tablas y objetos de aplicación.
- `auditoria`: historial de estados y actividad.
- `reportes`: vistas y funciones administrativas.
- La API usa JWT propio de Flask y un rol PostgreSQL de mínimo privilegio.
- RLS protege las tablas para la API y para clientes Supabase.

La documentación completa de la base (diagrama ER, procedimientos, triggers,
vistas, funciones, esquemas, transacciones, RLS y evidencias de pruebas) está en
[`database/README.md`](database/README.md).

## Requisitos

- Node.js 20 o superior y npm.
- Docker Desktop iniciado con contenedores Linux, o Docker Engine con Docker
  Compose v2 en Linux.
- Python 3.11 o superior. El arranque automático lo usa cuando el backend no está
  en Docker; si usas el contenedor `sosnet-backend`, no hace falta.
- Internet para descargar dependencias e imágenes en el primer arranque.
- Arduino IDE 2.x con el paquete ESP32 de Espressif y dos ESP32 para probar el
  enlace de hardware. No son necesarios para abrir la plataforma.

## Inicio local con un solo comando

```powershell
git clone https://github.com/xmanugonzalez/sosnet.git
cd sosnet
npm run dev
```

El comando:

1. Crea los `.env` que falten desde sus ejemplos.
2. Genera `SECRET_KEY` y `JWT_SECRET_KEY` aleatorias y distintas si faltan o son
   valores de ejemplo. No muestra los secretos ni los versiona.
3. Instala las dependencias del frontend y del backend.
4. Inicia PostgreSQL 17 con Docker. En un volumen nuevo ejecuta automáticamente
   `database/00_schemas.sql` … `database/09_seed.sql` y habilita el rol local
   `sosnet_api`.
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

## Usar Supabase

1. Crear el proyecto en Supabase.
2. En **SQL Editor**, ejecutar en orden los archivos `database/00_schemas.sql` a
   `database/09_seed.sql`.
3. Definir la contraseña del rol de la API:

   ```sql
   ALTER ROLE sosnet_api WITH LOGIN PASSWORD 'UNA_CLAVE_LARGA_Y_UNICA';
   ```

4. Configurar `backend/.env`:

   ```dotenv
   DATABASE_URL=postgresql+psycopg://sosnet_api:UNA_CLAVE_LARGA_Y_UNICA@aws-0-REGION.pooler.supabase.com:5432/postgres?sslmode=require
   AUTO_CREATE_TABLES=false
   ```

5. Ejecutar la API y el frontend por separado (no hace falta el PostgreSQL
   local):

   ```powershell
   Set-Location backend
   .\.venv\Scripts\Activate.ps1
   flask --app run.py run --debug
   ```

   ```powershell
   npm run dev:frontend
   ```

Nunca uses la `service_role key` en Flask ni en React. La API conecta con
`sosnet_api`, que no es superusuario y está sujeto a RLS. La autenticación sigue
siendo el JWT de Flask; la columna opcional `usuarios.supabase_uid` permite
adoptar Supabase Auth más adelante sin duplicar identidades.

La guía paso a paso y el script de verificación están en
[`database/supabase/README.md`](database/supabase/README.md) y
[`database/supabase/verify.sql`](database/supabase/verify.sql). El proyecto
remoto no se ejecutó en este entorno por falta de credenciales: no afirmes que
Supabase está configurado hasta ejecutar la verificación en el proyecto real.

`anon` no ejecuta procedimientos de escritura directamente; el formulario
público pasa por Flask, que aplica el límite de 30 solicitudes por minuto.
Los hashes de contraseña no se pueden consultar por columnas y el logout
invalida los JWT anteriores.

## Base de datos

- Motor: PostgreSQL 17 (local) o Supabase (PostgreSQL gestionado).
- Esquema: `database/00_schemas.sql` a `database/09_seed.sql`.
- Datos iniciales:
  - 5 tipos de emergencia.
  - Dispositivos `NODE-001`, `NODE-002`, `NODE-003` y `FORMULARIO-SOS`.
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

> Cambia las contraseñas demo en producción. Para cambios de esquema usa un
> archivo nuevo en `database/migrations/` o recrea el volumen `postgres_data`;
> no edites una base en producción sin respaldo.

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

- `DATABASE_URL`: PostgreSQL local o Supabase con `sslmode=require`.
- `AUTO_CREATE_TABLES=false`: el esquema se crea con los scripts SQL, no con
  `db.create_all()`.
- `SECRET_KEY` y `JWT_SECRET_KEY`: obligatorias y distintas en producción.
- `JWT_ACCESS_TOKEN_HOURS`: duración del token, por defecto 8.
- `CORS_ORIGINS`: por defecto `http://localhost:1010,http://localhost:5173`.
- `SOS_RETENTION_DAYS`: retención de solicitudes, por defecto 90.
- `RATELIMIT_ENABLED`: límites de login y envío público de SOS.
- `SERIAL_ENABLED`, `SERIAL_PORT`, `SERIAL_BAUDRATE`, `SERIAL_TIMEOUT`: enlace
  con el ESP32 receptor.

La autenticación usa JWT con tokens de 8 horas. El frontend los guarda en
`sessionStorage` y los envía como `Authorization: Bearer <token>`. Los permisos
se validan en el backend en cada solicitud y RLS actúa como segunda capa.

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
desarrollo.

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
- `POST /api/auth/logout` — registra el cierre de sesión e invalida el token
  anterior incrementando `usuarios.token_version`.
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
de estado genera historial y actividad mediante triggers. El esquema no tiene
columnas GPS; si el formulario envía coordenadas, se agregan como texto dentro de
`ubicacion`, igual que antes.

## ESP32 y enlace serial

1. Instalar en Arduino IDE el paquete **esp32 by Espressif Systems**.
2. Abrir `firmware/sosnet_receiver/sosnet_receiver.ino`, seleccionar la placa y
   cargarlo.
3. Copiar la MAC que muestra el monitor serial.
4. Copiar `firmware/sosnet_node/config.example.h` como `config.h` y colocar allí
   la MAC receptora.
5. Abrir y cargar `firmware/sosnet_node/sosnet_node.ino` en el ESP32 emisor.
6. Conectar el receptor y consultar su puerto COM.
7. En `backend/.env`, establecer `SERIAL_ENABLED=true` y ajustar `SERIAL_PORT`
   (por ejemplo `COM3`).
8. Reiniciar Flask. Cada mensaje válido se guardará en PostgreSQL.

### Portal Wi-Fi del nodo emisor

Al arrancar, el nodo crea la red abierta `SOSNET Emergencias` y publica el
formulario en `http://192.168.4.1`.

1. Conectar el celular a `SOSNET Emergencias`.
2. Si el sistema operativo detecta el portal cautivo, abre el formulario; si no,
   navegar a `http://192.168.4.1`.
3. Completar tipo, ubicación, cantidad de personas, prioridad y detalles.
4. Al enviar, el ESP32 transmite la solicitud por ESP-NOW al receptor.

El botón físico sigue disponible entre GPIO 4 y GND (pull-up interna).

> El formulario del ESP32 funciona sin internet. La pantalla `/sos` de React
> demuestra el flujo desde la computadora y necesita conexión con la central. El
> navegador no permite GPS sobre `http://192.168.4.1`, así que el portal solicita
> la ubicación escrita.

### Consideraciones del enlace

- Emisor y receptor deben usar el canal 1; el receptor lo fija al iniciar.
- El `struct EmergencyMessage` debe ser idéntico en ambos sketches. Si cambia,
  recargar los dos ESP32.
- El receptor entrega una línea JSON por emergencia.

## Estructura

```text
sosnet/
├── backend/             API Flask, JWT, modelos, receptor serial y pruebas
├── database/            Esquema PostgreSQL/Supabase, pruebas y migraciones
│   ├── legacy/mysql/    Esquema MySQL original conservado
│   └── migrations/      Migrador MySQL → PostgreSQL
├── firmware/
│   ├── sosnet_node/     ESP32 emisor
│   └── sosnet_receiver/ ESP32 receptor USB
├── frontend/            React, Vite y Tailwind CSS
├── scripts/             Arranque automático del entorno de desarrollo
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

## Migración desde MySQL

El sistema anterior está en `database/legacy/mysql/`. El migrador
`database/migrations/migrate_mysql_to_postgres.py` copia los datos de forma
idempotente y remapea IDs. Instrucciones completas en
[`database/migrations/README.md`](database/migrations/README.md).

## Convenciones de datos

El receptor entrega una línea JSON UTF-8 por emergencia:

```json
{"device_id":"NODE-001","type":"Inundación","message":"El agua sube rápido","reporter_name":"María","location":"Barrio San Francisco","people":5,"priority":"alta","latitude":-25.2867,"longitude":-57.3333}
```

No se deben confirmar emergencias únicamente por haber recibido el mensaje: la
central registra cada cambio de estado con el operador responsable y conserva la
auditoría de accesos y administración. La retención se controla con
`purge-old-sos`.
