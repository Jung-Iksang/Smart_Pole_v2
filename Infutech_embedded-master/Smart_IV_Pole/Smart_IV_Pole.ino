
#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <LittleFS.h>
#include "esp_system.h"
#include "esp_task_wdt.h"    // 하드웨어 워치독
#include "ads1232.h"
#include "cnn_detector.h"
#include "ble_wifi_prov.h"   // 커스텀 BLE WiFi 프로비저닝 (Flutter 앱용)

// ── 펌웨어 버전 ───────────────────────────────────────────────────
#define FW_VERSION  "1.3.0"

// ── 워치독 타임아웃 ──────────────────────────────────────────────
#define WDT_TIMEOUT_SEC  30

// ╔══════════════════════════════════════════════════════════════════╗
// ║  테스트 설정 — 여기만 바꾸면 됨                                    ║
// ╚══════════════════════════════════════════════════════════════════╝
#define SERVER_URL        "http://192.168.0.19:8000"   // FastAPI 서버 주소
#define HTTP_SEND_MS      5000    // 서버 데이터 전송 주기 (ms)
#define HEARTBEAT_MS      60000   // 하트비트 주기 (ms)

// ── 이미지 로그 파일 경로 ─────────────────────────────────────────
#define IMAGE_LOG_PATH  "/imglog.csv"

// ── 핀 정의 ──────────────────────────────────────────────────────
#define ADS_DOUT  19
#define ADS_SCLK  18
#define ADS_PDWN  23
#define ADS_GAIN0 33
#define ADS_GAIN1 32

// (MQTT 제거됨 — HTTP REST API 사용)

// ── 타이밍 설정 ───────────────────────────────────────────────────
#define WEIGHT_MS         2000     // 무게 측정 주기 (2초)
#define BOOT_DELAY_MS     500UL    // 전원 ON 후 영점까지 대기 (tare(20)이 자체 안정화)

// ── 드립 팩터 교정 ─────────────────────────────────────────────────
#define CALIB_DURATION_MS  60000UL   // 교정 측정 시간 (60초)

// ── 수액 자동 감지 임계값 ─────────────────────────────────────────
#define WEIGHT_HANG_G    100.0f   // 수액 감지: 이 이상이면 수액 걸린 것으로 판단
#define WEIGHT_REMOVE_G  80.0f   // 수액 제거: 이 미만이면 수액 없는 것으로 판단

// ── 수액 안정화 (흔들림 잡기) ────────────────────────────────────
#define STABILIZE_WINDOW    5       // 안정화 판정에 사용할 최근 측정 샘플 수
#define STABILIZE_RANGE_G   0.5f    // 윈도우 내 최대-최소 < 이 값이면 안정 판정
#define STABILIZE_TIMEOUT_MS  30000UL  // 30초 안에 안정 안 되면 강제 교정 진입

// ── 기본 목표 유속 ────────────────────────────────────────────────
// 앱에서 변경 전까지 사용하는 기본값 (성인용 20gtt/mL 세트)
#define DEFAULT_TARGET_GTT  60.0f   // gtt/min

// ── 로드셀 교정 계수 ─────────────────────────────────────────────
#define CALIB_FACTOR_DEFAULT  1642.8623f

// ── 드립 팩터 기본값 (교정 실패 시 백업) ─────────────────────────
#define DRIP_FACTOR_DEFAULT  0.0500f

// ── EMA 안정화 샘플 수 ────────────────────────────────────────────
#define WARMUP_SAMPLES  8

// =================================================================
// 기기 고유 ID — MAC 주소 뒤 4자리 기반 ("INFUCARE_XXYY")
// QR 코드 라벨에 인쇄 → 앱이 스캔하여 백엔드에서 기기 특정
// =================================================================
char deviceId[20];     // "INFUCARE_XXYY"
char bleName[24];      // BLE 검색명 = deviceId (기기마다 다름)

// ── HTTP 전송 타이밍 ──────────────────────────────────────────────
unsigned long lastHttpSendMs  = 0;
unsigned long lastHeartbeatMs = 0;

// ── WiFi 재연결 지수 백오프 ──────────────────────────────────────
unsigned long lastReconnectMs    = 0;
unsigned long reconnectBackoffMs = 2000;   // 시작 2초, 최대 60초

// =================================================================
// 부팅 절차 단계 정의
// =================================================================
enum IVPhase {
  PHASE_BOOT,        // 전원 ON — 2초 대기 중
  PHASE_TARE,        // 자동 영점 조정 중
  PHASE_WAIT,        // 수액 감지 대기
  PHASE_STABILIZE,   // 수액 흔들림 잡힐 때까지 대기 (교정 직전)
  PHASE_CALIB,       // 드립 팩터 교정 중 (60초)
  PHASE_WARMUP,      // EMA 안정화 대기 (8샘플)
  PHASE_MONITOR,     // 주입 모니터링 중
  PHASE_DONE         // 주입 완료
};

