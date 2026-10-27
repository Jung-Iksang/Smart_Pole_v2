import '../utils/alert_type_config.dart';

/// ESP32 → 앱 BLE notify 프레임 (IV 상태 특성 a3c87504)
///
/// 펌웨어 `ble_wifi_prov.h`의 notifyTelemetry / notifyAlert 와 1:1 대응.
/// `type` 필드가 없으면 기존 notifyIvStatus 프레임(phase 전환)으로 취급한다.
sealed class BleEvent {
  const BleEvent();

  static BleEvent? fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'telemetry':
        return BleTelemetry.fromJson(json);
      case 'alert':
        return BleAlert.fromJson(json);
      default:
        // 구 펌웨어 프레임 {phase, weight, flow, fw, heap} → 텔레메트리로 흡수
        if (json.containsKey('phase')) {
          return BleTelemetry(
            weightG: (json['weight'] as num?)?.toDouble() ?? 0,
            startWeightG: 0,
            flowGps: (json['flow'] as num?)?.toDouble() ?? 0,
            etaSec: -1,
            state: (json['phase'] as String? ?? 'unknown').toLowerCase(),
            deviationPct: null,
            receivedAt: DateTime.now(),
          );
        }
        return null;
    }
  }
}

/// 측정값 프레임
class BleTelemetry extends BleEvent {
  final double weightG;      // 현재 무게 (g) ≈ 잔량 (ml)
  final double startWeightG; // 거치 확인 시점 무게 (g). 0이면 미정
  final double flowGps;      // g/s
  final int etaSec;          // 예상 남은 초. -1이면 미정
  final String state;        // wait | baseline | monitor | stabilize | done | tare
  final double? deviationPct;
  final DateTime receivedAt;

  const BleTelemetry({
    required this.weightG,
    required this.startWeightG,
    required this.flowGps,
    required this.etaSec,
    required this.state,
    required this.deviationPct,
    required this.receivedAt,
  });

  factory BleTelemetry.fromJson(Map<String, dynamic> json) {
    return BleTelemetry(
      weightG: (json['w'] as num?)?.toDouble() ?? 0,
      startWeightG: (json['w0'] as num?)?.toDouble() ?? 0,
      flowGps: (json['flow'] as num?)?.toDouble() ?? 0,
      etaSec: (json['eta'] as num?)?.toInt() ?? -1,
      state: (json['state'] as String? ?? 'unknown').toLowerCase(),
      deviationPct: (json['dev'] as num?)?.toDouble(),
      receivedAt: DateTime.now(),
    );
  }

  /// 잔량 비율(0~100). 시작 무게가 없으면 null.
  int? get remainPercent {
    if (startWeightG <= 0) return null;
    return (weightG / startWeightG * 100).round().clamp(0, 100);
  }

  /// 서버 infusion_status 와 호환되는 값으로 매핑
  String get infusionStatus {
    switch (state) {
      case 'wait':
      case 'tare':
      case 'boot':
        return 'waiting';
      case 'done':
      case 'removed':
        return 'completed';
      default:
        return 'running';
    }
  }

  /// 기준 유속 측정 중(30초)인지
  bool get isBaseline => state == 'baseline';

  /// 유속 (ml/h). 1 g ≈ 1 ml
  double get flowMlPerHour => flowGps > 0 ? flowGps * 3600 : 0;
}

/// 이상 알림 프레임
class BleAlert extends BleEvent {
  static int _nextId = 1;

  final int id;
  final String type;        // flow_fast | flow_slow | flow_stop
  final double? deviationPct;
  final String message;
  final DateTime receivedAt;
  final bool isRead;

  BleAlert({
    int? id,
    required this.type,
    required this.deviationPct,
    required this.message,
    required this.receivedAt,
    this.isRead = false,
  }) : id = id ?? _nextId++;

  factory BleAlert.fromJson(Map<String, dynamic> json) {
    return BleAlert(
      type: json['alert'] as String? ?? 'unknown',
      deviationPct: (json['dev'] as num?)?.toDouble(),
      message: json['msg'] as String? ?? '',
      receivedAt: DateTime.now(),
    );
  }

  String get title => alertConfigFor(type).label;
  bool get isDanger => isDangerAlertType(type);

  BleAlert copyWith({bool? isRead}) => BleAlert(
        id: id,
        type: type,
        deviationPct: deviationPct,
        message: message,
        receivedAt: receivedAt,
        isRead: isRead ?? this.isRead,
      );

  /// "방금 전", "N분 전" (notification_data.dart 와 동일 규칙)
  String get relativeTime {
    final diff = DateTime.now().difference(receivedAt);
    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}
