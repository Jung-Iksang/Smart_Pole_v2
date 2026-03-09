 Smart Ringer 전체 시스템 아키텍처

> **프로젝트:** 스마트 수액/소변 측정 IoT 시스템
> **버전:** v1.0
> **최종 수정:** 2026-03-09
> **PCB 설계:** 권용현 (HARDWARE.md 참조)

---

## 1. 시스템 개요

병원에서 사용하는 수액(IV Fluid)과 소변통(Urine Bag)의 무게를 실시간으로 측정하여 모바일 앱과 서버에 전달하는 IoT 의료 모니터링 시스템.

```
┌─────────────┐      BLE         ┌─────────────┐     HTTPS      ┌─────────────┐     SQL       ┌─────────────┐
│  IoT Device │  (Provisioning)  │ Flutter App  │   REST/WS     │   FastAPI    │  asyncpg     │  PostgreSQL │
│ ESP32+ADS   │◄────────────────►│  iOS/Android │◄─────────────►│   Server     │◄────────────►│  (AWS RDS)  │
│ 1232+LoadCell│     WiFi설정     │              │               │              │              │             │
└──────┬──────┘                  └─────────────┘               └──────┬───────┘              └─────────────┘
       │                                                              │
       │              HTTPS (센서 데이터 POST)                         │
       └──────────────────────────────────────────────────────────────┘
```

### 1.1 핵심 데이터 흐름

1. **로드셀** → ADS1232 (24비트 ADC) → ESP32 → **HTTPS POST** → FastAPI → PostgreSQL
2. FastAPI → **WebSocket** → Flutter 앱 (실시간 모니터링)
3. FastAPI → **FCM Push** → Flutter 앱 (잔량 부족/이상 알림)

### 1.2 제품 종류

| 제품 | 측정 대상 | device_type | 알림 조건 |
|------|----------|-------------|----------|
| 스마트 링거 | 수액팩 무게 감소 | `iv_fluid` | 잔량 부족, 유속 이상, 기기 오프라인 |
| 스마트 소변통 | 소변량 증가 | `urine` | 용량 초과, 기기 오프라인 |

---

## 2. 하드웨어 레이어

> **상세 회로도 분석: [HARDWARE.md](./HARDWARE.md) 참조**

### 2.1 핵심 부품

| 부품 | 모델 | 역할 |
|------|------|------|
| MCU | ESP32-WROOM-32E | WiFi + BLE 통신, 메인 제어 |
| ADC | **ADS1232IPWR** (24비트) | 로드셀 아날로그 신호 → 디지털 변환 |
| USB-UART | CH340C | 펌웨어 프로그래밍/디버깅 |
| LDO | AMS1117-3.3 | USB 5V → 3.3V 전원 변환 |
| 커넥터 | DB2EVC-3.81-4P-GN | 4선식 로드셀 연결 (E+, E-, A+, A-) |

### 2.2 ESP32 ↔ ADS1232 GPIO 매핑

```c
#define PIN_ADS1232_DOUT    19   // 데이터 출력 + 변환 완료 (입력)
#define PIN_ADS1232_SCLK    18   // 시리얼 클럭 (출력)
#define PIN_ADS1232_PDWN     5   // 파워다운 제어 (출력, HIGH=정상)
#define PIN_ADS1232_GAIN1   32   // 게인 비트1 (출력)
#define PIN_ADS1232_GAIN0   33   // 게인 비트0 (출력)
```

### 2.3 확장 헤더 (H1~H4)

| 헤더 | GPIO | 기능 | 활용 예시 |
|------|------|------|----------|
| H1 | IO25 | DAC1 | 상태 LED, 부저 |
| H2 | IO26 | DAC2 | 추가 LED |
| H3 | IO27 | GPIO | 버튼, 센서 |
| H4 | IO14 | ADC2_CH6 | 배터리 전압 모니터링 (WiFi OFF 시만) |

### 2.4 펌웨어 동작 모드

