import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// ESP32 BLE GATT UUIDs (ble_wifi_prov.h 와 일치)
class EspBleUuids {
  static final service = Guid('4fafc201-1fb5-459e-8fcc-c5c9c331914b');
  static final wifiScan = Guid('a3c87500-8ed3-4bdf-8a39-a01bebede295');
  static final wifiCred = Guid('a3c87501-8ed3-4bdf-8a39-a01bebede295');
  static final wifiStat = Guid('a3c87502-8ed3-4bdf-8a39-a01bebede295');
  // v1.3+ 새 특성
  static final command = Guid('a3c87503-8ed3-4bdf-8a39-a01bebede295');
  static final ivStatus = Guid('a3c87504-8ed3-4bdf-8a39-a01bebede295');
}

/// WiFi 상태 코드 (ESP32와 동일)
enum WifiConnectionStatus {
  idle,       // 0
  connecting, // 1
  connected,  // 2
  failed,     // 3
  scanning,   // 4
}

/// ESP32 IV 상태 (BLE notify로 수신)
class IvDeviceStatus {
  final String phase;
  final double weight;
  final double flowRate;
  final String fwVersion;
  final int freeHeap;

  const IvDeviceStatus({
    required this.phase,
    required this.weight,
    required this.flowRate,
    required this.fwVersion,
    required this.freeHeap,
  });

  factory IvDeviceStatus.fromJson(Map<String, dynamic> json) {
    return IvDeviceStatus(
      phase: json['phase'] as String? ?? 'unknown',
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      flowRate: (json['flow'] as num?)?.toDouble() ?? 0,
      fwVersion: json['fw'] as String? ?? '',
      freeHeap: json['heap'] as int? ?? 0,
    );
  }
}

/// 스캔된 WiFi 네트워크 정보
class WifiNetwork {
  final String ssid;
  final int rssi;
  final bool isSecured;

  const WifiNetwork({
    required this.ssid,
    required this.rssi,
    required this.isSecured,
  });

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    return WifiNetwork(
      ssid: json['ssid'] as String? ?? '',
      rssi: json['rssi'] as int? ?? -100,
      isSecured: (json['auth'] as int? ?? 1) == 1,
    );
  }

  /// 신호 강도 레벨 (0~3)
  int get signalLevel {
    if (rssi >= -50) return 3;
    if (rssi >= -70) return 2;
    if (rssi >= -85) return 1;
    return 0;
  }
}

/// QR 코드에서 파싱한 기기 정보
class DeviceQrData {
  final String name;       // BLE 기기 이름 (예: IVPOLE_AABBCC)
  final String pop;        // Proof of Possession
  final String rawQrValue; // 서버 등록용 원본 QR JSON 문자열

  const DeviceQrData({
    required this.name,
    required this.pop,
    required this.rawQrValue,
  });

  factory DeviceQrData.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return DeviceQrData(
      name: json['name'] as String? ?? '',
      pop: json['pop'] as String? ?? '',
      rawQrValue: jsonStr,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'pop': pop};
}

