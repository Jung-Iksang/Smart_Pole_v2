import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/provisioning_service.dart';
import '../../shared/providers/navigation_provider.dart';
import '../../features/welcome/welcome_screen.dart';
import '../../features/auth/patient_auth_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/setup/setup_guide_screen.dart';
import '../../features/setup/wifi_instruction_screen.dart';
import '../../features/setup/wifi_input_screen.dart';
import '../../features/setup/qr_scan_screen.dart';
import '../../features/setup/connecting_screen.dart';
import '../../features/setup/success_screen.dart';
import '../../features/setup/failure_screen.dart';
import '../../features/setup/iv_bag_scan_screen.dart';
import '../../features/device/no_device_screen.dart';
import '../../features/device/iv_no_device_screen.dart';
import '../../features/iv_status/iv_status_screen.dart';
import '../../features/iv_status/iv_dashboard_screen.dart';
import '../../features/iv_status/iv_no_session_screen.dart';
import '../../features/iv_status/iv_loading_screen.dart';
import '../../features/iv_status/iv_disconnected_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/account/account_screen.dart';
import '../../features/account/caregiver_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/help_screen.dart';

/// InfuCare 앱 라우터 설정
/// 22개 스크린에 대한 라우트 정의
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  /// Creates a custom slide transition page based on tab navigation direction
  static CustomTransitionPage<void> _buildTabTransitionPage({
    required Widget child,
    required GoRouterState state,
    required int targetTabIndex,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Get the current navigation state from the extra parameter
        final fromTabIndex = state.extra is int ? state.extra as int : targetTabIndex;

        // Determine slide direction based on tab indices
        final slideFromRight = targetTabIndex > fromTabIndex;
        final begin = Offset(slideFromRight ? 1.0 : -1.0, 0.0);

        return SlideTransition(
          position: Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
    );
  }

  /// Creates a slide-from-right transition for pushed screens
  static CustomTransitionPage<void> _buildSlideFromRightPage({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
    );
  }

  static const _authRoutes = {'/', '/login', '/signup'};
  static const _storage = FlutterSecureStorage();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final token = await _storage.read(key: 'access_token');
      final autoLogin = await _storage.read(key: 'auto_login');
      final isLoggedIn = token != null;
      final isAutoLoginEnabled = autoLogin == 'true';
      final isAuthRoute = _authRoutes.contains(state.matchedLocation);

      // 자동 로그인 ON + 토큰 있음 + 인증 화면 접근 → 메인으로
      if (isLoggedIn && isAutoLoginEnabled && isAuthRoute) {
        return '/iv-status';
      }

      return null;
    },
    routes: [
      // ═══════════════════════════════════════════════════════════════════════
      // Authentication & Setup Flow
      // ═══════════════════════════════════════════════════════════════════════

      GoRoute(
        path: '/',
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/patient-auth',
        name: 'patientAuth',
        builder: (context, state) => const PatientAuthScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => _buildSlideFromRightPage(
          child: const LoginScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        pageBuilder: (context, state) => _buildSlideFromRightPage(
          child: const SignupScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/setup-guide',
        name: 'setupGuide',
        builder: (context, state) => const SetupGuideScreen(),
      ),
      GoRoute(
        path: '/wifi-list',
        name: 'wifiList',
        builder: (context, state) {
          final qrData = state.extra as DeviceQrData;
          return WiFiInstructionScreen(qrData: qrData);
        },
      ),
      GoRoute(
        path: '/wifi-input',
        name: 'wifiInput',
        builder: (context, state) {
          final ssid = state.extra as String;
          return WiFiInputScreen(ssid: ssid);
        },
      ),
      GoRoute(
        path: '/qr-scan',
        name: 'qrScan',
        builder: (context, state) => const QRScanScreen(),
      ),
      GoRoute(
        path: '/connecting',
        name: 'connecting',
        builder: (context, state) => const ConnectingScreen(),
      ),
      GoRoute(
        path: '/success',
        name: 'success',
        builder: (context, state) => const SuccessScreen(),
      ),
      GoRoute(
        path: '/failure',
        name: 'failure',
        builder: (context, state) => const FailureScreen(),
      ),
      GoRoute(
        path: '/iv-bag-scan',
        name: 'ivBagScan',
        builder: (context, state) {
          final deviceId = state.extra as int;
          return IVBagScanScreen(deviceId: deviceId);
        },
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // Main App Screens (Bottom Nav Tabs with slide transitions)
      // ═════════════════════════════════════════════════════════════════��═════

      // Redirect /device-home to /iv-status for backwards compatibility
      GoRoute(
        path: '/device-home',
        name: 'deviceHome',
        redirect: (context, state) => '/iv-status',
      ),
      GoRoute(
        path: '/no-device',
        name: 'noDevice',
        builder: (context, state) => const NoDeviceScreen(),
      ),
      GoRoute(
        path: '/iv-no-device',
        name: 'ivNoDevice',
        builder: (context, state) => const IVNoDeviceScreen(),
      ),

      // Tab 1: IV Status
      GoRoute(
        path: '/iv-status',
        name: 'ivStatus',
        pageBuilder: (context, state) {
          // If pushed (extra is 'push'), slide from right
          // If navigated via tab (extra is int), use tab transition
          if (state.extra == 'push') {
            return _buildSlideFromRightPage(
              child: const IVStatusScreen(),
              state: state,
            );
          }
          return _buildTabTransitionPage(
            child: const IVStatusScreen(),
            state: state,
            targetTabIndex: NavTabs.ivStatus,
          );
        },
      ),
      GoRoute(
        path: '/iv-dashboard',
        name: 'ivDashboard',
        pageBuilder: (context, state) => _buildTabTransitionPage(
          child: const IVDashboardScreen(),
          state: state,
          targetTabIndex: NavTabs.ivStatus,
        ),
      ),
      GoRoute(
        path: '/iv-no-session',
        name: 'ivNoSession',
        builder: (context, state) => const IVNoSessionScreen(),
      ),
      GoRoute(
        path: '/iv-loading',
        name: 'ivLoading',
        builder: (context, state) => const IVLoadingScreen(),
      ),
      GoRoute(
        path: '/iv-disconnected',
        name: 'ivDisconnected',
        builder: (context, state) => const IVDisconnectedScreen(),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // Notifications & Account (Bottom Nav Tabs with slide transitions)
      // ═══════════════════════════════════════════════════════════════════════

      // Tab 2: Notifications
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        pageBuilder: (context, state) {
          // If pushed (extra is 'push'), slide from right
          // If navigated via tab (extra is int), use tab transition
          if (state.extra == 'push') {
            return _buildSlideFromRightPage(
              child: const NotificationsScreen(),
              state: state,
            );
          }
          return _buildTabTransitionPage(
            child: const NotificationsScreen(),
            state: state,
            targetTabIndex: NavTabs.notifications,
          );
        },
      ),

      // Tab 3: Account
      GoRoute(
        path: '/account',
        name: 'account',
        pageBuilder: (context, state) => _buildTabTransitionPage(
          child: const AccountScreen(),
          state: state,
          targetTabIndex: NavTabs.account,
        ),
      ),
      GoRoute(
        path: '/caregiver',
        name: 'caregiver',
        builder: (context, state) => const CaregiverScreen(),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // Settings
      // ═══════════════════════════════════════════════════════════════════════

      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => _buildSlideFromRightPage(
          child: const SettingsScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/help',
        name: 'help',
        pageBuilder: (context, state) => _buildSlideFromRightPage(
          child: const HelpScreen(),
          state: state,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
}
