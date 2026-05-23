import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/widgets.dart';

/// 웰컴 스크린
/// 깔끔하고 현대적인 시작 화면
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ── App Logo & Name ──
                _buildLogo(),

                const Spacer(flex: 1),

                // ── Main Message ──
                _buildMessage(),

                const Spacer(flex: 2),

                // ── Actions ──
                _buildActions(context),

                const SizedBox(height: 16),

                // ── Bottom Trust Text ──
                _buildTrustText(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // App icon badge
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppColors.iconBadgeGradient,
            borderRadius: AppSpacing.borderRadiusXl,
            boxShadow: const [
              BoxShadow(
                color: Color(0x263B82F6),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              LucideIcons.droplets,
              size: 36,
              color: AppColors.blue500,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // App name
        Text(
          'InfuCare',
          style: AppTypography.appName.copyWith(
            fontSize: 28,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMessage() {
    return Column(
      children: [
        // Main headline
        Text(
          '내 수액 상태를\n한눈에',
          textAlign: TextAlign.center,
          style: AppTypography.heading1.copyWith(
            fontSize: 28,
            height: 1.3,
          ),
        ),

        const SizedBox(height: 16),

        // Description
        Text(
          '실시간으로 수액 상태를 확인하고\n중요한 알림을 받아보세요',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textMuted,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        // Primary button - 회원가입
        PrimaryButton(
          text: '시작하기',
          onPressed: () => context.push('/signup'),
        ),

        const SizedBox(height: 16),

        // Login link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '이미 계정이 있으신가요? ',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/login'),
              child: Text(
                '로그인',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.blue500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          LucideIcons.shieldCheck,
          size: 14,
          color: AppColors.textDisabled,
        ),
        const SizedBox(width: 6),
        Text(
          '안전한 의료 모니터링 서비스',
          style: AppTypography.caption.copyWith(
            color: AppColors.textDisabled,
          ),
        ),
      ],
    );
  }
}