```
[전원 ON]
    │
    ▼
[NVS에 WiFi 정보 있음?] ──NO──► [BLE Provisioning 모드]
    │                              │ LED: 파란색 깜빡임 (H1 활용)
    YES                            │ BLE 광고: "SRINGER_XXXX"
    │                              │ 앱에서 WiFi 정보 수신
    ▼                              │ WiFi 정보 NVS 저장
[WiFi 접속 시도]◄─────────────────┘
    │
    ├──실패──► [재시도 3회] ──실패──► [BLE 모드로 복귀]
    │
    ▼
[서버 등록/연결 확인]
    │
    ▼
[정상 운영 모드]
    │ LED: 녹색 점등 (H1 활용)
    │
    ├── 1~5초 주기: 로드셀 → ADS1232 → ESP32 → HTTPS POST → 서버
    ├── 30분 주기: OTA 업데이트 확인
    ├── 상시: WiFi 연결 상태 모니터링
    └── 네트워크 끊김 시: 링버퍼에 로컬 저장 → 재연결 시 일괄 전송
```

### 2.5 ADS1232 데이터 읽기 프로토콜

```
1. PDWN# = HIGH (IO5) → 정상 동작
2. DRDY#/DOUT (IO19) = LOW 대기 (변환 완료)
3. SCLK (IO18) 24회 토글 → 24비트 데이터 MSB-first 수신
4. 추가 클럭 1~3회 → 다음 변환 시작

게인 설정:
┌─────────┬─────────┬────────┐
│ GAIN1   │ GAIN0   │ 배율   │
│ (IO32)  │ (IO33)  │        │
├─────────┼─────────┼────────┤
│ LOW     │ LOW     │ 1x     │
│ LOW     │ HIGH    │ 2x     │
│ HIGH    │ LOW     │ 64x    │  ← 일반 로드셀 권장
│ HIGH    │ HIGH    │ 128x   │  ← 고정밀 측정
└─────────┴─────────┴────────┘
```

---

## 3. Flutter 앱 레이어

### 3.1 기술 스택

| 구분 | 패키지 | 용도 |
|------|--------|------|
| 프레임워크 | Flutter 3.x + Dart | 크로스플랫폼 앱 |
| 상태관리 | `flutter_riverpod` | 전역 상태 + 의존성 주입 |
| 라우팅 | `go_router` | 선언적 네비게이션 |
| HTTP | `dio` | REST API 통신 + 인터셉터 |
| WebSocket | `web_socket_channel` | 실시간 데이터 스트림 |
| BLE | `esp_provisioning_wifi` | ESP32 BLE 프로비저닝 |
| QR | `mobile_scanner` | QR코드 / 바코드 스캔 |
| 푸시 | `firebase_messaging` | FCM 알림 |
| 차트 | `fl_chart` | 실시간 그래프 |
| 로그인 | `kakao_flutter_sdk`, `google_sign_in` | 소셜 로그인 |
| 저장 | `flutter_secure_storage` | 토큰 안전 저장 |

### 3.2 디렉토리 구조

