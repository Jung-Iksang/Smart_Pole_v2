import '../models/device_data.dart';
import 'api_client.dart';

/// 수액 측정 데이터 REST API 서비스
class MeasurementService {
  final ApiClient _client = ApiClient.instance;

  /// 대시보드 조회 (전체 기기 목록 + 최신 측정값)
  Future<DashboardData> getDashboard() async {
    final response = await _client.dio.get('/dashboard');
    return DashboardData.fromJson(response.data as Map<String, dynamic>);
  }

  /// 수액 종료 확인 — completed 세션을 아카이브하여 수액 준비 화면으로 전환
  Future<void> acknowledgeCompletion(int deviceId) async {
    await _client.dio.post(
      '/devices/$deviceId/infusion/acknowledge-completion',
    );
  }

  /// 특정 기기의 현재 수액 상태
  Future<Map<String, dynamic>> getCurrentInfusion(int deviceId) async {
    final response = await _client.dio.get(
      '/devices/$deviceId/infusion/current',
      queryParameters: {'device_id': deviceId},
    );
    return response.data as Map<String, dynamic>;
  }

  /// 기기 상세 정보 (배터리, 네트워크 상태 등)
  Future<Map<String, dynamic>> getDeviceDetail(int deviceId) async {
    final response = await _client.dio.get('/devices/$deviceId');
    return response.data as Map<String, dynamic>;
  }

  /// 특정 기기의 전체 데이터 조합 (infusion + device detail)
  Future<IVDeviceData> getFullDeviceData(int deviceId) async {
    final results = await Future.wait([
      getCurrentInfusion(deviceId),
      getDeviceDetail(deviceId),
    ]);

    final infusion = results[0];
    final detail = results[1];

    return IVDeviceData.fromCurrentInfusionJson(
      infusion,
      deviceName: detail['device_name'] as String? ?? 'Smart Ringer',
      connectionStatus: 'connected',
      batteryLevel: detail['battery_level'] as int?,
      networkStatus: detail['network_status'] as String?,
      lastSeenAt: detail['last_seen_at'] != null
          ? DateTime.parse(detail['last_seen_at'] as String)
          : null,
    );
  }
}