// ─────────────────────────────────────────────────────────────────
// 전역 객체
// ─────────────────────────────────────────────────────────────────
ADS1232      loadCell(ADS_DOUT, ADS_SCLK, ADS_PDWN, ADS_GAIN0, ADS_GAIN1);
CNNDetector  detector;
BLEWiFiProv  bleProv;   // BLE 기반 WiFi 프로비저닝 (Flutter 앱)

// ─────────────────────────────────────────────────────────────────
// IV 상태 구조체
// ─────────────────────────────────────────────────────────────────
struct IVState {
  float targetFlowRate  = 0;
  float finishWeight    = 0;
  float currentWeight   = 0;
  float prevWeight      = 0;
  float currentFlowRate = 0;
  float dripFactor      = DRIP_FACTOR_DEFAULT;
  bool  started         = false;
  bool  complete        = false;
  int   warmup          = 0;
} iv;

// ─────────────────────────────────────────────────────────────────
// 부팅 절차 상태 변수
// ─────────────────────────────────────────────────────────────────
IVPhase       ivPhase          = PHASE_BOOT;
float         calibTargetGtt   = DEFAULT_TARGET_GTT;
float         calibWeightStart = 0;
unsigned long calibStartMs     = 0;
unsigned long bootMs           = 0;

// 안정화 단계 — 최근 N개 측정값의 변동 추적
float         stabilizeBuf[STABILIZE_WINDOW] = {0};
int           stabilizeIdx     = 0;
int           stabilizeCount   = 0;
unsigned long stabilizeStartMs = 0;

// ─────────────────────────────────────────────────────────────────
// 타이밍 변수
// ─────────────────────────────────────────────────────────────────
unsigned long lastWeightMs = 0;
unsigned long lastStatusMs = 0;

// ── 학습 데이터 CSV 로깅 ──────────────────────────────────────────
// 'log <label>' 시 모니터링 중 매 측정마다 라벨 포함 CSV 행을 출력.
// 실험자가 물리적으로 상황을 만들고(예: 클램프 조여 느리게) 라벨을 지정 →
// 그 구간 데이터에 자동으로 라벨이 찍힘 (ground-truth, 수동 편집 불필요).
//   log normal / log slow / log fast  → 로깅 ON + 해당 라벨
//   log off                            → 로깅 OFF
// 빈 문자열이면 로깅 OFF.
char csvLabel[8] = "";

// =================================================================
// IV Phase → 문자열 변환 (BLE notify + 시리얼 공용)
// =================================================================
const char* ivPhaseStr(IVPhase phase) {
  static const char *names[] = {
    "boot","tare","wait","stabilize","calib","warmup","monitor","done"
  };
  return (phase >= 0 && phase <= PHASE_DONE) ? names[phase] : "unknown";
}

// IV Phase 전환 시 BLE notify 전송
void notifyPhaseChange() {
  bleProv.notifyIvStatus(
    ivPhaseStr(ivPhase), iv.currentWeight, iv.currentFlowRate, FW_VERSION
  );
}

// BLE 커맨드 처리 (loop에서 호출)
void handleBleCommands() {
  if (bleProv.command.resetPending) {
    bleProv.command.resetPending = false;
    Serial.println("[BLE CMD] reset — IV 상태 초기화");
    iv = IVState{};
    ivPhase = PHASE_TARE;
    detector.reset();
    notifyPhaseChange();
  }

  if (bleProv.command.tarePending) {
    bleProv.command.tarePending = false;
    Serial.println("[BLE CMD] tare — 수동 영점 조정");
    loadCell.tare(20);
    Serial.println("[BLE CMD] 영점 완료.");
    notifyPhaseChange();
  }

  if (bleProv.command.statusPending) {
    bleProv.command.statusPending = false;
    Serial.println("[BLE CMD] status — IV 상태 전송");
    notifyPhaseChange();
  }
}

// =================================================================
// 기기 ID 생성 — ESP32 칩 고유 MAC으로 식별
// =================================================================
void buildDeviceId() {
  // 테스트 기기 1대 — QR 코드와 동일한 이름 고정
  // QR: {"name":"INFUCARE_A1B2","pop":"infucare123"}
  snprintf(deviceId, sizeof(deviceId), "INFUCARE_A1B2");
  snprintf(bleName,  sizeof(bleName),  "%s", deviceId);
}

// (MQTT 토픽 빌드 제거됨)

