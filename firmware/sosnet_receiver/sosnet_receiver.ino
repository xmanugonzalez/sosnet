#include <WiFi.h>
#include <esp_now.h>

struct EmergencyMessage {
  char deviceId[32];
  char type[24];
  char message[160];
  double latitude;
  double longitude;
};

void onReceive(const esp_now_recv_info_t*, const uint8_t* data, int length) {
  if (length != sizeof(EmergencyMessage)) return;

  EmergencyMessage emergency;
  memcpy(&emergency, data, sizeof(emergency));

  // Una línea JSON por mensaje para que PySerial pueda procesarla.
  Serial.printf(
    "{\"device_id\":\"%s\",\"type\":\"%s\",\"message\":\"%s\",\"latitude\":%.7f,\"longitude\":%.7f}\n",
    emergency.deviceId,
    emergency.type,
    emergency.message,
    emergency.latitude,
    emergency.longitude
  );
}

void setup() {
  Serial.begin(115200);
  WiFi.mode(WIFI_STA);
  Serial.print("MAC receptora: ");
  Serial.println(WiFi.macAddress());

  if (esp_now_init() != ESP_OK) {
    Serial.println("No se pudo iniciar ESP-NOW");
    return;
  }

  esp_now_register_recv_cb(onReceive);
}

void loop() {
  delay(1000);
}

