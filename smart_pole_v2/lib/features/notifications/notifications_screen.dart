import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/models/notification_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/alert_type_config.dart';
import '../../shared/providers/ble_monitor_provider.dart';
import '../../shared/providers/notification_provider.dart';
import '../../shared/widgets/widgets.dart';

/// 서버 알림(NotificationData)과 BLE 직결 알림(BleAlert)을 한 목록으로 보여주기 위한 행 모델
class _NotifRow {
  final String type;
  final String title;
  final String message;
  final String relativeTime;
  final DateTime at;
  final bool isRead;
  final bool fromBle;
  final VoidCallback? onTap;

  const _NotifRow({
    required this.type,
    required this.title,
    required this.message,
    required this.relativeTime,
    required this.at,
    required this.isRead,
    required this.fromBle,
    required this.onTap,
  });
}

/// 알림 스크린
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _filter = '전체'; // '전체', '미해결', '해결됨'

  List<_NotifRow> _applyFilter(List<_NotifRow> all) {
    if (_filter == '미해결') return all.where((n) => !n.isRead).toList();
    if (_filter == '해결됨') return all.where((n) => n.isRead).toList();
    return all;
  }

  /// BLE 알림(최신 우선) + 서버 알림을 시간순으로 병합
  List<_NotifRow> _mergeRows(List<NotificationData> server) {
    final ble = ref.watch(bleMonitorProvider).alerts;
    final rows = <_NotifRow>[
      for (final a in ble)
        _NotifRow(
          type: a.type,
          title: a.title,
          message: a.message,
          relativeTime: a.relativeTime,
          at: a.receivedAt,
          isRead: a.isRead,
          fromBle: true,
          onTap: a.isRead
              ? null
              : () => ref.read(bleMonitorProvider.notifier).markRead(a.id),
        ),
      for (final n in server)
        _NotifRow(
          type: n.type,
          title: n.title,
          message: n.message,
          relativeTime: n.relativeTime,
          at: n.createdAt,
          isRead: n.isRead,
          fromBle: false,
          onTap: n.isRead
              ? null
              : () => ref
                  .read(notificationProvider.notifier)
                  .markAsRead(n.notificationId),
        ),
    ];
    rows.sort((a, b) => b.at.compareTo(a.at));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(notificationProvider);
    final hasBle = ref.watch(bleMonitorProvider).alerts.isNotEmpty;

    // 서버가 꺼져 있어도(시연) BLE 알림은 보여준다.
    final Widget body;
    if (asyncState.isLoading && !hasBle) {
      body = const Center(
        child: CircularProgressIndicator(color: AppColors.blue500),
      );
    } else if (asyncState.hasError && !hasBle) {
      body = Center(
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
      );
    } else {
      final server = asyncState.valueOrNull?.notifications ?? const [];
      final filtered = _applyFilter(_mergeRows(server));
      body = RefreshIndicator(
        onRefresh: () => ref.read(notificationProvider.notifier).refresh(),
        color: AppColors.blue500,
        child: filtered.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: _buildEmptyState(),
                  ),
                ],
              )
            : ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _NotificationCard(
                      row: item,
                      config: alertConfigFor(item.type),
                      onTap: item.onTap,
                    ),
                  );
                },
              ),
      );
    }

    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: body),
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
                onTap: () {
                  ref.read(bleMonitorProvider.notifier).markAllRead();
                  ref.read(notificationProvider.notifier).markAllAsRead();
                },
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
  final _NotifRow row;
  final AlertTypeConfig config;
  final VoidCallback? onTap;

  const _NotificationCard({
    required this.row,
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
    final isRead = widget.row.isRead;

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
                        Row(
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
                            if (widget.row.fromBle) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.blue50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'BLE',
                                  style: AppTypography.micro.copyWith(
                                    color: AppColors.blue500,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          widget.row.relativeTime,
                          style: AppTypography.micro
                              .copyWith(color: AppColors.textDisabled),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.row.title,
                      style: AppTypography.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isRead
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.row.message,
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
