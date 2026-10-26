# SOSNET

SOSNET recibe solicitudes de emergencia mediante una red local de ESP32 con ESP-NOW. Un ESP32 receptor entrega cada alerta por USB/serial a una API Flask, que la almacena en MySQL y la expone a una interfaz React.

## Arquitectura inicial

```text
Celular / botón SOS -> ESP32 emisor -> ESP-NOW -> ESP32 receptor
                                                    |
                                               USB / Serial
                                                    |
React + Vite <- HTTP / JSON <- Flask + PySerial -> MySQL
```

## Requisitos

- Node.js 20 o superior y npm.
- Docker Desktop iniciado con contenedores Linux, o Docker Engine con Docker Compose v2 en Linux.
- Python 3.11 o superior. El arranque automático lo usa cuando el backend no está en Docker; si usas el contenedor `sosnet-backend`, no hace falta.
- Internet para descargar las dependencias y la imagen MySQL en el primer arranque.
- Arduino IDE 2.x con el paquete de placas ESP32 de Espressif y dos ESP32 para probar el enlace de hardware. No son necesarios para abrir la plataforma.

## Inicio con un solo comando

En una notebook nueva, instala los requisitos, abre Docker Desktop y ejecuta:

```powershell
git clone https://github.com/xmanugonzalez/sosnet.git
cd sosnet
npm run dev
```

El comando crea los `.env` que falten desde sus ejemplos, instala las dependencias del frontend y arranca MySQL. Después inicia Flask y Vite:

- Si el contenedor `sosnet-backend` ya está en ejecución, lo reutiliza y no necesita Python.
- Si no existe, crea `backend/.venv`, instala las dependencias Python e inicia Flask localmente.
- MySQL aplica `database/schema.sql` y `database/seed.sql` automáticamente cuando el volumen es nuevo.

La primera ejecución puede tardar varios minutos. MySQL dispone de hasta 10 minutos para inicializar y su healthcheck consulta la base con el usuario de la aplicación antes de arrancar Flask.

- Frontend: `http://localhost:1010`.
- API: `http://localhost:5000/api/health`.
- `Ctrl+C` detiene Flask local y Vite. Los contenedores de Docker siguen activos; para detener MySQL, ejecuta `npm run db:stop`. Para detener el backend en Docker, ejecuta `docker compose stop backend`.
- Para trabajar únicamente en la interfaz: `npm run dev:frontend`.

Si quieres usar el backend dentro de Docker, constrúyelo antes del primer `npm run dev`:

```powershell
docker compose up -d --build backend
npm run dev
```

Los puertos 3306 y 1010 deben estar libres. El puerto 5000 puede estar ocupado por el backend en Docker que se reutiliza; si no hay backend, el arranque lo usa para Flask local. Si personalizas `.env`, ajusta también `DATABASE_URL` en `backend/.env` para que coincidan puerto, usuario, contraseña y base de datos. Las credenciales de inicialización solo se aplican al crear el volumen por primera vez.

## 1. Base de datos

El esquema oficial está en `database/schema.sql` y los datos iniciales en `database/seed.sql`. Es la traducción del modelo de SQL Server a MySQL 8 (`INT IDENTITY` → `AUTO_INCREMENT`, `GO` eliminado, índices `NONCLUSTERED` → índices InnoDB, comentarios con `COMMENT`). La base se llama `sosnet` en minúsculas para coincidir con `DATABASE_URL`, ya que MySQL en Linux distingue mayúsculas.

Desde la raíz del proyecto:

```powershell
Copy-Item .env.example .env
docker compose up -d mysql
```

En un volumen nuevo, MySQL ejecuta automáticamente `schema.sql` y `seed.sql` porque `database/` se monta en `/docker-entrypoint-initdb.d`. Si el volumen ya existía, aplica el esquema manualmente:

```powershell
docker compose stop backend
docker compose cp database/schema.sql mysql:/tmp/schema.sql
docker compose cp database/seed.sql mysql:/tmp/seed.sql
docker compose exec -T mysql sh -c "mysql -uroot -proot_dev --default-character-set=utf8mb4 < /tmp/schema.sql"
docker compose exec -T mysql sh -c "mysql -uroot -proot_dev --default-character-set=utf8mb4 < /tmp/seed.sql"
docker compose start backend
```

Detener el backend evita que `db.create_all()` cree las tablas primero y luego el SQL agregue claves foráneas duplicadas.

Tablas: `TiposEmergencia`, `Dispositivos`, `SolicitudesSOS`, `RegistrosComunicacion`, `Usuarios` e `HistorialEstados`, con sus claves foráneas e índices únicos.

Datos iniciales:

- 5 tipos de emergencia.
- Dispositivos `NODE-001`, `NODE-002`, `NODE-003` y `FORMULARIO-SOS`.
- Usuario de demostración `operador` / `sosnet123` (cambiar en producción) y usuario interno `sistema` para el historial de estados.

