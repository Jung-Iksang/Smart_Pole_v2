import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/models/device_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/utils/alert_type_config.dart';
import '../../shared/providers/ble_monitor_provider.dart';
import '../../shared/providers/iv_status_provider.dart';
import '../../shared/providers/notification_provider.dart';
import '../../shared/widgets/widgets.dart';

/// 히어로/안전 카드에 표시할 "현재 활성 알림" (BLE 직결 알림 우선, 없으면 서버 알림)
class _ActiveAlert {
  final String type;
  final String title;
  final String message;
  final String relativeTime;
  const _ActiveAlert(this.type, this.title, this.message, this.relativeTime);
  bool get isDanger => isDangerAlertType(type);
}

/// IV 상태 스크린 — 실제 서버 데이터 연결
class IVStatusScreen extends ConsumerStatefulWidget {
  const IVStatusScreen({super.key});

  @override
  ConsumerState<IVStatusScreen> createState() => _IVStatusScreenState();
}

class _IVStatusScreenState extends ConsumerState<IVStatusScreen> {
  int _currentNavIndex = 0;
  bool _selectorOpen = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // WebSocket 실시간 연결 시작
    Future.microtask(() => ref.read(realtimeStreamProvider));
    // 프로비저닝이 BLE 연결을 열어 둔 채 넘어왔다면 그 연결로 바로 수신 시작
    Future.microtask(() => ref.read(bleMonitorProvider.notifier).attach());
    // 시연용: 하드웨어 없이 연결됨 + 90 mL 로 시작
    Future.microtask(
        () => ref.read(bleMonitorProvider.notifier).startDemoInfusion());
    // 2초마다 대시보드 자동 새로고침 (WebSocket 미연결 시 폴백)
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      ref.read(dashboardProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == _currentNavIndex) return;

