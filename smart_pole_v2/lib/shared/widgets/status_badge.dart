import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_shadows.dart';

/// 상태 표시 배지 (정상/주의/종료)
/// React의 floating status chip과 동일한 스타일
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    required this.label,
    this.showDot = true,
    this.size = StatusBadgeSize.medium,
  });

  final DeviceStatus status;
  final String label;
  final bool showDot;
  final StatusBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final colors = _getStatusColors();
    final padding = size == StatusBadgeSize.small
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    final fontSize = size == StatusBadgeSize.small ? 11.0 : 12.0;
    final dotSize = size == StatusBadgeSize.small ? 6.0 : 8.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.backgroundColor,
        borderRadius: AppSpacing.borderRadiusFull,
        border: Border.all(color: colors.borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: colors.dotColor,
                shape: BoxShape.circle,
                boxShadow: colors.dotShadow,
              ),
            ),
            SizedBox(width: size == StatusBadgeSize.small ? 4 : 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: colors.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _StatusColors _getStatusColors() {
    switch (status) {
      case DeviceStatus.normal:
      case DeviceStatus.active:
        return _StatusColors(
          backgroundColor: AppColors.statusNormal.withValues(alpha: 0.1),
          borderColor: AppColors.statusNormal.withValues(alpha: 0.35),
          textColor: AppColors.statusNormal,
          dotColor: AppColors.statusNormalLight,
          dotShadow: AppShadows.statusNormalGlow,
        );
      case DeviceStatus.warning:
        return _StatusColors(
          backgroundColor: AppColors.statusWarning.withValues(alpha: 0.1),
          borderColor: AppColors.statusWarning.withValues(alpha: 0.4),
          textColor: AppColors.statusWarning,
          dotColor: AppColors.statusWarningLight,
          dotShadow: AppShadows.statusWarningGlow,
        );
      case DeviceStatus.ended:
      case DeviceStatus.off:
        return _StatusColors(
          backgroundColor: AppColors.statusEnded.withValues(alpha: 0.1),
          borderColor: AppColors.statusEnded.withValues(alpha: 0.3),
          textColor: AppColors.statusEnded,
          dotColor: AppColors.statusEndedLight,
          dotShadow: null,
        );
    }
  }
}

/// 상태 도트만 표시하는 위젯
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.status,
    this.size = 8.0,
    this.hasGlow = true,
  });

  final DeviceStatus status;
  final double size;
  final bool hasGlow;

  @override
  Widget build(BuildContext context) {
    final color = _getDotColor();
    final shadow = hasGlow ? _getDotShadow() : null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: shadow,
      ),
    );
  }

  Color _getDotColor() {
    switch (status) {
      case DeviceStatus.normal:
      case DeviceStatus.active:
        return AppColors.statusNormalLight;
      case DeviceStatus.warning:
        return AppColors.statusWarningLight;
      case DeviceStatus.ended:
      case DeviceStatus.off:
        return AppColors.statusEndedLight;
    }
  }

  List<BoxShadow>? _getDotShadow() {
    switch (status) {
      case DeviceStatus.normal:
      case DeviceStatus.active:
        return AppShadows.statusNormalGlow;
      case DeviceStatus.warning:
        return AppShadows.statusWarningGlow;
      case DeviceStatus.ended:
      case DeviceStatus.off:
        return null;
    }
  }
}

/// 디바이스 상태 열거형
enum DeviceStatus {
  normal,
  active,
  warning,
  ended,
  off,
}

enum StatusBadgeSize {
  small,
  medium,
}

class _StatusColors {
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color dotColor;
  final List<BoxShadow>? dotShadow;

  _StatusColors({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.dotColor,
    this.dotShadow,
  });
}

/// 연결 상태 배지
class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({
    super.key,
    required this.isConnected,
  });

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isConnected ? AppColors.statusNormalBg : AppColors.statusEndedBg,
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isConnected
                  ? AppColors.statusNormal
                  : AppColors.statusEndedLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isConnected ? '연결됨' : '연결 끊김',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: isConnected
                  ? AppColors.statusNormal
                  : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
