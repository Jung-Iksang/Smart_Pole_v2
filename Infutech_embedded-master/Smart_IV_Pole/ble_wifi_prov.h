#pragma once
/*
 * BLE WiFi 프로비저닝 + IV 상태 — 커스텀 GATT 서버
 *
 * Flutter 앱(flutter_blue_plus 등)에서 직접 통신 가능한 BLE 서비스.
 * WiFiProv 라이브러리를 사용하지 않고 표준 BLE GATT 만 사용하므로
 * 어떤 BLE 라이브러리든 호환됨.
 *
 * ── BLE 프로토콜 ────────────────────────────────────────────────────
 *
 *  Service UUID : 4fafc201-1fb5-459e-8fcc-c5c9c331914b
 *
 *  1) WiFi 스캔 (Write/Notify)
 *     UUID : a3c87500-8ed3-4bdf-8a39-a01bebede295
 *     - Write 아무 1바이트  → 백그라운드 WiFi 스캔 시작
 *     - Notify             → JSON 배열 (20바이트 청크) + '\n' 끝 마커
 *
 *  2) WiFi 자격증명 (Write)
 *     UUID : a3c87501-8ed3-4bdf-8a39-a01bebede295
 *     - Write JSON : {"ssid":"<SSID>","pw":"<PASSWORD>"}
 *     - ESP32 가 논블로킹 연결 시도 + 성공 시 NVS 저장
 *
 *  3) 연결 상태 (Read/Notify)
 *     UUID : a3c87502-8ed3-4bdf-8a39-a01bebede295
 *     - Notify JSON : {"state":"idle|scanning|connecting|connected|failed", ...}
 *
 *  4) 커맨드 (Write) — v1.3+
 *     UUID : a3c87503-8ed3-4bdf-8a39-a01bebede295
 *     - Write JSON : {"cmd":"reset|status|tare"}
 *     - reset  → IV 상태 초기화 (PHASE_TARE)
 *     - status → IV 상태 notify 트리거
 *     - tare   → 수동 영점 조정
 *
 *  5) IV 상태 (Read/Notify) — v1.3+
 *     UUID : a3c87504-8ed3-4bdf-8a39-a01bebede295
 *     - Notify JSON : {"phase":"monitor","weight":123.4,"flow":0.003,
 *                      "fw":"1.3.0","heap":85000}
 *     - ivPhase 전환 시 + status 요청 시 자동 notify
 *
 * ── 동작 흐름 ────────────────────────────────────────────────────────
 *
 *   부팅 → NVS에 자격증명 있으면 논블로킹 자동 연결 시도
 *        → BLE GATT 서버 즉시 시작 (WiFi 연결과 병렬)
 *        → WiFi 미연결 시 앱에서 BLE로 설정
 *        → 연결 성공 시 NVS 저장
 */

#include <Arduino.h>
#include <WiFi.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "esp_gatt_common_api.h"   // esp_ble_gatt_set_local_mtu()

// ── UUID 정의 ─────────────────────────────────────────────────────
#define BLEPROV_SERVICE_UUID       "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define BLEPROV_CHAR_SCAN_UUID     "a3c87500-8ed3-4bdf-8a39-a01bebede295"
#define BLEPROV_CHAR_CRED_UUID     "a3c87501-8ed3-4bdf-8a39-a01bebede295"
#define BLEPROV_CHAR_STATUS_UUID   "a3c87502-8ed3-4bdf-8a39-a01bebede295"
#define BLEPROV_CHAR_CMD_UUID      "a3c87503-8ed3-4bdf-8a39-a01bebede295"
#define BLEPROV_CHAR_IVSTAT_UUID   "a3c87504-8ed3-4bdf-8a39-a01bebede295"

// ── NVS 네임스페이스 ──────────────────────────────────────────────
#define BLEPROV_NVS_NAMESPACE  "ble_wifi"

// ── WiFi 연결 타임아웃 ────────────────────────────────────────────
#define WIFI_CONNECT_TIMEOUT_MS  15000

