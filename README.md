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
- Python 3.11 o superior.
- Docker Desktop (recomendado para MySQL) o MySQL 8 instalado localmente.
- Arduino IDE 2.x con el paquete de placas ESP32 de Espressif.
- Dos ESP32 para probar el enlace completo.

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
