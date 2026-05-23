import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/device_service.dart';
import '../../core/services/provisioning_service.dart';

/// 프로비저닝 플로우 단계
enum ProvisioningStep {
  idle,              // 초기 상태
  scanningBle,       // BLE 기기 검색 중
  connectingBle,     // BLE 연결 중
  bleConnected,      // BLE 연결 완료
  scanningWifi,      // WiFi 스캔 중
  wifiListReady,     // WiFi 목록 준비 완료
  sendingCredentials, // WiFi 자격증명 전송 중
  waitingWifiConnect, // ESP32 WiFi 연결 대기
  registeringDevice,  // 서버에 기기 등록 중
  success,           // 프로비저닝 완료
  error,             // 에러
}

/// 프로비저닝 상태
class ProvisioningState {
  final ProvisioningStep step;
  final DeviceQrData? qrData;
  final List<WifiNetwork> wifiNetworks;
  final String? selectedSsid;
  final String? errorMessage;
  final int? registeredDeviceId;
  /// 에러 발생 시 실패한 단계 (부분 재시도용)
  final ProvisioningStep? failedStep;

  const ProvisioningState({
    this.step = ProvisioningStep.idle,
    this.qrData,
    this.wifiNetworks = const [],
    this.selectedSsid,
    this.errorMessage,
    this.registeredDeviceId,
    this.failedStep,
  });

  ProvisioningState copyWith({
    ProvisioningStep? step,
    DeviceQrData? qrData,
    List<WifiNetwork>? wifiNetworks,
    String? selectedSsid,
    String? errorMessage,
    int? registeredDeviceId,
    ProvisioningStep? failedStep,
  }) {
    return ProvisioningState(
      step: step ?? this.step,
      qrData: qrData ?? this.qrData,
      wifiNetworks: wifiNetworks ?? this.wifiNetworks,
      selectedSsid: selectedSsid ?? this.selectedSsid,
      errorMessage: errorMessage,
      registeredDeviceId: registeredDeviceId ?? this.registeredDeviceId,
      failedStep: failedStep,
    );
  }
}

/// 프로비저닝 상태 관리 Notifier
class ProvisioningNotifier extends StateNotifier<ProvisioningState> {
  final ProvisioningService _service;
  final DeviceService _deviceService;
  StreamSubscription? _wifiStatusSubscription;

  ProvisioningNotifier(this._service, this._deviceService)
      : super(const ProvisioningState());

  /// 외부에서 에러 상태 설정 (권한 거부 등)
  void setError(String message, {ProvisioningStep? failedStep}) {
    state = state.copyWith(
      step: ProvisioningStep.error,
      errorMessage: message,
      failedStep: failedStep,
    );
  }

  /// WiFi 재설정 모드 여부
  bool _forceWifiSetup = false;

  /// WiFi 재설정 모드 설정 (설정 화면에서 호출)
  void setForceWifiSetup(bool force) {
    _forceWifiSetup = force;
  }

  /// QR 스캔 결과 설정 → BLE 기기 검색 → BLE 연결 → WiFi 스캔까지 자동 진행
  Future<void> startProvisioning(DeviceQrData qrData) async {
    state = state.copyWith(
      step: ProvisioningStep.scanningBle,
      qrData: qrData,
      errorMessage: null,
      failedStep: null,
    );

    try {
      // 1. BLE 기기 검색
      final device = await _service.scanForDevice(qrData.name);
      if (device == null) {
        state = state.copyWith(
          step: ProvisioningStep.error,
          errorMessage: '기기를 찾을 수 없습니다.\n기기 전원을 확인해주세요.',
          failedStep: ProvisioningStep.scanningBle,
        );
        return;
      }

      // 2. BLE 연결
      state = state.copyWith(step: ProvisioningStep.connectingBle);
      await _service.connectToDevice(device);
      state = state.copyWith(step: ProvisioningStep.bleConnected);

      // 3. WiFi 재설정 모드가 아니면 → 이미 연결 시 스캔 건너뛰기
      if (!_forceWifiSetup) {
        try {
          final wifiStatus = await _service.readWifiStatus();
          if (wifiStatus == WifiConnectionStatus.connected) {
            debugPrint('[PROV] ESP32 이미 WiFi 연결됨 — 바로 서버 등록');
            await _registerDevice();
            return;
          }
        } catch (e) {
          debugPrint('[PROV] WiFi 상태 읽기 실패 (무시하고 스캔 진행): $e');
        }
      } else {
        debugPrint('[PROV] WiFi 재설정 모드 — 강제 WiFi 스캔');
        _forceWifiSetup = false;  // 플래그 리셋
      }

      // 4. WiFi 스캔
      await scanWifi();
    } catch (e) {
      state = state.copyWith(
        step: ProvisioningStep.error,
        errorMessage: '기기 연결 실패: ${e.toString()}',
        failedStep: ProvisioningStep.connectingBle,
      );
    }
  }