// ─────────────────────────────────────────────────────────────────
// HTTP REST API 전송 함수
// ─────────────────────────────────────────────────────────────────

// 센서 측정 데이터 전송 → POST /api/v1/measurements
void httpSendMeasurement() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(SERVER_URL) + "/api/v1/measurements";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Serial", deviceId);
  http.addHeader("X-Device-Key", "");

  StaticJsonDocument<256> doc;
  doc["weight_g"]        = round(iv.currentWeight * 100) / 100.0;
  doc["remaining_ml"]    = round(iv.currentWeight * 100) / 100.0;  // 무게 ≈ 잔량(ml)
  doc["drop_rate"]       = round(iv.currentFlowRate * 10000) / 10000.0;
  doc["infusion_status"] = (ivPhase == PHASE_MONITOR) ? "running"
                         : (ivPhase == PHASE_DONE)    ? "completed"
                                                      : "stopped";
  char buf[256];
  serializeJson(doc, buf);

  int code = http.POST(buf);
  if (code == 201) {
    Serial.println("[HTTP] 측정 데이터 전송 OK");
  } else {
    Serial.printf("[HTTP] 측정 전송 실패: %d\n", code);
  }
  http.end();
}

// 하트비트 전송 → POST /api/v1/devices/{id}/heartbeat
void httpSendHeartbeat() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(SERVER_URL) + "/api/v1/devices/0/heartbeat";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Serial", deviceId);
  http.addHeader("X-Device-Key", "");

  int code = http.POST("{}");
  if (code == 204) {
    Serial.println("[HTTP] 하트비트 OK");
  } else {
    Serial.printf("[HTTP] 하트비트 실패: %d\n", code);
  }
  http.end();
}

// 이상 감지 알림 (시리얼 출력 + 서버 전송)
void publishAlert(float measuredFlowRate) {
  Serial.printf("[ALERT] ⚠️ 수액 이상 발생  신뢰도:%.0f%%\n",
                detector.getWindowConfidence() * 100.0f);
  // 다음 주기적 전송에서 서버에 반영됨
}

// ─────────────────────────────────────────────────────────────────
// CNN 이미지 시각화 & LittleFS 로그
// ─────────────────────────────────────────────────────────────────
void printImage() {
  int img[CNN_DIM][CNN_DIM];
  detector.getImage(img);
  Serial.println("[CNN] ┌────┐");
  for (int r = 0; r < CNN_DIM; r++) {
    Serial.print("      │");
    for (int c = 0; c < CNN_DIM; c++) {
      if      (img[r][c] == FLOW_FAST) Serial.print('+');
      else if (img[r][c] == FLOW_SLOW) Serial.print('-');
      else                             Serial.print('.');
    }
    Serial.println("│");
  }
  Serial.println("      └────┘");
  Serial.printf("  + 빠름  · 정상  - 느림   score:%.3f\n",
                detector.getWindowConfidence());
}

void saveImageToLog() {
  int img[CNN_DIM][CNN_DIM];
  detector.getImage(img);
  File f = LittleFS.open(IMAGE_LOG_PATH, "a");
  if (!f) { Serial.println("[LOG] 파일 열기 실패"); return; }
  f.printf("=== %lu ms | %s | 신뢰도:%.0f%% ===\n",
           millis(), detector.getResultLabel(),
           detector.getWindowConfidence() * 100.0f);
  for (int r = 0; r < CNN_DIM; r++) {
    f.print("|");
    for (int c = 0; c < CNN_DIM; c++) {
      if      (img[r][c] == FLOW_FAST) f.print('+');
      else if (img[r][c] == FLOW_SLOW) f.print('-');
      else                             f.print('.');
    }
    f.println("|");
  }
  f.println();
  f.close();
  Serial.println("[LOG] 이미지 저장됨");
}

void dumpImageLog() {
  File f = LittleFS.open(IMAGE_LOG_PATH, "r");
  if (!f) { Serial.println("[LOG] 저장된 로그 없음"); return; }
  Serial.println("[LOG] ── imglog.csv 시작 ──────────────");
  while (f.available()) Serial.write(f.read());
  f.close();
  Serial.println("[LOG] ── 끝 ────────────────────────────");
}

void clearImageLog() {
  LittleFS.remove(IMAGE_LOG_PATH);
  Serial.println("[LOG] 로그 삭제됨");
}

