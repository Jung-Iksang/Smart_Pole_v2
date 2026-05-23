import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/device_data.dart';
import '../../core/services/measurement_service.dart';
import '../../core/services/realtime_service.dart';

// ── 서비스 프로바이더 ──

final measurementServiceProvider = Provider<MeasurementService>((ref) {
  return MeasurementService();
});

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ── 대시보드 프로바이더 ──

/// 대시보드 데이터 (기기 목록 + 최신 측정값)
final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardData>(
  DashboardNotifier.new,
);

class DashboardNotifier extends AsyncNotifier<DashboardData> {
  @override
  Future<DashboardData> build() => _fetch();

  Future<DashboardData> _fetch() async {
    final service = ref.read(measurementServiceProvider);
    return service.getDashboard();
  }

  /// 새로고침 (이전 데이터 유지하면서 백그라운드 갱신)
  Future<void> refresh() async {
    final newState = await AsyncValue.guard(_fetch);
    if (newState.hasValue) {
      state = newState;
    }
  }

  /// WebSocket에서 받은 실시간 데이터로 특정 기기 업데이트
  void updateDevice(int deviceId, MeasurementUpdate update) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedDevices = current.devices.map((d) {
      if (d.deviceId == deviceId) {
        return d.copyWithMeasurement(update);
      }
      return d;
    }).toList();

    state = AsyncValue.data(DashboardData(
      patientName: current.patientName,
      devices: updatedDevices,
      unreadNotificationCount: current.unreadNotificationCount,
    ));
  }
}

// ── 선택된 기기 ──

/// 현재 선택된 기기 ID
final selectedDeviceIdProvider = StateProvider<int?>((ref) {
  // 대시보드의 첫 번째 기기를 기본 선택
  final dashboard = ref.watch(dashboardProvider).valueOrNull;
  if (dashboard != null && dashboard.devices.isNotEmpty) {
    return dashboard.devices.first.deviceId;
  }
  return null;
});

/// 현재 선택된 기기 데이터
final selectedDeviceProvider = Provider<IVDeviceData?>((ref) {
  final deviceId = ref.watch(selectedDeviceIdProvider);
  final dashboard = ref.watch(dashboardProvider).valueOrNull;
  if (deviceId == null || dashboard == null) return null;

  try {
    return dashboard.devices.firstWhere((d) => d.deviceId == deviceId);
  } catch (_) {
    return dashboard.devices.isNotEmpty ? dashboard.devices.first : null;
  }
});

// ── 실시간 WebSocket 스트림 ──

/// 선택된 기기의 실시간 측정 데이터 스트림
final realtimeStreamProvider = StreamProvider.autoDispose<MeasurementUpdate>((ref) {
  final deviceId = ref.watch(selectedDeviceIdProvider);
  if (deviceId == null) return const Stream.empty();

  final service = ref.read(realtimeServiceProvider);
  final stream = service.connect(deviceId);

  // 실시간 데이터를 대시보드에도 반영
  final subscription = stream.listen((update) {
    ref.read(dashboardProvider.notifier).updateDevice(deviceId, update);
  });

  ref.onDispose(() {
    subscription.cancel();
    service.disconnect();
  });

  return stream;
});
