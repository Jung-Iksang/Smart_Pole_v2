import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/ble_event.dart';
import '../../core/services/local_notification_service.dart';
import '../../core/services/provisioning_service.dart';
import '../../core/utils/ble_permissions.dart';
import 'provisioning_provider.dart';

/// 펌웨어가 광고하는 기본 BLE 이름 (monitor_comms.h: deviceId)
const String defaultBleDeviceName = 'INFUCARE_A1B2';

enum BleLinkStatus { disconnected, scanning, connecting, connected }

/// BLE 직결 모니터 상태 (시연용, 포그라운드 전용, 메모리 보관)
class BleMonitorState {
  final BleLinkStatus status;
  final String deviceName;
  final BleTelemetry? telemetry;
  final List<BleAlert> alerts; // 최신이 앞
  final String? error;

  /// 시연용: 활성 시나리오 (flow_fast | flow_slow | flow_stop). null이면 시연 아님
  final String? demoAlertType;

  /// 시연용: 버튼을 누른 뒤 10초 대기 중
  final bool demoPending;

  /// 시연용: 가상 수액 감소 진행 중 (시작 버튼)
  final bool demoDraining;

  const BleMonitorState({
    this.status = BleLinkStatus.disconnected,
    this.deviceName = defaultBleDeviceName,
    this.telemetry,
    this.alerts = const [],
    this.error,
    this.demoAlertType,
    this.demoPending = false,
    this.demoDraining = false,
  });

  /// 시연 상태(대기 포함)인지. 이 동안 실제 BLE 알림은 무시한다.
  bool get isDemoMode => demoPending || demoAlertType != null;

  /// 시연 시나리오별 하드코딩 유속 (mL/h). 시연 아니면 null.
  double? get demoFlowMlPerHour {
    switch (demoAlertType) {
      case 'flow_fast':
        return 180.0;
      case 'flow_slow':
        return 15.0;
      case 'flow_stop':
        return 0.0;
      default:
        return null;
    }
  }

  bool get isConnected => status == BleLinkStatus.connected;
  bool get isBusy =>
      status == BleLinkStatus.scanning || status == BleLinkStatus.connecting;

  int get unreadCount => alerts.where((a) => !a.isRead).length;

  /// 가장 최근 미읽음 알림 (히어로/안전 카드 표시용)
  BleAlert? get latestUnread {
    for (final a in alerts) {
      if (!a.isRead) return a;
    }
    return null;
  }

  BleMonitorState copyWith({
    BleLinkStatus? status,
    String? deviceName,
    BleTelemetry? telemetry,
    bool clearTelemetry = false,
    List<BleAlert>? alerts,
    String? error,
    bool clearError = false,
    String? demoAlertType,
    bool clearDemoAlertType = false,
    bool? demoPending,
    bool? demoDraining,
  }) {
    return BleMonitorState(
      status: status ?? this.status,
      deviceName: deviceName ?? this.deviceName,
      telemetry: clearTelemetry ? null : (telemetry ?? this.telemetry),
      alerts: alerts ?? this.alerts,
      error: clearError ? null : (error ?? this.error),
      demoAlertType:
          clearDemoAlertType ? null : (demoAlertType ?? this.demoAlertType),
      demoPending: demoPending ?? this.demoPending,
      demoDraining: demoDraining ?? this.demoDraining,
    );
  }
}

class BleMonitorNotifier extends StateNotifier<BleMonitorState> {
  final ProvisioningService _service;
  StreamSubscription<Map<String, dynamic>>? _eventSub;
  StreamSubscription<bool>? _linkSub;
  bool _reconnecting = false;
  bool _userDisconnected = false;
  Timer? _demoTimer;
  Timer? _drainTimer;
  int _drainTick = 0;

  /// 시연용 가상 수액: 시작 90 mL, 총 100 mL, 표시 유속 60 mL/h
  static const double demoStartMl = 90.0;
  static const double demoCapacityMl = 100.0;
  static const double _demoFlowGps = 60.0 / 3600.0;

  BleMonitorNotifier(this._service) : super(const BleMonitorState());

