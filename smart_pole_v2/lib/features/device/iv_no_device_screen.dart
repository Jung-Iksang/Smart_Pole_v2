import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/widgets.dart';

/// 연결된 기기 없음 스크린 (내 수액 탭)
class IVNoDeviceScreen extends StatelessWidget {
  const IVNoDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Empty IV bag illustration
                      Opacity(
                        opacity: 0.8,
                        child: _EmptyIVBagIllustration(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '연결된 기기가 없어요',
                        style: AppTypography.heading3.copyWith(
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '기기를 연결하면 수액 상태를\n확인할 수 있어요',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textMuted,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          text: '기기 연결하기',
                          icon: const Icon(LucideIcons.plus, size: 20, color: Colors.white),
                          onPressed: () => context.go('/setup-guide'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.blue300,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'QR 코드를 통해 쉽게 연결할 수 있어요',
                            style: AppTypography.small.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AnimatedIconButton(
            icon: LucideIcons.arrowLeft,
            onTap: () => context.pop(),
            iconColor: AppColors.textSecondary,
            activeIconColor: AppColors.blue500,
            activeBackgroundColor: AppColors.blue50,
          ),
          Text(
            '내 수액',
            style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(LucideIcons.slidersHorizontal, size: 20, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty IV bag illustration widget
class _EmptyIVBagIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(88, 180),
      painter: _EmptyIVBagPainter(),
    );
  }
}

class _EmptyIVBagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Hook
    paint
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final hookPath = Path()
      ..moveTo(44, 6)
      ..cubicTo(44, 6, 44, 2, 48, 2)
      ..cubicTo(52, 2, 52, 6, 52, 6);
    canvas.drawPath(hookPath, paint);

    // Hook line
    canvas.drawLine(const Offset(44, 6), const Offset(44, 18), paint);

    // Bag outline
    paint
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final bagRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(10, 18, 68, 124),
      const Radius.circular(18),
    );

    // Draw dashed bag outline
    final bagPath = Path()..addRRect(bagRect);
    _drawDashedPath(canvas, bagPath, paint, 5, 3);

    // Fill bag
    paint
      ..color = const Color(0xFFF8FAFC)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bagRect, paint);

    // Inner dashed hint
    paint
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final innerRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(22, 30, 44, 100),
      const Radius.circular(12),
    );
    final innerPath = Path()..addRRect(innerRect);
    _drawDashedPath(canvas, innerPath, paint, 4, 3);

    // Droplets icon circle
    paint
      ..color = const Color(0xFFEFF6FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(44, 82), 18, paint);

    // Droplet shape
    paint.color = const Color(0xFFBFDBFE);
    final dropPath = Path()
      ..moveTo(44, 70)
      ..cubicTo(44, 70, 36, 78, 36, 84)
      ..cubicTo(36, 88.4, 39.6, 92, 44, 92)
      ..cubicTo(48.4, 92, 52, 88.4, 52, 84)
      ..cubicTo(52, 78, 44, 70, 44, 70);
    canvas.drawPath(dropPath, paint);

    // Tube
    paint.color = const Color(0xFFE2E8F0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(41, 142, 6, 14),
        const Radius.circular(2),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(43, 156, 2, 16),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawOval(Rect.fromCenter(center: const Offset(44, 175), width: 7, height: 8), paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dashWidth, double dashSpace) {
    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
