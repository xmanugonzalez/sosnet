# Frontend público SOSNET

Trabajo aislado en `frontend-publico`. No modifica Flask, SQL, firmware, autenticación ni permisos administrativos.

## Rutas

- `/` y `/sos`: interfaz pública sin registro. `/sos` conserva el enlace utilizado por el dashboard.
- `/admin` y `/admin/*`: aplicación administrativa existente, cargada por separado. No se modifica `App.jsx`, `Access.jsx` ni `AdminPanel.jsx`.
- Otras rutas muestran página no encontrada. El alojamiento de producción debe resolver las rutas del frontend a `index.html` sin capturar los endpoints del servidor.

## Ejecutar y comprobar

Desde `frontend/`: `npm install`, `npm run dev`, `npm run lint`, `npm run build`.
Pruebas del contrato y las validaciones: `node --test tests/public-request.test.mjs`.

El envío público está deshabilitado por defecto: el botón **Revisar formulario** valida los datos y explica que aún no se envían. No usa datos simulados ni genera folios de servidor.

## Integración pendiente con Angelo

Configurar `VITE_PUBLIC_REQUESTS_ENDPOINT` con la URL exacta acordada. Puede ser relativa al origen (servidor local incluido) o una URL absoluta. Reiniciar Vite después de cambiar variables. No se presupone que `/api/emergencies` ni otra ruta existente implemente este contrato. La variable administrativa `VITE_API_URL` no se altera.

El adaptador está en `src/public/services/emergencyApi.js`. Estructura provisional en `requestModel.js`:

```json
{
  "schema_version": 1,
  "client_request_id": "uuid-generado-por-el-navegador",
  "reporter": { "name": "Persona de prueba", "contact": "0981123456" },
  "emergency": {
    "type": "Inundación",
    "affected_people": 2,
    "description": "Descripción escrita por el solicitante"
  },
  "location": {
    "description": "Dirección o comunidad",
    "references": "Casa con portón negro, frente a la despensa",
    "coordinates": {
      "latitude": -25.2867,
      "longitude": -57.3333,
      "accuracy": 30,
      "source": "gps",
      "captured_at": "2026-10-25T12:00:00Z"
    }
  }
}
```

Las coordenadas pueden ser `null`; en ese caso se exige una descripción del lugar. Un ajuste manual usa `source: "manual"`, `accuracy: null`. Los tipos admitidos son los de `EMERGENCY_TYPES`. El teléfono se conserva como texto, sin asumir país. No se envían credenciales administrativas.

Capacidades que necesita el servidor (rutas y modelo a acordar, no implementados aquí):

1. **Crear solicitud pública (POST):** validar campos, registrar contacto/referencias/coordenadas y devolver un recibo solo después de persistir. Debe permitir solicitudes sin login administrativo.
2. **Idempotencia:** deduplicar por `client_request_id` y/o cabecera `Idempotency-Key`; devolver el mismo recibo al reintentar. El frontend conserva el código tras un error y bloquea la edición de envíos ambiguos. La protección definitiva necesita servidor.
3. **Consultar recibo/estado (GET o equivalente):** recuperar un resultado después de timeout o respuesta incompleta. Pendiente de acuerdo e implementación; este frontend no inventa un endpoint ni hace polling.
4. Si hay orígenes distintos, permitir CORS para el origen concreto, POST, Content-Type e Idempotency-Key. Acordar límites y formato de errores. No se cambió CORS ni código Flask.

Contrato de recibo **propuesto**, todavía por acordar:

```json
{
  "receipt": {
    "status": "received",
    "request_id": "codigo-del-servidor",
    "received_at": "2026-10-25T12:00:00Z"
  }
}
```

Solo una respuesta HTTP exitosa con ese recibo completo muestra **Recepción confirmada por el servidor**. Un 2xx sin recibo válido muestra **Enviada · recepción sin confirmar**. Esto indica respuesta al envío, no persistencia ni aceptación de la emergencia. Un error HTTP, de red o timeout muestra **Resultado desconocido**, conservando el formulario. Los ejemplos de esta documentación y las respuestas de las pruebas no se utilizan en producción.

## Guardado local y estados

IndexedDB: `sosnet-public-requests`, almacén `requests`, versión 1. Se guardan borradores parciales mediante acción explícita, además de resultados de intentos de envío. No hay envíos automáticos ni sincronización en segundo plano.

- **En preparación:** cambios en memoria; cerrar puede perderlos.
- **Guardada en este dispositivo:** transacción IndexedDB terminada; no implica comunicación con SOSNET.
- **Enviando:** petición HTTP en curso, no confirmada.
- **Enviada, sin confirmar:** respuesta exitosa sin recibo de registro válido.
- **Confirmada:** recibo explícito del backend. No implica rescatistas asignados ni ayuda en camino.
- **Resultado desconocido:** fallo o timeout; podría haberse procesado. Reintentar conserva el identificador.

Abrir un formulario local permite revisarlo. Se muestra la hora de captura GPS para comprobar si debe renovarse. Borrar la copia local no cancela una solicitud del servidor. El borrado puede solicitar confirmación. Los datos locales incluyen información personal y ubicación; no son permanentes ni cifrados por esta aplicación. El navegador puede borrarlos. Se informa al usuario y se muestran fallos de almacenamiento sin fingir un guardado exitoso.

## Ubicación y mapas

Geolocation API con permiso, HTTPS o localhost. Se informa la precisión aproximada del GPS y se permite dirección alternativa, coordenadas manuales, clic en el mapa y arrastre del marcador. Un ajuste manual elimina la precisión GPS previa. No se usa geocodificación ni servicios de pago.

Leaflet y sus recursos se empaquetan localmente. OpenStreetMap se carga solo al pulsar **Cargar mapa en línea**, con atribución visible. El mapa inicial se centra en Asunción y no coloca un marcador de usuario ficticio. El fondo requiere internet. No se descargan áreas para uso offline ni se usa un service worker para cachear mosaicos: [política de OpenStreetMap](https://operations.osmfoundation.org/policies/tiles/), [referencia de Leaflet](https://leafletjs.com/reference).

## Base para una futura PWA

La capa de servicios y el almacén versionado están separados de la interfaz. Se pueden ampliar con una cola de reintentos explícitos y estados de recibo cuando exista un contrato real. No se registra service worker, no se ofrece instalación ni se promete recarga sin conexión. Para una PWA futura: manifest e iconos, caché versionada solo del shell y recursos locales, actualización segura y prueba offline. Un mapa offline requiere un proveedor autorizado o mosaicos alojados por el proyecto; no debe cachearse masivamente el servicio público OSM.

El indicador del navegador solo describe conectividad aparente: sin internet puede existir un servidor HTTP accesible por Wi-Fi local. No se bloquean envíos basándose únicamente en `navigator.onLine`. El navegador no transmite ESP-NOW; la integración física corresponde a otra capa del proyecto.
