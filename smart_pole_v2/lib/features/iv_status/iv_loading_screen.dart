import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/widgets.dart';

/// IV 상태 로딩 스크린
class IVLoadingScreen extends StatefulWidget {
  const IVLoadingScreen({super.key});

  @override
  State<IVLoadingScreen> createState() => _IVLoadingScreenState();
}

class _IVLoadingScreenState extends State<IVLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.55).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildDeviceSelectorSkeleton(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildHeroCardSkeleton(),
                      const SizedBox(height: 12),
                      _buildInfoTilesSkeleton(),
                      const SizedBox(height: 12),
                      _buildSafetyCardSkeleton(),
                      const SizedBox(height: 12),
                      _buildActionRowSkeleton(),
                      const SizedBox(height: 16),
                      _buildLoadingIndicator(),
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

  Widget _buildHeader() {
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

  Widget _buildDeviceSelectorSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _ShimmerBlock(height: 36, width: 160, radius: 12),
      ),
    );
  }

  Widget _buildHeroCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: const Color(0xFFE8F0FE)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue500.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ShimmerBlock(height: 14, width: 80, radius: 7),
              _ShimmerBlock(height: 22, width: 60, radius: 11),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ShimmerBlock(height: 130, width: 72, radius: 14),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBlock(height: 14, width: double.infinity * 0.7, radius: 7),
                    const SizedBox(height: 12),
                    _ShimmerBlock(height: 12, width: double.infinity * 0.5, radius: 6),
                    const SizedBox(height: 8),
                    _ShimmerBlock(height: 8, width: double.infinity, radius: 4),
                    const SizedBox(height: 12),
                    _ShimmerBlock(height: 12, width: double.infinity * 0.4, radius: 6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ShimmerBlock(height: 48, width: double.infinity, radius: 12),
        ],
      ),
    );
  }

  Widget _buildInfoTilesSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: const Color(0xFFE8F0FE)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue500.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBlock(height: 12, width: 80, radius: 6),
          const SizedBox(height: 12),
          Row(
            children: List.generate(3, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i > 0 ? 12 : 0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: AppSpacing.borderRadiusMd,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShimmerBlock(height: 24, width: 24, radius: 6),
                        const SizedBox(height: 8),
                        _ShimmerBlock(height: 10, width: 50, radius: 5),
                        const SizedBox(height: 4),
                        _ShimmerBlock(height: 14, width: 60, radius: 7),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: const Color(0xFFE8F0FE)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue500.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          _ShimmerBlock(height: 40, width: 40, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBlock(height: 13, width: 100, radius: 6),
                const SizedBox(height: 8),
                _ShimmerBlock(height: 11, width: 150, radius: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRowSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: const Color(0xFFE8F0FE)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue500.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _ShimmerBlock(height: 44, width: double.infinity, radius: 12)),
          const SizedBox(width: 12),
          Expanded(child: _ShimmerBlock(height: 44, width: double.infinity, radius: 12)),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _pulseAnimation.value,
          child: Row(
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
                '수액 상태를 확인하는 중...',
                style: AppTypography.small.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.blue300,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shimmer block widget
class _ShimmerBlock extends StatefulWidget {
  final double height;
  final double width;
  final double radius;

  const _ShimmerBlock({
    required this.height,
    required this.width,
    required this.radius,
  });

  @override
  State<_ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<_ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
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
        return Container(
          height: widget.height,
          width: widget.width == double.infinity ? null : widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: const [
                Color(0xFFEFF6FF),
                Color(0xFFDBEAFE),
                Color(0xFFEFF6FF),
              ],
            ),
          ),
        );
      },
    );
  }
}
