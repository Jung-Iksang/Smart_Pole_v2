import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_shadows.dart';
import '../../shared/widgets/widgets.dart';

/// 기기 홈 스크린
/// React의 DeviceHomeScreen과 동일한 UI
class DeviceHomeScreen extends StatefulWidget {
  const DeviceHomeScreen({super.key});

  @override
  State<DeviceHomeScreen> createState() => _DeviceHomeScreenState();
}

class _DeviceHomeScreenState extends State<DeviceHomeScreen> {
  int _currentNavIndex = 0;
  int _activePage = 0;
  String _selectedDeviceId = 'IV-D10012';
  bool _selectorOpen = false;
  bool _isMenuOpen = false;

  static const List<_DeviceData> _devices = [
    _DeviceData(
      id: 'IV-D10012',
      name: 'IV Drip Pro',
      status: DeviceStatus.normal,
      battery: 92,
      remainingTime: '1h 24m',
      statusLabel: '주입 중',
    ),
    _DeviceData(
      id: 'IV-D10034',
      name: 'InfuTech IV-02',
      status: DeviceStatus.warning,
      battery: 61,
      remainingTime: '22m',
      statusLabel: '주의',
    ),
    _DeviceData(
      id: 'IV-D10058',
      name: 'InfuTech IV-03',
      status: DeviceStatus.ended,
      battery: 78,
      remainingTime: '—',
      statusLabel: '종료',
    ),
  ];

  _DeviceData get _currentDevice =>
      _devices.firstWhere((d) => d.id == _selectedDeviceId,
          orElse: () => _devices.first);

  void _onNavTap(int index) {
    if (index == _currentNavIndex) return; // Already on this tab

    final previousIndex = _currentNavIndex;
    setState(() => _currentNavIndex = index);

    // Navigate with current tab index for slide animation direction
    switch (index) {
      case 0:
        context.go('/iv-status', extra: previousIndex);
        break;
      case 1:
        context.go('/notifications', extra: previousIndex);
        break;
      case 2:
        context.go('/account', extra: previousIndex);
        break;
    }
  }

  void _onSwipe(DragEndDetails details) {
    const sensitivity = 300.0;
    if (details.primaryVelocity == null) return;

    if (details.primaryVelocity! < -sensitivity) {
      // Swipe left → go to next tab (iv-status)
      _onNavTap(1);
    }
    // No swipe right since this is tab 0 (leftmost)
  }

