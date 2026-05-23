import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/widgets.dart';

/// 알림 타입
enum AlertType { batteryLow, disconnected, ivLow, abnormal }

/// 알림 상태
enum AlertStatus { resolved, unresolved }

/// 알림 데이터 모델
class NotificationItem {
  final String id;
  final String device;
  final AlertType type;
  final String message;
  final String time;
  final AlertStatus status;

  const NotificationItem({
    required this.id,
    required this.device,
    required this.type,
    required this.message,
    required this.time,
    required this.status,
  });
}

/// 알림 타입별 설정
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

/// 알림 스크린
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = '전체'; // '전체', '미해결', '해결됨'

  static const List<NotificationItem> _notifications = [
    NotificationItem(
      id: '1',
      device: 'IV Drip Pro',
      type: AlertType.ivLow,
      message: '잔여 수액이 10% 미만이에요. 교체 준비를 해주세요.',
      time: '2분 전',
      status: AlertStatus.unresolved,
    ),
    NotificationItem(
      id: '2',
      device: 'InfuTech IV-02',
      type: AlertType.batteryLow,
      message: '배터리가 15%에요. 충전이 필요해요.',
      time: '14분 전',
      status: AlertStatus.unresolved,
    ),
    NotificationItem(
      id: '3',
      device: 'IV Drip Pro',
      type: AlertType.abnormal,
      message: '주입 속도에 이상이 감지되었어요. 기기를 확인해주세요.',
      time: '1시간 전',
      status: AlertStatus.resolved,
    ),
    NotificationItem(
      id: '4',
      device: 'InfuTech IV-03',
      type: AlertType.disconnected,
      message: 'Wi-Fi 연결이 일시적으로 끊어졌어요.',
      time: '3시간 전',
      status: AlertStatus.resolved,
    ),
  ];

  static const Map<AlertType, AlertTypeConfig> _typeConfig = {
    AlertType.batteryLow: AlertTypeConfig(
      icon: LucideIcons.battery,
      color: Color(0xFFF59E0B),
      bg: Color(0xFFFFFBEB),
      label: '배터리 부족',
    ),
    AlertType.disconnected: AlertTypeConfig(
      icon: LucideIcons.wifiOff,
      color: Color(0xFF94A3B8),
      bg: Color(0xFFF8FAFC),
      label: '연결 끊김',
    ),
    AlertType.ivLow: AlertTypeConfig(
      icon: LucideIcons.droplets,
      color: Color(0xFF3B82F6),
      bg: Color(0xFFEFF6FF),
      label: '수액 종료 임박',
    ),
    AlertType.abnormal: AlertTypeConfig(
      icon: LucideIcons.alertTriangle,
      color: Color(0xFFEF4444),
      bg: Color(0xFFFEF2F2),
      label: '이상 상태',
    ),
  };

  List<NotificationItem> get _filteredNotifications {
    if (_filter == '미해결') {
      return _notifications.where((n) => n.status == AlertStatus.unresolved).toList();
    } else if (_filter == '해결됨') {
      return _notifications.where((n) => n.status == AlertStatus.resolved).toList();
    }
    return _notifications;
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
                child: _filteredNotifications.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        itemCount: _filteredNotifications.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _NotificationCard(
                              notification: _filteredNotifications[index],
                              config: _typeConfig[_filteredNotifications[index].type]!,
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
  final NotificationItem notification;
  final AlertTypeConfig config;

  const _NotificationCard({
    required this.notification,
    required this.config,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isResolved = widget.notification.status == AlertStatus.resolved;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
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
          color: _isPressed ? AppColors.blue50.withValues(alpha: 0.3) : Colors.white,
          borderRadius: AppSpacing.borderRadiusLg,
          border: Border.all(
            color: isResolved ? const Color(0xFFF1F5F9) : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
          ),
          boxShadow: isResolved
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
          opacity: isResolved ? 0.72 : 1.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isResolved ? const Color(0xFFF8FAFC) : widget.config.bg,
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                child: Center(
                  child: Icon(
                    widget.config.icon,
                    size: 20,
                    color: isResolved ? AppColors.textDisabled : widget.config.color,
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
                            color: isResolved ? AppColors.textMuted : widget.config.color,
                          ),
                        ),
                        Text(
                          widget.notification.time,
                          style: AppTypography.micro.copyWith(color: AppColors.textDisabled),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.notification.device,
                      style: AppTypography.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isResolved ? AppColors.textMuted : AppColors.textPrimary,
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
              if (!isResolved)
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
