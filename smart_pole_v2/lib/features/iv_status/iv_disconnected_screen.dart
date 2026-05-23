import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/providers/iv_status_provider.dart';
import '../../shared/widgets/widgets.dart';

/// IV 연결 끊김 스크린 — 실제 재연결 로직 적용
class IVDisconnectedScreen extends ConsumerStatefulWidget {
  const IVDisconnectedScreen({super.key});

  @override
  ConsumerState<IVDisconnectedScreen> createState() => _IVDisconnectedScreenState();
}

class _IVDisconnectedScreenState extends ConsumerState<IVDisconnectedScreen> {
  bool _retrying = false;
  String? _retryError;

  static const _device = {
    'name': 'InfuTech IV-01',
    'lastUpdated': '9분 전',
    'battery': 78,
  };

  Future<void> _handleRetry() async {
    setState(() {
      _retrying = true;
      _retryError = null;
    });

    try {
      // 1. 서버에서 대시보드 데이터 새로고침
      await ref.read(dashboardProvider.notifier).refresh();

      // 2. 데이터 확인 — 기기가 다시 연결되었는지 체크
      final dashboard = ref.read(dashboardProvider).valueOrNull;
      if (dashboard != null && dashboard.devices.isNotEmpty) {
        final device = dashboard.devices.first;
        if (device.isConnected) {
          if (mounted) context.go('/iv-status');
          return;
        }
      }

      // 3. 아직 연결 안 됨
      if (mounted) {
        setState(() {
          _retrying = false;
          _retryError = '아직 기기가 연결되지 않았습니다';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _retrying = false;
          _retryError = '서버 연결 실패';
        });
      }
    }
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
              _buildDeviceChip(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildDisconnectionCard(),
                      if (_retryError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _retryError!,
                          style: AppTypography.small.copyWith(
                            color: AppColors.statusWarning,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildTipsCard(),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              _buildButtons(),
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

  Widget _buildDeviceChip() {
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
                decoration: const BoxDecoration(
                  color: Color(0xFFCBD5E1),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _device['name'] as String,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.statusWarning.withValues(alpha: 0.09),
            blurRadius: 20,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
              ),
              borderRadius: AppSpacing.borderRadiusLg,
            ),
            child: const Center(
              child: Icon(LucideIcons.wifiOff, size: 32, color: AppColors.statusWarning),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '기기와 연결이 끊어졌어요',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Wi-Fi 상태를 확인하거나\n다시 시도해주세요',
            style: AppTypography.small.copyWith(
              color: AppColors.textMuted,
              height: 1.65,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Device info row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.statusWarningBg,
              borderRadius: AppSpacing.borderRadiusMd,
              border: Border.all(color: const Color(0xFFFEF3C7)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFCD34D),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _device['name'] as String,
                      style: AppTypography.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(LucideIcons.battery, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Text(
                      '${_device['battery']}%',
                      style: AppTypography.small.copyWith(
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: const Color(0xFFFDE68A),
                    ),
                    const Icon(LucideIcons.clock, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Text(
                      _device['lastUpdated'] as String,
                      style: AppTypography.small.copyWith(
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    final tips = [
      '핸드폰이 Wi-Fi에 연결되어 있는지 확인해주세요',
      '기기의 전원이 켜져 있는지 확인해주세요',
      '기기 가까이에서 다시 시도해보세요',
    ];

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '확인해보세요',
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.04,
            ),
          ),
          const SizedBox(height: 12),
          ...tips.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.blue50,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blue500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: AppTypography.small.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _retrying ? null : _handleRetry,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                decoration: BoxDecoration(
                  gradient: _retrying
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.blue500, Color(0xFF6366F1)],
                        ),
                  color: _retrying ? const Color(0xFFE2E8F0) : null,
                  borderRadius: AppSpacing.borderRadiusLg,
                  boxShadow: _retrying
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.blue500.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _retrying
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textMuted,
                              ),
                            )
                          : const Icon(LucideIcons.refreshCw, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        _retrying ? '연결 중...' : '다시 시도',
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _retrying ? AppColors.textMuted : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {},
            child: Container(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.wifi, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Wi-Fi 설정 확인',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.textDisabled),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
