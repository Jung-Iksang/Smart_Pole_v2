import 'api_client.dart';

class DeviceService {
  final ApiClient _client = ApiClient.instance;

  Future<List<Map<String, dynamic>>> listDevices() async {
    final response = await _client.dio.get('/devices');
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<Map<String, dynamic>> registerDevice(String qrCodeValue) async {
    final response = await _client.dio.post('/devices/register', data: {
      'qr_code_value': qrCodeValue,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDeviceDetail(int deviceId) async {
    final response = await _client.dio.get('/devices/$deviceId');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConnectionStatus(int deviceId) async {
    final response =
        await _client.dio.get('/devices/$deviceId/connection-status');
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteDevice(int deviceId) async {
    await _client.dio.delete('/devices/$deviceId');
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _client.dio.get('/dashboard');
    return response.data as Map<String, dynamic>;
  }
}
