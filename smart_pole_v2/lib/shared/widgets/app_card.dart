import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_shadows.dart';

/// 기본 카드 위젯
/// React의 rounded card와 동일한 스타일
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.shadow,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? shadow;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? AppSpacing.cardPaddingMd;
    final effectiveBorderRadius = borderRadius ?? AppSpacing.borderRadiusXl;
    final effectiveShadow = shadow ?? AppShadows.subtle;

    Widget cardContent = Container(
      padding: effectivePadding,
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? AppColors.card) : null,
        gradient: gradient,
        borderRadius: effectiveBorderRadius,
        border: Border.all(
          color: borderColor ?? AppColors.borderBlue,
          width: 1,
        ),
        boxShadow: effectiveShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return _TappableCard(
        onTap: onTap!,
        borderRadius: effectiveBorderRadius,
        child: cardContent,
      );
    }

    return cardContent;
  }
}

class _TappableCard extends StatefulWidget {
  const _TappableCard({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  State<_TappableCard> createState() => _TappableCardState();
}

class _TappableCardState extends State<_TappableCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppSpacing.animFast,
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        transformAlignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

/// 액션 카드 (아이콘 + 텍스트)
/// DeviceHomeScreen의 2열 액션 버튼용
class ActionCard extends StatefulWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconBackgroundColor,
    this.iconColor,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconBackgroundColor;
  final Color? iconColor;

  @override
  State<ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<ActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppSpacing.animFast,
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        transformAlignment: Alignment.center,
        padding: AppSpacing.cardPaddingMd,
        decoration: BoxDecoration(
          color: AppColors.blueLight,
          borderRadius: AppSpacing.borderRadiusLg,
          border: Border.all(
            color: AppColors.blue500.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.iconBackgroundColor ??
                    AppColors.blue500.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: IconTheme(
                  data: IconThemeData(
                    color: widget.iconColor ?? AppColors.blue500,
                    size: 16,
                  ),
                  child: widget.icon,
                ),
              ),
            ),
            AppSpacing.gapVMd,
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 히어로 카드 (상태에 따라 그라디언트 변경)
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.child,
    required this.status,
    this.padding,
  });

  final Widget child;
  final String status; // 'normal', 'warning', 'ended'
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final gradient = _getGradient();
    final borderColor = _getBorderColor();

    return Container(
      padding: padding ?? AppSpacing.cardPaddingLg,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: AppSpacing.borderRadiusXxl,
        border: Border.all(color: borderColor, width: 1),
        boxShadow: AppShadows.medium,
      ),
      child: child,
    );
  }

  Gradient _getGradient() {
    switch (status) {
      case 'warning':
        return AppColors.heroWarningGradient;
      case 'ended':
        return AppColors.heroEndedGradient;
      default:
        return AppColors.heroNormalGradient;
    }
  }

  Color _getBorderColor() {
    switch (status) {
      case 'warning':
        return AppColors.statusWarningLight;
      case 'ended':
        return AppColors.borderLight;
      default:
        return AppColors.blue100;
    }
  }
}

/// 힌트 카드 (정보 안내용)
class HintCard extends StatelessWidget {
  const HintCard({
    super.key,
    required this.icon,
    required this.text,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
  });

  final Widget icon;
  final String text;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.blueLight,
        borderRadius: AppSpacing.borderRadiusLg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTheme(
            data: IconThemeData(
              color: iconColor ?? AppColors.blue400,
              size: 16,
            ),
            child: icon,
          ),
          AppSpacing.gapHMd,
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: textColor ?? AppColors.textSecondary,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