  /// 기기 이름으로 스캔 → 연결 → 이벤트 구독
  Future<void> connect({String? name}) async {
    if (state.isBusy) return;
    final deviceName = name ?? state.deviceName;
    _userDisconnected = false;
    state = state.copyWith(
      status: BleLinkStatus.scanning,
      deviceName: deviceName,
      clearError: true,
    );

    try {
      final readiness = await ensureBlePermissions();
      if (readiness != BleReadiness.ready) {
        throw Exception(bleReadinessMessage(readiness));
      }
      // 알림 배너용 권한 (Android 13+). 거부돼도 화면 표시는 계속된다.
      await LocalNotificationService.instance.requestPermission();

      // 프로비저닝 직후라면 이미 연결돼 있을 수 있다.
      if (_service.isConnected && _service.lastDeviceName == deviceName) {
        debugPrint('[BLE-MON] 기존 연결 재사용');
      } else {
        final device = await _service.scanForDevice(deviceName);
        if (device == null) {
          throw Exception('기기를 찾을 수 없어요. 전원과 거리를 확인해주세요.');
        }
        state = state.copyWith(status: BleLinkStatus.connecting);
        await _service.connectToDevice(device);
      }

      await _subscribe();
      state = state.copyWith(status: BleLinkStatus.connected, clearError: true);
      // 연결 직후 현재 상태 1회 요청
      unawaited(_service.requestStatus());
    } catch (e) {
      debugPrint('[BLE-MON] 연결 실패: $e');
      state = state.copyWith(
        status: BleLinkStatus.disconnected,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// 프로비저닝 플로우가 연결을 열어 둔 경우 그 연결을 이어받는다.
  Future<void> attach() async {
    if (!_service.isConnected || state.isConnected) return;
    try {
      await _subscribe();
      state = state.copyWith(
        status: BleLinkStatus.connected,
        deviceName: _service.lastDeviceName ?? state.deviceName,
        clearError: true,
      );
      unawaited(_service.requestStatus());
    } catch (e) {
      debugPrint('[BLE-MON] attach 실패: $e');
    }
  }

  Future<void> _subscribe() async {
    await _eventSub?.cancel();
    await _linkSub?.cancel();

    _eventSub = _service.watchDeviceEvents().listen(
      _onJson,
      onError: (e) => debugPrint('[BLE-MON] 이벤트 스트림 오류: $e'),
    );

    _linkSub = _service.connectionState.listen((connected) {
      if (connected) return;
      debugPrint('[BLE-MON] 링크 끊김');
      state = state.copyWith(status: BleLinkStatus.disconnected);
      if (!_userDisconnected) unawaited(_tryReconnect());
    });
  }

  void _onJson(Map<String, dynamic> json) {
    final event = BleEvent.fromJson(json);
    switch (event) {
      case BleTelemetry t:
        // 시연용 가상 주입 중에는 실제 측정값을 무시한다
        if (_demoInfusion) break;
        state = state.copyWith(telemetry: t);
      case BleAlert a:
        // 시연 중에는 실제 알림을 무시한다 (화면이 바뀌는 사고 방지)
        if (state.isDemoMode) break;
        _pushAlert(a);
      case null:
        break;
    }
  }

  void _pushAlert(BleAlert a) {
    state = state.copyWith(alerts: [a, ...state.alerts]);
    unawaited(LocalNotificationService.instance.show(
      id: a.id,
      title: a.title,
      body: a.message,
      danger: a.isDanger,
    ));
  }

  // ── 시연용 가상 주입 (하드웨어 없이 90 mL → 감소) ──

  bool _demoInfusion = false;

  BleTelemetry _demoTelemetry(double ml) => BleTelemetry(
        weightG: ml,
        startWeightG: demoCapacityMl,
        flowGps: _demoFlowGps,
        etaSec: -1,
        state: ml <= 0 ? 'done' : 'monitor',
        deviationPct: null,
        receivedAt: DateTime.now(),
      );

  /// 화면 진입 시 호출: 연결됨 + 90 mL 상태로 시작 (감소는 [startDemoDrain] 전까지 없음)
  void startDemoInfusion() {
    if (_demoInfusion) return;
    _demoInfusion = true;
    state = state.copyWith(
      status: BleLinkStatus.connected,
      telemetry: _demoTelemetry(demoStartMl),
      clearError: true,
    );
  }

  /// 시작/정지 토글. 기본 2초에 1 mL, 유속 빠름 1초, 느림 4초, 정지 시 멈춤.
  void toggleDemoDrain() {
    if (state.demoDraining) {
      _drainTimer?.cancel();
      _drainTimer = null;
      state = state.copyWith(demoDraining: false);
      return;
    }
    startDemoInfusion();
    _drainTick = 0;
    _drainTimer?.cancel();
    _drainTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final cur = state.telemetry?.weightG ?? demoStartMl;
      if (cur <= 0) {
        toggleDemoDrain();
        return;
      }
      final int secPerMl;
      switch (state.demoAlertType) {
        case 'flow_fast':
          secPerMl = 1;
        case 'flow_slow':
          secPerMl = 4;
        case 'flow_stop':
          return; // 흐름 정지: 변화 없음
        default:
          secPerMl = 2;
      }
      _drainTick++;
      if (_drainTick % secPerMl != 0) return;
      state = state.copyWith(telemetry: _demoTelemetry(cur - 1));
    });
    state = state.copyWith(demoDraining: true);
  }

  /// 90 mL 로 되돌리고 감소를 멈춘다
  void resetDemoVolume() {
    _drainTimer?.cancel();
    _drainTimer = null;
    _demoInfusion = true;
    state = state.copyWith(
      status: BleLinkStatus.connected,
      telemetry: _demoTelemetry(demoStartMl),
      demoDraining: false,
      clearError: true,
    );
  }

  // ── 시연용 하드코딩 알림 ──

  static const Map<String, (double, String)> _demoAlerts = {
    'flow_fast': (35.0, '기준 유속보다 35% 빠르게 들어가고 있어요. 조절기를 확인해주세요'),
    'flow_slow': (-40.0, '기준 유속보다 40% 느려요. 수액 줄과 높이를 확인해주세요'),
    'flow_stop': (-100.0, '수액 흐름이 멈췄어요. 줄 꺾임이나 혈액 역류 여부를 확인해주세요'),
  };

  /// 시연 시작: 기존 알림 읽음 처리 후 10초 뒤 [alertType] 알림을 주입한다.
  void startDemo(String alertType) {
    final spec = _demoAlerts[alertType];
    if (spec == null) return;
    _demoTimer?.cancel();
    state = state.copyWith(
      alerts: _allRead(),
      demoPending: true,
      clearDemoAlertType: true,
    );
    _demoTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      state = state.copyWith(demoAlertType: alertType, demoPending: false);
      _pushAlert(BleAlert(
        type: alertType,
        deviationPct: spec.$1,
        message: spec.$2,
        receivedAt: DateTime.now(),
      ));
    });
  }

  /// 시연 종료(정상 버튼): 타이머 취소, 전체 읽음 처리, 실제 유속/알림으로 복귀
  void stopDemo() {
    _demoTimer?.cancel();
    _demoTimer = null;
    state = state.copyWith(
      alerts: _allRead(),
      demoPending: false,
      clearDemoAlertType: true,
    );
  }

  List<BleAlert> _allRead() =>
      [for (final a in state.alerts) a.copyWith(isRead: true)];

  Future<void> _tryReconnect() async {
    if (_reconnecting) return;
    _reconnecting = true;
    try {
      state = state.copyWith(status: BleLinkStatus.connecting);
      final ok = await _service.reconnect(maxRetries: 3);
      if (ok) {
        await _subscribe();
        state = state.copyWith(status: BleLinkStatus.connected, clearError: true);
        unawaited(_service.requestStatus());
      } else {
        state = state.copyWith(
          status: BleLinkStatus.disconnected,
          error: '기기와 연결이 끊겼어요. 다시 연결해주세요.',
        );
      }
    } finally {
      _reconnecting = false;
    }
  }

  Future<void> disconnect() async {
    _userDisconnected = true;
    await _eventSub?.cancel();
    await _linkSub?.cancel();
    _eventSub = null;
    _linkSub = null;
    await _service.disconnect();
    state = state.copyWith(
      status: BleLinkStatus.disconnected,
      clearTelemetry: true,
      clearError: true,
    );
  }

  void markRead(int id) {
    state = state.copyWith(
      alerts: [
        for (final a in state.alerts) a.id == id ? a.copyWith(isRead: true) : a,
      ],
    );
  }

  void markAllRead() {
    state = state.copyWith(alerts: _allRead());
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _drainTimer?.cancel();
    _eventSub?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }
}

final bleMonitorProvider =
    StateNotifierProvider<BleMonitorNotifier, BleMonitorState>((ref) {
  final service = ref.watch(provisioningServiceProvider);
  return BleMonitorNotifier(service);
});
