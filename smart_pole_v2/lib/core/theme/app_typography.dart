import 'package:flutter/material.dart';
import 'app_colors.dart';

/// InfuCare 앱 타이포그래피 시스템
/// React 웹앱의 CSS 스타일에서 추출
class AppTypography {
  AppTypography._();

  // ═══════════════════════════════════════════════════════════════════════════
  // Headings
  // ═══════════════════════════════════════════════════════════════════════════

  /// Large heading - 24px, bold
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  /// Medium heading - 22px, bold
  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  /// Section heading - 20px, bold
  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  /// Subsection heading - 17px, semibold
  static const TextStyle heading4 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // Body Text
  // ═══════════════════════════════════════════════════════════════════════════

  /// Large body - 16px
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  /// Large body bold - 16px
  static const TextStyle bodyLargeBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  /// Medium body - 14px
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.textPrimary,
  );

  /// Medium body bold - 14px
  static const TextStyle bodyMediumBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // Small Text
  // ═══════════════════════════════════════════════════════════════════════════

  /// Small text - 13px
  static const TextStyle small = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  /// Small text bold - 13px
  static const TextStyle smallBold = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  /// Extra small - 12px
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textMuted,
  );

  /// Extra small bold - 12px
  static const TextStyle captionBold = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.textMuted,
  );

  /// Tiny label - 11px
  static const TextStyle tiny = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.textMuted,
  );

  /// Very tiny - 10px
  static const TextStyle micro = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textMuted,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // Button Text
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary button text
  static const TextStyle buttonPrimary = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.0,
    color: Colors.white,
  );

  /// Secondary button text
  static const TextStyle buttonSecondary = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.0,
    color: AppColors.blue500,
  );

  /// Small button text
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.0,
    color: AppColors.textPrimary,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // Label Text
  // ═══════════════════════════════════════════════════════════════════════════

  /// Form label
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  /// Uppercase label (tracking)
  static const TextStyle labelUppercase = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.04 * 12, // 0.04em
    height: 1.5,
    color: AppColors.textMuted,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // Special Styles
  // ═══════════════════════════════════════════════════════════════════════════

  /// Large number display (e.g., "420" mL)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.0,
    color: AppColors.blue800,
  );

  /// App name / Logo text
  static const TextStyle appName = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  /// Tagline
  static const TextStyle tagline = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // Input Text
  // ═══════════════════════════════════════════════════════════════════════════

  /// Input field text
  static const TextStyle input = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.02 * 16, // 0.02em
    color: AppColors.textPrimary,
  );

  /// Input placeholder
  static const TextStyle inputPlaceholder = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textDisabled,
  );

  /// Input error text
  static const TextStyle inputError = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.statusWarningDark,
  );
}
