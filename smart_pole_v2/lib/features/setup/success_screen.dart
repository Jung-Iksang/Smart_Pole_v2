import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/providers/provisioning_provider.dart';
import '../../shared/widgets/widgets.dart';

/// 연결 성공 스크린
class SuccessScreen extends ConsumerWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provState = ref.read(provisioningProvider);
    final deviceId = provState.registeredDeviceId;

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
                          color: AppColors.statusNormalBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            LucideIcons.checkCircle,
                            size: 48,
                            color: AppColors.statusNormal,
                          ),
                        ),
                      ),
                      AppSpacing.gapVXl,
                      Text(
                        '연결 완료!',
                        style: AppTypography.heading1.copyWith(
                          color: AppColors.statusNormal,
                        ),
                      ),
                      AppSpacing.gapVSm,
                      Text(
                        '기기가 성공적으로 연결되었어요\n수액팩 정보를 입력하면 모니터링이 시작돼요',
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
                child: PrimaryButton(
                  text: '수액 정보 입력하기',
                  onPressed: () {
                    if (deviceId != null) {
                      context.go('/iv-bag-scan', extra: deviceId);
                    } else {
                      context.go('/iv-status');
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
