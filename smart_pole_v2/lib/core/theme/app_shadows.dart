import 'package:flutter/material.dart';
import 'app_colors.dart';

/// InfuCare 앱 그림자 시스템
/// React 웹앱의 box-shadow에서 추출
class AppShadows {
  AppShadows._();

  // ═══════════════════════════════════════════════════════════════════════════
  // Card Shadows
  // ═══════════════════════════════════════════════════════════════════════════

  /// 미묘한 그림자 - 기본 카드
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0F3B82F6), // 6% blue
      blurRadius: 8,
      offset: Offset(0, 1),
    ),
  ];

  /// 중간 그림자 - 호버/포커스 카드
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x143B82F6), // 8% blue
      blurRadius: 20,
      offset: Offset(0, 2),
    ),
  ];

  /// 강한 그림자 - 버튼, 강조 요소
  static const List<BoxShadow> strong = [
    BoxShadow(
      color: Color(0x4D3B82F6), // 30% blue
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];

  /// 매우 강한 그림자 - 모달, 드롭다운
  static const List<BoxShadow> veryStrong = [
    BoxShadow(
      color: Color(0x1F3B82F6), // 12% blue
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0F000000), // 6% black
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // Button Shadows
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary 버튼 그림자
  static const List<BoxShadow> primaryButton = [
    BoxShadow(
      color: Color(0x593B82F6), // 35% blue
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];

  /// Icon badge 그림자
  static const List<BoxShadow> iconBadge = [
    BoxShadow(
      color: Color(0x243B82F6), // 14% blue
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // Status Glow
  // ═══════════════════════════════════════════════════════════════════════════

  /// 정상 상태 글로우
  static List<BoxShadow> statusNormalGlow = [
    BoxShadow(
      color: AppColors.statusNormal.withValues(alpha: 0.5),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  /// 주의 상태 글로우
  static List<BoxShadow> statusWarningGlow = [
    BoxShadow(
      color: AppColors.statusWarning.withValues(alpha: 0.5),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // Specialized Shadows
  // ═══════════════════════════════════════════════════════════════════════════

  /// Device selector 드롭다운
  static const List<BoxShadow> dropdown = [
    BoxShadow(
      color: Color(0x1F3B82F6), // 12% blue
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0F000000), // 6% black
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// 하단 카드
  static const List<BoxShadow> bottomCard = [
    BoxShadow(
      color: Color(0x1A000000), // 10% black
      blurRadius: 20,
      offset: Offset(0, -4),
    ),
  ];

  /// 입력 필드 포커스
  static const List<BoxShadow> inputFocus = [
    BoxShadow(
      color: Color(0x1A3B82F6), // 10% blue
      blurRadius: 8,
      offset: Offset(0, 0),
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // No Shadow
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<BoxShadow> none = [];
}
