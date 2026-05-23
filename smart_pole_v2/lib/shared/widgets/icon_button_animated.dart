import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// 앱 전체에서 사용하는 통일된 아이콘 버튼 위젯
/// 눌림 시 스케일 애니메이션 + 색상 변화 적용
class AnimatedIconButton extends StatefulWidget {
  const AnimatedIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 36,
    this.iconSize = 20,
    this.backgroundColor,
    this.activeBackgroundColor,
    this.iconColor,
    this.activeIconColor,
    this.badge,
    this.borderRadius,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  /// 기본 배경색 (null = 투명)
  final Color? backgroundColor;

  /// 눌림 시 배경색 (null = AppColors.blue50)
  final Color? activeBackgroundColor;

  /// 기본 아이콘 색상 (null = AppColors.textMuted)
  final Color? iconColor;

  /// 눌림 시 아이콘 색상 (null = AppColors.blue500)
  final Color? activeIconColor;

  /// 아이콘 위에 표시할 배지 위젯 (알림 개수 등)
  final Widget? badge;

  /// 모서리 둥글기 (null = AppSpacing.borderRadiusMd)
  final BorderRadius? borderRadius;

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _isPressed
        ? (widget.activeBackgroundColor ?? AppColors.blue50)
        : (widget.backgroundColor ?? Colors.transparent);

    final iconColor = _isPressed
        ? (widget.activeIconColor ?? AppColors.blue500)
        : (widget.iconColor ?? AppColors.textMuted);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppSpacing.animFast,
        transform: Matrix4.diagonal3Values(
          _isPressed ? 0.9 : 1.0,
          _isPressed ? 0.9 : 1.0,
          1.0,
        ),
        transformAlignment: Alignment.center,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: widget.borderRadius ?? AppSpacing.borderRadiusMd,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              widget.icon,
              size: widget.iconSize,
              color: iconColor,
            ),
            if (widget.badge != null) widget.badge!,
          ],
        ),
      ),
    );
  }
}