```
lib/
├── main.dart                          # 앱 진입점
├── app/
│   ├── app.dart                       # MaterialApp 설정
│   ├── routes.dart                    # GoRouter 라우트 정의
│   └── theme.dart                     # 앱 테마 (색상, 폰트)
│
├── core/
│   ├── constants/
│   │   ├── api_endpoints.dart         # API URL 상수
│   │   └── ble_constants.dart         # BLE 서비스 UUID 등
│   ├── network/
│   │   ├── api_client.dart            # Dio 인스턴스 + 인터셉터
│   │   ├── api_interceptor.dart       # JWT 자동 갱신 인터셉터
│   │   └── websocket_client.dart      # WebSocket 연결 관리
│   ├── ble/
│   │   ├── provisioning_service.dart  # ESP32 BLE 프로비저닝 로직
│   │   └── ble_scanner.dart           # BLE 기기 스캔
│   ├── error/
│   │   ├── exceptions.dart            # 커스텀 예외
│   │   └── failures.dart              # Failure 클래스
│   └── storage/
│       └── secure_storage.dart        # 토큰, 인증 정보 저장
│
├── features/
│   ├── auth/                          # ── 인증 기능 ──
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── auth_remote_source.dart
│   │   │   │   └── auth_local_source.dart
│   │   │   ├── models/
│   │   │   │   └── user_model.dart
│   │   │   └── repositories/
│   │   │       └── auth_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── user.dart
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository.dart
│   │   │   └── usecases/
│   │   │       ├── login_with_email.dart
│   │   │       ├── login_with_kakao.dart
│   │   │       ├── login_with_google.dart
│   │   │       ├── signup.dart
│   │   │       └── logout.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── auth_provider.dart
│   │       ├── screens/
│   │       │   ├── login_screen.dart
│   │       │   ├── signup_screen.dart
│   │       │   └── splash_screen.dart
│   │       └── widgets/
│   │           ├── social_login_button.dart
│   │           └── email_form.dart
│   │
│   ├── device_setup/                  # ── 기기 연결(프로비저닝) ──
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── device_model.dart
│   │   │   └── repositories/
│   │   │       └── device_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── device.dart
│   │   │   ├── repositories/
│   │   │   │   └── device_repository.dart
│   │   │   └── usecases/
│   │   │       ├── scan_qr_code.dart
│   │   │       ├── connect_ble.dart
│   │   │       ├── send_wifi_credentials.dart
│   │   │       └── register_device.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── setup_provider.dart
│   │       ├── screens/
│   │       │   ├── qr_scan_screen.dart          # 1단계: QR 스캔
│   │       │   ├── wifi_input_screen.dart        # 2단계: WiFi 정보 입력
│   │       │   ├── provisioning_screen.dart      # 3단계: BLE 전송 + 진행 표시
│   │       │   └── setup_complete_screen.dart    # 4단계: 연결 완료
│   │       └── widgets/
│   │           ├── ble_status_indicator.dart
│   │           └── wifi_network_selector.dart
│   │
│   ├── monitoring/                    # ── 실시간 모니터링 ──
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── measurement_remote_source.dart
│   │   │   │   └── websocket_source.dart
│   │   │   ├── models/
│   │   │   │   └── measurement_model.dart
│   │   │   └── repositories/
│   │   │       └── monitoring_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── measurement.dart
│   │   │   ├── repositories/
│   │   │   │   └── monitoring_repository.dart
│   │   │   └── usecases/
│   │   │       ├── get_realtime_data.dart
│   │   │       ├── get_history.dart
│   │   │       └── calculate_flow_rate.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   ├── realtime_provider.dart
│   │       │   └── history_provider.dart
│   │       ├── screens/
│   │       │   ├── dashboard_screen.dart         # 메인 대시보드
│   │       │   ├── device_detail_screen.dart      # 기기별 상세
│   │       │   └── history_screen.dart            # 과거 이력
│   │       └── widgets/
│   │           ├── realtime_gauge.dart            # 잔량 게이지
│   │           ├── flow_rate_chart.dart           # 유속 그래프
│   │           ├── weight_trend_chart.dart        # 무게 추이
│   │           └── device_status_card.dart        # 기기 상태 카드
│   │
│   ├── alerts/                        # ── 알림 ──
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── alert_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── alert.dart
│   │   │   └── usecases/
│   │   │       ├── get_alerts.dart
│   │   │       └── mark_as_read.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── alert_provider.dart
│   │       ├── screens/
│   │       │   └── alert_list_screen.dart
│   │       └── widgets/
│   │           └── alert_item.dart
│   │
│   └── settings/                      # ── 설정 ──
│       └── presentation/
│           └── screens/
│               ├── settings_screen.dart
│               ├── device_manage_screen.dart      # 기기 관리 (등록/해제)
│               └── profile_screen.dart
│
└── shared/
    ├── widgets/
    │   ├── loading_overlay.dart
    │   ├── error_dialog.dart
    │   └── bottom_nav_bar.dart
    └── providers/
        ├── connectivity_provider.dart             # 네트워크 상태
        └── fcm_provider.dart                      # 푸시 알림 처리
```

### 3.3 화면 플로우 (Screen Flow)

```
[앱 시작]
    │
    ▼
[Splash Screen]
    │
    ├── 토큰 없음 ──► [Login Screen]
    │                     ├── 카카오 로그인
    │                     ├── 구글 로그인
    │                     └── 이메일 회원가입 → [Signup Screen]
    │
    ├── 토큰 만료 ──► [Login Screen]
    │
    └── 토큰 유효 ──► [Dashboard Screen] (메인)
                          │
                          ├── Tab 1: 대시보드 (기기 목록 + 실시간 요약)
                          │     │
                          │     └── [Device Detail Screen]
                          │           ├── 실시간 게이지
                          │           ├── 유속 차트
                          │           └── 무게 추이 그래프
                          │
                          ├── Tab 2: 이력
                          │     └── [History Screen]
                          │           ├── 날짜별 필터
                          │           └── CSV 내보내기
                          │
                          ├── Tab 3: 알림
                          │     └── [Alert List Screen]
                          │
                          └── Tab 4: 설정
                                ├── [Device Manage Screen]
                                │     ├── 기기 추가 → [QR Scan] → [WiFi Input] → [Provisioning] → [Complete]
                                │     └── 기기 해제
                                └── [Profile Screen]
                                      ├── 로그아웃
                                      └── 회원 탈퇴
```

