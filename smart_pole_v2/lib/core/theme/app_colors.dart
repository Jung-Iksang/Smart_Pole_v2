import 'package:flutter/material.dart';

/// InfuCare 앱 색상 팔레트
/// React 웹앱의 theme.css에서 추출한 색상 시스템
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════════════════
  // Primary Colors
  // ═══════════════════════════════════════════════════════════════════════════

  /// Deep Navy - 주요 텍스트 및 UI 요소
  static const Color primary = Color(0xFF030213);
  static const Color primaryForeground = Color(0xFFFFFFFF);

  /// Light Purple - 보조 배경
  static const Color secondary = Color(0xFFF0EDFF);
  static const Color secondaryForeground = Color(0xFF030213);

  /// Light Gray - 강조 배경
  static const Color accent = Color(0xFFE9EBEF);
  static const Color accentForeground = Color(0xFF030213);

  // ═══════════════════════════════════════════════════════════════════════════
  // Background Colors
  // ═══════════════════════════════════════════════════════════════════════════

  /// 메인 배경색 (밝은 블루 틴트)
  static const Color background = Color(0xFFF8FBFF);

  /// 카드 배경색
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardForeground = Color(0xFF1E293B);

  /// 입력 필드 배경
  static const Color inputBackground = Color(0xFFF3F3F5);

  // ═══════════════════════════════════════════════════════════════════════════
  // Text Colors
  // ═══════════════════════════════════════════════════════════════════════════

  /// 기본 텍스트
  static const Color foreground = Color(0xFF000000);

  /// 비활성 텍스트
  static const Color muted = Color(0xFFECECF0);
  static const Color mutedForeground = Color(0xFF717182);

  /// 슬레이트 계열 텍스트
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFFCBD5E1);

  // ═══════════════════════════════════════════════════════════════════════════
  // Status Colors
  // ═══════════════════════════════════════════════════════════════════════════

  /// 정상 상태 (에메랄드)
  static const Color statusNormal = Color(0xFF10B981);
  static const Color statusNormalLight = Color(0xFF4ADE80);
  static const Color statusNormalBg = Color(0xFFECFDF5);

  /// 주의 상태 (앰버)
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusWarningLight = Color(0xFFFCD34D);
  static const Color statusWarningBg = Color(0xFFFFFBEB);
  static const Color statusWarningDark = Color(0xFFD97706);
  static const Color statusWarningText = Color(0xFF92400E);

  /// 종료/비활성 상태 (슬레이트)
  static const Color statusEnded = Color(0xFF94A3B8);
  static const Color statusEndedLight = Color(0xFFCBD5E1);
  static const Color statusEndedBg = Color(0xFFF8FAFC);

  /// 에러/파괴적 액션
  static const Color destructive = Color(0xFFD4183D);
  static const Color destructiveForeground = Color(0xFFFFFFFF);

  // ═══════════════════════════════════════════════════════════════════════════
  // Blue Gradient & Accent Colors
  // ═══════════════════════════════════════════════════════════════════════════

  /// 그라디언트 시작 (Blue-500)
  static const Color blueGradientStart = Color(0xFF3B82F6);

  /// 그라디언트 끝 (Indigo-500)
  static const Color blueGradientEnd = Color(0xFF6366F1);

  /// Blue 계열
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color blue100 = Color(0xFFDBEAFE);
  static const Color blue200 = Color(0xFFBFDBFE);
  static const Color blue300 = Color(0xFF93C5FD);
  static const Color blue400 = Color(0xFF60A5FA);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color blue700 = Color(0xFF1D4ED8);
  static const Color blue800 = Color(0xFF1E40AF);

  // ═══════════════════════════════════════════════════════════════════════════
  // Light Tints (배경용)
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color blueLight = Color(0xFFF0F7FF);
  static const Color greenLight = Color(0xFFF0FDF4);
  static const Color amberLight = Color(0xFFFEF3C7);
  static const Color purpleLight = Color(0xFFF5F3FF);
  static const Color grayLight = Color(0xFFF1F5F9);

  // ═══════════════════════════════════════════════════════════════════════════
  // Border Colors
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color border = Color(0x1A000000); // rgba(0, 0, 0, 0.1)
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderBlue = Color(0xFFE8F0FE);

  // ═══════════════════════════════════════════════════════════════════════════
  // Switch & Toggle
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color switchBackground = Color(0xFFCBCED4);

  // ═══════════════════════════════════════════════════════════════════════════
  // Gradients
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary Blue Gradient (버튼용)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blueGradientStart, blueGradientEnd],
  );

  /// Icon Badge Gradient
  static const LinearGradient iconBadgeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue100, Color(0xFFEEF2FF)],
  );

  /// Hero Card Gradients
  static const LinearGradient heroNormalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEFF6FF), Color(0xFFF0FDFA)],
  );

  static const LinearGradient heroWarningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFDF5), Color(0xFFFFFBEB)],
  );

  static const LinearGradient heroEndedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // Shadow Colors
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color shadowBlue = Color(0x0F3B82F6); // 6% opacity
  static const Color shadowBlueMedium = Color(0x143B82F6); // 8% opacity
  static const Color shadowBlueStrong = Color(0x4D3B82F6); // 30% opacity
  static const Color shadowBlack = Color(0x0F000000); // 6% opacity

  // ═══════════════════════════════════════════════════════════════════════════
  // Utility Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// 상태에 따른 색상 반환
  static Color getStatusColor(String status) {
    switch (status) {
      case 'normal':
      case 'active':
        return statusNormal;
      case 'warning':
        return statusWarning;
      case 'ended':
      case 'off':
        return statusEnded;
      default:
        return statusEnded;
    }
  }

  /// 상태에 따른 배경색 반환
  static Color getStatusBgColor(String status) {
    switch (status) {
      case 'normal':
      case 'active':
        return statusNormalBg;
      case 'warning':
        return statusWarningBg;
      case 'ended':
      case 'off':
        return statusEndedBg;
      default:
        return statusEndedBg;
    }
  }
}
