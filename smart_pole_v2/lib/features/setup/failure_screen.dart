import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/providers/provisioning_provider.dart';
import '../../shared/widgets/widgets.dart';

/// 연결 실패 스크린 — 부분 재시도 지원
class FailureScreen extends ConsumerStatefulWidget {
  const FailureScreen({super.key});

  @override
  ConsumerState<FailureScreen> createState() => _FailureScreenState();
}

class _FailureScreenState extends ConsumerState<FailureScreen> {
  bool _retrying = false;

  @override
  Widget build(BuildContext context) {
    final provState = ref.watch(provisioningProvider);
    final errorMsg = provState.errorMessage ?? '기기 연결에 실패했어요';
    final hasQrData = provState.qrData != null;

    // 재시도 중 상태가 변하면 해당 화면으로 이동
    ref.listen<ProvisioningState>(provisioningProvider, (prev, next) {
      if (!_retrying) return;
      if (next.step == ProvisioningStep.wifiListReady) {
        context.go('/wifi-list');
      } else if (next.step == ProvisioningStep.success) {
        context.go('/success');
      } else if (next.step == ProvisioningStep.error) {
        setState(() => _retrying = false);
      }
    });

    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.statusWarningBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            LucideIcons.alertTriangle,
                            size: 48,
                            color: AppColors.statusWarning,
                          ),
                        ),
                      ),
                      AppSpacing.gapVXl,
                      Text(
                        '연결 실패',
                        style: AppTypography.heading1.copyWith(
                          color: AppColors.statusWarning,
                        ),
                      ),
                      AppSpacing.gapVSm,
                      Text(
                        errorMsg,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  children: [
                    // 부분 재시도 (QR 데이터가 있으면 실패한 단계부터)
                    PrimaryButton(
                      text: _retrying ? '재시도 중...' : '다시 시도',
                      onPressed: _retrying
                          ? null
                          : () {
                              if (hasQrData) {
                                setState(() => _retrying = true);
                                ref
                                    .read(provisioningProvider.notifier)
                                    .retryFromLastStep();
                              } else {
                                context.go('/qr-scan');
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      text: '처음으로',
                      onPressed: _retrying
                          ? null
                          : () {
                              ref.read(provisioningProvider.notifier).reset();
                              context.go('/setup-guide');
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
