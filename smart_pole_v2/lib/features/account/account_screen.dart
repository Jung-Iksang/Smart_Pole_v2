import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/iv_status_provider.dart';
import '../../shared/widgets/widgets.dart';

/// 내 정보 스크린
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final patientName = dashboardAsync.valueOrNull?.patientName ?? '';
    final deviceCount = dashboardAsync.valueOrNull?.devices.length ?? 0;

    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildProfileCard(patientName),
                      const SizedBox(height: 16),
                      _buildSectionLabel('계정 정보'),
                      const SizedBox(height: 8),
                      _buildInfoCard(context, deviceCount),
                      const SizedBox(height: 12),
                      _buildLoginStatusBadge(),
                      const SizedBox(height: 16),
                      _buildSectionLabel('계정 관리'),
                      const SizedBox(height: 8),
                      _buildActionsCard(context, ref),
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          AnimatedIconButton(
            icon: LucideIcons.arrowLeft,
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/iv-status');
              }
            },
            backgroundColor: AppColors.blue50,
            activeBackgroundColor: AppColors.blue100,
            iconColor: AppColors.blue500,
            activeIconColor: AppColors.blue600,
          ),
          const SizedBox(width: 12),
          Text(
            '내 정보',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(String patientName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFF5F3FF)],
        ),
        borderRadius: AppSpacing.borderRadiusXl,
        border: Border.all(color: AppColors.blue400.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFDBEAFE), Color(0xFFC7D2FE)],
              ),
              borderRadius: AppSpacing.borderRadiusLg,
              boxShadow: [
                BoxShadow(
                  color: AppColors.blue500.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(LucideIcons.user, size: 28, color: AppColors.blue500),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                patientName.isNotEmpty ? patientName : '사용자',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: AppTypography.small.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.05,
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, int deviceCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.borderRadiusXl,
        border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.8)),
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
          // Connected devices
          _InfoRow(
            icon: LucideIcons.smartphone,
            iconColor: AppColors.statusNormal,
            iconBg: AppColors.statusNormalBg,
            label: '연결된 기기',
            value: deviceCount > 0 ? '$deviceCount대 연결 중' : '연결된 기기 없음',
            showBorder: false,
            onTap: () => context.go('/iv-status'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.statusNormal,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.statusNormal,
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '현재 로그인 상태예요',
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.w500,
              color: const Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.borderRadiusXl,
        border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.8)),
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
          // Account settings
          _ActionRow(
            icon: LucideIcons.user,
            iconColor: AppColors.textSecondary,
            iconBg: const Color(0xFFF8FAFC),
            label: '계정 설정으로 이동',
            showBorder: true,
            onTap: () {},
          ),
          // Logout
          _ActionRow(
            icon: LucideIcons.logOut,
            iconColor: const Color(0xFFF87171),
            iconBg: const Color(0xFFFEF2F2),
            label: '로그아웃',
            labelColor: const Color(0xFFEF4444),
            showBorder: false,
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final bool showBorder;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.showBorder,
    this.onTap,
  });

  @override
  State<_InfoRow> createState() => _InfoRowState();
}

class _InfoRowState extends State<_InfoRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.onTap != null ? (_) {
        setState(() => _isPressed = false);
        widget.onTap!();
      } : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onTap == null ? null : () {},
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppSpacing.animFast,
        transform: Matrix4.diagonal3Values(
          _isPressed ? 0.98 : 1.0,
          _isPressed ? 0.98 : 1.0,
          1.0,
        ),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isPressed ? AppColors.blue50.withValues(alpha: 0.5) : Colors.transparent,
          border: widget.showBorder
              ? const Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.iconBg,
                borderRadius: AppSpacing.borderRadiusMd,
              ),
              child: Center(
                child: Icon(widget.icon, size: 18, color: widget.iconColor),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: AppTypography.small.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.value,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.05,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onTap != null)
              const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final Color? labelColor;
  final bool showBorder;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    this.labelColor,
    required this.showBorder,
    required this.onTap,
  });

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
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
          _isPressed ? 0.98 : 1.0,
          _isPressed ? 0.98 : 1.0,
          1.0,
        ),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isPressed ? AppColors.blue50.withValues(alpha: 0.5) : Colors.transparent,
          border: widget.showBorder
              ? const Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.iconBg,
                borderRadius: AppSpacing.borderRadiusMd,
              ),
              child: Center(
                child: Icon(widget.icon, size: 18, color: widget.iconColor),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.label,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                  color: widget.labelColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            if (widget.labelColor == null)
              const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}
