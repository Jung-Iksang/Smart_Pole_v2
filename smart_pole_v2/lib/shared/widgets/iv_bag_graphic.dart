import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// IV 백 그래픽 위젯
/// React의 IVBagGraphic SVG와 동일한 CustomPainter 구현
class IVBagGraphic extends StatelessWidget {
  const IVBagGraphic({
    super.key,
    required this.percent,
    required this.status,
    this.width = 72,
    this.height = 160,
  });

  final double percent;
  final String status; // 'normal', 'warning', 'ended'
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _IVBagPainter(
        percent: percent.clamp(0, 100),
        status: status,
      ),
    );
  }
}

class _IVBagPainter extends CustomPainter {
  _IVBagPainter({
    required this.percent,
    required this.status,
  });

  final double percent;
  final String status;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 72;

    // Colors based on status
    final fluidStartColor = _getFluidStartColor();
    final fluidEndColor = _getFluidEndColor();
    final waveColor = _getWaveColor();
    final dropColor = _getDropColor();

    // Bag dimensions (scaled)
    const bagTop = 14.0;
    const bagHeight = 110.0;
    const bagLeft = 8.0;
    const bagWidth = 56.0;
    const bagRadius = 14.0;

    // Calculate fluid level
    final fluidHeight = (percent / 100) * bagHeight;
    final fluidY = bagTop + (bagHeight - fluidHeight);

    // Draw hook (top part)
    final hookPaint = Paint()
      ..color = AppColors.textDisabled
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Hook curve
    final hookPath = Path()
      ..moveTo(36 * scale, 4 * scale)
      ..quadraticBezierTo(36 * scale, 0, 40 * scale, 0)
      ..quadraticBezierTo(44 * scale, 0, 44 * scale, 4 * scale);
    canvas.drawPath(hookPath, hookPaint);

    // Hook line
    canvas.drawLine(
      Offset(36 * scale, 4 * scale),
      Offset(36 * scale, 14 * scale),
      hookPaint,
    );

    // Draw bag outline
    final bagRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        bagLeft * scale,
        bagTop * scale,
        bagWidth * scale,
        bagHeight * scale,
      ),
      Radius.circular(bagRadius * scale),
    );

    // Bag background
    final bagBgPaint = Paint()..color = AppColors.blue50;
    canvas.drawRRect(bagRect, bagBgPaint);

    // Bag border
    final bagBorderPaint = Paint()
      ..color = AppColors.blue200
      ..strokeWidth = 1.5 * scale
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(bagRect, bagBorderPaint);

    // Draw fluid (clipped to bag shape)
    if (percent > 0) {
      canvas.save();
      canvas.clipRRect(bagRect);

      // Fluid gradient
      final fluidRect = Rect.fromLTWH(
        bagLeft * scale,
        fluidY * scale,
        bagWidth * scale,
        fluidHeight * scale,
      );

      final fluidGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fluidStartColor, fluidEndColor],
      );

      final fluidPaint = Paint()
        ..shader = fluidGradient.createShader(fluidRect);

      canvas.drawRect(fluidRect, fluidPaint);

      // Wave effect at top of fluid
      final wavePaint = Paint()
        ..color = waveColor.withValues(alpha: 0.5);

      final waveCenter = Offset(36 * scale, fluidY * scale);
      canvas.drawOval(
        Rect.fromCenter(
          center: waveCenter,
          width: 56 * scale,
          height: 8 * scale,
        ),
        wavePaint,
      );

      canvas.restore();
    }

    // Draw tube connector (bottom of bag)
    final tubePaint = Paint()..color = AppColors.blue200;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(32 * scale, 124 * scale, 8 * scale, 10 * scale),
        Radius.circular(2 * scale),
      ),
      tubePaint,
    );

    // Draw tube
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(35 * scale, 134 * scale, 2 * scale, 18 * scale),
        Radius.circular(1 * scale),
      ),
      tubePaint,
    );

    // Draw drop
    final dropPaint = Paint()..color = dropColor.withValues(alpha: 0.4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(36 * scale, 155 * scale),
        width: 6 * scale,
        height: 8 * scale,
      ),
      dropPaint,
    );
  }

  Color _getFluidStartColor() {
    switch (status) {
      case 'warning':
        return AppColors.statusWarningLight;
      case 'ended':
        return AppColors.borderLight;
      default:
        return AppColors.blue200;
    }
  }

  Color _getFluidEndColor() {
    switch (status) {
      case 'warning':
        return AppColors.statusWarning.withValues(alpha: 0.4);
      case 'ended':
        return AppColors.statusEnded.withValues(alpha: 0.2);
      default:
        return AppColors.blue500.withValues(alpha: 0.5);
    }
  }

  Color _getWaveColor() {
    switch (status) {
      case 'warning':
        return AppColors.statusWarningLight;
      case 'ended':
        return AppColors.textDisabled;
      default:
        return AppColors.blue300;
    }
  }

  Color _getDropColor() {
    switch (status) {
      case 'warning':
        return AppColors.statusWarning;
      case 'ended':
        return AppColors.textDisabled;
      default:
        return AppColors.blue500;
    }
  }

  @override
  bool shouldRepaint(_IVBagPainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.status != status;
  }
}

/// 애니메이션 IV 백 (수액 레벨 변화 애니메이션)
class AnimatedIVBagGraphic extends StatefulWidget {
  const AnimatedIVBagGraphic({
    super.key,
    required this.percent,
    required this.status,
    this.width = 72,
    this.height = 160,
    this.duration = const Duration(milliseconds: 600),
  });

  final double percent;
  final String status;
  final double width;
  final double height;
  final Duration duration;

  @override
  State<AnimatedIVBagGraphic> createState() => _AnimatedIVBagGraphicState();
}

class _AnimatedIVBagGraphicState extends State<AnimatedIVBagGraphic>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentPercent = 0;

  @override
  void initState() {
    super.initState();
    _currentPercent = widget.percent;
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: _currentPercent,
      end: widget.percent,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(AnimatedIVBagGraphic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent != widget.percent) {
      _animation = Tween<double>(
        begin: _currentPercent,
        end: widget.percent,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ));
      _controller.forward(from: 0).then((_) {
        _currentPercent = widget.percent;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return IVBagGraphic(
          percent: _animation.value,
          status: widget.status,
          width: widget.width,
          height: widget.height,
        );
      },
    );
  }
}
