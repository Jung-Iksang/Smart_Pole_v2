import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/models/notification_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/providers/notification_provider.dart';
import '../../shared/widgets/widgets.dart';

/// 알림 타입별 UI 설정
class AlertTypeConfig {
  final IconData icon;
  final Color color;
  final Color bg;
  final String label;

  const AlertTypeConfig({
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
  });
}

const Map<String, AlertTypeConfig> _typeConfig = {
  'low_fluid': AlertTypeConfig(
    icon: LucideIcons.droplets,
    color: Color(0xFF3B82F6),
    bg: Color(0xFFEFF6FF),
    label: '수액 잔량 부족',
  ),
  'flow_stop': AlertTypeConfig(
    icon: LucideIcons.alertTriangle,
    color: Color(0xFFEF4444),
    bg: Color(0xFFFEF2F2),
    label: '수액 흐름 중단',
  ),
  'flow_fast': AlertTypeConfig(
    icon: LucideIcons.gauge,
    color: Color(0xFFF59E0B),
    bg: Color(0xFFFFFBEB),
    label: '유속 과다',
  ),
  'flow_slow': AlertTypeConfig(
    icon: LucideIcons.timer,
    color: Color(0xFFD97706),
    bg: Color(0xFFFFF7ED),
    label: '유속 저하',
  ),
};

const AlertTypeConfig _defaultTypeConfig = AlertTypeConfig(
  icon: LucideIcons.info,
  color: Color(0xFF94A3B8),
  bg: Color(0xFFF8FAFC),
  label: '알림',
);

AlertTypeConfig _getConfig(String type) => _typeConfig[type] ?? _defaultTypeConfig;

/// 알림 스크린
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _filter = '전체'; // '전체', '미해결', '해결됨'

  List<NotificationData> _applyFilter(List<NotificationData> all) {
    if (_filter == '미해결') return all.where((n) => !n.isRead).toList();
    if (_filter == '해결됨') return all.where((n) => n.isRead).toList();
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(notificationProvider);

    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: asyncState.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.blue500),
                  ),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('알림을 불러올 수 없어요',
                            style: AppTypography.bodyLarge
                                .copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () =>
                              ref.read(notificationProvider.notifier).refresh(),
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                  data: (state) {
                    final filtered = _applyFilter(state.notifications);
                    if (filtered.isEmpty) return _buildEmptyState();
                    return RefreshIndicator(
                      onRefresh: () =>
                          ref.read(notificationProvider.notifier).refresh(),
                      color: AppColors.blue500,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _NotificationCard(
                              notification: item,
                              config: _getConfig(item.type),
                              onTap: item.isRead
                                  ? null
                                  : () => ref
                                      .read(notificationProvider.notifier)
                                      .markAsRead(item.notificationId),
                            ),
                          );
                        },
                      ),
                    );
                  },
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
                '알림',
                style: AppTypography.heading4.copyWith(
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    ref.read(notificationProvider.notifier).markAllAsRead(),
                child: Text(
                  '모두 읽음',
                  style: AppTypography.small.copyWith(
                    color: AppColors.blue500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildFilterTabs(),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: AppSpacing.borderRadiusLg,
      ),
      child: Row(
        children: ['전체', '미해결', '해결됨'].map((tab) {
          final isActive = _filter == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _filter = tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: AppSpacing.borderRadiusMd,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.blue500.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    tab,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? AppColors.blue700 : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: AppSpacing.borderRadiusLg,
            ),
            child: const Center(
              child: Icon(LucideIcons.bellOff, size: 32, color: AppColors.blue300),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '현재 알림이 없어요',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '새로운 알림이 오면 여기에 표시돼요',
            style: AppTypography.small.copyWith(color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}

/// 알림 카드 위젯
class _NotificationCard extends StatefulWidget {
  final NotificationData notification;
  final AlertTypeConfig config;
  final VoidCallback? onTap;

  const _NotificationCard({
    required this.notification,
    required this.config,
    this.onTap,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isRead = widget.notification.isRead;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isPressed
              ? AppColors.blue50.withValues(alpha: 0.3)
              : Colors.white,
          borderRadius: AppSpacing.borderRadiusLg,
          border: Border.all(
            color: isRead
                ? const Color(0xFFF1F5F9)
                : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
          ),
          boxShadow: isRead
              ? null
              : [
                  BoxShadow(
                    color: AppColors.blue500.withValues(alpha: 0.07),
                    blurRadius: 16,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Opacity(
          opacity: isRead ? 0.72 : 1.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isRead ? const Color(0xFFF8FAFC) : widget.config.bg,
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                child: Center(
                  child: Icon(
                    widget.config.icon,
                    size: 20,
                    color: isRead ? AppColors.textDisabled : widget.config.color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.config.label,
                          style: AppTypography.small.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isRead
                                ? AppColors.textMuted
                                : widget.config.color,
                          ),
                        ),
                        Text(
                          widget.notification.relativeTime,
                          style: AppTypography.micro
                              .copyWith(color: AppColors.textDisabled),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.notification.title,
                      style: AppTypography.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isRead
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.notification.message,
                      style: AppTypography.small.copyWith(
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status indicator
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: widget.config.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.config.color.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    LucideIcons.checkCircle2,
                    size: 16,
                    color: AppColors.textDisabled,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
