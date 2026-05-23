import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import 'status_badge.dart';
import 'app_input.dart';

/// 디바이스 데이터 모델
class Device {
  final String id;
  final String name;
  final DeviceStatus status;
  final int battery;
  final String remainingTime;
  final String statusLabel;
  final bool connected;

  const Device({
    required this.id,
    required this.name,
    required this.status,
    required this.battery,
    required this.remainingTime,
    required this.statusLabel,
    this.connected = true,
  });
}

/// 디바이스 선택 드롭다운
/// React의 DeviceSelector와 동일한 오버레이 스타일
class DeviceSelector extends StatefulWidget {
  const DeviceSelector({
    super.key,
    required this.devices,
    required this.selectedId,
    required this.onSelect,
    required this.onClose,
  });

  final List<Device> devices;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  @override
  State<DeviceSelector> createState() => _DeviceSelectorState();
}

class _DeviceSelectorState extends State<DeviceSelector> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<Device> get _filteredDevices {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return widget.devices;
    return widget.devices.where((d) {
      return d.id.toLowerCase().contains(query) ||
          d.name.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            color: const Color(0x400F172A), // rgba(15,23,42,0.25)
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
                border: Border.all(color: AppColors.borderBlue, width: 1),
                boxShadow: AppShadows.dropdown,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '기기 선택 · 등록된 기기 ${widget.devices.length}대',
                          style: AppTypography.labelUppercase.copyWith(
                            fontSize: 12,
                            letterSpacing: 0.48,
                          ),
                        ),
                        AppSpacing.gapVMd,
                        SearchInput(
                          controller: _searchController,
                          placeholder: '기기 ID 또는 이름 검색',
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          onClear: () => setState(() {}),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: AppColors.grayLight),

                  // Device list
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: _filteredDevices.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _filteredDevices.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: AppColors.background,
                            ),
                            itemBuilder: (context, index) {
                              final device = _filteredDevices[index];
                              return _DeviceListItem(
                                device: device,
                                isSelected: device.id == widget.selectedId,
                                onTap: () {
                                  widget.onSelect(device.id);
                                  widget.onClose();
                                },
                              );
                            },
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.search,
            size: 20,
            color: AppColors.textDisabled,
          ),
          AppSpacing.gapVXs,
          Text(
            '검색 결과가 없어요',
            style: AppTypography.small.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceListItem extends StatelessWidget {
  const _DeviceListItem({
    required this.device,
    required this.isSelected,
    required this.onTap,
  });

  final Device device;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: isSelected ? AppColors.background : Colors.transparent,
        child: Row(
          children: [
            // Status dot
            StatusDot(
              status: device.status,
              size: 8,
            ),
            AppSpacing.gapHMd,

            // Device info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.id,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.blue800
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
              _getStatusText(),
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: _getStatusColor(),
              ),
            ),

            // Checkmark
            if (isSelected) ...[
              AppSpacing.gapHXs,
              Icon(
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

  String _getStatusText() {
    switch (device.status) {
      case DeviceStatus.normal:
      case DeviceStatus.active:
        return '정상';
      case DeviceStatus.warning:
        return '주의';
      case DeviceStatus.ended:
      case DeviceStatus.off:
        return '종료';
    }
  }

  Color _getStatusColor() {
    switch (device.status) {
      case DeviceStatus.normal:
      case DeviceStatus.active:
        return AppColors.statusNormal;
      case DeviceStatus.warning:
        return AppColors.statusWarningDark;
      case DeviceStatus.ended:
      case DeviceStatus.off:
        return AppColors.textMuted;
    }
  }
}

/// 디바이스 선택 버튼 (드롭다운 트리거)
class DeviceSelectorButton extends StatelessWidget {
  const DeviceSelectorButton({
    super.key,
    required this.device,
    required this.onTap,
  });

  final Device device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppSpacing.borderRadiusBase,
          border: Border.all(color: AppColors.borderBlue, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x123B82F6),
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusDot(status: device.status, size: 8),
            AppSpacing.gapHSm,
            Text(
              device.name,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.gapHXs,
            Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
