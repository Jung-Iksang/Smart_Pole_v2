// ============================================================================
// InfuCare Smart IV Pole - ESP32 Firmware
// ============================================================================
// BLE GATT 기반 WiFi 프로비저닝 + 수액 시뮬레이션
//
// BLE 프로토콜:
//   Service UUID: 0000ff01-0000-1000-8000-00805f9b34fb
//   - WiFi Scan Char (0xff02): Write 0x01 → 스캔 시작, Notify → JSON 결과
//   - WiFi Cred Char (0xff03): Write JSON {"ssid":"...","password":"..."}
//   - WiFi Status Char (0xff04): Read/Notify → 연결 상태 (0~4)
//
// 온도 센서 추가 후 온도 보정 알고리즘 추가 예정
// 로드셀 시뮬레이션 코드 포함 (센서 구매 후 수정 예정)
// ============================================================================

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>

// ============================================================================
// BLE UUIDs
// ============================================================================
#define SERVICE_UUID        "0000ff01-0000-1000-8000-00805f9b34fb"
#define CHAR_WIFI_SCAN_UUID "0000ff02-0000-1000-8000-00805f9b34fb"
#define CHAR_WIFI_CRED_UUID "0000ff03-0000-1000-8000-00805f9b34fb"
#define CHAR_WIFI_STAT_UUID "0000ff04-0000-1000-8000-00805f9b34fb"

// WiFi 상태 코드
#define WIFI_STATUS_IDLE        0
#define WIFI_STATUS_CONNECTING  1
#define WIFI_STATUS_CONNECTED   2
#define WIFI_STATUS_FAILED      3
#define WIFI_STATUS_SCANNING    4

// ============================================================================
// 전역 변수 — BLE
// ============================================================================
BLEServer* pServer = nullptr;
BLECharacteristic* pWifiScanChar = nullptr;
BLECharacteristic* pWifiCredChar = nullptr;
BLECharacteristic* pWifiStatChar = nullptr;
bool deviceConnected = false;
bool oldDeviceConnected = false;
uint8_t wifiStatus = WIFI_STATUS_IDLE;
bool wifiScanRequested = false;
bool wifiConnectRequested = false;
String pendingSsid = "";
String pendingPassword = "";

// ============================================================================
// 서버 설정
// ============================================================================
const char* SERVER_URL = "http://100.53.181.154:8000";  // FastAPI 서버 주소
String DEVICE_UID = "";     // setup()에서 MAC 기반 생성
String DEVICE_KEY = "";     // 기기 인증 키 (서버 등록 시 설정)

// 서버 전송 관련 변수
unsigned long lastHeartbeat = 0;
const unsigned long HEARTBEAT_INTERVAL = 60000;  // 1분
unsigned long lastDataSend = 0;
const unsigned long DATA_SEND_INTERVAL = 5000;   // 5초

// ============================================================================
// 전역 변수 — IV 시뮬레이션 (기존 코드 유지)
// ============================================================================
bool isConfigured = false;
float IV_bag_weight = 0;
float IV_finish_weight = 0;
float gtt_min = 0;
bool is_running = false;
float theory_weight = 0;
bool is_first_run = true;
float threshold = 1.5;
float manual_offset = 0;
unsigned long last_loadcell_time = 0;
unsigned long last_creep_time = 0;

// ============================================================================
// BLE 기기 이름 생성 (MAC 하위 4자리 사용)
// ============================================================================
String getDeviceName() {
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_BT);
  char suffix[5];
  snprintf(suffix, sizeof(suffix), "%02X%02X", mac[4], mac[5]);
  return "INFUCARE_" + String(suffix);
}

// ============================================================================
// WiFi 상태 업데이트 → BLE Notify
// ============================================================================
void updateWifiStatus(uint8_t status) {
  wifiStatus = status;
  if (deviceConnected && pWifiStatChar != nullptr) {
    pWifiStatChar->setValue(&wifiStatus, 1);
    pWifiStatChar->notify();
  }
  Serial.printf("[BLE] WiFi 상태 업데이트: %d\n", status);
}

// ============================================================================
// BLE 서버 콜백
// ============================================================================
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;
    Serial.println("[BLE] 클라이언트 연결됨");
  }

  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;
    Serial.println("[BLE] 클라이언트 연결 해제됨");
  }
};

