import 'package:dio/dio.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _client = ApiClient.instance;

  Future<Map<String, dynamic>> signup(String username, String password) async {
    final response = await _client.dio.post('/auth/signup', data: {
      'username': username,
      'password': password,
    });
    final data = response.data as Map<String, dynamic>;
    await _client.saveTokens(
      accessToken: data['access_token'],
      refreshToken: data['refresh_token'],
    );
    return data;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _client.dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    final data = response.data as Map<String, dynamic>;
    await _client.saveTokens(
      accessToken: data['access_token'],
      refreshToken: data['refresh_token'],
    );
    return data;
  }

  Future<Map<String, dynamic>> verifyPatient(
      String patientCode, String birthDate) async {
    final response = await _client.dio.post('/auth/verify-patient', data: {
      'patient_code': patientCode,
      'birth_date': birthDate,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    try {
      await _client.dio.post('/auth/logout');
    } catch (_) {}
    await _client.clearTokens();
  }

  Future<bool> isLoggedIn() async {
    return await _client.hasToken();
  }

  /// DioException에서 에러 메시지 추출
  static String getErrorMessage(dynamic error) {
    if (error is DioException && error.response?.data != null) {
      final data = error.response!.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
    }
    return '네트워크 오류가 발생했습니다';
  }
}
