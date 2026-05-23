import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_shadows.dart';

/// 아이콘 배지 위젯
/// 그라디언트 배경 + 아이콘의 둥근 배지
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.size = IconBadgeSize.medium,
    this.backgroundColor,
    this.gradient,
    this.iconColor,
    this.hasShadow = true,
    this.borderRadius,
  });

  final Widget icon;
  final IconBadgeSize size;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? iconColor;
  final bool hasShadow;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final dimensions = _getDimensions();
    final effectiveGradient = gradient ?? AppColors.iconBadgeGradient;
    final effectiveBorderRadius = borderRadius ?? AppSpacing.borderRadiusLg;

    return Container(
      width: dimensions.width,
      height: dimensions.height,
      decoration: BoxDecoration(
        color: backgroundColor,
        gradient: backgroundColor == null ? effectiveGradient : null,
        borderRadius: effectiveBorderRadius,
        boxShadow: hasShadow ? AppShadows.iconBadge : null,
      ),
      child: Center(
        child: IconTheme(
          data: IconThemeData(
            color: iconColor ?? AppColors.blue500,
            size: dimensions.iconSize,
          ),
          child: icon,
        ),
      ),
    );
  }

  _BadgeDimensions _getDimensions() {
    switch (size) {
      case IconBadgeSize.small:
        return _BadgeDimensions(
          width: AppSpacing.iconBadgeSm,
          height: AppSpacing.iconBadgeSm,
          iconSize: AppSpacing.iconSm,
        );
      case IconBadgeSize.medium:
        return _BadgeDimensions(
          width: AppSpacing.iconBadgeMd,
          height: AppSpacing.iconBadgeMd,
          iconSize: AppSpacing.iconMd,
        );
      case IconBadgeSize.large:
        return _BadgeDimensions(
          width: AppSpacing.iconBadgeLg,
          height: AppSpacing.iconBadgeLg,
          iconSize: AppSpacing.iconXl,
        );
    }
  }
}

enum IconBadgeSize { small, medium, large }

class _BadgeDimensions {
  final double width;
  final double height;
  final double iconSize;

  _BadgeDimensions({
    required this.width,
    required this.height,
    required this.iconSize,
  });
}

/// 원형 아이콘 배지
class CircleIconBadge extends StatelessWidget {
  const CircleIconBadge({
    super.key,
    required this.icon,
    this.size = 40.0,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
  });

  final Widget icon;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.blue50,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: IconTheme(
          data: IconThemeData(
            color: iconColor ?? AppColors.blue500,
            size: iconSize ?? size * 0.45,
          ),
          child: icon,
        ),
      ),
    );
  }
}
