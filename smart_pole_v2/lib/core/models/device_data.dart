import '../../shared/widgets/widgets.dart'; // DeviceStatus enum

/// 기본 수액 세트 gtt factor (일반 성인: 20 gtt/mL)
const int defaultGttFactor = 20;

/// 대시보드 응답 모델
class DashboardData {
  final String patientName;
  final List<IVDeviceData> devices;
  final int unreadNotificationCount;

  const DashboardData({
    required this.patientName,
    required this.devices,
    required this.unreadNotificationCount,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'] as Map<String, dynamic>;
    final deviceList = json['devices'] as List<dynamic>;

    return DashboardData(
      patientName: patient['name'] as String? ?? '',
      devices: deviceList
          .map((d) => IVDeviceData.fromDashboardJson(d as Map<String, dynamic>))
          .toList(),
      unreadNotificationCount: json['unread_notification_count'] as int? ?? 0,
    );
  }
}

/// IV 기기 + 측정 데이터 통합 모델
class IVDeviceData {
  final int deviceId;
  final String deviceName;
  final String connectionStatus;
  final double remainingMl;
  final double dropRate; // drops/min
  final String infusionStatus; // "running" | "stopped" | "paused"
  final int? batteryLevel;
  final String? networkStatus;
  final DateTime? lastSeenAt;
  final DateTime? measuredAt;
  final int? sessionId;
  final double? totalMl;   // 수액 총량 (OCR or 수동 입력)
  final String? fluidName; // 약품명

  const IVDeviceData({
    required this.deviceId,
    required this.deviceName,
    required this.connectionStatus,
    required this.remainingMl,
    required this.dropRate,
    required this.infusionStatus,
    this.batteryLevel,
    this.networkStatus,
    this.lastSeenAt,
    this.measuredAt,
    this.sessionId,
    this.totalMl,
    this.fluidName,
  });

  /// 대시보드 API 응답에서 생성
  factory IVDeviceData.fromDashboardJson(Map<String, dynamic> json) {
    return IVDeviceData(
      deviceId: json['device_id'] as int,
      deviceName: json['device_name'] as String? ?? 'Smart Ringer',
      connectionStatus: json['connection_status'] as String? ?? 'disconnected',
      remainingMl: (json['remaining_ml'] as num?)?.toDouble() ?? 0.0,
      dropRate: (json['drop_rate'] as num?)?.toDouble() ?? 0.0,
      infusionStatus: json['infusion_status'] as String? ?? 'stopped',
      totalMl: (json['total_ml'] as num?)?.toDouble(),
      fluidName: json['fluid_name'] as String?,
      batteryLevel: json['battery_level'] as int?,
    );
  }

  /// 현재 수액 상태 API 응답에서 생성
  factory IVDeviceData.fromCurrentInfusionJson(
    Map<String, dynamic> json, {
    required String deviceName,
    required String connectionStatus,
    int? batteryLevel,
    String? networkStatus,
    DateTime? lastSeenAt,
  }) {
    return IVDeviceData(
      deviceId: json['device_id'] as int,
      deviceName: deviceName,
      connectionStatus: connectionStatus,
      remainingMl: (json['remaining_ml'] as num?)?.toDouble() ?? 0.0,
      dropRate: (json['drop_rate'] as num?)?.toDouble() ?? 0.0,
      infusionStatus: json['infusion_status'] as String? ?? 'stopped',
      measuredAt: json['measured_at'] != null
          ? DateTime.parse(json['measured_at'] as String)
          : null,
      sessionId: json['session_id'] as int?,
      batteryLevel: batteryLevel,
      networkStatus: networkStatus,
      lastSeenAt: lastSeenAt,
    );
  }

  /// WebSocket 실시간 데이터로 업데이트된 복사본
  IVDeviceData copyWithMeasurement(MeasurementUpdate update) {
    return IVDeviceData(
      deviceId: deviceId,
      deviceName: deviceName,
      connectionStatus: connectionStatus,
      remainingMl: update.remainingMl,
      dropRate: update.dropRate,
      infusionStatus: update.infusionStatus,
      batteryLevel: batteryLevel,
      networkStatus: networkStatus,
      lastSeenAt: lastSeenAt,
      measuredAt: update.measuredAt,
      sessionId: sessionId,
      totalMl: totalMl,
      fluidName: fluidName,
    );
  }

  /// 기기 상세 정보 병합
  IVDeviceData copyWithDeviceDetail(Map<String, dynamic> detail) {
    return IVDeviceData(
      deviceId: deviceId,
      deviceName: deviceName,
      connectionStatus: connectionStatus,
      remainingMl: remainingMl,
      dropRate: dropRate,
      infusionStatus: infusionStatus,
      batteryLevel: detail['battery_level'] as int?,
      networkStatus: detail['network_status'] as String?,
      lastSeenAt: detail['last_seen_at'] != null
          ? DateTime.parse(detail['last_seen_at'] as String)
          : lastSeenAt,
      measuredAt: measuredAt,
      sessionId: sessionId,
      totalMl: totalMl,
      fluidName: fluidName,
    );
  }