    final previousIndex = _currentNavIndex;
    setState(() => _currentNavIndex = index);

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
      _onNavTap(1);
    } else if (details.primaryVelocity! > sensitivity) {
      return;
    }
  }

  /// 현재 표시할 알림: BLE 직결 알림(미읽음) 우선, 없으면 서버 미읽음 알림
  _ActiveAlert? _activeAlert() {
    final ble = ref.watch(bleMonitorProvider).latestUnread;
    if (ble != null) {
      return _ActiveAlert(ble.type, ble.title, ble.message, ble.relativeTime);
    }

    final notifState = ref.watch(notificationProvider).valueOrNull;
    final server = notifState?.notifications.where((n) => !n.isRead).firstOrNull;
    if (server != null) {
      return _ActiveAlert(
          server.type, server.title, server.message, server.relativeTime);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final ble = ref.watch(bleMonitorProvider);
    final tele = ble.telemetry;

    // 서버가 꺼져 있어도(시연) BLE 텔레메트리가 있으면 그것만으로 화면을 그린다.
    Widget bleOnlyOr(Widget fallback) {
      if (tele == null) return fallback;
      final device = IVDeviceData.fromBle(tele, deviceName: ble.deviceName);
      return _buildMain(device, [device], serverUnread: 0);
    }

    return dashboardAsync.when(
      loading: () => bleOnlyOr(_buildWithNav(
        const Center(child: CircularProgressIndicator(color: AppColors.blue500)),
      )),
      error: (error, _) => bleOnlyOr(_buildWithNav(
        _buildErrorView(error.toString()),
      )),
      data: (dashboard) {
        if (dashboard.devices.isEmpty) {
          return bleOnlyOr(_buildWithNav(_buildEmptyDeviceView()));
        }

        var device = ref.watch(selectedDeviceProvider);
        if (device == null) return _buildWithNav(const SizedBox.shrink());

        // BLE 직결 연결 중이면 서버 값 대신 ESP 측정값으로 덮어쓴다.
        if (tele != null) {
          device = device.copyWithBle(tele);
        } else if (device.totalMl == null) {
          // total_ml이 없으면 수액 정보 입력 대기 화면
          return _buildWithNav(
            _buildReadyForInfusionView(device, dashboard.devices.length),
            withAppBar: false,
          );
        }

        return _buildMain(
          device,
          dashboard.devices,
          serverUnread: dashboard.unreadNotificationCount,
        );
      },
    );
  }

  Widget _buildMain(IVDeviceData device, List<IVDeviceData> devices,
      {required int serverUnread}) {
    final ble = ref.watch(bleMonitorProvider);

    // 시연 상태면 유속 숫자만 하드코딩 값으로 덮어쓴다 (무게/잔량은 실제 값)
    final demoFlow = ble.demoFlowMlPerHour;
    if (demoFlow != null) device = device.copyWithFlowMlPerHour(demoFlow);

    // totalMl이 없으면 일반 수액 용량(500mL)으로 추정
    final effectiveTotalMl = device.totalMl ?? 500.0;
    final remainPercent = ble.telemetry?.remainPercent ??
        (effectiveTotalMl > 0
            ? (device.remainingMl / effectiveTotalMl * 100).round().clamp(0, 100)
            : 0);

    return Scaffold(
      body: GestureDetector(
        onHorizontalDragEnd: _onSwipe,
        child: Container(
          color: AppColors.background,
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildAppBar(),
                    if (!_selectorOpen) _buildDeviceSelector(device, devices),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            _buildConnectedDeviceCard(device, devices.length),
                            const SizedBox(height: 12),
                            _buildHeroCard(device, remainPercent),
                            const SizedBox(height: 12),
                            _buildMeasurementGrid(device),
                            const SizedBox(height: 12),
                            _buildSafetyCard(device),
                            const SizedBox(height: 16),
                            _buildQuickActions(device),
                            const SizedBox(height: 16),
                            _buildHiddenDemoButtons(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectorOpen)
                  _IVDeviceSelectorOverlay(
                    devices: devices,
                    selectedId: device.deviceId,
                    onSelect: (id) {
                      ref.read(selectedDeviceIdProvider.notifier).state = id;
                      setState(() => _selectorOpen = false);
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
        notificationBadge: serverUnread + ble.unreadCount,
      ),
    );
  }

  Widget _buildWithNav(Widget body, {bool withAppBar = true}) {
    final ble = ref.watch(bleMonitorProvider);
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          bottom: false,
          child: withAppBar
              ? Column(
                  children: [
                    _buildAppBar(),
                    Expanded(child: body),
                  ],
                )
              : body,
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
        notificationBadge: ble.unreadCount,
      ),
    );
  }

  /// 앱바의 BLE 직결 연결 칩. 탭: 끊김→연결, 연결됨→해제.
  Widget _buildBleChip() {
    final ble = ref.watch(bleMonitorProvider);

    final IconData icon;
    final Color fg;
    final Color bg;
    final String label;
    switch (ble.status) {
      case BleLinkStatus.connected:
        icon = LucideIcons.bluetoothConnected;
        fg = AppColors.statusNormal;
        bg = AppColors.greenLight;
        label = 'BLE 연결됨';
      case BleLinkStatus.scanning:
      case BleLinkStatus.connecting:
        icon = LucideIcons.bluetoothSearching;
        fg = AppColors.blue500;
        bg = AppColors.blue50;
        label = ble.status == BleLinkStatus.scanning ? '기기 찾는 중' : '연결 중';
      case BleLinkStatus.disconnected:
        icon = LucideIcons.bluetooth;
        fg = ble.error != null ? const Color(0xFFEF4444) : AppColors.textMuted;
        bg = ble.error != null ? const Color(0xFFFEF2F2) : AppColors.grayLight;
        label = ble.error != null ? '연결 끊김' : 'BLE 연결';
    }

    return GestureDetector(
      onTap: ble.isBusy
          ? null
          : () {
              final notifier = ref.read(bleMonitorProvider.notifier);
              if (ble.isConnected) {
                notifier.disconnect();
              } else {
                notifier.connect();
                if (ble.error != null && mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                }
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ble.isBusy)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            else
              Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.micro.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.alertTriangle,
                size: 48, color: AppColors.textMuted),
            AppSpacing.gapVBase,
            Text('데이터를 불러올 수 없어요',
                style: AppTypography.bodyLarge
                    .copyWith(color: AppColors.textMuted)),
            AppSpacing.gapVSm,
            Text(error,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center),
            AppSpacing.gapVLg,
            PrimaryButton(
              text: '다시 시도',
              onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDeviceView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.monitorSmartphone,
                size: 48, color: AppColors.textMuted),
            AppSpacing.gapVBase,
            Text('등록된 기기가 없어요',
                style: AppTypography.bodyLarge
                    .copyWith(color: AppColors.textMuted)),
            AppSpacing.gapVSm,
            Text('QR 코드를 스캔하여 기기를 등록해주세요',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textMuted)),
            AppSpacing.gapVLg,
            PrimaryButton(
              text: '기기 등록하기',
              onPressed: () => context.go('/setup-guide'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyForInfusionView(IVDeviceData device, int deviceCount) {
    return Column(
      children: [
        _buildAppBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // 메인 카드 — 수액 준비 안내
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: AppSpacing.borderRadiusXl,
                    border: Border.all(color: const Color(0xFFE8F0FE)),
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
                      // 수액 아이콘
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.blue50,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            LucideIcons.droplets,
                            size: 40,
                            color: AppColors.blue400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '수액 준비 중',
                        style: AppTypography.heading4.copyWith(
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '수액이 연결되면 자동으로 측정이 시작돼요\n수액팩을 촬영하면 정보를 미리 확인할 수 있어요',
                        style: AppTypography.small.copyWith(
                          color: AppColors.textMuted,
                          height: 1.65,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // 수액팩 촬영 버튼
                      GestureDetector(
                        onTap: () {
                          context.push('/iv-bag-scan', extra: device.deviceId);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                            ),
                            borderRadius: AppSpacing.borderRadiusLg,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.blue500.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.camera,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 10),
                              Text(
                                '수액팩 촬영하기',
                                style: AppTypography.small.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 기기 상태 바
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: AppSpacing.borderRadiusLg,
                    border: Border.all(color: const Color(0xFFE8F0FE)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blue500.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        device.deviceName,
                        style: AppTypography.small.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.wifi,
                            size: 14,
                            color: device.isConnected
                                ? AppColors.statusNormal
                                : AppColors.grayLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            device.isConnected ? '연결됨' : '끊김',
                            style: AppTypography.small.copyWith(
                              fontWeight: FontWeight.w500,
                              color: device.isConnected
                                  ? AppColors.statusNormal
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 12,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: const Color(0xFFE2E8F0),
                      ),
                      Row(
                        children: [
                          const Icon(LucideIcons.battery,
                              size: 14, color: AppColors.blue500),
                          const SizedBox(width: 4),
                          Text(
                            device.batteryLevel != null
                                ? '${device.batteryLevel}%'
                                : '—',
                            style: AppTypography.small.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.blue500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 안내 카드
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: AppSpacing.borderRadiusLg,
                    border: Border.all(color: AppColors.blue200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.blue50,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(LucideIcons.info,
                              size: 20, color: AppColors.blue400),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '이렇게 작동해요',
                              style: AppTypography.small.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.blue800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '수액이 걸리면 무게 변화를 감지해서\n자동으로 모니터링이 시작돼요',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.blue600,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '내 수액 상태',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBleChip(),
              const SizedBox(width: 8),
              AnimatedIconButton(
                icon: LucideIcons.settings,
                onTap: () => context.push('/settings'),
                iconColor: AppColors.textMuted,
                activeIconColor: AppColors.blue500,
                activeBackgroundColor: AppColors.blue50,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSelector(
      IVDeviceData device, List<IVDeviceData> devices) {
    final dotColor = _getDotColor(device.status);
    final dotShadow = _getDotShadow(device.status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: GestureDetector(
        onTap: devices.length > 1
            ? () => setState(() => _selectorOpen = true)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppSpacing.borderRadiusSm,
            border: Border.all(color: const Color(0xFFE8F0FE)),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue500.withValues(alpha: 0.07),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: dotShadow,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                device.deviceName,
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (devices.length > 1) ...[
                const SizedBox(width: 4),
                const Icon(
                  LucideIcons.chevronDown,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedDeviceCard(IVDeviceData device, int deviceCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: const Color(0xFFE8F0FE)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue500.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '연결된 기기',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
              ConnectionBadge(isConnected: device.isConnected),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceName,
                      style: AppTypography.bodyLargeBold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '현재 등록된 기기 $deviceCount대',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _buildDeviceInfoIcon(
                    icon: LucideIcons.wifi,
                    label: 'Wi-Fi',
                    color: device.isConnected
                        ? AppColors.blue400
                        : AppColors.grayLight,
                  ),
                  const SizedBox(width: 12),
                  _buildDeviceInfoIcon(
                    icon: LucideIcons.battery,
                    label: device.batteryLevel != null
                        ? '${device.batteryLevel}%'
                        : '—',
                    color: AppColors.statusNormal,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoIcon({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.micro.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(IVDeviceData device, int remainPercent) {
    // 알림 상태 확인 — 미읽음 알림(BLE 우선)이 있으면 히어로 카드도 경고 상태로
    final unreadAlert = _activeAlert();
    final hasAlert = unreadAlert != null;
    final isAlertDanger = hasAlert && unreadAlert.isDanger;

    final isWarning = hasAlert || device.status == DeviceStatus.warning;
    final isEnded = !hasAlert &&
        (device.status == DeviceStatus.ended ||
            device.status == DeviceStatus.off);

    // 알림이 있으면 라벨/서브 오버라이드
    final statusLabel = hasAlert ? unreadAlert.title : device.statusLabel;
    final statusSub = hasAlert ? unreadAlert.message : device.statusSub;

    final heroBg = isAlertDanger
        ? const LinearGradient(colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)])
        : isWarning
            ? AppColors.heroWarningGradient
            : isEnded
                ? AppColors.heroEndedGradient
                : AppColors.heroNormalGradient;

    final heroBorder = isAlertDanger
        ? const Color(0xFFFECACA)
        : isWarning
            ? AppColors.statusWarningLight
            : isEnded
                ? AppColors.borderLight
                : AppColors.blue100;

    final dotColor = isAlertDanger
        ? const Color(0xFFEF4444)
        : _getDotColor(device.status);
    final dotShadow = isAlertDanger
        ? [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.5), blurRadius: 6)]
        : _getDotShadow(device.status);

    final progressColor = isWarning
        ? const LinearGradient(colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)])
        : isEnded
            ? const LinearGradient(
                colors: [Color(0xFFE2E8F0), Color(0xFFE2E8F0)])
            : const LinearGradient(
                colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)]);

    final progressTrack = isWarning
        ? const Color(0xFFFEF3C7)
        : isEnded
            ? const Color(0xFFF1F5F9)
            : AppColors.blue100;

    final remainColor = isWarning
        ? const Color(0xFF92400E)
        : isEnded
            ? AppColors.textMuted
            : AppColors.blue800;

    final remainAccent = isWarning
        ? const Color(0xFFFCD34D)
        : isEnded
            ? AppColors.grayLight
            : AppColors.blue300;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: heroBg,
        borderRadius: AppSpacing.borderRadiusXl,
        border: Border.all(color: heroBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue500.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status label
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: dotShadow,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusLabel,
                  style: AppTypography.heading3.copyWith(
                    fontSize: 20,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            statusSub,
            style: AppTypography.small.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // 약품명 / 용량 뱃지
          if (device.fluidName != null || device.totalMl != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    [
                      if (device.fluidName != null) device.fluidName!,
                      if (device.totalMl != null)
                        '${device.totalMl!.toStringAsFixed(0)}mL',
                    ].join(' · '),
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // IV Bag and Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedIVBagGraphic(
                percent: remainPercent.toDouble(),
                status: _statusToString(device.status),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '남은 수액',
                      style: AppTypography.small.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          isEnded
                              ? '완료'
                              : '${device.remainingMl.round()}',
                          style: AppTypography.displayLarge.copyWith(
                            color: remainColor,
                          ),
                        ),
                        if (!isEnded)
                          Text(
                            'mL',
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                              color: remainAccent,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Progress bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '진행률',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          isEnded ? '0% 남음' : '약 $remainPercent% 남음',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isWarning
                                ? AppColors.statusWarningDark
                                : AppColors.blue500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: progressTrack,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: remainPercent / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: progressColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),

                    // ETA badge
                    if (!isEnded && device.eta.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isWarning
                              ? AppColors.statusWarning
                                  .withValues(alpha: 0.08)
                              : AppColors.blue500.withValues(alpha: 0.08),
                          borderRadius: AppSpacing.borderRadiusSm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.clock,
                              size: 14,
                              color: isWarning
                                  ? AppColors.statusWarning
                                  : AppColors.blue400,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                device.eta == '측정 중'
                                    ? '유속 측정 중...'
                                    : '예상 종료 ${device.eta} 후',
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isWarning
                                      ? AppColors.statusWarningText
                                      : AppColors.blue800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 주입 종료 시 종료 확인 버튼
                    if (isEnded) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => _acknowledgeCompletion(device.deviceId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF60A5FA),
                                Color(0xFF3B82F6)
                              ],
                            ),
                            borderRadius: AppSpacing.borderRadiusMd,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.blue500.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.checkCircle,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                '종료 확인',
                                style: AppTypography.small.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementGrid(IVDeviceData device) {
    final items = [
      _MeasurementItem(
        icon: LucideIcons.droplets,
        label: '남은 용량',
        value: '${device.remainingMl.round()} mL',
        color: const Color(0xFF6366F1),
        bgColor: const Color(0xFFEEF2FF),
      ),
      _MeasurementItem(
        icon: LucideIcons.gauge,
        label: '유속',
        value: device.speedText,
        color: const Color(0xFF0EA5E9),
        bgColor: const Color(0xFFF0F9FF),
      ),
      _MeasurementItem(
        icon: LucideIcons.clock,
        label: '마지막 업데이트',
        value: device.lastUpdateText,
        color: const Color(0xFF14B8A6),
        bgColor: const Color(0xFFF0FDFA),
      ),
    ];

    return Row(
      children: items
          .map((item) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: items.indexOf(item) < items.length - 1 ? 10 : 0,
                  ),
                  child: _buildMeasurementCard(item),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMeasurementCard(_MeasurementItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: AppColors.grayLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: item.bgColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(item.icon, size: 16, color: item.color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: AppTypography.micro.copyWith(
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCard(IVDeviceData device) {
    // 최신 미읽음 알림 확인 (BLE 직결 알림 우선)
    final unreadAlert = _activeAlert();

    final hasAlert = unreadAlert != null;
    final isNormal = !hasAlert &&
        (device.status == DeviceStatus.normal ||
            device.status == DeviceStatus.active);
    final isWarning = hasAlert || device.status == DeviceStatus.warning;

    // 알림 타입별 색상
    final isAlertDanger = hasAlert && unreadAlert.isDanger;

    final bgColor = isAlertDanger
        ? const Color(0xFFFEF2F2)
        : isNormal
            ? AppColors.greenLight
            : isWarning
                ? AppColors.statusWarningBg
                : AppColors.statusEndedBg;
    final borderColor = isAlertDanger
        ? const Color(0xFFFECACA)
        : isNormal
            ? const Color(0xFFBBF7D0)
            : isWarning
                ? AppColors.statusWarningLight
                : AppColors.borderLight;
    final iconBgColor = isAlertDanger
        ? const Color(0xFFFEE2E2)
        : isNormal
            ? const Color(0xFFDCFCE7)
            : isWarning
                ? const Color(0xFFFEF3C7)
                : AppColors.grayLight;
    final iconColor = isAlertDanger
        ? const Color(0xFFEF4444)
        : isNormal
            ? AppColors.statusNormal
            : isWarning
                ? AppColors.statusWarning
                : AppColors.textMuted;
    final titleColor = isAlertDanger
        ? const Color(0xFFB91C1C)
        : isNormal
            ? const Color(0xFF166534)
            : isWarning
                ? AppColors.statusWarningText
                : AppColors.textSecondary;
    final subColor = isAlertDanger
        ? const Color(0xFFDC2626)
        : isNormal
            ? const Color(0xFF16A34A)
            : isWarning
                ? AppColors.statusWarningDark
                : AppColors.textMuted;

    final IconData icon;
    final String title;
    final String sub;

    if (hasAlert) {
      icon = isAlertDanger ? LucideIcons.alertOctagon : LucideIcons.alertTriangle;
      title = unreadAlert.title;
      sub = unreadAlert.message;
    } else if (isNormal) {
      icon = LucideIcons.shieldCheck;
      title = '이상 없음';
      sub = '현재 이상 상태가 감지되지 않았어요';
    } else if (device.status == DeviceStatus.warning) {
      icon = LucideIcons.alertTriangle;
      title = '확인이 필요해요';
      sub = '수액 잔량이 적어요. 교체가 필요할 수 있어요';
    } else {
      icon = LucideIcons.shieldCheck;
      title = '주입 완료';
      sub = '수액 주입이 정상적으로 종료되었어요';
    }

    return GestureDetector(
      onTap: hasAlert ? () => context.go('/notifications') : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppSpacing.borderRadiusLg,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 20, color: iconColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.small.copyWith(
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                      ),
                      if (hasAlert)
                        Text(
                          unreadAlert.relativeTime,
                          style: AppTypography.caption.copyWith(
                            color: subColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: AppTypography.caption.copyWith(
                      color: subColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasAlert) ...[
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronRight, size: 16, color: subColor),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _acknowledgeCompletion(int deviceId) async {
    try {
      final service = ref.read(measurementServiceProvider);
      await service.acknowledgeCompletion(deviceId);
    } catch (_) {
      // 서버 에러 무시 — 세션이 이미 정리되었을 수 있음
    }
    // 성공/실패 무관하게 대시보드 새로고침
    ref.read(dashboardProvider.notifier).refresh();
  }

  void _refreshDevice() {
    ref.read(dashboardProvider.notifier).refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('기기 상태를 새로고침하는 중...'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildQuickActions(IVDeviceData device) {
    final actions = [
      _QuickAction(
        icon: LucideIcons.camera,
        label: '수액 정보 수정',
        sub: '수액팩을 다시 촬영하거나 정보를 수정해요',
        color: const Color(0xFF14B8A6),
        bgColor: const Color(0xFFF0FDFA),
        onTap: () => context.push('/iv-bag-scan', extra: device.deviceId),
      ),
      _QuickAction(
        icon: LucideIcons.refreshCw,
        label: '기기 다시 확인',
        sub: '연결 상태를 새로고침해요',
        color: AppColors.blue500,
        bgColor: AppColors.blue50,
        onTap: _refreshDevice,
      ),
      _QuickAction(
        icon: LucideIcons.settings,
        label: '설정',
        sub: '알림, 앱 설정을 변경해요',
        color: const Color(0xFF0EA5E9),
        bgColor: const Color(0xFFF0F9FF),
        onTap: () => context.push('/settings'),
      ),
      _QuickAction(
        icon: LucideIcons.lifeBuoy,
        label: '도움말',
        sub: '자주 묻는 질문과 고객 지원',
        color: const Color(0xFF8B5CF6),
        bgColor: AppColors.purpleLight,
        onTap: () => context.push('/help'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '빠른 실행',
          style: AppTypography.small.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        ...actions.map((action) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _QuickActionButton(action: action),
            )),
      ],
    );
  }

  /// 시연용 숨김 버튼 (화면 맨 아래, 완전 투명).
  /// 왼쪽부터 1 유속 빠름 / 2 유속 느림 / 3 유속 정지 / 4 정상.
  Widget _buildHiddenDemoButtons() {
    void tap(void Function(BleMonitorNotifier n) action) {
      HapticFeedback.lightImpact();
      action(ref.read(bleMonitorProvider.notifier));
    }

    final draining = ref.watch(bleMonitorProvider).demoDraining;
    final buttons = <(String, VoidCallback)>[
      (draining ? '정지' : '시작', () => tap((n) => n.toggleDemoDrain())),
      ('90', () => tap((n) => n.resetDemoVolume())),
      ('1 빠름', () => tap((n) => n.startDemo('flow_fast'))),
      ('2 느림', () => tap((n) => n.startDemo('flow_slow'))),
      ('3 정지', () => tap((n) => n.startDemo('flow_stop'))),
      ('정상', () => tap((n) => n.stopDemo())),
    ];

    // 희미하게만 보이도록 (스크롤 맨 아래라 평소엔 안 보임)
    final faint = AppColors.textMuted.withValues(alpha: 0.25);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (final (label, onTap) in buttons)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: faint),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: AppTypography.micro.copyWith(color: faint),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _statusToString(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.normal:
      case DeviceStatus.active:
        return 'normal';
      case DeviceStatus.warning:
        return 'warning';
      case DeviceStatus.ended:
      case DeviceStatus.off:
        return 'ended';
    }
  }

  Color _getDotColor(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.normal:
      case DeviceStatus.active:
        return AppColors.statusNormal;
      case DeviceStatus.warning:
        return AppColors.statusWarning;
      case DeviceStatus.ended:
      case DeviceStatus.off:
        return AppColors.grayLight;
    }
  }

  List<BoxShadow>? _getDotShadow(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.normal:
      case DeviceStatus.active:
        return AppShadows.statusNormalGlow;
      case DeviceStatus.warning:
        return AppShadows.statusWarningGlow;
      case DeviceStatus.ended:
      case DeviceStatus.off:
        return null;
    }
  }
}

/// Quick action button
class _QuickActionButton extends StatefulWidget {
  const _QuickActionButton({required this.action});

  final _QuickAction action;

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.action.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: AppSpacing.animFast,
        child: AnimatedContainer(
          duration: AppSpacing.animFast,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _pressed
                ? AppColors.blue50.withValues(alpha: 0.5)
                : AppColors.card,
            borderRadius: AppSpacing.borderRadiusLg,
            border: Border.all(
                color: _pressed ? AppColors.blue200 : AppColors.grayLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.action.bgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    widget.action.icon,
                    size: 16,
                    color: widget.action.color,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.action.label,
                      style: AppTypography.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.action.sub,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '›',
                style: TextStyle(
                  fontSize: 18,
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

/// Device selector overlay for IV Status
class _IVDeviceSelectorOverlay extends StatefulWidget {
  const _IVDeviceSelectorOverlay({
    required this.devices,
    required this.selectedId,
    required this.onSelect,
    required this.onClose,
  });

  final List<IVDeviceData> devices;
  final int selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;

  @override
  State<_IVDeviceSelectorOverlay> createState() =>
      _IVDeviceSelectorOverlayState();
}

class _IVDeviceSelectorOverlayState extends State<_IVDeviceSelectorOverlay> {
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

  List<IVDeviceData> get _filteredDevices {
    if (_query.isEmpty) return widget.devices;
    final q = _query.toLowerCase();
    return widget.devices
        .where((d) => d.deviceName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onClose,
          child: Container(color: const Color(0x400F172A)),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: 72,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: AppSpacing.borderRadiusLg,
                border: Border.all(color: const Color(0xFFE8F0FE)),
                boxShadow: AppShadows.dropdown,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFF),
                            borderRadius: AppSpacing.borderRadiusSm,
                            border:
                                Border.all(color: const Color(0xFFE8F0FE)),
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
                                  onChanged: (v) =>
                                      setState(() => _query = v),
                                  style: AppTypography.small.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: '기기 이름 검색',
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
                  Container(height: 1, color: AppColors.grayLight),
                  if (_filteredDevices.isNotEmpty)
                    ...List.generate(_filteredDevices.length, (index) {
                      final d = _filteredDevices[index];
                      final isSelected = d.deviceId == widget.selectedId;
                      return _IVDeviceListItem(
                        device: d,
                        isSelected: isSelected,
                        isLast: index == _filteredDevices.length - 1,
                        onTap: () => widget.onSelect(d.deviceId),
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

/// Device list item for IV selector
class _IVDeviceListItem extends StatelessWidget {
  const _IVDeviceListItem({
    required this.device,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
  });

  final IVDeviceData device;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNormal = device.status == DeviceStatus.normal ||
        device.status == DeviceStatus.active;
    final isWarning = device.status == DeviceStatus.warning;

    final dotColor = isNormal
        ? AppColors.statusNormal
        : isWarning
            ? AppColors.statusWarning
            : AppColors.grayLight;
    final dotShadow = isNormal
        ? AppColors.statusNormal.withValues(alpha: 0.4)
        : null;
    final statusText = isNormal
        ? '정상'
        : isWarning
            ? '주의'
            : '종료';
    final statusColor = isNormal
        ? AppColors.statusNormal
        : isWarning
            ? AppColors.statusWarningDark
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
            Expanded(
              child: Text(
                device.deviceName,
                style: AppTypography.small.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF1E40AF)
                      : AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              statusText,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
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

class _MeasurementItem {
  const _MeasurementItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;
}
