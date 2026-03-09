# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Smart Ringer - IoT medical monitoring system for IV fluid and urine bag weight measurement in hospitals. The system consists of three layers:

1. **ESP32 Firmware** - Load cell sensor reading via ADS1232 24-bit ADC, WiFi/BLE communication
2. **Flutter Mobile App** - Cross-platform iOS/Android app for real-time monitoring
3. **FastAPI Backend** - REST API + WebSocket server with PostgreSQL on AWS

## Architecture

```
ESP32+ADS1232 ──HTTPS POST──► FastAPI ──asyncpg──► PostgreSQL (AWS RDS)
      │                          │
      └──BLE Provisioning──► Flutter App ◄──WebSocket/REST──┘
                                 │
                          FCM Push Notifications
```

### Data Flow
1. Load cell → ADS1232 (24-bit ADC) → ESP32 → HTTPS POST → FastAPI → PostgreSQL
2. FastAPI → WebSocket → Flutter App (real-time)
3. FastAPI → FCM Push → Flutter App (alerts)

### Device Types
- `iv_fluid`: IV bag weight decrease monitoring (alerts: low fluid, flow stop)
- `urine`: Urine bag weight increase monitoring (alerts: capacity exceeded)

## Technology Stack

### Firmware (ESP-IDF)
- ESP32-WROOM-32E with ADS1232IPWR (24-bit ADC)
- BLE provisioning for WiFi setup
- HTTPS for sensor data transmission

### Flutter App
- State management: `flutter_riverpod`
- Routing: `go_router`
- HTTP: `dio` with JWT interceptors
- WebSocket: `web_socket_channel`
- BLE: `esp_provisioning_wifi`
- Charts: `fl_chart`
- Auth: Kakao/Google OAuth + email

### Backend
- FastAPI (Python 3.11+) with async
- SQLAlchemy 2.0 + asyncpg
- Alembic migrations
- JWT auth (python-jose)
- Firebase Admin for FCM

## Key GPIO Mapping (ESP32 → ADS1232)

```c
#define PIN_ADS1232_DOUT    19   // Data output + conversion ready
#define PIN_ADS1232_SCLK    18   // Serial clock
#define PIN_ADS1232_PDWN     5   // Power down control (HIGH=normal)
#define PIN_ADS1232_GAIN1   32   // Gain bit 1
#define PIN_ADS1232_GAIN0   33   // Gain bit 0
```

**Gain Settings**: GAIN1=HIGH, GAIN0=LOW for 64x (standard load cell)

## Authentication

| Client | Method |
|--------|--------|
| Mobile App | JWT Bearer token (Access: 15min, Refresh: 7 days) |
| ESP32 Device | `X-Device-Serial` + `X-Device-Key` headers |

## Project Structure (Target)

```
├── firmware/           # ESP32 (ESP-IDF)
├── flutter_app/        # Flutter mobile app
│   └── lib/
│       ├── core/       # Network, BLE, storage utilities
│       ├── features/   # auth, device_setup, monitoring, alerts, settings
│       └── shared/     # Common widgets and providers
└── backend/            # FastAPI server
    └── app/
        ├── api/v1/     # Route handlers
        ├── models/     # SQLAlchemy models
        ├── schemas/    # Pydantic schemas
        └── services/   # Business logic
```

## API Endpoints (Key)

- `POST /api/v1/measurements` - ESP32 sensor data (single)
- `POST /api/v1/measurements/batch` - ESP32 batch upload (after reconnect)
- `WS /api/v1/measurements/{device_id}/realtime` - Real-time stream
- `POST /api/v1/devices/register` - Device registration after provisioning
- `POST /api/v1/devices/{id}/heartbeat` - Device keepalive (1 min interval)
- `GET /api/v1/ota/check` - Firmware update check

## BLE Provisioning Flow

1. QR scan (device serial, type, PoP key)
2. BLE connect to "SRINGER_XXXX"
3. Send WiFi credentials (AES-CTR encrypted)
4. Device connects to WiFi and registers with server

## Development Notes

- ADS1232 requires custom driver (NOT HX711 compatible)
- ADC2 pins unavailable during WiFi operation (use ADS1232's dedicated interface)
- IO12 must NOT be pulled HIGH at boot (causes flash voltage error)
- Device offline detection: heartbeat missing for 3+ minutes
