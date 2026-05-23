import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_shadows.dart';

/// Primary 그라디언트 버튼
/// React의 primary button과 동일한 스타일
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isEnabled = true,
    this.isLoading = false,
    this.height = AppSpacing.buttonHeightLg,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final bool isLoading;
  final double height;
  final Widget? icon;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isEnabled && !widget.isLoading;

    return GestureDetector(
      onTapDown: isActive ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isActive ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isActive ? () => setState(() => _isPressed = false) : null,
      onTap: isActive ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: AppSpacing.animFast,
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        transformAlignment: Alignment.center,
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.primaryGradient : null,
          color: isActive ? null : AppColors.borderLight,
          borderRadius: AppSpacing.borderRadiusLg,
          boxShadow: isActive ? AppShadows.primaryButton : AppShadows.none,
        ),
        child: Center(
          child: widget.isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isActive ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      widget.icon!,
                      AppSpacing.gapHSm,
                    ],
                    Text(
                      widget.text,
                      style: AppTypography.buttonPrimary.copyWith(
                        color: isActive ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