### 3.4 BLE 프로비저닝 상세 플로우

```
[QR Scan Screen]
    │  QR 데이터: {"sn":"SRG-IV-2024-0001","type":"iv","pop":"abcd1234"}
    ▼
[WiFi Input Screen]
    │  사용자 입력: SSID + Password (2.4GHz 필수 안내)
    │  (선택) ESP32가 스캔한 AP 목록 표시 가능
    ▼
[Provisioning Screen]
    │
    ├── Step 1: BLE 스캔 (기기명: SRINGER_XXXX)
    │     └── esp_provisioning_wifi.searchBleEsp32Devices()
    │
    ├── Step 2: BLE 연결 + PoP 인증
    │     └── esp_provisioning_wifi.connectBleDevice(deviceName, pop)
    │
    ├── Step 3: WiFi 자격증명 전송 (AES-CTR 암호화)
    │     └── esp_provisioning_wifi.sendWifiConfig(ssid, password)
    │
    ├── Step 4: WiFi 연결 결과 수신 (BLE로 상태 확인)
    │     └── esp_provisioning_wifi.getStatus()
    │
    └── Step 5: 서버에 기기 등록 확인
          └── POST /api/v1/devices/register (앱 → 서버)
    ▼
[Setup Complete Screen]
    │  "기기가 성공적으로 등록되었습니다!"
    └── Dashboard로 이동
```

### 3.5 WebSocket 실시간 데이터 처리

```dart
// websocket_client.dart 핵심 로직
//
// 연결: wss://api.example.com/api/v1/measurements/{device_id}/realtime
// 인증: JWT 토큰을 쿼리 파라미터 또는 첫 메시지로 전송
//
// 수신 데이터 형식 (JSON):
// {
//   "device_id": "uuid",
//   "weight_grams": 523.45,
//   "flow_rate_ml_min": 2.3,
//   "remaining_ml": 245.0,
//   "measured_at": "2026-03-09T14:30:00Z"
// }
//
// 재연결 전략:
// - 연결 끊김 시 exponential backoff (1s → 2s → 4s → 8s → 최대 30s)
// - 앱이 foreground 복귀 시 즉시 재연결
// - 네트워크 상태 변화 감지 시 재연결
```

### 3.6 상태관리 구조 (Riverpod)

```
[Auth Provider]
    │  상태: AuthState (로그인/로그아웃/로딩)
    │  보유: User 엔티티, JWT 토큰
    │
[Device Provider]
    │  상태: List<Device> (등록된 기기 목록)
    │  의존: Auth Provider (사용자 ID 필요)
    │
[Realtime Provider]
    │  상태: Map<deviceId, MeasurementStream>
    │  의존: Device Provider (기기 ID), WebSocket Client
    │  동작: 기기별 WebSocket 연결 관리
    │
[Alert Provider]
    │  상태: List<Alert> (알림 목록, unread count)
    │  의존: Auth Provider
    │  동작: FCM 수신 시 자동 갱신
    │
[Connectivity Provider]
    │  상태: NetworkStatus (online/offline)
    │  동작: 오프라인 시 UI 알림, 온라인 복귀 시 데이터 동기화
```

---

## 4. 백엔드 레이어 (FastAPI)

### 4.1 기술 스택

| 구분 | 기술 | 용도 |
|------|------|------|
| 프레임워크 | FastAPI (Python 3.11+) | 비동기 REST API + WebSocket |
| ORM | SQLAlchemy 2.0 + asyncpg | 비동기 DB 접근 |
| 마이그레이션 | Alembic | DB 스키마 버전 관리 |
| 검증 | Pydantic v2 | 요청/응답 데이터 검증 |
| 인증 | python-jose (JWT) | 토큰 기반 인증 |
| 해싱 | passlib[bcrypt] | 비밀번호 해싱 |
| 푸시 | firebase-admin | FCM 푸시 알림 |
| 서버 | uvicorn | ASGI 서버 |
| 테스트 | pytest + httpx | API 테스트 |

### 4.2 디렉토리 구조

