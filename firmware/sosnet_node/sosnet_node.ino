#include <WiFi.h>
#include <esp_now.h>
#include <WebServer.h>
#include <DNSServer.h>
#include "config.h"

struct EmergencyMessage {
  char deviceId[32];
  char type[24];
  char message[160];
  char reporterName[48];
  char location[80];
  char priority[12];
  uint16_t people;
  double latitude;
  double longitude;
};

constexpr int SOS_BUTTON_PIN = 4;
constexpr char PORTAL_SSID[] = "SOSNET Emergencias";
constexpr uint8_t WIFI_CHANNEL = 1;

WebServer server(80);
DNSServer dnsServer;

const char PORTAL_HTML[] = R"rawliteral(
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SOSNET - Solicitud de auxilio</title>
<style>
*{box-sizing:border-box}
body{margin:0;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:#020617;color:#e2e8f0}
.wrap{max-width:520px;margin:0 auto;padding:22px 18px 44px}
header{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:18px}
.logo{display:flex;align-items:center;gap:10px}
.mark{width:42px;height:42px;border-radius:12px;background:#ef4444;display:grid;place-items:center;font-weight:900;color:#fff;font-size:20px}
h1{margin:0;font-size:20px;line-height:1.2}
.sub{margin:2px 0 0;font-size:12px;color:#94a3b8}
.net{font-size:11px;color:#6ee7b7;background:rgba(16,185,129,.12);padding:6px 10px;border-radius:999px;white-space:nowrap}
.hero{border:1px solid rgba(239,68,68,.35);background:linear-gradient(135deg,rgba(239,68,68,.16),#0f172a);border-radius:18px;padding:16px;margin-bottom:18px}
.hero h2{margin:0 0 6px;font-size:17px}
.hero p{margin:0;font-size:13px;line-height:1.55;color:#cbd5e1}
fieldset{border:0;padding:0;margin:0 0 16px}
legend{font-size:13px;font-weight:700;margin-bottom:8px;padding:0}
.types{display:grid;grid-template-columns:1fr 1fr;gap:8px}
.type{position:relative;display:block}
.type input{position:absolute;opacity:0;inset:0}
.type span{display:block;border:1px solid #1e293b;background:#0f172a;color:#94a3b8;border-radius:12px;padding:11px 10px;font-size:12px;font-weight:600;text-align:center}
.type input:checked+span{border-color:#f87171;background:rgba(239,68,68,.18);color:#fff}
label.field{display:block;font-size:13px;font-weight:700;margin-bottom:6px}
input[type=text],input[type=number],textarea,select{width:100%;border:1px solid #1e293b;background:#0f172a;color:#f8fafc;border-radius:12px;padding:12px;font-size:15px;font-family:inherit}
textarea{min-height:82px;resize:vertical}
input:focus,textarea:focus,select:focus{outline:none;border-color:#f87171}
.req{color:#f87171}
.row{margin-bottom:16px}
.two{display:grid;grid-template-columns:1fr 110px;gap:10px}
button{width:100%;border:0;border-radius:16px;background:#ef4444;color:#fff;font-size:16px;font-weight:800;padding:16px;margin-top:4px;font-family:inherit}
button:active{background:#dc2626}
.note{margin:18px 0 0;font-size:11px;line-height:1.6;color:#64748b}
.center{text-align:center;padding-top:40px}
.big{width:72px;height:72px;border-radius:50%;display:grid;place-items:center;margin:0 auto 18px;font-size:36px;font-weight:900}
.ok{background:rgba(16,185,129,.15);color:#6ee7b7}
.bad{background:rgba(239,68,68,.15);color:#fca5a5}
h2.title{font-size:22px;margin:0 0 10px}
p.text{font-size:14px;line-height:1.6;color:#94a3b8;margin:0 0 22px}
a.back{display:inline-block;color:#93c5fd;font-size:13px;text-decoration:none}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <div class="logo">
      <div class="mark">S</div>
      <div>
        <h1>SOSNET</h1>
        <p class="sub">Solicitud de auxilio</p>
      </div>
    </div>
    <span class="net">Red local</span>
  </header>

  <section class="hero">
    <h2>Necesito ayuda</h2>
    <p>Completa los datos. Tu solicitud viaja por la red de emergencia SOSNET, sin necesidad de internet.</p>
  </section>

  <form method="POST" action="/enviar">
    <fieldset>
      <legend>&iquest;Qu&eacute; est&aacute; ocurriendo?</legend>
      <div class="types">
        <label class="type"><input type="radio" name="type" value="Inundaci&oacute;n" checked><span>Inundaci&oacute;n</span></label>
        <label class="type"><input type="radio" name="type" value="Asistencia m&eacute;dica"><span>Asistencia m&eacute;dica</span></label>
        <label class="type"><input type="radio" name="type" value="Evacuaci&oacute;n"><span>Evacuaci&oacute;n</span></label>
        <label class="type"><input type="radio" name="type" value="Suministros"><span>Suministros</span></label>
        <label class="type"><input type="radio" name="type" value="Otra"><span>Otra</span></label>
      </div>
    </fieldset>

    <div class="row">
      <label class="field" for="location">&iquest;D&oacute;nde est&aacute;n? <span class="req">*</span></label>
      <input id="location" type="text" name="location" maxlength="80" required placeholder="Barrio, calle, casa de referencia">
    </div>

    <div class="row two">
      <div>
        <label class="field" for="name">Tu nombre (opcional)</label>
        <input id="name" type="text" name="name" maxlength="47" placeholder="Persona de contacto">
      </div>
      <div>
        <label class="field" for="people">Personas</label>
        <input id="people" type="number" name="people" min="1" max="1000" value="1" inputmode="numeric">
      </div>
    </div>

    <div class="row">
      <label class="field" for="priority">Prioridad</label>
      <select id="priority" name="priority">
        <option value="baja">Baja - podemos esperar</option>
        <option value="media" selected>Media - ayuda pronto</option>
        <option value="alta">Alta - estamos en peligro</option>
      </select>
    </div>

    <div class="row">
      <label class="field" for="message">Detalles (opcional)</label>
      <textarea id="message" name="message" maxlength="159" placeholder="Ej.: hay ni&ntilde;os y una persona mayor, el agua sube r&aacute;pido."></textarea>
    </div>

    <button type="submit">Enviar solicitud de auxilio</button>
  </form>

  <p class="note">Prototipo acad&eacute;mico. No reemplaza a los servicios de emergencia oficiales. Recibir la solicitud no confirma que la ayuda ya est&eacute; en camino.</p>
</div>
</body>
</html>
)rawliteral";

const char SENT_HTML[] = R"rawliteral(
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SOSNET - Solicitud enviada</title>
<style>
*{box-sizing:border-box}
body{margin:0;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:#020617;color:#e2e8f0}
.wrap{max-width:520px;margin:0 auto;padding:40px 20px}
.center{text-align:center}
.big{width:72px;height:72px;border-radius:50%;display:grid;place-items:center;margin:0 auto 18px;font-size:36px;font-weight:900;background:rgba(16,185,129,.15);color:#6ee7b7}
h2{font-size:22px;margin:0 0 10px}
p{font-size:14px;line-height:1.6;color:#94a3b8;margin:0 0 22px}
a{display:inline-block;color:#93c5fd;font-size:13px;text-decoration:none}
.note{margin-top:26px;font-size:11px;color:#64748b}
</style>
</head>
<body>
<div class="wrap center">
  <div class="big">&#10003;</div>
  <h2>Solicitud enviada</h2>
  <p>Tu pedido de ayuda fue transmitido a la central de rescate por la red SOSNET.</p>
  <p class="note">Recibir la solicitud no significa que la ayuda ya est&eacute; en camino. Si tu vida corre peligro inmediato, busca un lugar seguro y avisa a las personas cercanas.</p>
  <a href="/">&larr; Enviar otra solicitud</a>
</div>
</body>
</html>
)rawliteral";

const char FAILED_HTML[] = R"rawliteral(
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SOSNET - Error de envio</title>
<style>
*{box-sizing:border-box}
body{margin:0;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:#020617;color:#e2e8f0}
.wrap{max-width:520px;margin:0 auto;padding:40px 20px;text-align:center}
.big{width:72px;height:72px;border-radius:50%;display:grid;place-items:center;margin:0 auto 18px;font-size:36px;font-weight:900;background:rgba(239,68,68,.15);color:#fca5a5}
h2{font-size:22px;margin:0 0 10px}
p{font-size:14px;line-height:1.6;color:#94a3b8;margin:0 0 22px}
a{display:inline-block;color:#93c5fd;font-size:13px;text-decoration:none}
</style>
</head>
<body>
<div class="wrap">
  <div class="big">!</div>
  <h2>No se pudo transmitir</h2>
  <p>El nodo no logr&oacute; enviar la solicitud a la central. Intenta nuevamente o usa el bot&oacute;n f&iacute;sico del dispositivo.</p>
  <a href="/">&larr; Volver al formulario</a>
</div>
</body>
</html>
)rawliteral";

void onSent(const uint8_t*, esp_now_send_status_t status) {
  Serial.println(status == ESP_NOW_SEND_SUCCESS ? "Enviado" : "Error de envío");
}

bool sendAlert(String type, String name, String location, String message, uint16_t people, String priority) {
  EmergencyMessage alert;
  memset(&alert, 0, sizeof(alert));

  strlcpy(alert.deviceId, DEVICE_ID, sizeof(alert.deviceId));
  strlcpy(alert.type, type.c_str(), sizeof(alert.type));
  strlcpy(alert.reporterName, name.c_str(), sizeof(alert.reporterName));
  strlcpy(alert.location, location.c_str(), sizeof(alert.location));
  strlcpy(alert.message, message.c_str(), sizeof(alert.message));
  strlcpy(alert.priority, priority.c_str(), sizeof(alert.priority));
  alert.people = people;
  alert.latitude = 0;
  alert.longitude = 0;

  esp_err_t result = esp_now_send(
    RECEIVER_MAC, reinterpret_cast<const uint8_t*>(&alert), sizeof(alert)
  );
  return result == ESP_OK;
}

void handleRoot() {
  server.send(200, "text/html; charset=utf-8", PORTAL_HTML);
}

void handleSubmit() {
  String type = server.arg("type");
  String name = server.arg("name");
  String location = server.arg("location");
  String message = server.arg("message");
  String priority = server.arg("priority");
  long people = server.arg("people").toInt();

  if (type.isEmpty()) type = "Otra";
  if (priority.isEmpty()) priority = "media";
  if (message.isEmpty()) message = "Solicitud de emergencia";
  if (people < 1) people = 1;
  if (people > 1000) people = 1000;

  bool queued = sendAlert(type, name, location, message, static_cast<uint16_t>(people), priority);
  server.send(200, "text/html; charset=utf-8", queued ? SENT_HTML : FAILED_HTML);
}

void handleNotFound() {
  server.sendHeader("Location", String("http://") + WiFi.softAPIP().toString() + "/", true);
  server.send(302, "text/plain", "");
}

void setup() {
  Serial.begin(115200);
  pinMode(SOS_BUTTON_PIN, INPUT_PULLUP);

  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(PORTAL_SSID, nullptr, WIFI_CHANNEL);
  Serial.print("Portal Wi-Fi: ");
  Serial.println(PORTAL_SSID);
  Serial.print("Dirección: http://");
  Serial.println(WiFi.softAPIP());

  if (esp_now_init() != ESP_OK) {
    Serial.println("No se pudo iniciar ESP-NOW");
    return;
  }

  esp_now_register_send_cb(onSent);
  esp_now_peer_info_t peer{};
  memcpy(peer.peer_addr, RECEIVER_MAC, 6);
  peer.channel = WIFI_CHANNEL;
  peer.encrypt = false;
  esp_now_add_peer(&peer);

  dnsServer.start(53, "*", WiFi.softAPIP());
  server.on("/", HTTP_GET, handleRoot);
  server.on("/enviar", HTTP_POST, handleSubmit);
  server.onNotFound(handleNotFound);
  server.begin();
  Serial.println("Formulario SOS listo");
}

void loop() {
  dnsServer.processNextRequest();
  server.handleClient();

  if (digitalRead(SOS_BUTTON_PIN) == LOW) {
    sendAlert("SOS", "", "Botón físico del nodo", "Solicitud de emergencia", 1, "alta");
    delay(1500);
  }
}