// ─────────────────────────────────────────────────────────────────
// 시리얼 디버그 명령 (엔지니어용, 실무 사용 불필요)
// ─────────────────────────────────────────────────────────────────
void handleSerial() {
  if (!Serial.available()) return;
  String line = Serial.readStringUntil('\n');
  line.trim();
  if (line.length() == 0) return;

  // ── gtt / target : 목표 유속 (gtt/min) 설정 ────────────────────
  // 동의어: "target 60" == "gtt 60"
  if (line.startsWith("target ") || line.startsWith("gtt ")) {
    int p = line.indexOf(' ');
    float v = line.substring(p + 1).toFloat();
    if (v <= 0 || v > 300) {
      Serial.println("[DBG] gtt 범위 오류 (1~300). 예) gtt 60");
    } else {
      calibTargetGtt = v;
      Serial.printf("[DBG] ✓ 목표 유속 설정: %.0f gtt/min\n", calibTargetGtt);
      switch (ivPhase) {
        case PHASE_MONITOR:
        case PHASE_WARMUP:
          iv.targetFlowRate = (calibTargetGtt / 60.0f) * iv.dripFactor;
          detector.reset();
          Serial.printf("[DBG]   → 즉시 반영: %.4f g/s (dripFactor 유지)\n",
                        iv.targetFlowRate);
          Serial.println("[DBG]   ※ 정확한 측정 위해 'reset' 후 재교정 권장");
          break;
        case PHASE_CALIB:
          Serial.println("[DBG]   → 현재 진행 중인 교정에 적용됨");
          break;
        case PHASE_STABILIZE:
        case PHASE_WAIT:
          Serial.println("[DBG]   → 곧 시작될 교정에 적용됨");
          break;
        default:
          Serial.println("[DBG]   → 다음 교정 시작 시 적용됨");
          break;
      }
    }
  } else if (line.startsWith("finish ")) {
    iv.finishWeight = line.substring(7).toFloat();
    Serial.printf("[DBG] 종료 무게: %.2f g\n", iv.finishWeight);
  } else if (line == "tare") {
    loadCell.tare(20);
    Serial.println("[DBG] 영점 완료.");
  } else if (line == "reset") {
    iv = IVState{};  ivPhase = PHASE_TARE;  detector.reset();
    Serial.println("[DBG] 초기화 → 재영점.");
  } else if (line == "wifireset") {
    // 저장된 WiFi 자격증명 삭제 → 재부팅 후 BLE 프로비저닝 모드 진입
    Serial.println("[DBG] WiFi 자격증명 삭제 후 재부팅...");
    bleProv.clearStoredCredentials();
    WiFi.disconnect(true, true);
    delay(500);
    ESP.restart();
  } else if (line == "status") {
    const char *ph[] = { "부팅대기","영점조정","수액대기","흔들림안정화",
                         "드립팩터교정","EMA안정화","모니터링","완료" };
    Serial.printf("[STATUS] 단계:%s  W:%.2fg\n"
                  "         목표:%.0f gtt/min (%.4f g/s)  현재유속:%.4f g/s\n"
                  "         dripFactor:%.5f g/gtt  종료무게:%.1fg\n"
                  "         결과:%s  신뢰도:%.0f%%  CNN:%s  샘플:%d/%d\n",
                  ph[ivPhase], iv.currentWeight,
                  calibTargetGtt, iv.targetFlowRate, iv.currentFlowRate,
                  iv.dripFactor, iv.finishWeight,
                  detector.getResultLabel(),
                  detector.getWindowConfidence() * 100.0f,
                  detector.isTFLiteActive() ? "ON" : "fallback",
                  detector.getSampleCount(), CNN_WIN);
  } else if (line.startsWith("tolerance ")) {
    float t = line.substring(10).toFloat();
    if (t > 0 && t < 1.0f) { detector.setTolerance(t); Serial.printf("[DBG] tolerance=±%.0f%%\n", t*100); }
  } else if (line.startsWith("alpha ")) {
    float a = constrain(line.substring(6).toFloat(), 0.05f, 0.5f);
    loadCell.setEmaAlpha(a);  Serial.printf("[DBG] EMA alpha=%.2f\n", a);
  } else if (line == "log off") {
    csvLabel[0] = '\0';
    Serial.println("[DBG] CSV 로깅 OFF");
  } else if (line.startsWith("log ")) {
    String lab = line.substring(4);
    lab.trim();
    if (lab == "normal" || lab == "slow" || lab == "fast") {
      snprintf(csvLabel, sizeof(csvLabel), "%s", lab.c_str());
      Serial.printf("LOG_HEADER,ms,flow_gs,target_gs,state,label\n");
      Serial.printf("[DBG] CSV 로깅 ON — 라벨:'%s'. 'LOG,' 줄을 캡처하세요.\n", csvLabel);
      Serial.println("[DBG]   상황 바뀌면 log normal/slow/fast 로 라벨 변경, log off 로 종료.");
    } else {
      Serial.println("[DBG] 사용법: log normal | log slow | log fast | log off");
    }
  } else if (line == "cnn") {
    detector.printDebugInfo();
  } else if (line == "cnntest") {
    detector.runSelfTest();
  } else if (line == "cnnverbose" || line == "cnnv") {
    detector.setVerbose(!detector.getVerbose());
    Serial.printf("[DBG] CNN verbose %s\n",
                  detector.getVerbose() ? "ON (매 추론 상세 출력)" : "OFF");
  } else if (line == "image")   { printImage();   }
  else if (line == "dumplog")   { dumpImageLog(); }
  else if (line == "clearlog")  { clearImageLog();}
  else if (line == "help" || line == "?") {
    Serial.println("──── 엔지니어 시리얼 명령어 ────");
    Serial.println("  gtt <n>       목표 유속(gtt/min) 설정.   예) gtt 60");
    Serial.println("  target <n>    gtt 와 동일 (alias)");
    Serial.println("  finish <g>    주입 종료 무게 설정");
    Serial.println("  tare          영점 조정");
    Serial.println("  reset         전체 초기화 + 재영점");
    Serial.println("  wifireset     WiFi 자격증명 삭제 + 재부팅");
    Serial.println("  status        현재 상태 출력");
    Serial.println("  tolerance <t> 이상감지 허용 오차 (0~1)");
    Serial.println("  alpha <a>     EMA 계수 (0.05~0.5)");
    Serial.println("  log <label>   학습 데이터 CSV 로깅 (normal/slow/fast), log off 종료");
    Serial.println("  cnn           CNN 엔진 진단 (모드/확률/텐서 정보)");
    Serial.println("  cnntest       알려진 패턴으로 추론 검증 (TFLite 증명)");
    Serial.println("  cnnv          CNN 추론 상세 로그 토글");
    Serial.println("  image         CNN 이미지 출력");
    Serial.println("  dumplog       이미지 로그 출력");
    Serial.println("  clearlog      이미지 로그 삭제");
  }
  else {
    Serial.printf("[DBG] 모르는 명령: %s   ('help' 입력)\n", line.c_str());
  }
}

