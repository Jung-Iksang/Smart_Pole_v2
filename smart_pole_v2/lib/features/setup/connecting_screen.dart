import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/providers/provisioning_provider.dart';
import '../../shared/widgets/widgets.dart';

/// 연결 중 스크린
/// ESP32가 WiFi에 연결하는 동안 상태를 모니터링합니다.
class ConnectingScreen extends ConsumerWidget {
  const ConnectingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provisioningProvider);

    // 상태에 따라 자동 네비게이션
    ref.listen<ProvisioningState>(provisioningProvider, (prev, next) {
      if (next.step == ProvisioningStep.success) {
        context.pushReplacement('/success');
      } else if (next.step == ProvisioningStep.error) {
        context.pushReplacement('/failure');
      }
    });

    String message;
    switch (state.step) {
      case ProvisioningStep.sendingCredentials:
        message = 'WiFi 정보를 전송하고 있어요';
        break;
      case ProvisioningStep.waitingWifiConnect:
        message = 'WiFi에 연결하고 있어요\n잠시만 기다려주세요';
        break;
      case ProvisioningStep.registeringDevice:
        message = '서버에 기기를 등록하고 있어요\n잠시만 기다려주세요';
        break;
      default:
        message = '기기 연결 중...\n잠시만 기다려주세요';
    }

    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedGlowRings(
                  outerSize: 200,
                  middleSize: 150,
                  innerSize: 100,
                  animate: true,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: AppColors.iconBadgeGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.wifi,
                        size: 32,
                        color: AppColors.blue500,
                      ),
                    ),
                  ),
                ),
                AppSpacing.gapVXl,
                Text(
                  '기기 연결 중...',
                  style: AppTypography.heading2,
                ),
                AppSpacing.gapVSm,
                Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapVXl,
                const CircularProgressIndicator(
                  color: AppColors.blue500,
                  strokeWidth: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
