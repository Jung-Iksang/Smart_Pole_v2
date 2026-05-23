import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/widgets.dart';

/// 환자 인증 스크린
/// React의 PatientAuthScreen과 동일한 UI
class PatientAuthScreen extends StatefulWidget {
  const PatientAuthScreen({super.key});

  @override
  State<PatientAuthScreen> createState() => _PatientAuthScreenState();
}

class _PatientAuthScreenState extends State<PatientAuthScreen> {
  final _codeController = TextEditingController();
  final _birthController = TextEditingController();

  String? _codeError;
  String? _birthError;
  bool _codeTouched = false;
  bool _birthTouched = false;

  @override
  void dispose() {
    _codeController.dispose();
    _birthController.dispose();
    super.dispose();
  }

  String _formatBirth(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return digits;
    if (digits.length <= 6) {
      return '${digits.substring(0, 4)}.${digits.substring(4)}';
    }
    return '${digits.substring(0, 4)}.${digits.substring(4, 6)}.${digits.substring(6, digits.length.clamp(0, 8))}';
  }

  void _validate() {
    setState(() {
      // Validate code
      final code = _codeController.text.trim();
      if (code.isEmpty) {
        _codeError = '환자 코드를 입력해주세요';
      } else if (!RegExp(r'^[A-Za-z0-9]{4,12}$').hasMatch(code)) {
        _codeError = '영문·숫자 4~12자리로 입력해주세요';
      } else {
        _codeError = null;
      }

      // Validate birth
      final digits = _birthController.text.replaceAll(RegExp(r'\D'), '');
      if (digits.isEmpty) {
        _birthError = '생년월일을 입력해주세요';
      } else if (digits.length != 8) {
        _birthError = '8자리를 모두 입력해주세요 (예: 19900101)';
      } else {
        _birthError = null;
      }
    });
  }

  void _handleSubmit() {
    setState(() {
      _codeTouched = true;
      _birthTouched = true;
    });
    _validate();

    if (_codeError == null && _birthError == null) {
      context.push('/no-device');
    }
  }

  bool get _isReady {
    final code = _codeController.text.trim();
    final digits = _birthController.text.replaceAll(RegExp(r'\D'), '');
    return code.length >= 4 && digits.length == 8;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    AnimatedIconButton(
                      icon: LucideIcons.arrowLeft,
                      onTap: () => context.pop(),
                      backgroundColor: AppColors.blue50,
                      activeBackgroundColor: AppColors.blue100,
                      iconColor: AppColors.blue500,
                      activeIconColor: AppColors.blue600,
                    ),
                    AppSpacing.gapVXl,

                    // Icon badge
                    IconBadge(
                      icon: const Icon(LucideIcons.userCheck),
                      size: IconBadgeSize.large,
                    ),
                    AppSpacing.gapVBase,

                    // Title
                    Text(
                      '환자 인증',
                      style: AppTypography.heading2.copyWith(
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '본인 확인 후 기기를 연결할 수 있어요',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form card ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      AppCard(
                        padding: AppSpacing.cardPaddingLg,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Helper hint
                            HintCard(
                              icon: const Icon(LucideIcons.alertCircle),
                              text: '입원 시 안내받은 정보를 입력해주세요',
                            ),
                            AppSpacing.gapVLg,

                            // 환자 코드
                            AppInput(
                              controller: _codeController,
                              label: '환자 코드',
                              placeholder: '예: PT-20394',
                              errorText: _codeTouched ? _codeError : null,
                              maxLength: 12,
                              onChanged: (value) {
                                _codeController.text =
                                    value.replaceAll(RegExp(r'\s'), '');
                                _codeController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                      offset: _codeController.text.length),
                                );
                                if (_codeTouched) _validate();
                              },
                            ),
                            AppSpacing.gapVBase,

                            // 생년월일
                            AppInput(
                              controller: _birthController,
                              label: '생년월일',
                              placeholder: '예: 1990.01.01',
                              errorText: _birthTouched ? _birthError : null,
                              keyboardType: TextInputType.number,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(8),
                              ],
                              onChanged: (value) {
                                final formatted = _formatBirth(value);
                                _birthController.text = formatted;
                                _birthController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                      offset: _birthController.text.length),
                                );
                                if (_birthTouched) _validate();
                              },
                            ),
                          ],
                        ),
                      ),

                      // ── Privacy note ──
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: AppColors.blue50,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.blue400,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            AppSpacing.gapHSm,
                            Expanded(
                              child: Text(
                                '입력하신 정보는 인증 목적으로만 사용되며 저장되지 않아요',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textMuted,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Primary button ──
                      PrimaryButton(
                        text: '인증하기',
                        onPressed: _handleSubmit,
                        isEnabled: _isReady,
                      ),

                      // ── Secondary help button ──
                      const SizedBox(height: 12),
                      HelpButton(
                        text: '도움이 필요해요',
                        icon: Icon(
                          LucideIcons.helpCircle,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () {
                          // TODO: Navigate to help
                        },
                      ),
                      AppSpacing.gapVXl,
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
}
