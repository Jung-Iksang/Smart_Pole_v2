import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/models/device_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/providers/iv_status_provider.dart';
import '../../shared/widgets/widgets.dart';

/// 필터 타입
enum FilterType { all, normal, warning }

/// 내 수액 대시보드 스크린 — 실제 서버 데이터 연결
class IVDashboardScreen extends ConsumerStatefulWidget {
  const IVDashboardScreen({super.key});

  @override
  ConsumerState<IVDashboardScreen> createState() => _IVDashboardScreenState();
}

class _IVDashboardScreenState extends ConsumerState<IVDashboardScreen> {
  FilterType _filter = FilterType.all;
  int _activeTab = 0;

  List<IVDeviceData> _applyFilter(List<IVDeviceData> devices) {
    switch (_filter) {
      case FilterType.normal:
        return devices
            .where((d) =>
                d.status == DeviceStatus.normal ||
                d.status == DeviceStatus.active)
            .toList();
      case FilterType.warning:
        return devices
            .where((d) => d.status == DeviceStatus.warning)
            .toList();
      case FilterType.all:
        return devices;
    }
  }

  int _normalCount(List<IVDeviceData> devices) => devices
      .where((d) =>
          d.status == DeviceStatus.normal || d.status == DeviceStatus.active)
      .length;

