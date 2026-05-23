import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/widgets.dart';

/// FAQ 데이터 모델
class FAQ {
  final String id;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String question;
  final String answer;

  const FAQ({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.question,
    required this.answer,
  });
}

/// 도움말 스크린
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final Set<String> _openIds = {};

  static const List<FAQ> _faqs = [
    FAQ(
      id: '1',
      icon: LucideIcons.smartphone,
      iconColor: Color(0xFF3B82F6),
      iconBg: Color(0xFFEFF6FF),
      question: '기기를 어떻게 연결하나요?',
      answer: '앱 하단의 "기기 연결" 버튼을 누르고 안내에 따라 기기 옆의 QR 코드를 스캔하면 돼요. 핸드폰과 기기가 같은 Wi-Fi에 연결되어 있는지 먼저 확인해주세요.',
    ),
    FAQ(
      id: '2',
      icon: LucideIcons.droplets,
      iconColor: Color(0xFF6366F1),
      iconBg: Color(0xFFEEF2FF),
      question: '수액 상태는 어떻게 확인하나요?',
      answer: '홈 화면에서 연결된 기기를 탭하면 현재 수액 잔량, 주입 속도, 예상 완료 시간을 바로 확인할 수 있어요. 수액이 10% 미만이 되면 알림도 보내드려요.',
    ),
    FAQ(
      id: '3',
      icon: LucideIcons.alertTriangle,
      iconColor: Color(0xFFF59E0B),
      iconBg: Color(0xFFFFFBEB),
      question: '문제가 발생하면 어떻게 해야 하나요?',
      answer: '알림 화면에서 발생한 문제를 확인할 수 있어요. 해결이 어려운 경우, 담당 간호사에게 문의하거나 아래 고객 지원 버튼을 눌러주세요. 긴급 상황에서는 항상 의료진에게 먼저 연락해주세요.',
    ),
    FAQ(
      id: '4',
      icon: LucideIcons.wifi,
      iconColor: Color(0xFF10B981),
      iconBg: Color(0xFFECFDF5),
      question: '기기 연결이 자꾸 끊겨요',
      answer: '핸드폰과 기기가 같은 Wi-Fi 네트워크에 있는지 확인해주세요. 신호가 약한 경우 기기 가까이서 사용해보세요. 문제가 계속된다면 앱을 껐다가 다시 켜거나 고객 지원에 문의해주세요.',
    ),
    FAQ(
      id: '5',
      icon: LucideIcons.battery,
      iconColor: Color(0xFF8B5CF6),
      iconBg: Color(0xFFF5F3FF),
      question: '배터리 알림이 왔어요',
      answer: '기기 배터리가 20% 이하일 때 알림을 드려요. 기기 측면의 충전 포트에 충전선을 꽂아 충전해주세요. 충전 중에도 정상적으로 사용할 수 있어요.',
    ),
  ];

  void _toggleFaq(String id) {
    setState(() {
      if (_openIds.contains(id)) {
        _openIds.remove(id);
      } else {
        _openIds.add(id);
      }
    });
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildSectionLabel('자주 묻는 질문'),
                      const SizedBox(height: 8),
                      _buildFaqList(),
                      const SizedBox(height: 16),
                      _buildSupportCard(),
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedIconButton(
                icon: LucideIcons.arrowLeft,
                onTap: () => context.pop(),
                backgroundColor: AppColors.blue50,
                activeBackgroundColor: AppColors.blue100,
                iconColor: AppColors.blue500,
                activeIconColor: AppColors.blue600,
              ),
              const SizedBox(width: 12),
              Text(
                '도움말',
                style: AppTypography.heading4.copyWith(
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildHintCard(),
        ],
      ),
    );
  }

  Widget _buildHintCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: AppSpacing.borderRadiusLg,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF60A5FA),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '궁금한 항목을 눌러서 답변을 확인해보세요',
              style: AppTypography.small.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
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

  Widget _buildFaqList() {
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
        children: _faqs.map((faq) {
          final isOpen = _openIds.contains(faq.id);
          return _FAQItem(
            faq: faq,
            isOpen: isOpen,
            onTap: () => _toggleFaq(faq.id),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSupportCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: AppSpacing.borderRadiusLg,
            ),
            child: const Center(
              child: Icon(LucideIcons.headphones, size: 24, color: AppColors.blue500),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '해결이 안 되셨나요?',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '고객 지원팀이 도와드릴게요',
            style: AppTypography.small.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: '고객 지원 요청',
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  final FAQ faq;
  final bool isOpen;
  final VoidCallback onTap;

  const _FAQItem({
    required this.faq,
    required this.isOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isOpen ? faq.iconBg : const Color(0xFFF8FAFC),
                    borderRadius: AppSpacing.borderRadiusMd,
                  ),
                  child: Center(
                    child: Icon(
                      faq.icon,
                      size: 18,
                      color: isOpen ? faq.iconColor : AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    faq.question,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: isOpen ? FontWeight.w700 : FontWeight.w500,
                      color: isOpen ? AppColors.textPrimary : const Color(0xFF334155),
                      height: 1.45,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    LucideIcons.chevronDown,
                    size: 16,
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 20, 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: AppSpacing.borderRadiusLg,
                border: Border.all(color: AppColors.blue50),
              ),
              child: Text(
                faq.answer,
                style: AppTypography.small.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.65,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
