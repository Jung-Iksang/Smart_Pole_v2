#pragma once
#include <Arduino.h>

// ── 설정값 ────────────────────────────────────────────────────────
#define RATE_BUF_SIZE      30      // 링버퍼 크기 (60초분, 2초 간격)
#define SHORT_WINDOW        3      // 단기 비교 구간 (6초 = 3 × 2초)
#define LONG_WINDOW        15      // 장기 baseline 구간 (30초 = 15 × 2초)
#define FAST_RATIO         1.5f    // baseline 대비 150% 이상 → 유속 과다
#define SLOW_RATIO         0.5f    // baseline 대비 50% 이하 → 유속 저하
#define SHAKE_WINDOW        5      // 흔들림 판정에 사용할 최근 샘플 수
#define SHAKE_THRESHOLD_G   2.0f   // max-min > 이 값 → 흔들림 상태

// 감지 결과
#define RATE_OK        0
#define RATE_FAST      1
#define RATE_SLOW     -1
#define RATE_SHAKING  -2   // 흔들림 중 — 감지 보류

/*
 * FlowRateMonitor — 이동평균 기반 실시간 유속 이상 감지기
 *
 * 스무딩된 무게(loadCell.readWeight())를 링버퍼에 쌓고,
 * 단기(6초) 감소율 vs 장기(30초) 감소율을 비교하여
 * 유속 과다/저하를 ~5초 이내에 감지한다.
 *
 * 흔들림(이동 중) 감지 시 알림을 보류하여 오알림을 방지한다.
 */
class FlowRateMonitor {
public:
  FlowRateMonitor()
    : _head(0), _count(0), _alertState(RATE_OK),
      _targetRate(0), _lastResult(RATE_OK) {
    memset(_buf, 0, sizeof(_buf));
  }

  // calibration에서 확정된 정상 유속 설정 (g/s)
  // PHASE_MONITOR 진입 시 호출 — 링버퍼가 부족할 때 baseline으로 사용
  void setTargetRate(float rate) { _targetRate = rate; }

  // 링버퍼 + 상태 초기화 (재영점, 수액 교체 시)
  void reset() {
    memset(_buf, 0, sizeof(_buf));
    _head = 0;
    _count = 0;
    _alertState = RATE_OK;
    _lastResult = RATE_OK;
  }

  // ── 매 측정(2초)마다 호출 ─────────────────────────────────────────
  // smoothedWeight: loadCell.readWeight() 반환값 (이미 중앙값+EMA 필터링됨)
  // weightIntervalSec: 측정 주기 (초), 보통 2.0
  // 반환: RATE_OK / RATE_FAST / RATE_SLOW / RATE_SHAKING
  int update(float smoothedWeight, float weightIntervalSec) {
    // 1. 링버퍼에 저장
    _buf[_head] = smoothedWeight;
    _head = (_head + 1) % RATE_BUF_SIZE;
    if (_count < RATE_BUF_SIZE) _count++;

    // 2. 흔들림 체크
    if (_isShaking()) {
      _lastResult = RATE_SHAKING;
      // 흔들림 중에는 alertState 리셋하지 않음 — 멈추면 이전 상태에서 재개
      return RATE_SHAKING;
    }

    // 3. 최소 데이터 필요 (SHORT_WINDOW + 1)
    if (_count < SHORT_WINDOW + 1) {
      _lastResult = RATE_OK;
      return RATE_OK;
    }

    // 4. 단기 감소율 (최근 SHORT_WINDOW 샘플 구간)
    int nowIdx   = (_head - 1 + RATE_BUF_SIZE) % RATE_BUF_SIZE;
    int shortIdx = (_head - SHORT_WINDOW - 1 + RATE_BUF_SIZE) % RATE_BUF_SIZE;
    float shortDelta = _buf[shortIdx] - _buf[nowIdx];  // 양수 = 무게 감소
    float shortSec   = SHORT_WINDOW * weightIntervalSec;

    // 5. baseline 결정
    float baselineRate;  // g/s
    if (_count >= LONG_WINDOW + 1) {
      // 장기 이동평균 사용
      int longIdx = (_head - LONG_WINDOW - 1 + RATE_BUF_SIZE) % RATE_BUF_SIZE;
      float longDelta = _buf[longIdx] - _buf[nowIdx];
      float longSec   = LONG_WINDOW * weightIntervalSec;
      baselineRate = longDelta / longSec;
    } else {
      // calibration 값 사용 (초기 30초 이내)
      baselineRate = _targetRate;
    }

    // 6. baseline이 너무 작으면 (수액 거의 안 줄고 있으면) 스킵
    if (baselineRate < 0.001f) {
      _lastResult = RATE_OK;
      return RATE_OK;
    }

    // 7. 비율 계산
    float shortRate = shortDelta / shortSec;
    float ratio = shortRate / baselineRate;

    // 8. 판정
    int result = RATE_OK;
    if (ratio > FAST_RATIO) {
      result = RATE_FAST;
    } else if (ratio < SLOW_RATIO) {
      result = RATE_SLOW;
    }

    // 9. 알림 상태 관리 (같은 상태 반복 알림 방지)
    if (result != RATE_OK && _alertState != result) {
      // 새로운 이상 감지 → 알림 필요
      _alertState = result;
      _lastResult = result;
      return result;
    } else if (result == RATE_OK) {
      // 정상 복귀 → 쿨다운 리셋
      _alertState = RATE_OK;
    }

    _lastResult = RATE_OK;  // 이미 알림 보낸 상태이거나 정상
    return RATE_OK;
  }

  // 최근 판정 결과 문자열 (디버그용)
  const char* getResultLabel() const {
    switch (_lastResult) {
      case RATE_FAST:    return "FAST";
      case RATE_SLOW:    return "SLOW";
      case RATE_SHAKING: return "SHAKING";
      default:           return "OK";
    }
  }

  int   getLastResult()  const { return _lastResult; }
  int   getAlertState()  const { return _alertState; }
  int   getSampleCount() const { return _count; }
  bool  isReady()        const { return _count >= SHORT_WINDOW + 1; }

private:
  float _buf[RATE_BUF_SIZE];
  int   _head;
  int   _count;
  int   _alertState;    // 현재 알림 상태 (중복 방지)
  float _targetRate;    // calibration baseline (g/s)
  int   _lastResult;    // 최근 update() 반환값

  // 최근 SHAKE_WINDOW 샘플의 max-min > SHAKE_THRESHOLD_G 이면 흔들림
  bool _isShaking() const {
    if (_count < SHAKE_WINDOW) return false;

    float mn = _buf[(_head - 1 + RATE_BUF_SIZE) % RATE_BUF_SIZE];
    float mx = mn;
    for (int i = 1; i < SHAKE_WINDOW; i++) {
      int idx = (_head - 1 - i + RATE_BUF_SIZE) % RATE_BUF_SIZE;
      if (_buf[idx] < mn) mn = _buf[idx];
      if (_buf[idx] > mx) mx = _buf[idx];
    }
    return (mx - mn) > SHAKE_THRESHOLD_G;
  }
};
