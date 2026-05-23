import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/widgets.dart';

/// 현재 진행 중인 수액 없음 스크린
class IVNoSessionScreen extends StatelessWidget {
  const IVNoSessionScreen({super.key});

  static const _lastSession = {
    'date': '2025년 12월 3일',
    'duration': '3시간 42분',
    'totalMl': 500,
    'device': 'InfuTech IV-01',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildDeviceSelector(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildMainCard(),
                      const SizedBox(height: 12),
                      _buildDeviceStatusRow(),
                      const SizedBox(height: 16),
                      _buildLastSessionLabel(),
                      const SizedBox(height: 8),
                      _buildLastSessionCard(),
                      const SizedBox(height: 24),
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

  Widget _buildDeviceSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppSpacing.borderRadiusMd,
            border: Border.all(color: const Color(0xFFE8F0FE)),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue500.withValues(alpha: 0.07),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.statusNormal,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.statusNormal.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'InfuTech IV-01',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.borderRadiusXl,
        border: Border.all(color: const Color(0xFFE8F0FE)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue500.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Idle IV bag illustration
          Opacity(
            opacity: 0.85,
            child: _IdleIVBagIllustration(),
          ),
          const SizedBox(height: 16),
          Text(
            '현재 진행 중인 수액이 없어요',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '수액이 시작되면 상태를 확인할 수 있어요',
            style: AppTypography.small.copyWith(
              color: AppColors.textMuted,
              height: 1.65,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceStatusRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: const Color(0xFFE8F0FE)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue500.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '기기 상태',
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(LucideIcons.wifi, size: 14, color: AppColors.statusNormal),
              const SizedBox(width: 4),
              Text(
                '연결됨',
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.statusNormal,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFFE2E8F0),
          ),
          Row(
            children: [
              const Icon(LucideIcons.battery, size: 14, color: AppColors.blue500),
              const SizedBox(width: 4),
              Text(
                '92%',
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.blue500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLastSessionLabel() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          '마지막 수액 기록',
          style: AppTypography.small.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.05,
          ),
        ),
      ),
    );
  }

  Widget _buildLastSessionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: const Color(0xFFE8F0FE)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue500.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: const Center(
              child: Icon(LucideIcons.droplets, size: 20, color: AppColors.blue500),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lastSession['device'] as String,
                  style: AppTypography.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(LucideIcons.clock, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      _lastSession['duration'] as String,
                      style: AppTypography.small.copyWith(color: AppColors.textMuted),
                    ),
                    Container(
                      width: 1,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: const Color(0xFFE2E8F0),
                    ),
                    Text(
                      '${_lastSession['totalMl']}ml',
                      style: AppTypography.small.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            _lastSession['date'] as String,
            style: AppTypography.small.copyWith(color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}

/// Idle IV bag illustration
class _IdleIVBagIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(80, 168),
      painter: _IdleIVBagPainter(),
    );
  }
}

class _IdleIVBagPainter extends CustomPainter {
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
      ..moveTo(40, 5)
      ..cubicTo(40, 5, 40, 1, 44, 1)
      ..cubicTo(48, 1, 48, 5, 48, 5);
    canvas.drawPath(hookPath, paint);

    canvas.drawLine(const Offset(40, 5), const Offset(40, 16), paint);

    // Bag
    paint
      ..color = const Color(0xFFBFDBFE)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 16, 68, 114),
        const Radius.circular(17),
      ),
      paint,
    );

    paint
      ..color = const Color(0xFFF0F7FF)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 16, 68, 114),
        const Radius.circular(17),
      ),
      paint,
    );

    // Light fluid at bottom
    paint.color = const Color(0xFFDBEAFE).withValues(alpha: 0.5);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(6, 16, 68, 114),
      const Radius.circular(17),
    ));
    canvas.drawRect(const Rect.fromLTWH(6, 110, 68, 20), paint);

    paint.color = const Color(0xFF93C5FD).withValues(alpha: 0.3);
    canvas.drawOval(Rect.fromCenter(center: const Offset(40, 110), width: 68, height: 7), paint);
    canvas.restore();

    // Pause icon circle
    paint
      ..color = const Color(0xFFEFF6FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(40, 73), 18, paint);

    // Pause bars
    paint.color = const Color(0xFF93C5FD);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(34, 65, 5, 16),
        const Radius.circular(2.5),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(41, 65, 5, 16),
        const Radius.circular(2.5),
      ),
      paint,
    );

    // Tube
    paint.color = const Color(0xFFBFDBFE);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(37, 130, 6, 10),
        const Radius.circular(2),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(39, 140, 2, 20),
        const Radius.circular(1),
      ),
      paint,
    );

    paint.color = const Color(0xFF93C5FD).withValues(alpha: 0.35);
    canvas.drawOval(Rect.fromCenter(center: const Offset(40, 163), width: 6, height: 8), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
