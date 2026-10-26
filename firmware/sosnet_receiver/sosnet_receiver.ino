#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>

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

void printEscaped(const char* value) {
  for (const char* cursor = value; *cursor; ++cursor) {
    switch (*cursor) {
      case '"': Serial.print("\\\""); break;
      case '\\': Serial.print("\\\\"); break;
      case '\n': Serial.print("\\n"); break;
      case '\r': Serial.print("\\r"); break;
      case '\t': Serial.print("\\t"); break;
      default: Serial.print(*cursor);
    }
  }
}

void onReceive(const esp_now_recv_info_t*, const uint8_t* data, int length) {
  if (length != sizeof(EmergencyMessage)) return;

  EmergencyMessage emergency;
  memcpy(&emergency, data, sizeof(emergency));

  emergency.deviceId[sizeof(emergency.deviceId) - 1] = '\0';
  emergency.type[sizeof(emergency.type) - 1] = '\0';
  emergency.message[sizeof(emergency.message) - 1] = '\0';
  emergency.reporterName[sizeof(emergency.reporterName) - 1] = '\0';
  emergency.location[sizeof(emergency.location) - 1] = '\0';
  emergency.priority[sizeof(emergency.priority) - 1] = '\0';

  // Una línea JSON por mensaje para que PySerial pueda procesarla.
  Serial.print("{\"device_id\":\"");
  printEscaped(emergency.deviceId);
  Serial.print("\",\"type\":\"");
  printEscaped(emergency.type);
  Serial.print("\",\"message\":\"");
  printEscaped(emergency.message);
  Serial.print("\",\"reporter_name\":\"");
  printEscaped(emergency.reporterName);
  Serial.print("\",\"location\":\"");
  printEscaped(emergency.location);
  Serial.print("\",\"people\":");
  Serial.print(emergency.people);
  Serial.print(",\"priority\":\"");
  printEscaped(emergency.priority);
  Serial.print("\",\"latitude\":");
  Serial.print(emergency.latitude, 7);
  Serial.print(",\"longitude\":");
  Serial.print(emergency.longitude, 7);
  Serial.println("}");
}

void setup() {
  Serial.begin(115200);
  WiFi.mode(WIFI_STA);
  esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE);

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