// ─────────────────────────────────────────────────────────────────
// setup — 논블로킹 부팅 (WiFi 연결과 메인 루프 병렬 진행)
// ─────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.println("\n=== Smart IV Pole v1.3 ===");

  // ── 워치독 초기화 ────────────────────────────────────────────────
  // ESP-IDF 5.x (Arduino Core 3.x): esp_task_wdt_config_t 사용
  // ESP-IDF 4.x (Arduino Core 2.x): esp_task_wdt_init(timeout, panic) 사용
#if ESP_IDF_VERSION >= ESP_IDF_VERSION_VAL(5, 0, 0)
  const esp_task_wdt_config_t wdtCfg = {
    .timeout_ms = WDT_TIMEOUT_SEC * 1000,
    .idle_core_mask = 0,            // idle 태스크 감시 안 함
    .trigger_panic = true,
  };
  esp_task_wdt_reconfigure(&wdtCfg);
#else
  esp_task_wdt_init(WDT_TIMEOUT_SEC, true);
#endif
  esp_task_wdt_add(NULL);                      // 현재 태스크 등록
  Serial.printf("[WDT] 워치독 활성화 (%ds)\n", WDT_TIMEOUT_SEC);

  // ── 기기 ID 생성 ────────────────────────────────────────────────
  buildDeviceId();

  // ── 부팅 시 기기 정보 출력 (QR 라벨 제작용) ─────────────────────
  Serial.println("╔══════════════════════════════════════════════╗");
  Serial.printf( "║  기기 ID : %-34s║\n", deviceId);
  Serial.printf( "║  BLE 이름: %-34s║\n", bleName);
  Serial.printf( "║  FW 버전 : %-34s║\n", FW_VERSION);
  Serial.printf( "║  서버 URL: %-34s║\n", SERVER_URL);
  Serial.println("╠══════════════════════════════════════════════╣");
  Serial.printf( "║  QR JSON : {\"name\":\"%s\",\"pop\":\"infucare123\"}  ║\n", deviceId);
  Serial.println("╚══════════════════════════════════════════════╝");

  // ── LittleFS 마운트 ──────────────────────────────────────────────
  if (!LittleFS.begin(true))
    Serial.println("[FS] LittleFS 마운트 실패");
  else
    Serial.println("[FS] LittleFS OK");

  // ── 로드셀 초기화 ────────────────────────────────────────────────
  loadCell.begin(128);
  loadCell.setCalibFactor(CALIB_FACTOR_DEFAULT);
  Serial.printf("[ADS] CalibFactor=%.2f\n", loadCell.getCalibFactor());

  // ── WiFi + BLE 초기화 (논블로킹) ────────────────────────────────
  //
  // 정책: ★ 모든 초기화를 논블로킹으로 ★
  //   1) 저장된 자격증명으로 WiFi.begin() 호출 (결과 대기 안 함)
  //   2) BLE GATT 서버 즉시 시작
  //   3) WiFi 연결은 loop()에서 비동기 체크
  //   4) WiFi 미연결 상태에서도 메인 루프 진입 (HTTP 전송은 WiFi 가드)
  //
  bleProv.startStoredCredentials();   // 논블로킹: WiFi.begin()만 호출

  // BLE 항상 시작 (WiFi 연결과 병렬)
  Serial.printf("[WiFi] BLE 프로비저닝 광고 시작. 기기명: %s\n", bleName);
  Serial.println("[WiFi] 앱에서 언제든 WiFi 재설정 가능합니다.");
  bleProv.begin(bleName);

  // WiFi 연결 대기 없이 즉시 메인 루프 진입
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] WiFi 연결 진행 중 — 메인 루프 시작 (백그라운드 연결)");
  } else {
    Serial.printf("[WiFi] WiFi 연결 완료. IP: %s\n", WiFi.localIP().toString().c_str());
  }

  // ── CNN 탐지기 초기화 ────────────────────────────────────────────
  if (detector.begin())
    Serial.println("[CNN] ✓ TFLite 학습 모델 활성화됨.");
  else
    Serial.println("[CNN] ⚠️ Fallback 모드 (학습 모델 미탑재). 'cnn' 명령으로 진단.");

  // ── HTTP REST API 모드 ──────────────────────────────────────────
  Serial.printf("[HTTP] 서버: %s\n", SERVER_URL);
  Serial.printf("[HTTP] 전송 주기: %dms / 하트비트: %dms\n", HTTP_SEND_MS, HEARTBEAT_MS);

  // ── 부팅 타이머 시작 ────────────────────────────────────────────
  bootMs = millis();
  Serial.printf("[SYS] %.1f초 후 자동 영점 조정 시작.\n", BOOT_DELAY_MS / 1000.0f);
  Serial.printf("[SYS] 기본 목표 유속: %.0f gtt/min (앱에서 변경 가능)\n", calibTargetGtt);

  lastWeightMs = lastStatusMs = millis();
  Serial.printf("[SYS] 부팅 완료 (%lu ms)\n", millis());
}

