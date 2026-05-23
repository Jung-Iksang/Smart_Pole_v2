import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Secondary 텍스트 버튼
/// React의 secondary text button과 동일한 스타일
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.icon,
    this.height = AppSpacing.buttonHeightMd,
  });

  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final Widget? icon;
  final double height;

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  double _opacity = 1.0;

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.color ?? AppColors.blue500;

    return GestureDetector(
      onTapDown: (_) => setState(() => _opacity = 0.6),
      onTapUp: (_) => setState(() => _opacity = 1.0),
      onTapCancel: () => setState(() => _opacity = 1.0),
      onTap: widget.onPressed,
      child: AnimatedOpacity(
        duration: AppSpacing.animFast,
        opacity: _opacity,
        child: Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: AppSpacing.borderRadiusLg,
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  widget.icon!,
                  AppSpacing.gapHXs,
                ],
                Text(
                  widget.text,
                  style: AppTypography.buttonSecondary.copyWith(
                    color: buttonColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon + Text + Arrow 형태의 도움말 버튼
class HelpButton extends StatefulWidget {
  const HelpButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final Widget? icon;

  @override
  State<HelpButton> createState() => _HelpButtonState();
}

class _HelpButtonState extends State<HelpButton> {
  double _opacity = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _opacity = 0.6),
      onTapUp: (_) => setState(() => _opacity = 1.0),
      onTapCancel: () => setState(() => _opacity = 1.0),
      onTap: widget.onPressed,
      child: AnimatedOpacity(
        duration: AppSpacing.animFast,
        opacity: _opacity,
        child: Container(
          height: AppSpacing.buttonHeightMd,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: AppSpacing.borderRadiusLg,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                widget.icon!,
                AppSpacing.gapHXs,
              ],
              Text(
                widget.text,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
              AppSpacing.gapHXxs,
              Icon(
                Icons.chevron_right,
                size: 14,
                color: AppColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
