import 'package:flutter/material.dart';

/// InfuCare 앱 간격 및 크기 상수
/// React 웹앱의 Tailwind 스케일에서 추출
class AppSpacing {
  AppSpacing._();

  // ═══════════════════════════════════════════════════════════════════════════
  // Spacing Scale
  // ═══════════════════════════════════════════════════════════════════════════

  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double base = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // Border Radius
  // ═══════════════════════════════════════════════════════════════════════════

  /// 8px - 작은 요소 (아이콘 배지)
  static const double radiusSm = 8.0;

  /// 10px - 기본
  static const double radiusMd = 10.0;

  /// 12px
  static const double radiusBase = 12.0;

  /// 16px - 버튼, 입력필드
  static const double radiusLg = 16.0;

  /// 24px - 카드
  static const double radiusXl = 24.0;

  /// 30px - 대형 카드
  static const double radiusXxl = 30.0;

  /// 9999px - 완전 둥근 (pill)
  static const double radiusFull = 9999.0;

  // BorderRadius 객체들
  static final BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static final BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static final BorderRadius borderRadiusBase = BorderRadius.circular(radiusBase);
  static final BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static final BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);
  static final BorderRadius borderRadiusXxl = BorderRadius.circular(radiusXxl);
  static final BorderRadius borderRadiusFull = BorderRadius.circular(radiusFull);

  // ═══════════════════════════════════════════════════════════════════════════
  // Component Sizes
  // ═══════════════════════════════════════════════════════════════════════════

  /// 버튼 높이
  static const double buttonHeightSm = 44.0;
  static const double buttonHeightMd = 48.0;
  static const double buttonHeightLg = 56.0;

  /// 아이콘 버튼
  static const double iconButtonSm = 36.0;
  static const double iconButtonMd = 40.0;
  static const double iconButtonLg = 44.0;

  /// 아이콘 배지
  static const double iconBadgeSm = 36.0;
  static const double iconBadgeMd = 40.0;
  static const double iconBadgeLg = 56.0;

  /// 입력 필드 높이
  static const double inputHeight = 56.0;

  /// 하단 네비게이션 바 높이
  static const double bottomNavHeight = 80.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // Icon Sizes
  // ═══════════════════════════════════════════════════════════════════════════

  static const double iconXs = 14.0;
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 28.0;
  static const double iconXxl = 32.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // Screen Padding
  // ═══════════════════════════════════════════════════════════════════════════

  /// 수평 패딩
  static const EdgeInsets screenPaddingHorizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets screenPaddingHorizontalSm = EdgeInsets.symmetric(horizontal: base);

  /// 전체 화면 패딩
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: xl,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // Card Padding
  // ═══════════════════════════════════════════════════════════════════════════

  static const EdgeInsets cardPaddingSm = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingMd = EdgeInsets.all(base);
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(lg);
  static const EdgeInsets cardPaddingXl = EdgeInsets.all(xl);

  // ═══════════════════════════════════════════════════════════════════════════
  // Gap Sizes (Row/Column spacing)
  // ═══════════════════════════════════════════════════════════════════════════

  static const SizedBox gapXxs = SizedBox(width: xxs, height: xxs);
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapBase = SizedBox(width: base, height: base);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
  static const SizedBox gapXxl = SizedBox(width: xxl, height: xxl);

  // 수평 간격
  static const SizedBox gapHXxs = SizedBox(width: xxs);
  static const SizedBox gapHXs = SizedBox(width: xs);
  static const SizedBox gapHSm = SizedBox(width: sm);
  static const SizedBox gapHMd = SizedBox(width: md);
  static const SizedBox gapHBase = SizedBox(width: base);
  static const SizedBox gapHLg = SizedBox(width: lg);
  static const SizedBox gapHXl = SizedBox(width: xl);

  // 수직 간격
  static const SizedBox gapVXxs = SizedBox(height: xxs);
  static const SizedBox gapVXs = SizedBox(height: xs);
  static const SizedBox gapVSm = SizedBox(height: sm);
  static const SizedBox gapVMd = SizedBox(height: md);
  static const SizedBox gapVBase = SizedBox(height: base);
  static const SizedBox gapVLg = SizedBox(height: lg);
  static const SizedBox gapVXl = SizedBox(height: xl);
  static const SizedBox gapVXxl = SizedBox(height: xxl);

  // ═══════════════════════════════════════════════════════════════════════════
  // Animation Durations
  // ═══════════════════════════════════════════════════════════════════════════

  static const Duration animFast = Duration(milliseconds: 100);
  static const Duration animNormal = Duration(milliseconds: 200);
  static const Duration animSlow = Duration(milliseconds: 300);
  static const Duration animVerySlow = Duration(milliseconds: 600);

  // ═══════════════════════════════════════════════════════════════════════════
  // Status Badge Sizes
  // ═══════════════════════════════════════════════════════════════════════════

  static const double statusDotSm = 6.0;
  static const double statusDotMd = 8.0;
  static const double statusDotLg = 10.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // Device Image Constraints
  // ═══════════════════════════════════════════════════════════════════════════

  static const double deviceImageMaxHeight = 220.0;
  static const double deviceImageMaxWidth = 200.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // Glow Ring Sizes
  // ═══════════════════════════════════════════════════════════════════════════

  static const double glowRingOuter = 270.0;
  static const double glowRingMiddle = 216.0;
  static const double glowRingInner = 160.0;
}
