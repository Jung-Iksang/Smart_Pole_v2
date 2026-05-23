import 'dart:math';
import 'package:flutter/material.dart';

/// 반응형 디자인 유틸리티
/// 모든 기기 크기에서 일관된 UI를 제공하기 위한 헬퍼
class ResponsiveUtils {
  ResponsiveUtils._();

  // ═══════════════════════════════════════════════════════════════════════════
  // Screen Dimensions
  // ═══════════════════════════════════════════════════════════════════════════

  /// 기준 디자인 너비 (iPhone 12/13/14)
  static const double designWidth = 390.0;

  /// 기준 디자인 높이
  static const double designHeight = 844.0;

  /// 최소 지원 너비 (iPhone SE)
  static const double minWidth = 320.0;

  /// 최대 콘텐츠 너비 (태블릿 대응)
  static const double maxContentWidth = 500.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // Screen Getters
  // ═══════════════════════════════════════════════════════════════════════════

  /// 화면 너비
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// 화면 높이
  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// 콘텐츠 너비 (최대 500px 제한)
  static double contentWidth(BuildContext context) =>
      min(screenWidth(context), maxContentWidth);

  /// Safe Area Padding
  static EdgeInsets safeAreaPadding(BuildContext context) =>
      MediaQuery.of(context).padding;

  /// Safe Area를 제외한 높이
  static double safeHeight(BuildContext context) {
    final padding = safeAreaPadding(context);
    return screenHeight(context) - padding.top - padding.bottom;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Device Type Detection
  // ═══════════════════════════════════════════════════════════════════════════

  /// 작은 화면 (iPhone SE 등)
  static bool isSmallScreen(BuildContext context) =>
      screenWidth(context) <= 360;

  /// 일반 화면 (iPhone 12/13/14 등)
  static bool isNormalScreen(BuildContext context) =>
      screenWidth(context) > 360 && screenWidth(context) <= 414;

  /// 큰 화면 (iPhone Plus/Max, iPad 등)
  static bool isLargeScreen(BuildContext context) =>
      screenWidth(context) > 414;

  /// 태블릿 여부
  static bool isTablet(BuildContext context) => screenWidth(context) > 600;

  // ═══════════════════════════════════════════════════════════════════════════
  // Scale Factors
  // ═══════════════════════════════════════════════════════════════════════════

  /// 스케일 팩터 (기준 디자인 대비)
  static double scaleFactor(BuildContext context) {
    final width = screenWidth(context);
    if (width <= 320) return 0.85;
    if (width <= 360) return 0.92;
    if (width <= 390) return 1.0;
    if (width <= 414) return 1.05;
    return 1.0; // 큰 화면에서는 maxContentWidth로 제한
  }

  /// 폰트 스케일 팩터
  static double fontScaleFactor(BuildContext context) {
    final width = screenWidth(context);
    if (width <= 320) return 0.9;
    if (width <= 360) return 0.95;
    return 1.0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Responsive Padding
  // ═══════════════════════════════════════════════════════════════════════════

  /// 수평 패딩 (화면 크기에 따라 조정)
  static EdgeInsets horizontalPadding(BuildContext context) {
    final width = screenWidth(context);
    if (width <= 360) return const EdgeInsets.symmetric(horizontal: 16);
    if (width <= 414) return const EdgeInsets.symmetric(horizontal: 20);
    return const EdgeInsets.symmetric(horizontal: 24);
  }

  /// 화면 패딩 (수평 + 수직)
  static EdgeInsets screenPadding(BuildContext context) {
    final width = screenWidth(context);
    if (width <= 360) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 20);
    }
    if (width <= 414) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 24);
    }
    return const EdgeInsets.symmetric(horizontal: 24, vertical: 24);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Responsive Values
  // ═══════════════════════════════════════════════════════════════════════════

  /// 반응형 값 (화면 크기에 따라 다른 값 반환)
  static T responsive<T>(
    BuildContext context, {
    required T small,
    required T normal,
    T? large,
  }) {
    if (isSmallScreen(context)) return small;
    if (isNormalScreen(context)) return normal;
    return large ?? normal;
  }

  /// 스케일된 값 반환
  static double scaled(BuildContext context, double value) {
    return value * scaleFactor(context);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Layout Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  /// 태블릿에서 중앙 정렬된 콘텐츠
  static Widget centeredContent({
    required BuildContext context,
    required Widget child,
    double? maxWidth,
  }) {
    if (!isTablet(context)) return child;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? maxContentWidth,
        ),
        child: child,
      ),
    );
  }

  /// 반응형 그리드 컬럼 수
  static int gridColumns(BuildContext context) {
    final width = screenWidth(context);
    if (width <= 360) return 1;
    if (width <= 600) return 2;
    if (width <= 900) return 3;
    return 4;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Component Sizes
  // ═══════════════════════════════════════════════════════════════════════════

  /// 글로우 링 크기 (화면 크기에 따라 조정)
  static double glowRingSize(BuildContext context, double baseSize) {
    final scale = min(1.0, screenWidth(context) / designWidth);
    return baseSize * scale;
  }

  /// 디바이스 이미지 크기
  static Size deviceImageSize(BuildContext context) {
    final scale = min(1.0, screenWidth(context) / designWidth);
    return Size(
      200 * scale,
      220 * scale,
    );
  }
}

/// BuildContext 확장
extension ResponsiveExtension on BuildContext {
  double get screenWidth => ResponsiveUtils.screenWidth(this);
  double get screenHeight => ResponsiveUtils.screenHeight(this);
  double get contentWidth => ResponsiveUtils.contentWidth(this);
  bool get isSmallScreen => ResponsiveUtils.isSmallScreen(this);
  bool get isNormalScreen => ResponsiveUtils.isNormalScreen(this);
  bool get isLargeScreen => ResponsiveUtils.isLargeScreen(this);
  bool get isTablet => ResponsiveUtils.isTablet(this);
  double get scaleFactor => ResponsiveUtils.scaleFactor(this);
  EdgeInsets get horizontalPadding => ResponsiveUtils.horizontalPadding(this);
  EdgeInsets get screenPadding => ResponsiveUtils.screenPadding(this);
}