// ─────────────────────────────────────────────────────────────────
// loop — 워치독 리셋 + 논블로킹 WiFi + BLE 커맨드 처리
// ─────────────────────────────────────────────────────────────────
void loop() {
  unsigned long now = millis();

  // ── 워치독 리셋 (매 루프) ────────────────────────────────────────
  esp_task_wdt_reset();

  handleSerial();
  bleProv.loop();          // BLE 백그라운드 처리 (논블로킹 WiFi 포함)
  handleBleCommands();     // BLE 커맨드 처리 (reset/status/tare)

  // ── WiFi 재연결 감시 (지수 백오프) ──────────────────────────────
  if (WiFi.status() != WL_CONNECTED && !bleProv.isConnecting()) {
    if (now - lastReconnectMs >= reconnectBackoffMs) {
      lastReconnectMs = now;
      WiFi.reconnect();
      Serial.printf("[WiFi] 재연결 시도 (백오프: %lums)\n", reconnectBackoffMs);
      // 지수 백오프: 2s → 4s → 8s → ... → 60s (최대)
      reconnectBackoffMs = min(reconnectBackoffMs * 2, 60000UL);
    }
  } else if (WiFi.status() == WL_CONNECTED) {
    reconnectBackoffMs = 2000;   // 연결 성공 시 백오프 리셋
  }

  // HTTP 하트비트 전송 (주기적)
  if (WiFi.status() == WL_CONNECTED && now - lastHeartbeatMs >= HEARTBEAT_MS) {
    lastHeartbeatMs = now;
    httpSendHeartbeat();
  }

  // =================================================================
  // 자동 부팅 절차 상태 머신
  // =================================================================

  // ── 1단계: 부팅 대기 ──────────────────────────────────────────────
  if (ivPhase == PHASE_BOOT) {
    if (now - bootMs >= BOOT_DELAY_MS) ivPhase = PHASE_TARE;
    return;
  }

  // ── 2단계: 자동 영점 조정 ─────────────────────────────────────────
  if (ivPhase == PHASE_TARE) {
    Serial.println("[AUTO] 영점 조정 중...");
    loadCell.tare(20);
    iv = IVState{};
    detector.reset();
    ivPhase = PHASE_WAIT;
    Serial.println("[AUTO] 영점 완료. 수액팩을 걸어주세요.");
    notifyPhaseChange();
    lastWeightMs = millis();
    return;
  }

  // ── 3단계: 수액 감지 대기 ─────────────────────────────────────────
  if (ivPhase == PHASE_WAIT && now - lastWeightMs >= WEIGHT_MS) {
    lastWeightMs = now;
    float w = loadCell.readWeight();
    iv.currentWeight = w;

    if (w > WEIGHT_HANG_G) {
      Serial.printf("[AUTO] 수액 감지 (%.1fg) — 흔들림 안정화 대기 시작\n", w);
      for (int i = 0; i < STABILIZE_WINDOW; i++) stabilizeBuf[i] = 0;
      stabilizeIdx     = 0;
      stabilizeCount   = 0;
      stabilizeStartMs = millis();
      ivPhase          = PHASE_STABILIZE;
      notifyPhaseChange();
    }
    return;
  }

  // ── 3-1단계: 흔들림 안정화 대기 ──────────────────────────────────
  if (ivPhase == PHASE_STABILIZE && now - lastWeightMs >= WEIGHT_MS) {
    lastWeightMs = now;
    float w = loadCell.readWeight();
    iv.currentWeight = w;

    // 수액팩이 빠졌으면 다시 대기
    if (w < WEIGHT_REMOVE_G) {
      Serial.println("[AUTO] 안정화 중 수액 제거 감지 — 다시 대기.");
      ivPhase = PHASE_WAIT;
      notifyPhaseChange();
      return;
    }

    stabilizeBuf[stabilizeIdx] = w;
    stabilizeIdx = (stabilizeIdx + 1) % STABILIZE_WINDOW;
    if (stabilizeCount < STABILIZE_WINDOW) stabilizeCount++;

    bool forceContinue = (now - stabilizeStartMs >= STABILIZE_TIMEOUT_MS);
    if (stabilizeCount >= STABILIZE_WINDOW) {
      float mn = stabilizeBuf[0], mx = stabilizeBuf[0];
      for (int i = 1; i < STABILIZE_WINDOW; i++) {
        if (stabilizeBuf[i] < mn) mn = stabilizeBuf[i];
        if (stabilizeBuf[i] > mx) mx = stabilizeBuf[i];
      }
      float range = mx - mn;
      Serial.printf("[AUTO] 안정화 중... W:%.2fg  변동:%.2fg (기준 <%.2fg)\n",
                    w, range, STABILIZE_RANGE_G);

      if (range < STABILIZE_RANGE_G || forceContinue) {
        if (forceContinue)
          Serial.println("[AUTO] ⚠️ 안정화 시간 초과 — 강제로 교정 진입");
        else
          Serial.println("[AUTO] ✓ 안정화 완료 — 드립 팩터 교정 시작");

        Serial.printf("[AUTO] 목표: %.0f gtt/min | 교정 시간: %lu초\n",
                      calibTargetGtt, CALIB_DURATION_MS / 1000UL);
        calibWeightStart = loadCell.stableRead(10);
        calibStartMs     = millis();
        ivPhase          = PHASE_CALIB;
        notifyPhaseChange();
      }
    } else {
      Serial.printf("[AUTO] 안정화 샘플 수집 중... W:%.2fg (%d/%d)\n",
                    w, stabilizeCount, STABILIZE_WINDOW);
    }
    return;
  }

  // ── 4단계: 드립 팩터 교정 (60초) ──────────────────────────────────
  if (ivPhase == PHASE_CALIB && now - calibStartMs >= CALIB_DURATION_MS) {
    float weightEnd  = loadCell.stableRead(10);
    float weightLost = calibWeightStart - weightEnd;

    if (weightLost > 0.05f && calibTargetGtt > 0) {
      iv.dripFactor = weightLost / calibTargetGtt;
      Serial.printf("[AUTO] 교정 완료: %.5f g/gtt  (감소 %.3fg / %.0f방울)\n",
                    iv.dripFactor, weightLost, calibTargetGtt);
    } else {
      Serial.printf("[AUTO] 교정 실패 — 기본값 %.5f g/gtt 사용\n", iv.dripFactor);
    }

    iv.targetFlowRate = (calibTargetGtt / 60.0f) * iv.dripFactor;
    Serial.printf("[AUTO] 목표 유속 확정: %.4f g/s (%.0f gtt/min)\n",
                  iv.targetFlowRate, calibTargetGtt);

    loadCell.resetEma();
    iv.currentWeight = loadCell.readWeight();
    iv.prevWeight    = iv.currentWeight;
    iv.started       = true;
    iv.complete      = false;
    iv.warmup        = WARMUP_SAMPLES;
    ivPhase          = PHASE_WARMUP;
    notifyPhaseChange();
    Serial.printf("[AUTO] EMA 안정화 중... (%d 샘플)\n", WARMUP_SAMPLES);
    lastWeightMs = millis();
    return;
  }

  // =================================================================
  // 무게 측정 주기 — WAIT/STABILIZE 단계는 위에서 따로 처리
  // =================================================================
  if (ivPhase != PHASE_WAIT && ivPhase != PHASE_STABILIZE
      && now - lastWeightMs >= WEIGHT_MS) {
    lastWeightMs = now;

    iv.prevWeight    = iv.currentWeight;
    iv.currentWeight = loadCell.readWeight();

    // ── EMA 안정화 단계 ────────────────────────────────────────────
    if (ivPhase == PHASE_WARMUP) {
      iv.prevWeight = iv.currentWeight;
      iv.warmup--;
      Serial.printf("[AUTO] 안정화 중... W:%.2fg  (남은 샘플 %d개)\n",
                    iv.currentWeight, iv.warmup);
      if (iv.warmup == 0) {
        ivPhase = PHASE_MONITOR;
        notifyPhaseChange();
        Serial.println("[AUTO] ✓ 모니터링 시작!");
      }
      return;
    }

    // ── 모니터링 단계 ──────────────────────────────────────────────
    if (ivPhase == PHASE_MONITOR) {

      // 수액팩 제거 감지 → 서버에 stopped 전송 + BLE notify 후 재영점
      if (iv.currentWeight < WEIGHT_REMOVE_G) {
        Serial.println("[AUTO] 수액 제거 감지 — stopped 전송 후 재영점.");
        ivPhase = PHASE_DONE;
        iv.currentWeight = 0;
        notifyPhaseChange();       // BLE로 즉시 앱에 알림
        httpSendMeasurement();     // 서버에 종료 상태 전송
        iv      = IVState{};
        ivPhase = PHASE_TARE;
        detector.reset();
        return;
      }

      // 유속 계산: g/s = 무게 감소량 ÷ 측정 주기
      iv.currentFlowRate = (iv.prevWeight - iv.currentWeight)
                           / (WEIGHT_MS / 1000.0f);

      // CNN 샘플 추가 (16개 채워지면 자동 분류)
      detector.addSample(iv.currentFlowRate, iv.targetFlowRate);

      // 학습 데이터 CSV 로깅
      if (csvLabel[0] != '\0') {
        Serial.printf("LOG,%lu,%.4f,%.4f,%d,%s\n",
                      now, iv.currentFlowRate, iv.targetFlowRate,
                      detector.getLastState(), csvLabel);
      }

      // 이상 감지
      if (detector.detectAnomaly()) {
        publishAlert(iv.currentFlowRate);
        saveImageToLog();
      }

      // 주입 완료 판정
      if (iv.finishWeight > 0 && iv.currentWeight <= iv.finishWeight) {
        iv.complete = true;
        iv.started  = false;
        ivPhase     = PHASE_DONE;
        Serial.println("[IV] 주입 완료.");
        notifyPhaseChange();
        httpSendMeasurement();
        return;
      }

      // 측정 결과 출력
      if (detector.getSampleCount() == 0 && detector.isWindowFull()) {
        Serial.printf("[IV] W:%.2fg  유속:%.4f/%.4fg/s  → %s (신뢰도:%.0f%%)\n",
                      iv.currentWeight, iv.currentFlowRate, iv.targetFlowRate,
                      detector.getResultLabel(),
                      detector.getWindowConfidence() * 100.0f);
      } else {
        Serial.printf("[IV] W:%.2fg  유속:%.4f/%.4fg/s  [수집중 %d/%d]\n",
                      iv.currentWeight, iv.currentFlowRate, iv.targetFlowRate,
                      detector.getSampleCount(), CNN_WIN);
      }
    }

    // ── 주입 완료 후 수액 제거 감지 ───────────────────────────────
    if (ivPhase == PHASE_DONE && iv.currentWeight < WEIGHT_REMOVE_G) {
      Serial.println("[AUTO] 빈 수액 제거 — 재영점 후 대기 중.");
      iv      = IVState{};
      ivPhase = PHASE_TARE;
      detector.reset();
      notifyPhaseChange();
    }
  }

  // ── HTTP 데이터 전송 (주기적, 모니터링 중에만) ──────────────────
  if (WiFi.status() == WL_CONNECTED && ivPhase == PHASE_MONITOR
      && now - lastHttpSendMs >= HTTP_SEND_MS) {
    lastHttpSendMs = now;
    httpSendMeasurement();
  }
}