```
backend/
├── app/
│   ├── main.py                    # FastAPI 앱 인스턴스, 미들웨어, 라우터 등록
│   ├── config.py                  # 환경변수 설정 (pydantic-settings)
│   ├── database.py                # async engine, sessionmaker
│   │
│   ├── models/                    # SQLAlchemy ORM 모델
│   │   ├── __init__.py
│   │   ├── user.py                # User 테이블
│   │   ├── device.py              # Device 테이블
│   │   ├── measurement.py         # Measurement 테이블
│   │   └── alert.py               # Alert 테이블
│   │
│   ├── schemas/                   # Pydantic 스키마 (요청/응답)
│   │   ├── auth.py                # LoginRequest, TokenResponse, SignupRequest
│   │   ├── device.py              # DeviceRegister, DeviceResponse, DeviceUpdate
│   │   ├── measurement.py         # MeasurementCreate, MeasurementResponse
│   │   └── alert.py               # AlertResponse, AlertUpdate
│   │
│   ├── api/
│   │   ├── deps.py                # 의존성 (get_db, get_current_user, get_device_auth)
│   │   └── v1/
│   │       ├── __init__.py
│   │       ├── auth.py            # /auth/* 라우터
│   │       ├── devices.py         # /devices/* 라우터
│   │       ├── measurements.py    # /measurements/* 라우터
│   │       ├── alerts.py          # /alerts/* 라우터
│   │       └── ota.py             # /ota/* 라우터
│   │
│   ├── services/                  # 비즈니스 로직
│   │   ├── auth_service.py        # 로그인, OAuth, 토큰 발급
│   │   ├── device_service.py      # 기기 등록/해제/상태 관리
│   │   ├── measurement_service.py # 데이터 수신, 유속 계산, 알림 트리거
│   │   ├── alert_service.py       # 알림 생성, 조건 판단
│   │   └── fcm_service.py         # Firebase 푸시 발송
│   │
│   └── websocket/
│       └── manager.py             # WebSocket 연결 풀 관리, 브로드캐스트
│
├── alembic/                       # DB 마이그레이션
│   ├── versions/
│   └── env.py
├── alembic.ini
│
├── tests/
│   ├── conftest.py                # 테스트 DB, 클라이언트 fixture
│   ├── test_auth.py
│   ├── test_devices.py
│   └── test_measurements.py
│
├── Dockerfile
├── docker-compose.yml             # FastAPI + PostgreSQL + Redis (로컬)
└── requirements.txt
```

### 4.3 API 엔드포인트 전체 목록

#### 인증 (Auth)

| 메서드 | 경로 | 요청자 | 설명 |
|--------|------|--------|------|
| POST | `/api/v1/auth/signup` | 앱 | 이메일 회원가입 |
| POST | `/api/v1/auth/login` | 앱 | 이메일 로그인 → JWT 발급 |
| POST | `/api/v1/auth/oauth/kakao` | 앱 | 카카오 OAuth (인가코드 → JWT) |
| POST | `/api/v1/auth/oauth/google` | 앱 | 구글 OAuth (ID 토큰 → JWT) |
| POST | `/api/v1/auth/refresh` | 앱 | Access Token 갱신 |
| POST | `/api/v1/auth/fcm-token` | 앱 | FCM 토큰 등록/갱신 |
| DELETE | `/api/v1/auth/account` | 앱 | 회원 탈퇴 |

#### 디바이스 (Devices)

| 메서드 | 경로 | 요청자 | 설명 |
|--------|------|--------|------|
| POST | `/api/v1/devices/register` | **ESP32** | 기기 등록 (프로비저닝 후) |
| GET | `/api/v1/devices` | 앱 | 내 기기 목록 |
| GET | `/api/v1/devices/{id}` | 앱 | 기기 상세 정보 |
| GET | `/api/v1/devices/{id}/status` | 앱 | 기기 실시간 상태 |
| PUT | `/api/v1/devices/{id}` | 앱 | 기기 설정 변경 (이름, 알림 설정) |
| DELETE | `/api/v1/devices/{id}` | 앱 | 기기 등록 해제 |
| POST | `/api/v1/devices/{id}/heartbeat` | **ESP32** | 기기 생존 신호 (1분 주기) |

#### 측정 데이터 (Measurements)

| 메서드 | 경로 | 요청자 | 설명 |
|--------|------|--------|------|
| POST | `/api/v1/measurements` | **ESP32** | 측정 데이터 전송 (단건) |
| POST | `/api/v1/measurements/batch` | **ESP32** | 측정 데이터 일괄 전송 (네트워크 복구 시) |
| GET | `/api/v1/measurements/{device_id}` | 앱 | 이력 조회 (페이지네이션, 날짜 필터) |
| GET | `/api/v1/measurements/{device_id}/summary` | 앱 | 일별/시간별 요약 통계 |
| WS | `/api/v1/measurements/{device_id}/realtime` | 앱 | **WebSocket** 실시간 스트림 |