> `db.create_all()` solo crea tablas que no existan; no modifica columnas. Si cambias el modelo durante el desarrollo, aplica el SQL o recrea el volumen `mysql_data`.

## 2. Backend

Con Docker:

```powershell
docker compose up -d --build backend
docker compose logs -f backend
```

Sin Docker, en otra terminal:

```powershell
Set-Location backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
Copy-Item .env.example .env
flask --app run.py run --debug
```

Comprobar la API en `http://localhost:5000/api/health`. Al arrancar, SQLAlchemy crea las tablas que todavía no existan.

Para ejecutar las pruebas y el análisis estático:

```powershell
pytest
ruff check .
```

## 3. Frontend

En otra terminal:

```powershell
Set-Location frontend
npm install
Copy-Item .env.example .env
npm run dev
```

Abrir `http://localhost:1010`. Vite redirige `/api` al backend durante el desarrollo.

- `http://localhost:1010` — centro de operaciones para el equipo de rescate.
- `http://localhost:1010/sos` — formulario de solicitud de auxilio para la persona afectada.

La pantalla de acceso permite entrar como operador o administrador. Es una demostración local del frontend: la tabla `Usuarios` todavía no está conectada al inicio de sesión.

### API de emergencias

- `GET /api/emergencies` — últimas 100 solicitudes registradas.
- `POST /api/emergencies` — registra una solicitud. Campos: `emergency_type`, `people`, `priority` (`alta`, `media`, `baja`), `location`, `message`, `reporter_name`, `latitude`, `longitude`.
- `PATCH /api/emergencies/<id>` — actualiza `status` (`pending`, `in_progress`, `resolved`) o `priority`.

Cada `POST` crea una fila en `SolicitudesSOS` y su registro en `RegistrosComunicacion`; cada cambio de estado genera una fila en `HistorialEstados`. El esquema no tiene columnas de latitud/longitud: si el formulario envía GPS, las coordenadas se agregan como texto dentro de `ubicacion`.

## 4. ESP32 y enlace serial

1. Instalar en Arduino IDE el paquete **esp32 by Espressif Systems**.
2. Abrir `firmware/sosnet_receiver/sosnet_receiver.ino`, seleccionar la placa y cargarlo.
3. Copiar la MAC que muestra el monitor serial.
4. Copiar `firmware/sosnet_node/config.example.h` como `config.h` y colocar allí la MAC receptora.
5. Abrir y cargar `firmware/sosnet_node/sosnet_node.ino` en el ESP32 emisor.
6. Conectar el receptor a la computadora y consultar su puerto COM en el Administrador de dispositivos.
7. En `backend/.env`, establecer `SERIAL_ENABLED=true` y ajustar `SERIAL_PORT`, por ejemplo `COM3`.
8. Reiniciar Flask. Cada mensaje válido se guardará automáticamente en MySQL.

### Portal Wi-Fi del nodo emisor

Al arrancar, el nodo crea la red abierta `SOSNET Emergencias` y publica el formulario en `http://192.168.4.1`.

1. Conectar el celular a `SOSNET Emergencias`.
2. Si el sistema operativo detecta el portal cautivo, abre el formulario automáticamente; si no, navegar a `http://192.168.4.1`.
3. Completar tipo de emergencia, ubicación, cantidad de personas, prioridad y detalles.
4. Al enviar, el ESP32 transmite la solicitud por ESP-NOW al receptor.

El botón físico sigue disponible como respaldo y se conecta entre GPIO 4 y GND (pull-up interna).

> El formulario del ESP32 funciona sin internet. La pantalla `/sos` de React sirve para demostrar el flujo desde la computadora y necesita conexión con la central. El navegador no permite GPS sobre `http://192.168.4.1` porque no es un contexto seguro, así que el portal solicita la ubicación escrita.

### Consideraciones del enlace

- Emisor y receptor deben usar el canal 1; el receptor lo fija al iniciar.
- El `struct EmergencyMessage` debe ser idéntico en ambos sketches. Si cambia, recargar los dos ESP32.
- El receptor entrega una línea JSON por emergencia con los campos del formulario.

## Estructura

```text
sosnet/
├── backend/             API, modelos, receptor serial y pruebas
├── database/            Esquema MySQL y datos iniciales
├── firmware/
│   ├── sosnet_node/     ESP32 emisor
│   └── sosnet_receiver/ ESP32 receptor USB
├── frontend/            React, Vite y Tailwind CSS
├── scripts/             Arranque automático del entorno de desarrollo
├── docker-compose.yml   MySQL y backend de desarrollo
└── .env.example         Configuración del contenedor
```

## Convenciones de datos

El receptor entrega una línea JSON UTF-8 por emergencia:

```json
{"device_id":"NODE-001","type":"Inundación","message":"El agua sube rápido","reporter_name":"María","location":"Barrio San Francisco","people":5,"priority":"alta","latitude":-25.2867,"longitude":-57.3333}
```

No se deben confirmar emergencias únicamente por haber recibido el mensaje: la futura capa de negocio debe registrar estados, operador responsable y trazabilidad.