// ============================================================================
// WiFi Scan Characteristic 콜백
// 앱에서 0x01 쓰면 WiFi 스캔 시작
// ============================================================================
class WifiScanCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) override {
    uint8_t* data = pCharacteristic->getData();
    size_t len = pCharacteristic->getLength();
    if (len > 0 && data[0] == 0x01) {
      Serial.println("[BLE] WiFi 스캔 요청 수신");
      wifiScanRequested = true;
    }
  }
};

// ============================================================================
// WiFi Credential Characteristic 콜백
// 앱에서 JSON {"ssid":"...","password":"..."} 전송
// ============================================================================
class WifiCredCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) override {
    std::string value = pCharacteristic->getValue();
    if (value.length() > 0) {
      Serial.printf("[BLE] WiFi 자격증명 수신: %s\n", value.c_str());

      JsonDocument doc;
      DeserializationError error = deserializeJson(doc, value.c_str());
      if (error) {
        Serial.printf("[BLE] JSON 파싱 실패: %s\n", error.c_str());
        updateWifiStatus(WIFI_STATUS_FAILED);
        return;
      }

      const char* ssid = doc["ssid"];
      const char* password = doc["password"];
      if (ssid == nullptr) {
        Serial.println("[BLE] SSID 없음");
        updateWifiStatus(WIFI_STATUS_FAILED);
        return;
      }

      pendingSsid = String(ssid);
      pendingPassword = password ? String(password) : "";
      wifiConnectRequested = true;
    }
  }
};

// ============================================================================
// BLE 초기화
// ============================================================================
void ble_init() {
  String deviceName = getDeviceName();
  Serial.printf("[BLE] 기기 이름: %s\n", deviceName.c_str());

  BLEDevice::init(deviceName.c_str());
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  // 서비스 생성
  BLEService* pService = pServer->createService(SERVICE_UUID);

  // WiFi Scan Characteristic (Write + Notify)
  pWifiScanChar = pService->createCharacteristic(
    CHAR_WIFI_SCAN_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY
  );
  pWifiScanChar->setCallbacks(new WifiScanCallbacks());
  pWifiScanChar->addDescriptor(new BLE2902());

  // WiFi Credential Characteristic (Write)
  pWifiCredChar = pService->createCharacteristic(
    CHAR_WIFI_CRED_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pWifiCredChar->setCallbacks(new WifiCredCallbacks());

  // WiFi Status Characteristic (Read + Notify)
  pWifiStatChar = pService->createCharacteristic(
    CHAR_WIFI_STAT_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pWifiStatChar->addDescriptor(new BLE2902());
  pWifiStatChar->setValue(&wifiStatus, 1);

  // 서비스 시작
  pService->start();

  // Advertising 시작
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] BLE GATT 서버 시작 완료, Advertising 중...");
}

// ============================================================================
// WiFi 스캔 수행 → 결과를 BLE Notify로 전송
// ============================================================================
void performWifiScan() {
  updateWifiStatus(WIFI_STATUS_SCANNING);
  Serial.println("[WiFi] 스캔 시작...");

  int numNetworks = WiFi.scanNetworks();
  Serial.printf("[WiFi] %d개 네트워크 발견\n", numNetworks);

  // JSON 배열로 결과 전송 (BLE MTU 제한으로 최대 10개)
  JsonDocument doc;
  JsonArray networks = doc.to<JsonArray>();

  int maxNetworks = min(numNetworks, 10);
  for (int i = 0; i < maxNetworks; i++) {
    JsonObject network = networks.add<JsonObject>();
    network["ssid"] = WiFi.SSID(i);
    network["rssi"] = WiFi.RSSI(i);
    network["auth"] = WiFi.encryptionType(i) != WIFI_AUTH_OPEN ? 1 : 0;
  }

  String jsonStr;
  serializeJson(doc, jsonStr);

  // BLE MTU가 작을 수 있으므로 청크로 전송
  // 첫 번째 패킷: 네트워크 수 + JSON
  if (deviceConnected && pWifiScanChar != nullptr) {
    // JSON 결과를 512바이트 이내로 전송
    if (jsonStr.length() <= 512) {
      pWifiScanChar->setValue(jsonStr.c_str());
      pWifiScanChar->notify();
    } else {
      // 너무 길면 잘라서 전송
      String truncated = jsonStr.substring(0, 510);
      pWifiScanChar->setValue(truncated.c_str());
      pWifiScanChar->notify();
    }
  }

  WiFi.scanDelete();
  updateWifiStatus(WIFI_STATUS_IDLE);
  Serial.printf("[WiFi] 스캔 결과 전송 완료: %s\n", jsonStr.c_str());
}

// ============================================================================
// WiFi 연결 수행
// ============================================================================
void performWifiConnect() {
  Serial.printf("[WiFi] 연결 시도: SSID=%s\n", pendingSsid.c_str());
  updateWifiStatus(WIFI_STATUS_CONNECTING);

  // 기존 연결 해제
  WiFi.disconnect(true);
  delay(500);

  WiFi.begin(pendingSsid.c_str(), pendingPassword.c_str());

  // 최대 15초 대기
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;

    // 중간 상태를 BLE로 알림
    if (attempts % 4 == 0 && deviceConnected) {
      updateWifiStatus(WIFI_STATUS_CONNECTING);
    }
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("[WiFi] 연결 성공! IP: %s\n", WiFi.localIP().toString().c_str());
    updateWifiStatus(WIFI_STATUS_CONNECTED);
    isConfigured = true;
  } else {
    Serial.println("[WiFi] 연결 실패");
    updateWifiStatus(WIFI_STATUS_FAILED);
  }

  pendingSsid = "";
  pendingPassword = "";
}