#### 알림 (Alerts)

| 메서드 | 경로 | 요청자 | 설명 |
|--------|------|--------|------|
| GET | `/api/v1/alerts` | 앱 | 알림 목록 (읽음/안읽음 필터) |
| PUT | `/api/v1/alerts/{id}/read` | 앱 | 읽음 처리 |
| PUT | `/api/v1/alerts/read-all` | 앱 | 전체 읽음 처리 |

#### OTA (펌웨어 업데이트)

| 메서드 | 경로 | 요청자 | 설명 |
|--------|------|--------|------|
| GET | `/api/v1/ota/check?current_version=x.x.x` | **ESP32** | 업데이트 확인 |
| GET | `/api/v1/ota/download/{version}` | **ESP32** | 펌웨어 바이너리 다운로드 |

### 4.4 인증 체계

```
┌─────────────────────────────────────────────────────┐
│                    인증 방식 2가지                      │
├─────────────────────┬───────────────────────────────┤
│   앱 사용자 (JWT)    │     ESP32 기기 (API Key)       │
├─────────────────────┼───────────────────────────────┤
│ Authorization:       │ X-Device-Serial: SRG-IV-xxx  │
│   Bearer <jwt>       │ X-Device-Key: <api-key>      │
├─────────────────────┼───────────────────────────────┤
│ Access: 15분         │ 프로비저닝 시 서버가 발급          │
│ Refresh: 7일         │ ESP32 NVS에 저장               │
└─────────────────────┴───────────────────────────────┘
```

### 4.5 알림 트리거 조건

```python
# measurement_service.py 내 알림 판단 로직 (의사코드)

def check_alerts(device, measurement):
    if device.type == "iv_fluid":
        # 수액 잔량 부족 (기본 임계값: 50ml)
        if measurement.remaining_ml <= device.alert_threshold_ml:
            create_alert("low_fluid", "수액 잔량이 {remaining_ml}ml 입니다.")

        # 유속 이상 (이전 측정과 비교하여 유속이 0이 된 경우)
        if measurement.flow_rate_ml_min == 0 and prev.flow_rate_ml_min > 0:
            create_alert("flow_stop", "수액 주입이 멈췄습니다.")

    elif device.type == "urine":
        # 소변통 용량 초과 (기본 임계값: 2000ml)
        if measurement.remaining_ml >= device.alert_threshold_ml:
            create_alert("urine_full", "소변통 교체가 필요합니다.")

    # 공통: 기기 오프라인 (heartbeat 3분 이상 미수신)
    # → 별도 스케줄러(cron job)에서 주기적으로 확인
```

### 4.6 WebSocket 매니저

```python
# websocket/manager.py 핵심 구조

class ConnectionManager:
    """기기별 WebSocket 연결을 관리"""

    # device_id → Set[WebSocket]
    active_connections: dict[str, set[WebSocket]]

    async def connect(self, device_id: str, websocket: WebSocket):
        """앱 클라이언트가 특정 기기의 실시간 데이터 구독"""

    async def disconnect(self, device_id: str, websocket: WebSocket):
        """연결 해제"""

    async def broadcast(self, device_id: str, data: dict):
        """ESP32에서 데이터 수신 시, 해당 기기를 구독 중인 모든 앱에 전달"""

# 사용 흐름:
# 1. ESP32 → POST /measurements → measurement_service에서 처리
# 2. measurement_service → manager.broadcast(device_id, data)
# 3. manager → 해당 device_id를 구독 중인 모든 WebSocket에 전송
```

---

## 5. 데이터베이스 (PostgreSQL on AWS RDS)

### 5.1 ERD (Entity Relationship)

