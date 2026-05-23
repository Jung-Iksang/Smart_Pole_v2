import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/iv_bag_ocr_result.dart';

/// OCR 판독 결과 신뢰도 배너
///
/// confidence 수준에 따라 색상/아이콘/문구가 자동 변경된다.
/// - 0.90+ : 초록 (자동 판독 가능)
/// - 0.70+ : 주황 (확인 필요)
/// - 0.70- : 빨강/회색 (수동 입력 권장)
class OcrConfidenceBanner extends StatelessWidget {
  final IVBagOcrResult result;

  const OcrConfidenceBanner({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final tier = _ConfidenceTier.from(result.confidence);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tier.bgColor,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: tier.borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 아이콘 + 라벨 + 신뢰도
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tier.iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(tier.icon, size: 16, color: tier.iconColor),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.confidenceLabel,
                      style: AppTypography.small.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tier.titleColor,
                      ),
                    ),
                    if (result.hasVolume || result.hasFluidName)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          result.displaySummary,
                          style: AppTypography.caption.copyWith(
                            color: tier.subtitleColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 신뢰도 퍼센트 뱃지
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tier.badgeBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '신뢰도 ${result.confidencePercent}',
                  style: AppTypography.micro.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tier.badgeTextColor,
                  ),
                ),
              ),
            ],
          ),

          // 경고 메시지 (최대 2개)
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: tier.dividerColor),
            const SizedBox(height: 10),
            ...result.warnings.take(2).map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            LucideIcons.info,
                            size: 12,
                            color: tier.warningIconColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            w,
                            style: AppTypography.caption.copyWith(
                              color: tier.warningTextColor,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],

          // 확인 필요 안내 (중간 신뢰도)
          if (result.confidence >= 0.70 && result.confidence < 0.90) ...[
            const SizedBox(height: 6),
            Text(
              '저장 전 실제 라벨과 비교해주세요.',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: tier.warningTextColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 신뢰도 수준별 스타일 정의
class _ConfidenceTier {
  final Color bgColor;
  final Color borderColor;
  final Color iconBgColor;
  final IconData icon;
  final Color iconColor;
  final Color titleColor;
  final Color subtitleColor;
  final Color badgeBgColor;
  final Color badgeTextColor;
  final Color dividerColor;
  final Color warningIconColor;
  final Color warningTextColor;

  const _ConfidenceTier({
    required this.bgColor,
    required this.borderColor,
    required this.iconBgColor,
    required this.icon,
    required this.iconColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.badgeBgColor,
    required this.badgeTextColor,
    required this.dividerColor,
    required this.warningIconColor,
    required this.warningTextColor,
  });

  factory _ConfidenceTier.from(double confidence) {
    if (confidence >= 0.90) return _high;
    if (confidence >= 0.70) return _medium;
    return _low;
  }

  // 0.90+ : 자동 판독 가능
  static const _high = _ConfidenceTier(
    bgColor: AppColors.statusNormalBg,
    borderColor: Color(0xFFBBF7D0),
    iconBgColor: Color(0xFFDCFCE7),
    icon: LucideIcons.checkCircle,
    iconColor: AppColors.statusNormal,
    titleColor: Color(0xFF166534),
    subtitleColor: Color(0xFF16A34A),
    badgeBgColor: Color(0xFFDCFCE7),
    badgeTextColor: Color(0xFF166534),
    dividerColor: Color(0xFFBBF7D0),
    warningIconColor: Color(0xFF16A34A),
    warningTextColor: Color(0xFF166534),
  );

  // 0.70~0.89 : 확인 필요
  static const _medium = _ConfidenceTier(
    bgColor: AppColors.statusWarningBg,
    borderColor: Color(0xFFFDE68A),
    iconBgColor: Color(0xFFFEF3C7),
    icon: LucideIcons.alertCircle,
    iconColor: AppColors.statusWarning,
    titleColor: Color(0xFF92400E),
    subtitleColor: Color(0xFFD97706),
    badgeBgColor: Color(0xFFFEF3C7),
    badgeTextColor: Color(0xFF92400E),
    dividerColor: Color(0xFFFDE68A),
    warningIconColor: Color(0xFFD97706),
    warningTextColor: Color(0xFF92400E),
  );

  // 0.70 미만 : 수동 입력 권장
  static const _low = _ConfidenceTier(
    bgColor: Color(0xFFFEF2F2),
    borderColor: Color(0xFFFECACA),
    iconBgColor: Color(0xFFFEE2E2),
    icon: LucideIcons.alertTriangle,
    iconColor: Color(0xFFEF4444),
    titleColor: Color(0xFF991B1B),
    subtitleColor: Color(0xFFDC2626),
    badgeBgColor: Color(0xFFFEE2E2),
    badgeTextColor: Color(0xFF991B1B),
    dividerColor: Color(0xFFFECACA),
    warningIconColor: Color(0xFFDC2626),
    warningTextColor: Color(0xFF991B1B),
  );
}
