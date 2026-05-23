import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/services/device_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/providers/iv_status_provider.dart';
import '../../shared/providers/provisioning_provider.dart';
import '../../shared/widgets/widgets.dart';

/// 설정 스크린
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifOn = true;
  bool _vibrationOn = true;
  bool _soundOn = false;
  bool _largeText = false;
  bool _darkMode = false;
  bool _autoLogin = false; // 기본 OFF
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadAutoLogin();
  }

  Future<void> _loadAutoLogin() async {
    final value = await _storage.read(key: 'auto_login');
    if (mounted) {
      setState(() => _autoLogin = value == 'true');
    }
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
                      _buildSectionLabel('알림 설정'),
                      const SizedBox(height: 8),
                      _buildNotificationSection(),
                      const SizedBox(height: 16),
                      _buildSectionLabel('기기 관리'),
                      const SizedBox(height: 8),
                      _buildDeviceSection(),
                      const SizedBox(height: 16),
                      _buildSectionLabel('앱 설정'),
                      const SizedBox(height: 8),
                      _buildAppSection(),
                      const SizedBox(height: 16),
                      _buildSectionLabel('기타'),
                      const SizedBox(height: 8),
                      _buildOtherSection(),
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
      child: Row(
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
            '설정',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
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

  Widget _buildNotificationSection() {
    return _buildCard([
      _ToggleRow(
        icon: LucideIcons.bell,
        iconColor: AppColors.blue500,
        iconBg: AppColors.blue50,
        label: '알림 받기',
        sublabel: '기기 상태 알림을 받아요',
        value: _notifOn,
        onChanged: (v) => setState(() => _notifOn = v),
        showBorder: true,
      ),
      _ToggleRow(
        icon: LucideIcons.vibrate,
        iconColor: const Color(0xFF8B5CF6),
        iconBg: const Color(0xFFF5F3FF),
        label: '진동',
        value: _vibrationOn,
        onChanged: (v) => setState(() => _vibrationOn = v),
        showBorder: true,
      ),
      _ToggleRow(
        icon: LucideIcons.volume2,
        iconColor: AppColors.statusNormal,
        iconBg: AppColors.statusNormalBg,
        label: '소리',
        value: _soundOn,
        onChanged: (v) => setState(() => _soundOn = v),
        showBorder: false,
      ),
    ]);
  }

  Widget _buildAppSection() {
    return _buildCard([
      _ToggleRow(
        icon: LucideIcons.type,
        iconColor: AppColors.statusWarning,
        iconBg: AppColors.statusWarningBg,
        label: '큰 글씨 모드',
        sublabel: '텍스트 크기를 키워요',
        value: _largeText,
        onChanged: (v) => setState(() => _largeText = v),
        showBorder: true,
      ),
      _ToggleRow(
        icon: LucideIcons.moon,
        iconColor: const Color(0xFF6366F1),
        iconBg: const Color(0xFFEEF2FF),
        label: '다크 모드',
        value: _darkMode,
        onChanged: (v) => setState(() => _darkMode = v),
        showBorder: true,
      ),
      _ToggleRow(
        icon: LucideIcons.shieldCheck,
        iconColor: AppColors.statusNormal,
        iconBg: AppColors.statusNormalBg,
        label: '자동 로그인',
        sublabel: '다음 방문 시 자동으로 로그인해요',
        value: _autoLogin,
        onChanged: (v) {
          setState(() => _autoLogin = v);
          _storage.write(key: 'auto_login', value: v.toString());
        },
        showBorder: false,
      ),
    ]);
  }

  Widget _buildDeviceSection() {
    return _buildCard([
      _LinkRow(
        icon: LucideIcons.wifi,
        iconColor: const Color(0xFF0EA5E9),
        iconBg: const Color(0xFFF0F9FF),
        label: '기기 WiFi 재설정',
        onTap: () {
          ref.read(provisioningProvider.notifier).setForceWifiSetup(true);
          context.push('/qr-scan');
        },
        showBorder: true,
      ),
      _LinkRow(
        icon: LucideIcons.unlink,
        iconColor: const Color(0xFFEF4444),
        iconBg: const Color(0xFFFEF2F2),
        label: '기기 연결 해제',
        onTap: _showDisconnectDialog,
        showBorder: false,
      ),
    ]);
  }

  Future<void> _showDisconnectDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기기 연결 해제'),
        content: const Text('기기 연결을 해제하시겠어요?\n해제 후 다시 QR 코드를 스캔하여 연결할 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('해제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final deviceId = ref.read(selectedDeviceIdProvider);
      if (deviceId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('연결된 기기가 없습니다')),
        );
        return;
      }

      // BLE 연결 해제 + 프로비저닝 상태 초기화
      await ref.read(provisioningProvider.notifier).reset();

      final deviceService = DeviceService();
      await deviceService.deleteDevice(deviceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기기 연결이 해제되었습니다')),
        );
        context.go('/setup-guide');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결 해제 실패: $e')),
        );
      }
    }
  }

  Widget _buildOtherSection() {
    return _buildCard([
      _LinkRow(
        icon: LucideIcons.helpCircle,
        iconColor: AppColors.blue500,
        iconBg: AppColors.blue50,
        label: '도움말',
        onTap: () => context.push('/help'),
        showBorder: true,
      ),
      _LinkRow(
        icon: LucideIcons.info,
        iconColor: AppColors.textMuted,
        iconBg: const Color(0xFFF8FAFC),
        label: '버전 정보',
        value: '1.3.0',
        showBorder: false,
      ),
    ]);
  }

  Widget _buildCard(List<Widget> children) {
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
      child: Column(children: children),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String? sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showBorder;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    this.sublabel,
    required this.value,
    required this.onChanged,
    required this.showBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: Center(
              child: Icon(icon, size: 18, color: iconColor),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (sublabel != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    sublabel!,
                    style: AppTypography.small.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 26,
              decoration: BoxDecoration(
                gradient: value
                    ? const LinearGradient(
                        colors: [AppColors.blue500, Color(0xFF6366F1)],
                      )
                    : null,
                color: value ? null : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(13),
                boxShadow: value
                    ? [
                        BoxShadow(
                          color: AppColors.blue500.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool showBorder;

  const _LinkRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    this.value,
    this.onTap,
    required this.showBorder,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: showBorder
              ? const Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: AppSpacing.borderRadiusMd,
              ),
              child: Center(
                child: Icon(icon, size: 18, color: iconColor),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: AppTypography.small.copyWith(color: AppColors.textMuted),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textDisabled),
            ],
          ],
        ),
      ),
    );
  }
}