// ============================================================================
// BLE 연결 해제 후 재 Advertising
// ============================================================================
void ble_handle_reconnect() {
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("[BLE] 재 Advertising 시작");
    oldDeviceConnected = false;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = true;
  }
}

// ============================================================================
// 서버 하트비트 전송
// ============================================================================
void sendHeartbeat() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(SERVER_URL) + "/api/v1/devices/0/heartbeat";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Serial", DEVICE_UID);
  http.addHeader("X-Device-Key", DEVICE_KEY);

  int httpCode = http.POST("{}");
  if (httpCode == 204) {
    Serial.println("[HTTP] 하트비트 전송 성공");
  } else {
    Serial.printf("[HTTP] 하트비트 실패: %d\n", httpCode);
  }
  http.end();
}

// ============================================================================
// 센서 데이터 서버 전송
// ============================================================================
void sendMeasurement(float weight_g, float remaining_ml, float drop_rate, const char* status) {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(SERVER_URL) + "/api/v1/measurements";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Serial", DEVICE_UID);
  http.addHeader("X-Device-Key", DEVICE_KEY);

  JsonDocument doc;
  doc["weight_g"] = weight_g;
  doc["remaining_ml"] = remaining_ml;
  doc["drop_rate"] = drop_rate;
  doc["infusion_status"] = status;

  String jsonStr;
  serializeJson(doc, jsonStr);

  int httpCode = http.POST(jsonStr);
  if (httpCode == 201) {
    Serial.println("[HTTP] 측정 데이터 전송 성공");
  } else {
    Serial.printf("[HTTP] 측정 데이터 전송 실패: %d\n", httpCode);
  }
  http.end();
}

// ============================================================================
// 시리얼 입력 (IV 시뮬레이션 설정용)
// ============================================================================
float getSerialInput() {
  while (!Serial.available());
  float val = Serial.parseFloat();
  while (Serial.available()) { Serial.read(); }
  return val;
}

// ============================================================================
// IV 시뮬레이션 초기 설정
// ============================================================================
void iv_set() {
  Serial.println("================================");
  Serial.println("IV Simulation System Ready");

  Serial.print("초기 IV bag 무게 입력 (g): ");
  IV_bag_weight = getSerialInput();
  Serial.println(IV_bag_weight);

  Serial.print("IV bag 종료 무게 입력 (g): ");
  IV_finish_weight = getSerialInput();
  Serial.println(IV_finish_weight);

  Serial.print("gtt_min 입력: ");
  float gtt_min_input = getSerialInput();
  Serial.println(gtt_min_input);

  gtt_min = (gtt_min_input / 60.0) * 0.05;

  Serial.println("--- 시뮬레이션을 시작합니다 ---");
  is_running = true;
  last_loadcell_time = millis();
  last_creep_time = millis();
}

// ============================================================================
// 수액 시뮬레이션 (크리프, 노이즈 포함)
// ============================================================================
void iv_bag() {
  unsigned long current_time = millis();

  if (current_time - last_loadcell_time >= 1000) {
    last_loadcell_time = current_time;

    if (IV_bag_weight > IV_finish_weight) {
      float noise = random(-70, 71) / 1000.0;
      IV_bag_weight -= gtt_min;
      IV_bag_weight += noise;
      float practical_weight = IV_bag_weight + manual_offset;
      iv_predict(IV_bag_weight);
    } else {
      Serial.println("수액 투여 종료");
      is_running = false;
    }
  }

  // 30초 주기 크리프 현상
  if (current_time - last_creep_time >= 30000) {
    last_creep_time = current_time;
    float creep_noise = random(-60, 61) / 100.0;
    IV_bag_weight += creep_noise;
    Serial.println(">>> [EVENT] 30초 크리프 발생 <<<");
  }
}