  /// 실패한 단계부터 재시도 (QR 재스캔 불필요)
  /// BLE 끊김 → 재연결, WiFi 실패 → WiFi 재입력, 등록 실패 → 재등록
  Future<void> retryFromLastStep() async {
    final qrData = state.qrData;
    if (qrData == null) return;

    final failedAt = state.failedStep;
    state = state.copyWith(errorMessage: null, failedStep: null);

    try {
      switch (failedAt) {
        case ProvisioningStep.scanningBle:
          // BLE 기기 검색부터 재시도
          await startProvisioning(qrData);
          break;

        case ProvisioningStep.connectingBle:
        case ProvisioningStep.bleConnected:
        case ProvisioningStep.scanningWifi:
          // BLE 재연결 시도 (이미 알고 있는 디바이스)
          state = state.copyWith(step: ProvisioningStep.connectingBle);
          final reconnected = await _service.reconnect();
          if (!reconnected) {
            // 재연결 실패 → 스캔부터 다시
            await startProvisioning(qrData);
            return;
          }
          state = state.copyWith(step: ProvisioningStep.bleConnected);
          await scanWifi();
          break;

        case ProvisioningStep.sendingCredentials:
        case ProvisioningStep.waitingWifiConnect:
          // WiFi 비번 틀렸을 가능성 → WiFi 목록 화면으로 복귀
          if (!_service.isConnected) {
            final reconnected = await _service.reconnect();
            if (!reconnected) {
              await startProvisioning(qrData);
              return;
            }
          }
          await scanWifi();
          break;

        case ProvisioningStep.registeringDevice:
          // 서버 등록만 재시도
          await _registerDevice();
          break;

        default:
          // 알 수 없는 단계 → 처음부터
          await startProvisioning(qrData);
      }
    } catch (e) {
      state = state.copyWith(
        step: ProvisioningStep.error,
        errorMessage: '재시도 실패: ${e.toString()}',
        failedStep: failedAt,
      );
    }
  }

  /// WiFi 스캔 요청
  Future<void> scanWifi() async {
    state = state.copyWith(step: ProvisioningStep.scanningWifi);

    try {
      final networks = await _service.requestWifiScan();
      state = state.copyWith(
        step: ProvisioningStep.wifiListReady,
        wifiNetworks: networks,
      );
    } catch (e) {
      state = state.copyWith(
        step: ProvisioningStep.error,
        errorMessage: 'WiFi 스캔 실패: ${e.toString()}',
        failedStep: ProvisioningStep.scanningWifi,
      );
    }
  }

  /// WiFi 선택
  void selectWifi(String ssid) {
    state = state.copyWith(selectedSsid: ssid);
  }

