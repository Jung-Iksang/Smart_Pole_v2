import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 소셜 로그인 버튼 타입
enum SocialLoginType {
  kakao,
  google,
}

/// 소셜 로그인 버튼 위젯
/// 카카오, 구글 로그인/가입 버튼에 사용
class SocialLoginButton extends StatefulWidget {
  const SocialLoginButton({
    super.key,
    required this.type,
    required this.onPressed,
    this.label,
    this.isLoading = false,
  });

  final SocialLoginType type;
  final VoidCallback onPressed;
  final String? label;
  final bool isLoading;

  @override
  State<SocialLoginButton> createState() => _SocialLoginButtonState();
}

class _SocialLoginButtonState extends State<SocialLoginButton> {
  bool _isPressed = false;

  String get _defaultLabel {
    switch (widget.type) {
      case SocialLoginType.kakao:
        return '카카오로 계속하기';
      case SocialLoginType.google:
        return 'Google로 계속하기';
    }
  }

  Color get _backgroundColor {
    switch (widget.type) {
      case SocialLoginType.kakao:
        return const Color(0xFFFEE500); // 카카오 노란색
      case SocialLoginType.google:
        return Colors.white;
    }
  }

  Color get _textColor {
    switch (widget.type) {
      case SocialLoginType.kakao:
        return const Color(0xFF191919); // 카카오 검정색
      case SocialLoginType.google:
        return const Color(0xFF1F1F1F);
    }
  }

  Color? get _borderColor {
    switch (widget.type) {
      case SocialLoginType.kakao:
        return null;
      case SocialLoginType.google:
        return const Color(0xFFDADCE0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (!widget.isLoading) {
          widget.onPressed();
        }
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: AppSpacing.animFast,
        transform: Matrix4.diagonal3Values(
          _isPressed ? 0.98 : 1.0,
          _isPressed ? 0.98 : 1.0,
          1.0,
        ),
        transformAlignment: Alignment.center,
        height: AppSpacing.buttonHeightLg,
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: AppSpacing.borderRadiusLg,
          border: _borderColor != null
              ? Border.all(color: _borderColor!, width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 로고
            Positioned(
              left: 16,
              child: _buildLogo(),
            ),
            // 텍스트
            if (!widget.isLoading)
              Text(
                widget.label ?? _defaultLabel,
                style: AppTypography.buttonSecondary.copyWith(
                  color: _textColor,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_textColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    switch (widget.type) {
      case SocialLoginType.kakao:
        return SvgPicture.asset(
          'assets/icons/kakao_logo.svg',
          width: 24,
          height: 24,
        );
      case SocialLoginType.google:
        return SvgPicture.asset(
          'assets/icons/google_logo.svg',
          width: 24,
          height: 24,
        );
    }
  }
}

/// 구분선과 "또는" 텍스트 위젯
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.grayLight,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '또는',
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.grayLight,
          ),
        ),
      ],
    );
  }
}