```
┌──────────────┐       ┌──────────────┐       ┌──────────────────┐
│    users     │       │   devices    │       │  measurements    │
├──────────────┤       ├──────────────┤       ├──────────────────┤
│ id (PK,UUID) │◄──┐   │ id (PK,UUID) │◄──┐   │ id (PK,BIGSERIAL)│
│ email        │   │   │ serial_number│   │   │ device_id (FK)   │──►devices.id
│ password_hash│   └───│ owner_id(FK) │   └───│ weight_grams     │
│ provider     │       │ device_type  │       │ flow_rate_ml_min │
│ provider_id  │       │ firmware_ver │       │ remaining_ml     │
│ name         │       │ status       │       │ battery_level    │
│ role         │       │ api_key      │       │ measured_at      │
│ fcm_token    │       │ alert_config │       │ created_at       │
│ created_at   │       │ last_seen_at │       └──────────────────┘
└──────────────┘       │ registered_at│
        │              └──────────────┘        ┌──────────────────┐
        │                     │                │     alerts       │
        │                     │                ├──────────────────┤
        │                     │                │ id (PK,UUID)     │
        └─────────────────────┼───────────────►│ device_id (FK)   │
                              │                │ user_id (FK)     │
                              └───────────────►│ alert_type       │
                                               │ message          │
                                               │ is_read          │
                                               │ created_at       │
                                               └──────────────────┘
```

### 5.2 테이블 상세

#### users

```sql
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   VARCHAR(255),                          -- 소셜 로그인 시 NULL
    provider        VARCHAR(20) NOT NULL DEFAULT 'email',  -- 'email' | 'kakao' | 'google'
    provider_id     VARCHAR(255),                          -- 소셜 로그인 고유 ID
    name            VARCHAR(100) NOT NULL,
    role            VARCHAR(20) NOT NULL DEFAULT 'patient', -- 'patient' | 'nurse' | 'admin'
    fcm_token       VARCHAR(500),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(provider, provider_id)
);
```

#### devices

```sql
CREATE TABLE devices (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    serial_number   VARCHAR(50) UNIQUE NOT NULL,           -- SRG-IV-2024-0001
    device_type     VARCHAR(20) NOT NULL,                  -- 'iv_fluid' | 'urine'
    firmware_version VARCHAR(20),
    status          VARCHAR(20) NOT NULL DEFAULT 'inactive', -- 'active' | 'inactive' | 'error'
    api_key         VARCHAR(255) NOT NULL,                 -- 기기 인증용
    owner_id        UUID REFERENCES users(id) ON DELETE SET NULL,
    alert_config    JSONB DEFAULT '{"threshold_ml": 50, "enabled": true}',
    last_seen_at    TIMESTAMPTZ,
    registered_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    INDEX idx_devices_owner (owner_id),
    INDEX idx_devices_serial (serial_number)
);
```

#### measurements

```sql
CREATE TABLE measurements (
    id              BIGSERIAL PRIMARY KEY,
    device_id       UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    weight_grams    DECIMAL(10,2) NOT NULL,
    flow_rate_ml_min DECIMAL(8,2),                         -- 계산값 (이전 측정과 비교)
    remaining_ml    DECIMAL(8,2),                          -- 계산값 (초기값 - 현재값)
    battery_level   SMALLINT,                              -- 0~100 (%)
    measured_at     TIMESTAMPTZ NOT NULL,                  -- 기기 측정 시각
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),    -- 서버 수신 시각

    INDEX idx_measurements_device_time (device_id, measured_at DESC)
);

-- 파티셔닝 권장 (데이터 증가 대비)
-- PARTITION BY RANGE (measured_at); -- 월별 파티션
```

#### alerts

```sql
CREATE TABLE alerts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id       UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    alert_type      VARCHAR(30) NOT NULL,    -- 'low_fluid' | 'flow_stop' | 'device_offline' | 'urine_full'
    message         TEXT NOT NULL,
    is_read         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    INDEX idx_alerts_user_unread (user_id, is_read, created_at DESC)
);
```

### 5.3 성능 고려사항

| 항목 | 전략 |
|------|------|
| 측정 데이터 증가 | TimescaleDB 확장 또는 월별 파티셔닝 |
| 실시간 조회 | `(device_id, measured_at DESC)` 복합 인덱스 |
| 오래된 데이터 | 90일 이후 S3로 아카이빙 (비용 절감) |
| 연결 풀 | asyncpg 풀 (min=5, max=20) |

---

## 6. AWS 인프라

### 6.1 구성도

