import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 기기 로컬 알림 (BLE 직결 알림 배너용)
///
/// 서버/FCM 없이 앱이 직접 상단 배너 + 소리 + 진동을 띄운다.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  static const _channelId = 'iv_alerts';
  static const _channelName = '수액 이상 알림';
  static const _channelDesc = '유속 과다, 유속 느림, 줄 꺾임·혈액 역류 가능 알림';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 알림 탭 콜백 (라우터에서 /notifications 로 이동시킬 때 사용)
  VoidCallback? onTap;

  Future<void> init() async {
    if (_initialized) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (_) => onTap?.call(),
      );

      // Android 8+ 채널 생성 (중요도 최대 → 헤드업 배너)
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      _initialized = true;
      debugPrint('[LocalNotif] 초기화 완료');
    } catch (e) {
      debugPrint('[LocalNotif] 초기화 실패: $e');
    }
  }

  /// Android 13+ 알림 권한 요청. 다른 플랫폼은 true.
  Future<bool> requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        debugPrint('[LocalNotif] Android 알림 권한: $granted');
        return granted ?? true;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? true;
      }
    } catch (e) {
      debugPrint('[LocalNotif] 권한 요청 실패: $e');
    }
    return true;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    bool danger = false,
  }) async {
    if (!_initialized) await init();
    if (!_initialized) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        color: danger ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
        styleInformation: BigTextStyleInformation(body),
        ticker: title,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: false,
      ),
    );
    try {
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('[LocalNotif] 표시 실패: $e');
    }
  }
}
