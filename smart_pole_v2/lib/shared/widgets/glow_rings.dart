import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// 글로우 링 효과
/// React의 glow rings와 동일한 3중 원형 효과
class GlowRings extends StatelessWidget {
  const GlowRings({
    super.key,
    this.outerSize = AppSpacing.glowRingOuter,
    this.middleSize = AppSpacing.glowRingMiddle,
    this.innerSize = AppSpacing.glowRingInner,
    this.ringColor,
    this.innerGlowColor,
    this.child,
  });

  final double outerSize;
  final double middleSize;
  final double innerSize;
  final Color? ringColor;
  final Color? innerGlowColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final effectiveRingColor = ringColor ?? AppColors.blue400;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: outerSize,
            height: outerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: effectiveRingColor.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
          ),

          // Middle ring
          Container(
            width: middleSize,
            height: middleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: effectiveRingColor.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
          ),

          // Inner glow blob
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (innerGlowColor ?? AppColors.blue100).withValues(alpha: 0.85),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7],
              ),
            ),
          ),

          // Child (usually an image)
          if (child != null) child!,
        ],
      ),
    );
  }
}

/// 애니메이션 글로우 링 (선택적)
class AnimatedGlowRings extends StatefulWidget {
  const AnimatedGlowRings({
    super.key,
    this.outerSize = AppSpacing.glowRingOuter,
    this.middleSize = AppSpacing.glowRingMiddle,
    this.innerSize = AppSpacing.glowRingInner,
    this.ringColor,
    this.innerGlowColor,
    this.child,
    this.animate = true,
  });

  final double outerSize;
  final double middleSize;
  final double innerSize;
  final Color? ringColor;
  final Color? innerGlowColor;
  final Widget? child;
  final bool animate;

  @override
  State<AnimatedGlowRings> createState() => _AnimatedGlowRingsState();
}

class _AnimatedGlowRingsState extends State<AnimatedGlowRings>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnimatedGlowRings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return GlowRings(
        outerSize: widget.outerSize,
        middleSize: widget.middleSize,
        innerSize: widget.innerSize,
        ringColor: widget.ringColor,
        innerGlowColor: widget.innerGlowColor,
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GlowRings(
            outerSize: widget.outerSize,
            middleSize: widget.middleSize,
            innerSize: widget.innerSize,
            ringColor: widget.ringColor,
            innerGlowColor: widget.innerGlowColor,
            child: widget.child,
          ),
        );
      },
    );
  }
}