  @override
  Widget build(BuildContext context) {
    final device = _currentDevice;

    return Scaffold(
      body: GestureDetector(
        onHorizontalDragEnd: _onSwipe,
        child: Container(
          color: AppColors.card,
          child: SafeArea(
            bottom: false, // Let bottomNavigationBar handle bottom safe area
            child: Stack(
              children: [
                Column(
                  children: [
                    // ── Header ──
                    _buildHeader(device),

                    // ── Status Summary Card ──
                    Expanded(
                      child: Center(
                        child: _buildStatusSummaryCard(device),
                      ),
                    ),

                    // ── Bottom Card ──
                    _buildBottomCard(device),
                  ],
                ),

                // ── Device Selector Overlay ──
                if (_selectorOpen)
                  _DeviceSelectorOverlay(
                    devices: _devices,
                    selectedId: _selectedDeviceId,
                    onSelect: (id) {
                      setState(() {
                        _selectedDeviceId = id;
                        _selectorOpen = false;
                      });
                    },
                    onClose: () => setState(() => _selectorOpen = false),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
      ),
    );
  }

  Widget _buildHeader(_DeviceData device) {
    if (_selectorOpen) {
      return const SizedBox(height: 56);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Device selector button
          GestureDetector(
            onTap: () => setState(() => _selectorOpen = true),
            child: Row(
              children: [
                Text(
                  device.id,
                  style: AppTypography.heading3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  LucideIcons.chevronDown,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),

          // Actions
          Row(
            children: [
              // Bell with badge - navigates to notifications
              GestureDetector(
                onTap: () => context.push('/notifications'),
                child: Stack(
                  children: [
                    const Icon(
                      LucideIcons.bell,
                      size: 24,
                      color: AppColors.textSecondary,
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.destructive,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // More menu - styled popup with settings, help, logout
              PopupMenuButton<String>(
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white,
                elevation: 8,
                shadowColor: AppColors.blue500.withValues(alpha: 0.15),
                onOpened: () => setState(() => _isMenuOpen = true),
                onCanceled: () => setState(() => _isMenuOpen = false),
                child: AnimatedContainer(
                  duration: AppSpacing.animFast,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _isMenuOpen ? AppColors.blue50 : Colors.transparent,
                    borderRadius: AppSpacing.borderRadiusMd,
                  ),
                  child: Center(
                    child: Icon(
                      LucideIcons.moreVertical,
                      size: 20,
                      color: _isMenuOpen ? AppColors.blue500 : AppColors.textMuted,
                    ),
                  ),
                ),
                itemBuilder: (context) => [
                  _buildPopupItem(LucideIcons.settings, '설정', 'settings'),
                  _buildPopupItem(LucideIcons.helpCircle, '도움말', 'help'),
                  const PopupMenuDivider(height: 1),
                  _buildPopupItem(LucideIcons.logOut, '로그아웃', 'logout', isDestructive: true),
                ],
                onSelected: (value) {
                  setState(() => _isMenuOpen = false);
                  switch (value) {
                    case 'settings':
                      context.push('/settings');
                      break;
                    case 'help':
                      context.push('/help');
                      break;
                    case 'logout':
                      context.go('/');
                      break;
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSummaryCard(_DeviceData device) {
    final statusColor = _getStatusColor(device.status);
    final dotColor = _getDotColor(device.status);
    final dotGlow = _getDotGlow(device.status);
    final statusLabel = device.status == DeviceStatus.normal
        ? '주입 중'
        : device.status == DeviceStatus.warning
            ? '주의 필요'
            : '종료됨';

    // Mock data for demo
    const remainingPercent = 72;
    const currentWeight = 485;
    const flowRate = 60;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue500.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Status Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status indicator
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        boxShadow: dotGlow != Colors.transparent
                            ? [
                                BoxShadow(
                                  color: dotGlow.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      statusLabel,
                      style: AppTypography.bodyMediumBold.copyWith(
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                // Remaining time
                Row(
                  children: [
                    Icon(
                      LucideIcons.clock,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '남은 시간 ',
                      style: AppTypography.small.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      device.remainingTime,
                      style: AppTypography.bodyMediumBold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Progress Section ──
            Column(
              children: [
                // Large percentage
                Text(
                  '$remainingPercent%',
                  style: AppTypography.heading1.copyWith(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '잔량',
                  style: AppTypography.small.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                // Progress bar
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.grayLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: remainingPercent / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _getProgressGradient(device.status),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Summary Grid ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Current weight
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          LucideIcons.scale,
                          size: 20,
                          color: AppColors.blue500,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${currentWeight}g',
                          style: AppTypography.heading4.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '현재 무게',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 60,
                    color: AppColors.grayLight,
                  ),
                  // Flow rate
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          LucideIcons.droplets,
                          size: 20,
                          color: AppColors.blue500,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$flowRate mL/h',
                          style: AppTypography.heading4.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '주입 속도',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getProgressGradient(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.normal:
      case DeviceStatus.active:
        return const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF34D399)],
        );
      case DeviceStatus.warning:
        return const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        );
      case DeviceStatus.ended:
      case DeviceStatus.off:
        return const LinearGradient(
          colors: [Color(0xFF94A3B8), Color(0xFFCBD5E1)],
        );
    }
  }

  Widget _buildBottomCard(_DeviceData device) {
    final dotColor = _getDotColor(device.status);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: AppColors.blue500.withValues(alpha: 0.15),
        ),
        boxShadow: AppShadows.strong,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Device Name Row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            device.name,
                            style: AppTypography.heading3.copyWith(
                              fontSize: 20,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            LucideIcons.zap,
                            size: 16,
                            color: AppColors.blue500,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${device.statusLabel} · 배터리 ${device.battery}%',
                            style: AppTypography.small.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            color: AppColors.grayLight,
          ),

          // Action Cards
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: LucideIcons.activity,
                    label: '주입 상태 상세',
                    onTap: () => context.push('/iv-status', extra: 'push'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: LucideIcons.bell,
                    label: '알림 확인',
                    badgeCount: 2, // Mock: 읽지 않은 알림 개수
                    onTap: () => context.push('/notifications', extra: 'push'),
                  ),
                ),
              ],
            ),
          ),

          // Pagination dots
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _activePage = 0),
                  child: AnimatedContainer(
                    duration: AppSpacing.animFast,
                    width: _activePage == 0 ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color:
                          _activePage == 0 ? AppColors.blue500 : AppColors.grayLight,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _activePage = 1),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color:
                          _activePage == 1 ? AppColors.blue500 : AppColors.grayLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.normal:
      case DeviceStatus.active:
        return AppColors.statusNormal;
      case DeviceStatus.warning:
        return AppColors.statusWarning;
      case DeviceStatus.ended:
      case DeviceStatus.off:
        return AppColors.statusEnded;
    }
  }

  Color _getDotColor(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.normal:
      case DeviceStatus.active:
        return const Color(0xFF4ADE80);
      case DeviceStatus.warning:
        return const Color(0xFFFCD34D);
      case DeviceStatus.ended:
      case DeviceStatus.off:
        return AppColors.grayLight;
    }
  }

  Color _getDotGlow(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.normal:
      case DeviceStatus.active:
        return AppColors.statusNormal;
      case DeviceStatus.warning:
        return AppColors.statusWarning;
      case DeviceStatus.ended:
      case DeviceStatus.off:
        return Colors.transparent;
    }
  }

  PopupMenuItem<String> _buildPopupItem(
    IconData icon,
    String label,
    String value, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDestructive ? const Color(0xFFFEF2F2) : AppColors.blue50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 16,
                color: isDestructive ? AppColors.destructive : AppColors.blue500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: isDestructive ? AppColors.destructive : AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Action card widget
class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: AppSpacing.animFast,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F7FF),
            borderRadius: AppSpacing.borderRadiusLg,
            border: Border.all(
              color: AppColors.blue500.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon with optional badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.blue500.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        widget.icon,
                        size: 16,
                        color: AppColors.blue500,
                      ),
                    ),
                  ),
                  // Badge count
                  if (widget.badgeCount != null && widget.badgeCount! > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.destructive,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          widget.badgeCount! > 99 ? '99+' : '${widget.badgeCount}',
                          style: AppTypography.micro.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Device selector overlay
class _DeviceSelectorOverlay extends StatefulWidget {
  const _DeviceSelectorOverlay({
    required this.devices,
    required this.selectedId,
    required this.onSelect,
    required this.onClose,
  });

  final List<_DeviceData> devices;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  @override
  State<_DeviceSelectorOverlay> createState() => _DeviceSelectorOverlayState();
}

class _DeviceSelectorOverlayState extends State<_DeviceSelectorOverlay> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<_DeviceData> get _filteredDevices {
    if (_query.isEmpty) return widget.devices;
    final q = _query.toLowerCase();
    return widget.devices
        .where((d) =>
            d.id.toLowerCase().contains(q) || d.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            color: const Color(0x400F172A),
          ),
        ),

        // Panel
        Positioned(
          left: 20,
          right: 20,
          top: 56,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: AppSpacing.borderRadiusLg,
                border: Border.all(color: const Color(0xFFE8F0FE)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blue500.withValues(alpha: 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '기기 선택 · 등록된 기기 ${widget.devices.length}대',
                          style: AppTypography.tiny.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Search input
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFF),
                            borderRadius: AppSpacing.borderRadiusSm,
                            border: Border.all(color: const Color(0xFFE8F0FE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.search,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _focusNode,
                                  onChanged: (v) => setState(() => _query = v),
                                  style: AppTypography.small.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: '기기 ID 또는 이름 검색',
                                    hintStyle: AppTypography.small.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              if (_query.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  child: const Icon(
                                    LucideIcons.x,
                                    size: 14,
                                    color: AppColors.grayLight,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(height: 1, color: AppColors.grayLight),

                  // List
                  if (_filteredDevices.isNotEmpty)
                    ...List.generate(_filteredDevices.length, (index) {
                      final d = _filteredDevices[index];
                      final isSelected = d.id == widget.selectedId;
                      return _DeviceListItem(
                        device: d,
                        isSelected: isSelected,
                        isLast: index == _filteredDevices.length - 1,
                        onTap: () => widget.onSelect(d.id),
                      );
                    })
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const Icon(
                            LucideIcons.search,
                            size: 20,
                            color: AppColors.grayLight,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '검색 결과가 없어요',
                            style: AppTypography.small.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Device list item
class _DeviceListItem extends StatelessWidget {
  const _DeviceListItem({
    required this.device,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
  });

  final _DeviceData device;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dotColor = device.status == DeviceStatus.normal
        ? AppColors.statusNormal
        : device.status == DeviceStatus.warning
            ? AppColors.statusWarning
            : AppColors.grayLight;
    final dotShadow = device.status == DeviceStatus.normal
        ? AppColors.statusNormal.withValues(alpha: 0.5)
        : device.status == DeviceStatus.warning
            ? AppColors.statusWarning.withValues(alpha: 0.4)
            : null;
    final statusText = device.status == DeviceStatus.normal
        ? '정상'
        : device.status == DeviceStatus.warning
            ? '주의'
            : '종료';
    final statusColor = device.status == DeviceStatus.normal
        ? AppColors.statusNormal
        : device.status == DeviceStatus.warning
            ? const Color(0xFFD97706)
            : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF8FBFF) : Colors.transparent,
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFF8FAFC)),
                ),
        ),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: dotShadow != null
                    ? [BoxShadow(color: dotShadow, blurRadius: 6)]
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            // Device info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.id,
                    style: AppTypography.small.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF1E40AF)
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    device.name,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            // Status text
            Text(
              statusText,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
            // Check icon
            if (isSelected) ...[
              const SizedBox(width: 4),
              const Icon(
                LucideIcons.check,
                size: 16,
                color: AppColors.blue500,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Device data model
class _DeviceData {
  const _DeviceData({
    required this.id,
    required this.name,
    required this.status,
    required this.battery,
    required this.remainingTime,
    required this.statusLabel,
  });

  final String id;
  final String name;
  final DeviceStatus status;
  final int battery;
  final String remainingTime;
  final String statusLabel;
}