// ============================================================================
// IV 오차 예측 알고리즘
// ============================================================================
void iv_predict(float current_weight) {
  if (is_first_run) {
    theory_weight = current_weight;
    is_first_run = false;
    Serial.println("[System] 알고리즘 추적 시작");
    return;
  }

  theory_weight -= gtt_min;
  float error = theory_weight - current_weight;

  Serial.print("Theory:"); Serial.print(theory_weight, 2);
  Serial.print(",");
  Serial.print("Raw:"); Serial.print(current_weight, 2);
  Serial.print(",");

  if (abs(error) > threshold) {
    Serial.print("Corrected:"); Serial.print(current_weight, 2);
    Serial.print(" [!!! ANOMALY DETECTED !!! Error: ");
    Serial.print(error);
    Serial.println("g]");
  } else {
    float corrected_weight = current_weight + error;
    Serial.print("Corrected:"); Serial.print(corrected_weight, 2);
    Serial.print(",Error:"); Serial.println(error, 4);
  }
}

// ============================================================================
// 시리얼 수동 오차 주입 (테스트용)
// ============================================================================
void checkManualInput() {
  if (Serial.available()) {
    char cmd = Serial.read();
    if (cmd == 'a') {
      manual_offset += 5.0;
      Serial.println("\n[EVENT] 비정상 오차 주입 (+5g)");
    } else if (cmd == 's') {
      manual_offset -= 5.0;
      Serial.println("\n[EVENT] 비정상 오차 주입 (-5g)");
    } else if (cmd == 'r') {
      manual_offset = 0;
      Serial.println("\n[EVENT] 상황 종료 (Normalizing)");
    }
  }
}

// ============================================================================
// setup()
// ============================================================================
void setup() {
  Serial.begin(115200);
  WiFi.mode(WIFI_STA);

  // DEVICE_UID를 MAC 주소 기반으로 생성
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  char uid[18];
  snprintf(uid, sizeof(uid), "%02X:%02X:%02X:%02X:%02X:%02X",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  DEVICE_UID = String(uid);
  Serial.printf("[System] Device UID: %s\n", DEVICE_UID.c_str());

  ble_init();
  delay(2000);
  randomSeed(analogRead(0));
  iv_set();
}

// ============================================================================
// loop()
// ============================================================================
void loop() {
  // 1. BLE 연결 관리
  ble_handle_reconnect();

  // 2. WiFi 스캔 요청 처리
  if (wifiScanRequested) {
    wifiScanRequested = false;
    performWifiScan();
  }

  // 3. WiFi 연결 요청 처리
  if (wifiConnectRequested) {
    wifiConnectRequested = false;
    performWifiConnect();
  }

  // 4. WiFi 상태 감시 (자동 재연결)
  static unsigned long lastWiFiCheck = 0;
  if (millis() - lastWiFiCheck > 5000) {
    lastWiFiCheck = millis();
    if (isConfigured && WiFi.status() != WL_CONNECTED) {
      Serial.println("[WiFi] 연결 끊김 감지! 재연결 시도...");
      WiFi.reconnect();
    }
  }

  // 5. IV 시뮬레이션 (WiFi 연결 시에만)
  if (is_running && WiFi.status() == WL_CONNECTED) {
    iv_bag();
    checkManualInput();

    // 6. 주기적 서버 데이터 전송 (5초마다)
    if (millis() - lastDataSend >= DATA_SEND_INTERVAL) {
      lastDataSend = millis();
      float remaining_ml = IV_bag_weight - IV_finish_weight;
      if (remaining_ml < 0) remaining_ml = 0;
      const char* infusionStatus = is_running ? "running" : "stopped";
      sendMeasurement(IV_bag_weight, remaining_ml, gtt_min * 60.0 / 0.05, infusionStatus);
    }
  }

  // 7. 하트비트 전송 (1분마다, WiFi 연결 시)
  if (WiFi.status() == WL_CONNECTED && millis() - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    lastHeartbeat = millis();
    sendHeartbeat();
  }
}