  int _warningCount(List<IVDeviceData> devices) =>
      devices.where((d) => d.status == DeviceStatus.warning).length;

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return dashboardAsync.when(
      loading: () => Scaffold(
        body: Container(
          color: AppColors.background,
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.blue500),
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
      error: (error, _) => Scaffold(
        body: Container(
          color: AppColors.background,
          child: Center(child: Text('오류: $error')),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
      data: (dashboard) {
        final devices = dashboard.devices;
        final filtered = _applyFilter(devices);
        final normalCount = _normalCount(devices);
        final warningCount = _warningCount(devices);

        return Scaffold(
          body: Container(
            color: AppColors.background,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          _buildSummaryCard(
                              devices, normalCount, warningCount),
                          const SizedBox(height: 12),
                          _buildFilterChips(),
                          const SizedBox(height: 12),
                          if (warningCount > 0 &&
                              _filter != FilterType.normal)
                            _buildWarningNotice(devices),
                          if (warningCount > 0 &&
                              _filter != FilterType.normal)
                            const SizedBox(height: 12),
                          _buildDeviceList(filtered),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AnimatedIconButton(
            icon: LucideIcons.arrowLeft,
            onTap: () => context.go('/iv-status'),
            iconColor: AppColors.textSecondary,
            activeIconColor: AppColors.blue500,
            activeBackgroundColor: AppColors.blue50,
          ),
          Text(
            '내 수액 대시보드',
            style:
                AppTypography.heading4.copyWith(color: AppColors.textPrimary),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(LucideIcons.listFilter,
                  size: 20, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      List<IVDeviceData> devices, int normalCount, int warningCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFF0FDFA)],
        ),
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: AppColors.blue200),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue500.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '현재 연결된 기기',
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.blue200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '총 ${devices.length}대',
                  style: AppTypography.small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.statusNormalBg,
                    borderRadius: AppSpacing.borderRadiusMd,
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.shieldCheck,
                          size: 16, color: AppColors.statusNormal),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$normalCount',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF166534),
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '정상',
                            style: AppTypography.micro
                                .copyWith(color: const Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.statusWarningBg,
                    borderRadius: AppSpacing.borderRadiusMd,
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertTriangle,
                          size: 16, color: AppColors.statusWarning),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$warningCount',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '주의',
                            style: AppTypography.micro
                                .copyWith(color: const Color(0xFFD97706)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.blue500.withValues(alpha: 0.06),
                    borderRadius: AppSpacing.borderRadiusMd,
                    border: Border.all(color: AppColors.blue200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...devices.map((d) {
                        final isEnded = d.status == DeviceStatus.ended ||
                            d.status == DeviceStatus.off;
                        final pct = isEnded
                            ? 0.0
                            : (d.totalMl != null && d.totalMl! > 0
                                ? (d.remainingMl / d.totalMl! * 100)
                                    .clamp(0, 100)
                                : 0.0);
                        final barColor =
                            d.status == DeviceStatus.normal ||
                                    d.status == DeviceStatus.active
                                ? AppColors.blue500
                                : d.status == DeviceStatus.warning
                                    ? AppColors.statusWarning
                                    : const Color(0xFFE2E8F0);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.blue200,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: pct / 100,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 1),
                      Text(
                        '수액 현황',
                        style: AppTypography.micro
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        _buildFilterChip('전체', FilterType.all),
        const SizedBox(width: 8),
        _buildFilterChip('정상', FilterType.normal),
        const SizedBox(width: 8),
        _buildFilterChip('주의', FilterType.warning),
      ],
    );
  }

  Widget _buildFilterChip(String label, FilterType type) {
    final isActive = _filter == type;
    return GestureDetector(
      onTap: () => setState(() => _filter = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.blue500 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.blue500 : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.blue500.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildWarningNotice(List<IVDeviceData> devices) {
    final warningDevice = devices
        .where((d) => d.status == DeviceStatus.warning)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusWarningBg,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(LucideIcons.alertTriangle,
                  size: 16, color: AppColors.statusWarning),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '주의가 필요한 기기가 있어요',
                  style: AppTypography.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  warningDevice != null
                      ? '${warningDevice.deviceName} 카드를 확인해 주세요'
                      : '기기를 확인해 주세요',
                  style: AppTypography.small
                      .copyWith(color: const Color(0xFFD97706)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(List<IVDeviceData> devices) {
    if (devices.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppSpacing.borderRadiusLg,
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            const Icon(LucideIcons.shieldCheck,
                size: 32, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 8),
            Text(
              '해당하는 기기가 없어요',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: devices.map((device) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _DeviceCard(
            device: device,
            onTap: () {
              ref.read(selectedDeviceIdProvider.notifier).state =
                  device.deviceId;
              context.go('/iv-status');
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomNav() {
    return AppBottomNavBar(
      currentIndex: _activeTab,
      onTap: (index) {
        if (index == _activeTab) return;

        final previousIndex = _activeTab;
        setState(() => _activeTab = index);

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
      },
    );
  }
}

/// 기기 카드 위젯
class _DeviceCard extends StatelessWidget {
  final IVDeviceData device;
  final VoidCallback onTap;

  const _DeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isWarning = device.status == DeviceStatus.warning;
    final isEnded = device.status == DeviceStatus.ended ||
        device.status == DeviceStatus.off;
    final remainPercent = device.totalMl != null && device.totalMl! > 0
        ? ((device.remainingMl / device.totalMl!) * 100).round().clamp(0, 100)
        : 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isWarning
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFDF5), Color(0xFFFFFBEB)],
                  )
                : null,
            color: isWarning ? null : Colors.white,
            borderRadius: AppSpacing.borderRadiusLg,
            border: Border.all(
              color: isWarning
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFE8F0FE),
              width: isWarning ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isWarning
                    ? AppColors.statusWarning.withValues(alpha: 0.1)
                    : AppColors.blue500.withValues(alpha: 0.06),
                blurRadius: isWarning ? 12 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isWarning) ...[
                            const Icon(LucideIcons.alertTriangle,
                                size: 14, color: AppColors.statusWarning),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            device.deviceName,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (isWarning)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '확인 필요',
                            style: AppTypography.micro.copyWith(
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildStatusBadge(),
                      const SizedBox(width: 6),
                      const Icon(LucideIcons.chevronRight,
                          size: 16, color: Color(0xFFCBD5E1)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '남은 수액',
                    style: AppTypography.small
                        .copyWith(color: AppColors.textMuted),
                  ),
                  RichText(
                    text: TextSpan(
                      style: AppTypography.small.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isWarning
                            ? const Color(0xFFD97706)
                            : isEnded
                                ? AppColors.textMuted
                                : AppColors.blue700,
                      ),
                      children: [
                        TextSpan(
                            text: isEnded
                                ? '완료'
                                : '${device.remainingMl.round()} mL'),
                        if (!isEnded)
                          TextSpan(
                            text: ' ($remainPercent% 남음)',
                            style: AppTypography.micro.copyWith(
                              fontWeight: FontWeight.w400,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _FluidBar(
                  percent: isEnded ? 0 : remainPercent,
                  status: device.status),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.clock,
                          size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        isEnded
                            ? '주입 완료'
                            : device.eta.isNotEmpty
                                ? '예상 종료 ${device.eta} 후'
                                : '—',
                        style: AppTypography.micro
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        device.isConnected
                            ? LucideIcons.wifi
                            : LucideIcons.wifiOff,
                        size: 12,
                        color: device.isConnected
                            ? AppColors.blue400
                            : const Color(0xFFCBD5E1),
                      ),
                      const SizedBox(width: 10),
                      const Icon(LucideIcons.battery,
                          size: 12, color: AppColors.statusNormal),
                      const SizedBox(width: 4),
                      Text(
                        device.batteryLevel != null
                            ? '${device.batteryLevel}%'
                            : '—',
                        style: AppTypography.micro
                            .copyWith(color: AppColors.textMuted),
                      ),
                      Text(
                        ' · ',
                        style: AppTypography.micro
                            .copyWith(color: const Color(0xFFCBD5E1)),
                      ),
                      Text(
                        '${device.lastUpdateText} 업데이트',
                        style: AppTypography.micro
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;
    Color dotColor;
    String label;

    switch (device.status) {
      case DeviceStatus.normal:
      case DeviceStatus.active:
        bgColor = AppColors.statusNormalBg;
        textColor = AppColors.statusNormal;
        dotColor = const Color(0xFF34D399);
        label = '정상 주입 중';
        break;
      case DeviceStatus.warning:
        bgColor = AppColors.statusWarningBg;
        textColor = const Color(0xFFD97706);
        dotColor = const Color(0xFFFBBF24);
        label = '주의 필요';
        break;
      case DeviceStatus.ended:
      case DeviceStatus.off:
        bgColor = const Color(0xFFF8FAFC);
        textColor = AppColors.textMuted;
        dotColor = const Color(0xFFCBD5E1);
        label = '종료됨';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 수액 바 위젯
class _FluidBar extends StatelessWidget {
  final int percent;
  final DeviceStatus status;

  const _FluidBar({required this.percent, required this.status});

  @override
  Widget build(BuildContext context) {
    final isNormal =
        status == DeviceStatus.normal || status == DeviceStatus.active;
    final isWarning = status == DeviceStatus.warning;

    final trackColor = isNormal
        ? const Color(0xFFDBEAFE)
        : isWarning
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFF1F5F9);

    final barGradient = isNormal
        ? const LinearGradient(
            colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)])
        : isWarning
            ? const LinearGradient(
                colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)])
            : const LinearGradient(
                colors: [Color(0xFFE2E8F0), Color(0xFFE2E8F0)]);

    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: percent / 100,
        child: Container(
          decoration: BoxDecoration(
            gradient: barGradient,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
