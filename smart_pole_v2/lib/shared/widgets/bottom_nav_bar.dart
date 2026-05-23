import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 하단 네비게이션 바
/// React의 bottom navigation과 동일한 4탭 구조
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_NavItem> _items = [
    _NavItem(icon: LucideIcons.droplets, label: '내 수액'),
    _NavItem(icon: LucideIcons.bell, label: '알림'),
    _NavItem(icon: LucideIcons.user, label: '내 정보'),
  ];

  @override
  Widget build(BuildContext context) {
    // Get bottom padding for safe area (home indicator on iPhone X+)
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(
          top: BorderSide(color: AppColors.grayLight, width: 1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.base,
          right: AppSpacing.base,
          top: AppSpacing.md,
          // Use actual bottom safe area padding for all phone types
          bottom: bottomPadding > 0 ? bottomPadding : AppSpacing.base,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
            _items.length,
            (index) => _NavBarItem(
              item: _items[index],
              isActive: currentIndex == index,
              onTap: () => onTap(index),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppSpacing.animNormal,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? AppColors.blue50 : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              size: 20,
              color: isActive ? AppColors.blue500 : AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: AppTypography.tiny.copyWith(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? AppColors.blue500 : AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

/// 탭 인덱스 열거형
enum NavTab {
  iv,
  alarm,
  me,
}