/// BLE WiFi 프로비저닝 서비스
/// ESP32와 BLE GATT로 통신하여 WiFi 설정을 전달
class ProvisioningService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _wifiScanChar;
  BluetoothCharacteristic? _wifiCredChar;
  BluetoothCharacteristic? _wifiStatChar;
  BluetoothCharacteristic? _cmdChar;
  BluetoothCharacteristic? _ivStatusChar;

  StreamSubscription? _connectionSubscription;
  StreamSubscription? _scanNotifySubscription;
  StreamSubscription? _statusNotifySubscription;
  StreamSubscription? _ivStatusSubscription;

  bool get isConnected => _device?.isConnected ?? false;

  /// 마지막으로 연결했던 디바이스 이름 (재연결용)
  String? get lastDeviceName =>
      _device?.platformName.isNotEmpty == true ? _device!.platformName : null;

  /// BLE 스캔으로 ESP32 기기 찾기
  /// [deviceName] QR에서 읽은 기기 이름 (예: INFUCARE_A1B2)
  /// 타임아웃 15초
  Future<BluetoothDevice?> scanForDevice(String deviceName) async {
    final completer = Completer<BluetoothDevice?>();
    StreamSubscription? scanSubscription;

    // 타임아웃 설정
    final timer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        scanSubscription?.cancel();
        FlutterBluePlus.stopScan();
        completer.complete(null);
      }
    });

    scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        final name = result.device.platformName;
        if (name == deviceName) {
          timer.cancel();
          scanSubscription?.cancel();
          FlutterBluePlus.stopScan();
          if (!completer.isCompleted) {
            completer.complete(result.device);
          }
          return;
        }
      }
    });

    await FlutterBluePlus.startScan(
      withNames: [deviceName],
      timeout: const Duration(seconds: 15),
    );

    return completer.future;
  }

  /// BLE 기기에 연결하고 서비스/캐릭터리스틱 탐색
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _device = device;

      debugPrint('[BLE] 연결 시도: ${device.platformName}');
      await device.connect(timeout: const Duration(seconds: 10));
      debugPrint('[BLE] 연결 완료');

      // MTU 요청 (JSON 데이터 전송을 위해)
      debugPrint('[BLE] MTU 요청...');
      await device.requestMtu(512);
      debugPrint('[BLE] MTU 완료');

      // 서비스 탐색 + 캐릭터리스틱 매핑
      await _discoverCharacteristics();

      debugPrint('[BLE] 캐릭터리스틱: scan=${_wifiScanChar != null}, cred=${_wifiCredChar != null}, stat=${_wifiStatChar != null}, cmd=${_cmdChar != null}, iv=${_ivStatusChar != null}');

      if (_wifiScanChar == null || _wifiCredChar == null || _wifiStatChar == null) {
        throw Exception('필수 BLE 캐릭터리스틱을 찾을 수 없습니다');
      }

      return true;
    } catch (e) {
      debugPrint('[BLE] connectToDevice 실패: $e');
      await disconnect();
      rethrow;
    }
  }

  /// 이미 알고 있는 디바이스에 재연결 (QR 재스캔 불필요)
  /// BLE 끊김 후 자동 재연결에 사용
  /// 최대 [maxRetries]회 시도, 실패 시 false 반환
  Future<bool> reconnect({int maxRetries = 3}) async {
    if (_device == null) return false;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      debugPrint('[BLE] 재연결 시도 $attempt/$maxRetries');
      try {
        // 기존 구독 정리
        _scanNotifySubscription?.cancel();
        _statusNotifySubscription?.cancel();
        _ivStatusSubscription?.cancel();

        await _device!.connect(timeout: const Duration(seconds: 10));
        await _device!.requestMtu(512);
        await _discoverCharacteristics();

        if (_wifiScanChar == null || _wifiCredChar == null || _wifiStatChar == null) {
          throw Exception('캐릭터리스틱 탐색 실패');
        }

        debugPrint('[BLE] 재연결 성공');
        return true;
      } catch (e) {
        debugPrint('[BLE] 재연결 실패 ($attempt/$maxRetries): $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt)); // 점진적 대기
        }
      }
    }
    return false;
  }

  /// 서비스 탐색 후 캐릭터리스틱 매핑 (공통 로직)
  Future<void> _discoverCharacteristics() async {
    if (_device == null) throw Exception('디바이스가 없습니다');

    debugPrint('[BLE] 서비스 탐색 시작...');
    final services = await _device!.discoverServices();
    debugPrint('[BLE] 서비스 탐색 완료: ${services.length}개');
    final provService = services.firstWhere(
      (s) => s.serviceUuid == EspBleUuids.service,
      orElse: () => throw Exception('프로비저닝 서비스를 찾을 수 없습니다'),
    );

    // 캐릭터리스틱 초기화
    _wifiScanChar = null;
    _wifiCredChar = null;
    _wifiStatChar = null;
    _cmdChar = null;
    _ivStatusChar = null;

    for (final c in provService.characteristics) {
      if (c.characteristicUuid == EspBleUuids.wifiScan) {
        _wifiScanChar = c;
      } else if (c.characteristicUuid == EspBleUuids.wifiCred) {
        _wifiCredChar = c;
      } else if (c.characteristicUuid == EspBleUuids.wifiStat) {
        _wifiStatChar = c;
      } else if (c.characteristicUuid == EspBleUuids.command) {
        _cmdChar = c;
      } else if (c.characteristicUuid == EspBleUuids.ivStatus) {
        _ivStatusChar = c;
      }
    }

    // v1.3+ 특성은 선택적 (이전 펌웨어 호환)
    if (_cmdChar != null) {
      debugPrint('[BLE] v1.3+ 커맨드 특성 발견');
    }
    if (_ivStatusChar != null) {
      debugPrint('[BLE] v1.3+ IV 상태 특성 발견');
    }
  }

  /// ESP32에 WiFi 스캔 요청 → 결과를 WiFi 목록으로 반환
  /// ESP32는 큰 JSON을 20바이트 청크로 나눠 notify하고, 끝에 '\n' 마커를 보냄
  Future<List<WifiNetwork>> requestWifiScan() async {
    if (_wifiScanChar == null) throw Exception('BLE 연결이 필요합니다');

    final completer = Completer<List<WifiNetwork>>();
    final buffer = StringBuffer();

    // 기존 구독 정리
    _scanNotifySubscription?.cancel();

    // Notify 활성화
    await _wifiScanChar!.setNotifyValue(true);

    // listener 등록
    _scanNotifySubscription = _wifiScanChar!.onValueReceived.listen((value) {
      if (value.isEmpty || completer.isCompleted) return;

      // write 트리거(0x01 등)가 notify 스트림에 섞이는 경우 무시
      if (value.length == 1 && value[0] < 0x20 && value[0] != 0x0A) return;

      final chunk = utf8.decode(value, allowMalformed: true);
      debugPrint('[BLE] 청크 수신 (${value.length}B): $chunk');

      // 끝 마커: '\n'이 포함되면 전송 완료
      if (chunk.contains('\n')) {
        final beforeNewline = chunk.split('\n').first;
        if (beforeNewline.isNotEmpty) {
          buffer.write(beforeNewline);
        }
        try {
          final jsonStr = buffer.toString();
          debugPrint('[BLE] 전체 JSON (${jsonStr.length}B): ${jsonStr.substring(0, jsonStr.length.clamp(0, 200))}');
          final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;
          final networks = jsonList
              .map((e) => WifiNetwork.fromJson(e as Map<String, dynamic>))
              .where((n) => n.ssid.isNotEmpty)
              .toList();

          networks.sort((a, b) => b.rssi.compareTo(a.rssi));

          if (!completer.isCompleted) {
            completer.complete(networks);
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(Exception('WiFi 스캔 결과 파싱 실패: $e'));
          }
        }
      } else {
        buffer.write(chunk);
      }
    });

    // notify 구독이 확실히 활성화될 때까지 대기
    await Future.delayed(const Duration(milliseconds: 500));

    // 스캔 요청 (아무 1바이트 전송)
    debugPrint('[BLE] WiFi 스캔 요청 write(0x01)');
    await _wifiScanChar!.write([0x01], withoutResponse: false);

    // 타임아웃 20초 (스캔 + 청크 전송 시간)
    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        debugPrint('[BLE] 타임아웃 — 버퍼 내용: ${buffer.toString()}');
        _scanNotifySubscription?.cancel();
        throw TimeoutException('WiFi 스캔 시간 초과');
      },
    );
  }

  /// WiFi 자격증명을 ESP32에 전송
  Future<void> sendWifiCredentials(String ssid, String password) async {
    if (_wifiCredChar == null) throw Exception('BLE 연결이 필요합니다');

    final json = jsonEncode({'ssid': ssid, 'pw': password});
    await _wifiCredChar!.write(utf8.encode(json), withoutResponse: false);
  }

  /// WiFi 연결 상태 스트림 구독
  Stream<WifiConnectionStatus> watchWifiStatus() async* {
    if (_wifiStatChar == null) throw Exception('BLE 연결이 필요합니다');

    await _wifiStatChar!.setNotifyValue(true);

    await for (final value in _wifiStatChar!.onValueReceived) {
      if (value.isNotEmpty) {
        final raw = utf8.decode(value, allowMalformed: true);
        debugPrint('[BLE] WiFi 상태 수신 (${value.length}B): $raw');
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final state = json['state'] as String? ?? 'idle';
          debugPrint('[BLE] WiFi 상태 파싱: state=$state');
          yield _parseWifiState(state);
        } catch (e) {
          debugPrint('[BLE] WiFi 상태 JSON 파싱 실패: $e — fallback 시도');
          if (value[0] < WifiConnectionStatus.values.length) {
            debugPrint('[BLE] fallback: value[0]=${value[0]} → ${WifiConnectionStatus.values[value[0]]}');
            yield WifiConnectionStatus.values[value[0]];
          }
        }
      }
    }
  }

  /// 현재 WiFi 연결 상태 읽기 (5초 타임아웃)
  Future<WifiConnectionStatus> readWifiStatus() async {
    if (_wifiStatChar == null) throw Exception('BLE 연결이 필요합니다');

    try {
      final value = await _wifiStatChar!.read().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[BLE] WiFi 상태 읽기 타임아웃');
          return <int>[];
        },
      );
      if (value.isNotEmpty) {
        final jsonStr = utf8.decode(value, allowMalformed: true);
        debugPrint('[BLE] WiFi 상태 읽기: $jsonStr');
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final state = json['state'] as String? ?? 'idle';
          return _parseWifiState(state);
        } catch (_) {
          if (value[0] < WifiConnectionStatus.values.length) {
            return WifiConnectionStatus.values[value[0]];
          }
        }
      }
    } catch (e) {
      debugPrint('[BLE] WiFi 상태 읽기 실패: $e');
    }
    return WifiConnectionStatus.idle;
  }

  WifiConnectionStatus _parseWifiState(String state) {
    switch (state) {
      case 'connecting': return WifiConnectionStatus.connecting;
      case 'connected':  return WifiConnectionStatus.connected;
      case 'failed':     return WifiConnectionStatus.failed;
      case 'scanning':   return WifiConnectionStatus.scanning;
      default:           return WifiConnectionStatus.idle;
    }
  }

  // ── v1.3+ BLE 커맨드 ──────────────────────────────────────────

  /// ESP32에 리셋 커맨드 전송 (IV 상태 → PHASE_TARE)
  Future<void> sendResetCommand() async {
    if (_cmdChar == null) {
      debugPrint('[BLE] 커맨드 특성 없음 (v1.2 이하 펌웨어)');
      return;
    }
    final json = jsonEncode({'cmd': 'reset'});
    await _cmdChar!.write(utf8.encode(json), withoutResponse: false);
    debugPrint('[BLE] reset 커맨드 전송');
  }

  /// ESP32에 상태 요청 커맨드 전송 → IV Status notify 트리거
  Future<void> requestStatus() async {
    if (_cmdChar == null) {
      debugPrint('[BLE] 커맨드 특성 없음 (v1.2 이하 펌웨어)');
      return;
    }
    final json = jsonEncode({'cmd': 'status'});
    await _cmdChar!.write(utf8.encode(json), withoutResponse: false);
    debugPrint('[BLE] status 커맨드 전송');
  }

  /// ESP32에 영점(tare) 커맨드 전송
  Future<void> sendTareCommand() async {
    if (_cmdChar == null) {
      debugPrint('[BLE] 커맨드 특성 없음 (v1.2 이하 펌웨어)');
      return;
    }
    final json = jsonEncode({'cmd': 'tare'});
    await _cmdChar!.write(utf8.encode(json), withoutResponse: false);
    debugPrint('[BLE] tare 커맨드 전송');
  }

  /// IV 상태 notify 스트림 구독
  /// ESP32가 phase 전환 시 자동으로 JSON notify 전송
  Stream<IvDeviceStatus> watchIvStatus() async* {
    if (_ivStatusChar == null) {
      debugPrint('[BLE] IV 상태 특성 없음 (v1.2 이하 펌웨어)');
      return;
    }

    await _ivStatusChar!.setNotifyValue(true);

    await for (final value in _ivStatusChar!.onValueReceived) {
      if (value.isNotEmpty) {
        try {
          final raw = utf8.decode(value, allowMalformed: true);
          debugPrint('[BLE] IV 상태 수신: $raw');
          final json = jsonDecode(raw) as Map<String, dynamic>;
          yield IvDeviceStatus.fromJson(json);
        } catch (e) {
          debugPrint('[BLE] IV 상태 파싱 실패: $e');
        }
      }
    }
  }

  /// v1.3+ 커맨드 특성 사용 가능 여부
  bool get supportsCommands => _cmdChar != null;

  /// v1.3+ IV 상태 특성 사용 가능 여부
  bool get supportsIvStatus => _ivStatusChar != null;

  /// BLE 연결 해제 및 리소스 정리
  Future<void> disconnect() async {
    _scanNotifySubscription?.cancel();
    _statusNotifySubscription?.cancel();
    _connectionSubscription?.cancel();
    _ivStatusSubscription?.cancel();

    try {
      if (_device?.isConnected ?? false) {
        await _device?.disconnect();
      }
    } catch (_) {}

    _device = null;
    _wifiScanChar = null;
    _wifiCredChar = null;
    _wifiStatChar = null;
    _cmdChar = null;
    _ivStatusChar = null;
  }

  void dispose() {
    disconnect();
  }
}
