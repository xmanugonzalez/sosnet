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
- Python 3.11 o superior con pip y venv, disponible en el PATH (`py` o `python` en Windows; `python3` en Linux/macOS).
- Docker Desktop iniciado con contenedores Linux, o Docker Engine con Docker Compose v2 en Linux.
- Internet para descargar las dependencias y la imagen MySQL en el primer arranque.
- Arduino IDE 2.x con el paquete de placas ESP32 de Espressif y dos ESP32 para probar el enlace de hardware. No son necesarios para abrir la plataforma.

## Inicio con un solo comando

En una notebook nueva, instala los requisitos anteriores, abre Docker Desktop y ejecuta:

```powershell
git clone https://github.com/xmanugonzalez/sosnet.git
cd sosnet
npm run dev
```

El comando crea los `.env` que falten desde sus ejemplos, crea `backend/.venv`, instala las dependencias Python y React y después inicia MySQL, Flask y Vite. No necesitas copiar archivos, ejecutar `npm install` por separado ni activar el entorno virtual. Conserva los `.env` existentes. En arranques posteriores solo reinstala dependencias cuando cambian sus manifiestos.

La primera ejecución puede tardar varios minutos descargando MySQL y las dependencias. MySQL dispone de hasta 10 minutos para terminar la inicialización, y su healthcheck consulta la base con el usuario de la aplicación antes de arrancar Flask.

- Frontend: `http://localhost:5173`.
- API: `http://localhost:5000/api/health`.
- `Ctrl+C` detiene Flask y Vite. MySQL permanece activo con sus datos; para detenerlo, ejecuta `npm run db:stop`.
- Para trabajar únicamente en la interfaz: `npm run dev:frontend`.

El lector serial arranca con Flask si `SERIAL_ENABLED=true` y el ESP32 está conectado al puerto configurado. El hardware se programa por separado con Arduino IDE. Flask se ejecuta sin recarga automática para evitar duplicar el lector serial; después de editar Python, reinicia `npm run dev`. Vite mantiene la recarga automática de React.

Si falta Python o Docker está cerrado, el comando muestra el problema y termina. Los puertos 3306, 5000 y 5173 deben estar libres. Si personalizas `.env`, ajusta también `DATABASE_URL` en `backend/.env` para que coincidan puerto, usuario, contraseña y base de datos. En Linux puede ser necesario instalar el paquete de venv de tu distribución y habilitar el acceso de tu usuario a Docker.

Si MySQL aparece como `unhealthy`, el comando muestra sus últimos logs. Puedes consultarlos con `docker compose logs --tail 60 mysql`. Las credenciales de inicialización solo se aplican al crear el volumen por primera vez: cambiarlas en `.env` no modifica las de una base existente. No borres el volumen para resolver un fallo si contiene datos que quieras conservar.

Las secciones siguientes describen el arranque manual alternativo; no hace falta seguirlas para usar `npm run dev`.

## 1. Base de datos

Desde la raíz del proyecto:

```powershell
Copy-Item .env.example .env
docker compose up -d mysql
```

El contenedor expone MySQL en `localhost:3306` y crea la base `sosnet`. Los valores incluidos son solo para desarrollo.

## 2. Backend

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

Abrir `http://localhost:5173`. Vite redirige `/api` al backend durante el desarrollo.

## 4. ESP32 y enlace serial

1. Instalar en Arduino IDE el paquete **esp32 by Espressif Systems**.
2. Abrir `firmware/sosnet_receiver/sosnet_receiver.ino`, seleccionar la placa y cargarlo.
3. Copiar la MAC que muestra el monitor serial.
4. Copiar `firmware/sosnet_node/config.example.h` como `config.h` y colocar allí la MAC receptora.
5. Abrir y cargar `firmware/sosnet_node/sosnet_node.ino` en el ESP32 emisor.
6. Conectar el receptor a la computadora y consultar su puerto COM en el Administrador de dispositivos.
7. En `backend/.env`, establecer `SERIAL_ENABLED=true` y ajustar `SERIAL_PORT`, por ejemplo `COM3`.
8. Reiniciar Flask. Cada mensaje válido se guardará automáticamente en MySQL.

El botón SOS se conecta entre GPIO 4 y GND; se utiliza la resistencia pull-up interna.

## Estructura

```text
sosnet/
├── backend/             API, modelos, receptor serial y pruebas
├── firmware/
│   ├── sosnet_node/     ESP32 emisor
│   └── sosnet_receiver/ ESP32 receptor USB
├── frontend/            React, Vite y Tailwind CSS
├── docker-compose.yml   MySQL de desarrollo
└── .env.example         Configuración del contenedor
```

## Convenciones de datos

El receptor entrega una línea JSON UTF-8 por emergencia:

```json
{"device_id":"NODE-001","type":"sos","message":"Solicitud de emergencia","latitude":-25.2867,"longitude":-57.3333}
```

No se deben confirmar emergencias únicamente por haber recibido el mensaje: la futura capa de negocio debe registrar estados, operador responsable y trazabilidad.
