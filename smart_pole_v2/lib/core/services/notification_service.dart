import '../models/notification_data.dart';
import 'api_client.dart';

class NotificationService {
  final ApiClient _client = ApiClient.instance;

  Future<NotificationListData> getNotifications({int page = 1, int size = 20}) async {
    final response = await _client.dio.get(
      '/notifications',
      queryParameters: {'page': page, 'size': size},
    );
    return NotificationListData.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> markAsRead(int notificationId) async {
    await _client.dio.patch('/notifications/$notificationId/read');
  }

  Future<void> markAllAsRead() async {
    await _client.dio.patch('/notifications/read-all');
  }
}
