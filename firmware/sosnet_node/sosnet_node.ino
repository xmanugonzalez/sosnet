#include <WiFi.h>
#include <esp_now.h>
#include "config.h"

struct EmergencyMessage {
  char deviceId[32];
  char type[24];
  char message[160];
  double latitude;
  double longitude;
};

constexpr int SOS_BUTTON_PIN = 4;
EmergencyMessage emergency;

void onSent(const uint8_t*, esp_now_send_status_t status) {
  Serial.println(status == ESP_NOW_SEND_SUCCESS ? "Enviado" : "Error de envío");
}

void setup() {
  Serial.begin(115200);
  pinMode(SOS_BUTTON_PIN, INPUT_PULLUP);
  WiFi.mode(WIFI_STA);

  if (esp_now_init() != ESP_OK) {
    Serial.println("No se pudo iniciar ESP-NOW");
    return;
  }

  esp_now_register_send_cb(onSent);
  esp_now_peer_info_t peer{};
  memcpy(peer.peer_addr, RECEIVER_MAC, 6);
  peer.channel = 0;
  peer.encrypt = false;
  esp_now_add_peer(&peer);

  strlcpy(emergency.deviceId, DEVICE_ID, sizeof(emergency.deviceId));
  strlcpy(emergency.type, "sos", sizeof(emergency.type));
  strlcpy(emergency.message, "Solicitud de emergencia", sizeof(emergency.message));
  emergency.latitude = 0;
  emergency.longitude = 0;
}

void loop() {
  if (digitalRead(SOS_BUTTON_PIN) == LOW) {
    esp_now_send(RECEIVER_MAC, reinterpret_cast<uint8_t*>(&emergency), sizeof(emergency));
    delay(1500);
  }
}

