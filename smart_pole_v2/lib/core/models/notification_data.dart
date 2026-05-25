class NotificationData {
  final int notificationId;
  final String type; // "low_fluid" | "flow_stop"
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const NotificationData({
    required this.notificationId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      notificationId: json['notification_id'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// 읽음 상태 변경 복사본
  NotificationData copyWith({bool? isRead}) {
    return NotificationData(
      notificationId: notificationId,
      type: type,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  /// 상대 시간 텍스트 ("방금 전", "2분 전", "1시간 전", …)
  String get relativeTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

/// 페이지네이션 응답
class NotificationListData {
  final List<NotificationData> items;
  final int page;
  final int size;
  final int total;

  const NotificationListData({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  bool get hasMore => (page * size) < total;

  factory NotificationListData.fromJson(Map<String, dynamic> json) {
    final itemList = json['items'] as List<dynamic>;
    return NotificationListData(
      items: itemList
          .map((e) => NotificationData.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      size: json['size'] as int,
      total: json['total'] as int,
    );
  }
}