  /// WiFi 자격증명 전송 → 연결 대기
  Future<void> sendWifiCredentials(String ssid, String password) async {
    state = state.copyWith(
      step: ProvisioningStep.sendingCredentials,
      selectedSsid: ssid,
    );

    try {
      // WiFi 상태 모니터링 시작
      _wifiStatusSubscription?.cancel();
      _wifiStatusSubscription = _service.watchWifiStatus().listen((status) {
        switch (status) {
          case WifiConnectionStatus.connecting:
            state = state.copyWith(step: ProvisioningStep.waitingWifiConnect);
            break;
          case WifiConnectionStatus.connected:
            _wifiStatusSubscription?.cancel();
            _registerDevice();
            break;
          case WifiConnectionStatus.failed:
            state = state.copyWith(
              step: ProvisioningStep.error,
              errorMessage: 'WiFi 연결에 실패했습니다.\n비밀번호를 확인해주세요.',
              failedStep: ProvisioningStep.waitingWifiConnect,
            );
            _wifiStatusSubscription?.cancel();
            break;
          default:
            break;
        }
      });

      // 자격증명 전송
      await _service.sendWifiCredentials(ssid, password);
      state = state.copyWith(step: ProvisioningStep.waitingWifiConnect);

      // 20초 타임아웃 — 상태가 아직 waiting이면 에러
      await Future.delayed(const Duration(seconds: 20));
      if (state.step == ProvisioningStep.waitingWifiConnect) {
        state = state.copyWith(
          step: ProvisioningStep.error,
          errorMessage: 'WiFi 연결 시간이 초과되었습니다.',
          failedStep: ProvisioningStep.waitingWifiConnect,
        );
        _wifiStatusSubscription?.cancel();
      }
    } catch (e) {
      state = state.copyWith(
        step: ProvisioningStep.error,
        errorMessage: 'WiFi 설정 전송 실패: ${e.toString()}',
        failedStep: ProvisioningStep.sendingCredentials,
      );
    }
  }

  /// 서버에 기기 등록
  Future<void> _registerDevice() async {
    final rawQr = state.qrData?.rawQrValue;
    if (rawQr == null || rawQr.isEmpty) {
      state = state.copyWith(
        step: ProvisioningStep.error,
        errorMessage: 'QR 코드 데이터가 없습니다.',
        failedStep: ProvisioningStep.registeringDevice,
      );
      return;
    }

    state = state.copyWith(step: ProvisioningStep.registeringDevice);
    debugPrint('[REG] 기기 등록 시작: rawQr=$rawQr');

    try {
      final result = await _deviceService.registerDevice(rawQr);
      debugPrint('[REG] 기기 등록 성공: $result');
      state = state.copyWith(
        step: ProvisioningStep.success,
        registeredDeviceId: result['device_id'] as int?,
      );
    } on DioException catch (e) {
      debugPrint('[REG] DioException: status=${e.response?.statusCode} body=${e.response?.data}');
      if (e.response?.statusCode == 400) {
        state = state.copyWith(step: ProvisioningStep.success);
      } else {
        state = state.copyWith(
          step: ProvisioningStep.error,
          errorMessage: '서버에 기기 등록을 실패했습니다.\n(${e.response?.statusCode}: ${e.response?.data})',
          failedStep: ProvisioningStep.registeringDevice,
        );
      }
    } catch (e) {
      debugPrint('[REG] 기타 에러: $e');
      state = state.copyWith(
        step: ProvisioningStep.error,
        errorMessage: '기기 등록 실패: ${e.toString()}',
        failedStep: ProvisioningStep.registeringDevice,
      );
    }
  }

  /// ESP32에 리셋 커맨드 전송 (v1.3+ 펌웨어)
  Future<void> sendResetCommand() async {
    await _service.sendResetCommand();
  }

  /// 초기 상태로 리셋
  Future<void> reset() async {
    _wifiStatusSubscription?.cancel();
    await _service.disconnect();
    state = const ProvisioningState();
  }

  @override
  void dispose() {
    _wifiStatusSubscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}

/// Providers
final provisioningServiceProvider = Provider<ProvisioningService>((ref) {
  final service = ProvisioningService();
  ref.onDispose(() => service.dispose());
  return service;
});

final deviceServiceProvider = Provider<DeviceService>((ref) {
  return DeviceService();
});

final provisioningProvider =
    StateNotifierProvider<ProvisioningNotifier, ProvisioningState>((ref) {
  final service = ref.watch(provisioningServiceProvider);
  final deviceService = ref.watch(deviceServiceProvider);
  return ProvisioningNotifier(service, deviceService);
});
