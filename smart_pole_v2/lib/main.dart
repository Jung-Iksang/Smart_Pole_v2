import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/router/app_router.dart';
import 'core/services/api_client.dart';
import 'core/services/fcm_service.dart';
import 'core/services/local_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ApiClient.instance.init();

  // Firebase/FCM 초기화. google-services.json 이 없는 빌드(BLE 직결 시연)에서는
  // 초기화가 실패하므로 건너뛰고 앱은 계속 뜬다.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FcmService.instance.init();
  } catch (e) {
    debugPrint('[FCM] Firebase 비활성 (설정 파일 없음 또는 초기화 실패): $e');
  }

  // 로컬 알림 채널 (BLE 직결 알림 배너). 배너 탭 → 알림 화면
  await LocalNotificationService.instance.init();
  LocalNotificationService.instance.onTap = () => AppRouter.router.go('/notifications');

  runApp(
    const ProviderScope(
      child: InfuCareApp(),
    ),
  );
}
