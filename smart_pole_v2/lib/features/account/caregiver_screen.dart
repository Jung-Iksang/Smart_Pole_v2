import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/widgets.dart';

/// 보호자 연결 스크린
class CaregiverScreen extends StatefulWidget {
  const CaregiverScreen({super.key});

  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  bool _isConnected = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _alertOn = true;
  bool _nameTouched = false;
  bool _phoneTouched = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 3) return digits;
    if (digits.length <= 7) return '${digits.substring(0, 3)}-${digits.substring(3)}';
    return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, digits.length.clamp(7, 11))}';
  }

  bool get _nameError => _nameTouched && _nameController.text.trim().length < 2;
  bool get _phoneError => _phoneTouched && _phoneController.text.replaceAll(RegExp(r'\D'), '').length < 10;
  bool get _isReady => _nameController.text.trim().length >= 2 &&
                       _phoneController.text.replaceAll(RegExp(r'\D'), '').length >= 10;

  void _handleConnect() {
    setState(() {
      _nameTouched = true;
      _phoneTouched = true;
    });
    if (_isReady) {
      setState(() => _isConnected = true);
    }
  }

  void _handleDisconnect() {
    setState(() {
      _isConnected = false;
      _nameController.clear();
      _phoneController.clear();
      _nameTouched = false;
      _phoneTouched = false;
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
                    children: [
                      if (_isConnected) ...[
                        const SizedBox(height: 16),
                        _buildConnectedCard(),
                        const SizedBox(height: 12),
                        _buildAlertStatus(),
                        const SizedBox(height: 12),
                        _buildDisconnectButton(),
                      ] else ...[
                        const SizedBox(height: 16),
                        _buildFormCard(),
                        const SizedBox(height: 12),
                        _buildAlertToggle(),
                        const SizedBox(height: 12),
                        _buildPrivacyNote(),
                        const SizedBox(height: 16),
                        _buildConnectButton(),
                      ],
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
                '보호자 연결',
                style: AppTypography.heading4.copyWith(
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildIntroCard(),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFF5F3FF)],
        ),
        borderRadius: AppSpacing.borderRadiusXl,
        border: Border.all(color: AppColors.blue400.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: const Center(
              child: Icon(LucideIcons.heart, size: 20, color: Color(0xFFF472B6)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '보호자를 연결하면 이상 상태 발생 시 함께 알림을 받을 수 있어요',
              style: AppTypography.small.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name field
          Text(
            '보호자 이름',
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            onTap: () => setState(() => _nameTouched = true),
            decoration: InputDecoration(
              hintText: '이름을 입력해주세요',
              hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.textDisabled),
              filled: true,
              fillColor: _nameError ? const Color(0xFFFFFBEB).withValues(alpha: 0.4) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _nameError ? const Color(0xFFFCD34D) : const Color(0xFFF1F5F9),
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _nameError ? const Color(0xFFFCD34D) : const Color(0xFFF1F5F9),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _nameError ? const Color(0xFFFCD34D) : AppColors.blue400,
                  width: 2,
                ),
              ),
            ),
          ),
          if (_nameError) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.statusWarning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '이름을 입력해주세요',
                  style: AppTypography.small.copyWith(color: const Color(0xFFD97706)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // Phone field
          Text(
            '연락처',
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            onChanged: (value) {
              final formatted = _formatPhone(value);
              if (formatted != value) {
                _phoneController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
              setState(() {});
            },
            onTap: () => setState(() => _phoneTouched = true),
            decoration: InputDecoration(
              hintText: '010-0000-0000',
              hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.textDisabled),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 16, right: 8),
                child: Icon(LucideIcons.phone, size: 16, color: AppColors.textDisabled),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              filled: true,
              fillColor: _phoneError ? const Color(0xFFFFFBEB).withValues(alpha: 0.4) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _phoneError ? const Color(0xFFFCD34D) : const Color(0xFFF1F5F9),
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _phoneError ? const Color(0xFFFCD34D) : const Color(0xFFF1F5F9),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _phoneError ? const Color(0xFFFCD34D) : AppColors.blue400,
                  width: 2,
                ),
              ),
            ),
          ),
          if (_phoneError) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.statusWarning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '올바른 전화번호를 입력해주세요',
                  style: AppTypography.small.copyWith(color: const Color(0xFFD97706)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertToggle() {
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
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: const Center(
              child: Icon(LucideIcons.bell, size: 18, color: AppColors.blue500),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이상 상태 시 알림 보내기',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '보호자에게 문자로 알려드려요',
                  style: AppTypography.small.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _alertOn = !_alertOn),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 26,
              decoration: BoxDecoration(
                gradient: _alertOn
                    ? const LinearGradient(
                        colors: [AppColors.blue500, Color(0xFF6366F1)],
                      )
                    : null,
                color: _alertOn ? null : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(13),
                boxShadow: _alertOn
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
                alignment: _alertOn ? Alignment.centerRight : Alignment.centerLeft,
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

  Widget _buildPrivacyNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 2),
          child: Icon(LucideIcons.alertCircle, size: 14, color: AppColors.blue300),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '입력하신 연락처는 알림 전송 목적으로만 사용돼요',
            style: AppTypography.small.copyWith(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectButton() {
    return SizedBox(
      width: double.infinity,
      child: PrimaryButton(
        text: '보호자 연결하기',
        onPressed: _isReady ? _handleConnect : null,
      ),
    );
  }

  Widget _buildConnectedCard() {
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
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFCE7F3), Color(0xFFEDE9FE)],
              ),
              borderRadius: AppSpacing.borderRadiusLg,
            ),
            child: const Center(
              child: Icon(LucideIcons.users, size: 28, color: Color(0xFFEC4899)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '연결된 보호자',
                  style: AppTypography.micro.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.04,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _nameController.text.isNotEmpty ? _nameController.text : '김지영',
                  style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 1),
                Text(
                  _phoneController.text.isNotEmpty ? _phoneController.text : '010-****-5678',
                  style: AppTypography.small.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.statusNormal,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.statusNormal,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '연결됨',
                  style: AppTypography.micro.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.statusNormal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: AppColors.blue400.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.checkCircle2, size: 20, color: AppColors.blue500),
          const SizedBox(width: 8),
          Text(
            '이상 상태 발생 시 보호자에게 알림이 전송돼요',
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.blue700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectButton() {
    return GestureDetector(
      onTap: _handleDisconnect,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: AppSpacing.borderRadiusLg,
          border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.userX, size: 16, color: Color(0xFFF87171)),
            const SizedBox(width: 8),
            Text(
              '연결 해제',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF87171),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