  // ── 계산 필드 ──

  /// 유속 (mL/h) = (drops_per_min / gtt_factor) × 60
  double get flowRateMlPerHour {
    if (dropRate <= 0) return 0.0;
    return (dropRate / defaultGttFactor) * 60;
  }

  /// 예상 남은 시간 (분)
  double get etaMinutes {
    final rate = flowRateMlPerHour;
    if (rate <= 0 || remainingMl <= 0) return 0.0;
    return (remainingMl / rate) * 60;
  }

  /// 예상 남은 시간 포맷 ("2시간 10분", "22분")
  String get eta {
    final mins = etaMinutes;
    if (mins <= 0) return '';
    // 유속이 너무 낮아 ETA가 48시간 초과면 "측정 중"
    if (mins > 48 * 60) return '측정 중';
    final hours = mins ~/ 60;
    final remainMins = (mins % 60).round();
    if (hours > 0 && remainMins > 0) return '$hours시간 $remainMins분';
    if (hours > 0) return '$hours시간';
    return '$remainMins분';
  }

  /// 유속 텍스트 (mL/h)
  String get speedText {
    final rate = flowRateMlPerHour;
    if (rate <= 0) return '—';
    return '${rate.toStringAsFixed(1)} mL/h';
  }

  /// 마지막 업데이트 상대 시간
  String get lastUpdateText {
    final ts = measuredAt ?? lastSeenAt;
    if (ts == null) return '—';
    final diff = DateTime.now().difference(ts);
    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  /// 연결 상태
  bool get isConnected => connectionStatus == 'connected';

  /// 수액 대기 상태 (정보 입력됨, 측정 대기)
  bool get isWaiting => infusionStatus == 'waiting';

  /// DeviceStatus enum 매핑
  DeviceStatus get status {
    if (infusionStatus == 'stopped' || infusionStatus == 'completed') {
      return DeviceStatus.ended;
    }
    if (infusionStatus == 'waiting') return DeviceStatus.normal;
    if (!isConnected) return DeviceStatus.off;
    if (remainingMl > 0 && totalMl != null && totalMl! > 0) {
      if (remainingMl / totalMl! <= 0.2) return DeviceStatus.warning;
    }
    if (remainingMl <= 100 && remainingMl > 0) return DeviceStatus.warning;
    if (dropRate == 0 && infusionStatus == 'running') return DeviceStatus.warning;
    return DeviceStatus.normal;
  }

  /// 상태 라벨 (한국어)
  String get statusLabel {
    if (isWaiting) return '수액 대기 중';
    switch (status) {
      case DeviceStatus.normal:
      case DeviceStatus.active:
        return '정상 주입 중';
      case DeviceStatus.warning:
        if (dropRate == 0) return '흐름 중단';
        return '주의 필요';
      case DeviceStatus.ended:
        return '주입 종료됨';
      case DeviceStatus.off:
        return '연결 끊김';
    }
  }

  /// 상태 부제목
  String get statusSub {
    if (isWaiting) return '수액이 연결되면 1분~2분 후 자동으로 모니터링이 시작돼요';
    switch (status) {
      case DeviceStatus.normal:
      case DeviceStatus.active:
        return '현재 수액이 안정적으로 진행되고 있어요';
      case DeviceStatus.warning:
        if (dropRate == 0) return '수액 흐름이 감지되지 않아요';
        return '수액 잔량이 얼마 남지 않았어요';
      case DeviceStatus.ended:
        return '수액 주입이 완료되었어요';
      case DeviceStatus.off:
        return '기기와 연결이 끊겼어요';
    }
  }
}

/// WebSocket 실시간 측정 데이터
class MeasurementUpdate {
  final int logId;
  final double remainingMl;
  final double dropRate;
  final String infusionStatus;
  final DateTime measuredAt;

  const MeasurementUpdate({
    required this.logId,
    required this.remainingMl,
    required this.dropRate,
    required this.infusionStatus,
    required this.measuredAt,
  });

  factory MeasurementUpdate.fromJson(Map<String, dynamic> json) {
    return MeasurementUpdate(
      logId: json['log_id'] as int,
      remainingMl: (json['remaining_ml'] as num).toDouble(),
      dropRate: (json['drop_rate'] as num).toDouble(),
      infusionStatus: json['infusion_status'] as String,
      measuredAt: DateTime.parse(json['measured_at'] as String),
    );
  }
}
