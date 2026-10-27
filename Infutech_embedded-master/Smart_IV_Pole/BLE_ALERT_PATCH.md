# 시연용 BLE 직결 알림 패치 (ADS1232 모니터 스케치용 참고 문서)

> **2026-10-07 기준 이미 적용됨**: `~/Downloads/sketch_sep12a/` 의 `ble_wifi_prov.h`,
> `monitor_comms.h`, `sketch_sep12a.ino` 에 아래 내용이 반영되어 있습니다.
> 실제 적용은 `monitor_comms.h`의 `notifyMonitorStatus()`/`sendAlert()`에 BLE 호출을 넣는 방식이라
> 아래 "3. 호출 지점"의 `bleSendTelemetry()` 대신 기존 `notifyMonitorStatus()`를 그대로 씁니다.
> 이 문서는 다른 스케치에 같은 변경을 옮길 때의 참고용입니다.

앱이 서버 없이 BLE로 측정값과 알림을 받도록 하는 변경입니다.
저장소의 `ble_wifi_prov.h`에 `notifyTelemetry()` / `notifyAlert()`가 추가되었으니
**이 파일을 대상 스케치의 `ble_wifi_prov.h`에 덮어쓴 뒤**, 아래를 `.ino`에 적용하세요.

전제: 전역 BLE 객체 이름이 `bleProv` (`BLEWiFiProv bleProv;`). 다르면 이름만 바꾸세요.

---

## 1. `checkDeviation()` 교체 — 정지 판정 추가 + 상태 바뀔 때만 알림

기존:
```cpp
void checkDeviation() {
  float deviation = flowDeviationPercent();
  if (isfinite(deviation) && fabsf(deviation) >= deviationThresholdPercent) {
    sendAlert(measuredFlow > baselineFlow ? "flow_fast" : "flow_slow", fabsf(deviation) / 100.0f);
  }
}
```

교체:
```cpp
// 기준 유속의 10% 이하로 떨어지면 "느림"이 아니라 "정지"(줄 꺾임·혈액 역류 가능)로 본다.
const float STOP_RATIO = 0.10f;

enum FlowAlert { FA_NONE, FA_FAST, FA_SLOW, FA_STOP };
FlowAlert lastFlowAlert = FA_NONE;

void checkDeviation() {
  float deviation = flowDeviationPercent();
  if (!isfinite(deviation)) return;

  FlowAlert now = FA_NONE;
  if (measuredFlow <= baselineFlow * STOP_RATIO)              now = FA_STOP;
  else if (deviation >=  deviationThresholdPercent)           now = FA_FAST;
  else if (deviation <= -deviationThresholdPercent)           now = FA_SLOW;

  if (now == lastFlowAlert) return;   // 같은 상태가 이어지면 4초마다 다시 보내지 않음
  lastFlowAlert = now;
  if (now == FA_NONE) return;         // 정상 복귀는 알림 없음 (다음 이상을 다시 허용)

  const char* type =
      now == FA_STOP ? "flow_stop" : now == FA_FAST ? "flow_fast" : "flow_slow";
  const char* msg =
      now == FA_STOP ? "줄 꺾임 또는 혈액 역류 가능성이 있습니다. 라인을 확인하세요."
    : now == FA_FAST ? "유속이 기준보다 너무 빠릅니다. 조절기를 확인하세요."
                     : "유속이 기준보다 너무 느립니다. 라인과 조절기를 확인하세요.";

  // 1) BLE 직결 (시연용, 서버/WiFi 무관)
  bleProv.notifyAlert(type, deviation, msg);
  // 2) 기존 서버 전송은 그대로 유지
  sendAlert(type, fabsf(deviation) / 100.0f);
}
```

## 2. 텔레메트리 헬퍼 추가 (아무 함수 밖, `checkDeviation` 위쪽)

```cpp
// 앱 잔량 카드용. w0 = 거치 확인 시점 무게(baselineStartWeight).
void bleSendTelemetry() {
  bleProv.notifyTelemetry(currentWeight, baselineStartWeight, measuredFlow,
                          predicted, getStateString(currentState),
                          flowDeviationPercent());
}
```

## 3. 호출 지점 4곳

| 위치 | 추가할 줄 | 이유 |
|---|---|---|
| `STABLE` 케이스, `send_data(...)` 바로 다음 | `bleSendTelemetry();` | 4초마다 무게·잔량·상태 갱신 |
| `sampleFlowBaseline()`의 `Serial.printf("[BASELINE] ...")` 다음 | `bleSendTelemetry();` | 기준 측정 30초 동안도 화면이 움직이게 |
| `beginLoadedMeasurement()` 끝 | `lastFlowAlert = FA_NONE; bleSendTelemetry();` | 세션 시작 알림 + 래치 초기화 |
| `finishMonitorAutomatically()` 와 `resetMonitorSession()` 끝 (monitor_comms.h 안이면 .ino 호출부 뒤에) | `bleSendTelemetry();` | 종료/대기 상태를 앱에 전달 |

`WAITING_LOAD` 케이스의 `Serial.printf("[WAIT] ...")` 뒤에도 `bleSendTelemetry();`를 넣으면
"수액팩을 올려주세요" 상태가 앱에 바로 보입니다 (1초마다 1프레임, 부담 없음).

## 4. 전송되는 JSON (참고)

```json
{"type":"telemetry","w":512.3,"w0":550.0,"flow":0.0123,"eta":3400,"state":"STABLE","dev":12.5}
{"type":"alert","alert":"flow_stop","dev":-96.1,"msg":"줄 꺾임 또는 혈액 역류 가능성이 있습니다. 라인을 확인하세요."}
```

`state` 값: `WAITING_LOAD` / `BASELINE` / `STABLE` / `UNSTABLE` / `WAITING` (기존 `getStateString`).
앱은 `type`이 없는 기존 `notifyIvStatus` 프레임도 그대로 받아들이므로 기존 동작은 깨지지 않습니다.

## 5. 시연 중 임계값 조절

시리얼에서 `threshold 10` 처럼 낮추면 작은 유속 변화에도 알림이 뜹니다.
정지 알림은 라인을 완전히 꺾거나 클램프를 닫으면 다음 측정(4초 이내)에 발생합니다.