// ── 커맨드 플래그 (외부에서 처리) ─────────────────────────────────
// Smart_IV_Pole.ino 의 loop() 에서 이 플래그를 확인하고 처리
struct BleCommand {
  bool resetPending  = false;
  bool statusPending = false;
  bool tarePending   = false;
};

class BLEWiFiProv {
  // 콜백 클래스가 private 멤버 접근 가능하도록
  friend class ScanCallbacks;
  friend class CredCallbacks;
  friend class CmdCallbacks;

public:
  enum State {
    IDLE,        // 대기 상태
    SCANNING,    // WiFi 스캔 중
    CONNECTING,  // WiFi 연결 시도 중
    CONNECTED,   // WiFi 연결 완료
    FAILED       // 연결 실패
  };

  // 외부에서 접근 가능한 커맨드 플래그
  BleCommand command;

  // 초기화 — BLE GATT 서버 시작, 광고 시작
  // deviceName : BLE 광고에 사용할 이름 (예: "IVPOLE_AABBCC")
  void begin(const char *deviceName) {
    strncpy(_deviceName, deviceName, sizeof(_deviceName) - 1);
    _state = IDLE;
    _scanJson[0] = '\0';

    Serial.printf("[BLEProv] BLE 초기화 중... 기기명: %s\n", _deviceName);
    BLEDevice::init(_deviceName);

    // ★ MTU 늘리기 — Bluedroid 는 BLEDevice::setMTU 만으로는 부족.
    BLEDevice::setMTU(517);
    esp_err_t mtuRet = esp_ble_gatt_set_local_mtu(517);
    Serial.printf("[BLEProv] esp_ble_gatt_set_local_mtu(517) = %d\n", mtuRet);

    // GATT 서버 생성
    BLEServer *server = BLEDevice::createServer();
    server->setCallbacks(new ServerCallbacks(this));

    BLEService *service = server->createService(
      BLEUUID(BLEPROV_SERVICE_UUID), 20  // 핸들 수 늘림 (5개 특성)
    );

    // 1) Scan characteristic — Write(스캔 트리거) + Notify(청크 push)
    _charScan = service->createCharacteristic(
      BLEPROV_CHAR_SCAN_UUID,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY
    );
    _charScan->addDescriptor(new BLE2902());
    _charScan->setCallbacks(new ScanCallbacks(this));

    // 2) Credentials characteristic
    _charCred = service->createCharacteristic(
      BLEPROV_CHAR_CRED_UUID,
      BLECharacteristic::PROPERTY_WRITE
    );
    _charCred->setCallbacks(new CredCallbacks(this));

    // 3) WiFi Status characteristic (Read/Notify)
    _charStatus = service->createCharacteristic(
      BLEPROV_CHAR_STATUS_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    _charStatus->addDescriptor(new BLE2902());
    updateStatusValue();

    // 4) Command characteristic (Write) — 앱→ESP32 제어
    _charCmd = service->createCharacteristic(
      BLEPROV_CHAR_CMD_UUID,
      BLECharacteristic::PROPERTY_WRITE
    );
    _charCmd->setCallbacks(new CmdCallbacks(this));

    // 5) IV Status characteristic (Read/Notify) — ESP32→앱 상태
    _charIvStatus = service->createCharacteristic(
      BLEPROV_CHAR_IVSTAT_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    _charIvStatus->addDescriptor(new BLE2902());

    service->start();

    // ── 광고 패킷 구성 ──────────────────────────────────────────
    BLEAdvertising *adv = BLEDevice::getAdvertising();

    BLEAdvertisementData advData;
    advData.setFlags(0x06);   // LE General Discoverable + BR/EDR Not Supported
    advData.setName(_deviceName);
    advData.setCompleteServices(BLEUUID(BLEPROV_SERVICE_UUID));
    adv->setAdvertisementData(advData);

    BLEAdvertisementData scanRsp;
    scanRsp.setName(_deviceName);
    adv->setScanResponseData(scanRsp);

    adv->setScanResponse(true);

    // 광고 인터벌: 100ms ~ 150ms (전력 vs 발견 속도 균형)
    adv->setMinInterval(0xA0);   // 160 * 0.625 = 100ms
    adv->setMaxInterval(0xF0);   // 240 * 0.625 = 150ms

    BLEDevice::startAdvertising();

    Serial.printf("[BLEProv] BLE 광고 시작 (인터벌 100~150ms)\n");
    Serial.printf("[BLEProv] 광고 이름: %s\n", _deviceName);
    Serial.println("[BLEProv] ※ 안드로이드: 위치 서비스 ON + 앱 위치권한 허용 필요");
  }

  // loop() 에서 주기적으로 호출 — 모든 비동기 작업 처리
  void loop() {
    // ── 비동기 WiFi 스캔 완료 체크 ─────────────────────────────
    if (_scanInProgress) {
      int16_t n = WiFi.scanComplete();
      if (n >= 0) {
        buildScanJson(n);
        WiFi.scanDelete();
        _scanInProgress = false;
        setState(IDLE);

        size_t total = strlen(_scanJson);
        Serial.printf("[BLEProv] WiFi 스캔 완료: %d개, JSON %u bytes (free heap: %u) — 청크 전송\n",
                      n, (unsigned)total, ESP.getFreeHeap());
        if (n == 0) {
          Serial.println("[BLEProv] ⚠️ 0개 스캔 — 메모리 부족 또는 BLE 간섭 의심.");
          Serial.printf( "[BLEProv]   free heap: %u\n", ESP.getFreeHeap());
        }

        // 청크 분할 notify — MTU 협상 무관하게 안정적 전송
        const size_t CHUNK = 20;
        size_t chunkCount = 0;
        for (size_t i = 0; i < total; i += CHUNK) {
          size_t len = (i + CHUNK < total) ? CHUNK : (total - i);
          _charScan->setValue((uint8_t*)(_scanJson + i), len);
          _charScan->notify();
          chunkCount++;
          delay(50);
        }
        // 끝 마커: 단일 '\n' (0x0A) 1바이트
        delay(50);
        _charScan->setValue((uint8_t*)"\n", 1);
        _charScan->notify();
        Serial.printf("[BLEProv] 청크 전송 완료 (%u 청크, 총 %u bytes)\n",
                      (unsigned)chunkCount, (unsigned)total);
      }
    }

    // ── 자격증명 받았으면 논블로킹 연결 시작 ───────────────────
    if (_credPending) {
      _credPending = false;
      startConnect();
    }

    // ── 논블로킹 WiFi 연결 진행 중 체크 ───────────────────────
    if (_connectInProgress) {
      checkConnectProgress();
    }
  }

  // 저장된 자격증명으로 논블로킹 연결 시작 (부팅 시 호출)
  // WiFi.begin()만 호출하고 즉시 리턴. loop()에서 결과 확인.
  // 저장된 자격증명이 없으면 false 반환.
  bool startStoredCredentials() {
    Preferences prefs;
    if (!prefs.begin(BLEPROV_NVS_NAMESPACE, true)) return false;

    String ssid = prefs.getString("ssid", "");
    String pw   = prefs.getString("pw",   "");
    prefs.end();

    if (ssid.length() == 0) {
      Serial.println("[BLEProv] 저장된 자격증명 없음.");
      return false;
    }

    Serial.printf("[BLEProv] 저장된 자격증명으로 연결 시작 (논블로킹): %s\n", ssid.c_str());
    _pendingSsid = ssid;
    _pendingPw   = pw;
    _isStoredCred = true;

    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid.c_str(), pw.c_str());

    _connectInProgress = true;
    _connectStartMs    = millis();
    setState(CONNECTING);
    return true;
  }

  // WiFi 연결이 진행 중인지 확인
  bool isConnecting() const { return _connectInProgress; }

  // 저장된 자격증명 삭제 (재프로비저닝 강제)
  void clearStoredCredentials() {
    Preferences prefs;
    if (prefs.begin(BLEPROV_NVS_NAMESPACE, false)) {
      prefs.clear();
      prefs.end();
      Serial.println("[BLEProv] 저장된 자격증명 삭제.");
    }
  }

  State getState() const { return _state; }

  // ── IV 상태 notify (외부에서 호출) ──────────────────────────
  // ivPhase 전환 시 + status 요청 시 호출
  void notifyIvStatus(const char *phase, float weight, float flowRate,
                      const char *fwVersion) {
    if (!_charIvStatus) return;

    StaticJsonDocument<256> doc;
    doc["phase"]  = phase;
    doc["weight"] = round(weight * 100) / 100.0;
    doc["flow"]   = round(flowRate * 10000) / 10000.0;
    doc["fw"]     = fwVersion;
    doc["heap"]   = ESP.getFreeHeap();

    char buf[256];
    size_t n = serializeJson(doc, buf);
    _charIvStatus->setValue((uint8_t*)buf, n);
    _charIvStatus->notify();
  }

private:
  char _deviceName[24];
  State _state = IDLE;

  BLECharacteristic *_charScan     = nullptr;
  BLECharacteristic *_charCred     = nullptr;
  BLECharacteristic *_charStatus   = nullptr;
  BLECharacteristic *_charCmd      = nullptr;
  BLECharacteristic *_charIvStatus = nullptr;

  bool _scanInProgress    = false;
  bool _credPending       = false;
  bool _connectInProgress = false;
  bool _isStoredCred      = false;
  unsigned long _connectStartMs = 0;
  String _pendingSsid;
  String _pendingPw;

  char _scanJson[2048];   // WiFi 목록 JSON 버퍼

  // ── 상태 변경 + Notify ──────────────────────────────────────────
  void setState(State newState) {
    _state = newState;
    updateStatusValue();
    if (_charStatus) _charStatus->notify();
  }

  void updateStatusValue() {
    StaticJsonDocument<256> doc;
    const char *stateStr[] = { "idle","scanning","connecting","connected","failed" };
    doc["state"]    = stateStr[_state];
    doc["ssid"]     = (WiFi.status() == WL_CONNECTED) ? WiFi.SSID() : String("");
    doc["ip"]       = (WiFi.status() == WL_CONNECTED) ? WiFi.localIP().toString() : String("");
    doc["deviceId"] = _deviceName;
    char buf[256];
    size_t n = serializeJson(doc, buf);
    if (_charStatus) _charStatus->setValue((uint8_t*)buf, n);
  }

  // ── WiFi 스캔 시작 ──────────────────────────────────────────────
  void startScan() {
    if (_scanInProgress) return;
    setState(SCANNING);
    WiFi.mode(WIFI_STA);
    WiFi.scanNetworks(true, false);   // 비동기, hidden 제외
    _scanInProgress = true;
    Serial.printf("[BLEProv] WiFi 스캔 시작... (free heap: %u)\n", ESP.getFreeHeap());
  }

  // 스캔 결과를 JSON으로 변환
  void buildScanJson(int16_t n) {
    StaticJsonDocument<2048> doc;
    JsonArray arr = doc.to<JsonArray>();
    int added = 0;
    for (int i = 0; i < n && added < 15; i++) {
      String ssid = WiFi.SSID(i);
      if (ssid.length() == 0) continue;
      if (ssid.length() > 32) ssid = ssid.substring(0, 32);
      JsonObject o = arr.createNestedObject();
      o["ssid"] = ssid;
      o["rssi"] = WiFi.RSSI(i);
      o["enc"]  = (int)WiFi.encryptionType(i);
      added++;
    }
    size_t n_written = serializeJson(doc, _scanJson, sizeof(_scanJson));
    if (n_written == 0 || n_written >= sizeof(_scanJson) - 1) {
      strcpy(_scanJson, "[]");
      Serial.println("[BLEProv] ⚠️ JSON 직렬화 실패 — 빈 배열로 응답");
    }
  }

  // ── 논블로킹 WiFi 연결 시작 ────────────────────────────────────
  void startConnect() {
    if (_pendingSsid.length() == 0) return;
    Serial.printf("[BLEProv] WiFi 연결 시작 (논블로킹): %s\n", _pendingSsid.c_str());
    setState(CONNECTING);
    _isStoredCred = false;

    WiFi.mode(WIFI_STA);
    WiFi.begin(_pendingSsid.c_str(), _pendingPw.c_str());

    _connectInProgress = true;
    _connectStartMs    = millis();
  }

  // ── 논블로킹 WiFi 연결 진행 체크 ──────────────────────────────
  void checkConnectProgress() {
    if (WiFi.status() == WL_CONNECTED) {
      _connectInProgress = false;
      Serial.printf("[BLEProv] 연결 성공. IP: %s\n", WiFi.localIP().toString().c_str());

      // NVS 저장 (이미 저장된 자격증명이면 다시 저장할 필요 없음)
      if (!_isStoredCred) {
        Preferences prefs;
        if (prefs.begin(BLEPROV_NVS_NAMESPACE, false)) {
          prefs.putString("ssid", _pendingSsid);
          prefs.putString("pw",   _pendingPw);
          prefs.end();
          Serial.println("[BLEProv] 자격증명 NVS 저장 완료.");
        }
      }
      setState(CONNECTED);
      return;
    }

    // 타임아웃 체크
    if (millis() - _connectStartMs >= WIFI_CONNECT_TIMEOUT_MS) {
      _connectInProgress = false;
      Serial.println("[BLEProv] 연결 실패 (타임아웃).");
      WiFi.disconnect();
      setState(FAILED);
    }
  }

  // ── BLE 콜백 클래스들 ──────────────────────────────────────────
  class ServerCallbacks : public BLEServerCallbacks {
  public:
    ServerCallbacks(BLEWiFiProv *p) : _p(p) {}
    void onConnect(BLEServer *server) override {
      Serial.println("[BLEProv] 앱 연결됨.");
    }
    void onDisconnect(BLEServer *server) override {
      Serial.println("[BLEProv] 앱 연결 해제 — 광고 재시작.");
      BLEDevice::startAdvertising();
    }
  private:
    BLEWiFiProv *_p;
  };

  class ScanCallbacks : public BLECharacteristicCallbacks {
  public:
    ScanCallbacks(BLEWiFiProv *p) : _p(p) {}
    void onWrite(BLECharacteristic *c) override {
      Serial.println("[BLEProv] WiFi 스캔 요청 수신 (write)");
      _p->startScan();
    }
  private:
    BLEWiFiProv *_p;
  };

  class CredCallbacks : public BLECharacteristicCallbacks {
  public:
    CredCallbacks(BLEWiFiProv *p) : _p(p) {}
    void onWrite(BLECharacteristic *c) override {
      String val = c->getValue().c_str();
      Serial.printf("[BLEProv] 자격증명 수신: %s\n", val.c_str());

      StaticJsonDocument<256> doc;
      if (deserializeJson(doc, val)) {
        Serial.println("[BLEProv] JSON 파싱 실패.");
        return;
      }
      _p->_pendingSsid = doc["ssid"].as<String>();
      _p->_pendingPw   = doc["pw"].as<String>();
      _p->_credPending = true;
    }
  private:
    BLEWiFiProv *_p;
  };

  // 커맨드 콜백 — 앱에서 reset/status/tare 요청
  class CmdCallbacks : public BLECharacteristicCallbacks {
  public:
    CmdCallbacks(BLEWiFiProv *p) : _p(p) {}
    void onWrite(BLECharacteristic *c) override {
      String val = c->getValue().c_str();
      Serial.printf("[BLEProv] 커맨드 수신: %s\n", val.c_str());

      StaticJsonDocument<128> doc;
      if (deserializeJson(doc, val)) {
        Serial.println("[BLEProv] 커맨드 JSON 파싱 실패.");
        return;
      }

      const char *cmd = doc["cmd"] | "";
      if (strcmp(cmd, "reset") == 0) {
        _p->command.resetPending = true;
        Serial.println("[BLEProv] → reset 커맨드 대기열 추가");
      } else if (strcmp(cmd, "status") == 0) {
        _p->command.statusPending = true;
        Serial.println("[BLEProv] → status 커맨드 대기열 추가");
      } else if (strcmp(cmd, "tare") == 0) {
        _p->command.tarePending = true;
        Serial.println("[BLEProv] → tare 커맨드 대기열 추가");
      } else {
        Serial.printf("[BLEProv] 알 수 없는 커맨드: %s\n", cmd);
      }
    }
  private:
    BLEWiFiProv *_p;
  };
};