```
[인터넷]
    │
    ▼
[Route 53] ── api.smartringer.com
    │
    ▼
[ALB (Application Load Balancer)]
    │  SSL 종료 (ACM 인증서)
    │
    ├──► [ECS Fargate / EC2]  ── FastAPI (uvicorn)
    │         │
    │         ├──► [RDS PostgreSQL]  ── db.t3.micro (프리티어)
    │         │     └── Multi-AZ (프로덕션 시)
    │         │
    │         ├──► [S3]  ── OTA 펌웨어 바이너리
    │         │
    │         └──► [Firebase] ── FCM 푸시 알림
    │
    └──► [CloudWatch]  ── 로그, 메트릭, 알람
```

### 6.2 인프라 단계별 구성

| 단계 | 서비스 | 사양 | 예상 비용 |
|------|--------|------|----------|
| **개발** | EC2 t3.micro | 1 vCPU, 1GB RAM | 프리티어 무료 |
| **개발** | RDS db.t3.micro | PostgreSQL 15, 20GB | 프리티어 무료 |
| **개발** | S3 | 5GB 이하 | 거의 무료 |
| **프로덕션** | ECS Fargate | 0.5 vCPU, 1GB | ~$15/월 |
| **프로덕션** | RDS db.t3.small | Multi-AZ, 50GB | ~$30/월 |
| **프로덕션** | ALB | HTTPS 종료 | ~$20/월 |

---

## 7. 통신 프로토콜 요약

| 구간 | 프로토콜 | 포트 | 인증 | 데이터 형식 |
|------|---------|------|------|-----------|
| ESP32 ↔ 앱 | BLE GATT (프로비저닝 시만) | - | PoP + SRP6a | Protobuf |
| ESP32 → 서버 | HTTPS (TLS 1.2+) | 443 | Device API Key | JSON |
| 앱 ↔ 서버 (API) | HTTPS (TLS 1.2+) | 443 | JWT Bearer | JSON |
| 앱 ↔ 서버 (실시간) | WSS (WebSocket Secure) | 443 | JWT (query param) | JSON |
| 서버 → 앱 (알림) | FCM (Firebase) | - | 서버 키 | JSON payload |

---

## 8. 보안 체크리스트

| 영역 | 항목 | 구현 |
|------|------|------|
| 통신 | 모든 HTTP → HTTPS 강제 | ACM 인증서 + ALB |
| 앱 인증 | JWT (Access 15분 / Refresh 7일) | python-jose + bcrypt |
| 기기 인증 | Serial + API Key 조합 | 프로비저닝 시 서버 발급 |
| BLE | PoP 기반 SRP6a 암호화 | ESP-IDF wifi_provisioning |
| DB | RDS 암호화 (at-rest) | AWS KMS |
| 비밀번호 | bcrypt (cost 12) | passlib |
| 입력 검증 | Pydantic v2 스키마 | FastAPI 자동 적용 |
| 환경변수 | .env (비밀키, DB URL) | pydantic-settings |
| CORS | 앱 도메인만 허용 | FastAPI CORSMiddleware |

---

## 9. ESP32 → 서버 데이터 전송 형식

### 9.1 단건 전송

```json
// POST /api/v1/measurements
// Headers: X-Device-Serial: SRG-IV-2024-0001, X-Device-Key: 
{
    "weight_grams": 523.45,
    "battery_level": 87,
    "measured_at": "2026-03-09T14:30:05.123Z"
}
```

### 9.2 일괄 전송 (네트워크 복구 시)

```json
// POST /api/v1/measurements/batch
{
    "measurements": [
        {"weight_grams": 530.12, "battery_level": 88, "measured_at": "2026-03-09T14:29:00Z"},
        {"weight_grams": 528.34, "battery_level": 88, "measured_at": "2026-03-09T14:29:05Z"},
        {"weight_grams": 526.78, "battery_level": 87, "measured_at": "2026-03-09T14:29:10Z"}
    ]
}
```

### 9.3 서버 응답

```json
// 200 OK
{
    "status": "ok",
    "flow_rate_ml_min": 2.3,
    "remaining_ml": 245.0,
    "ota_available": false
}
```

---

## 10. 파일 구조 요약

```
프로젝트 루트/
├── ARCHITECTURE.md          ← 이 문서 (전체 시스템 아키텍처)
├── HARDWARE.md              ← PCB 회로도 분석 (핀맵, 부품, 전원)
├── system-architecture.html ← 시각적 아키텍처 다이어그램
│
├── firmware/                ← ESP32 펌웨어 (ESP-IDF)
│   └── (미구현)
│
├── backend/                 ← FastAPI 서버
│   └── (미구현)
│
└── flutter_app/             ← Flutter 모바일 앱
    └── (미구현)
```