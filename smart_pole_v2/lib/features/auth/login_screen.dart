import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/services/measurement_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/widgets/widgets.dart';

/// 로그인 화면
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _usernameError;
  String? _passwordError;
  bool _usernameTouched = false;
  bool _passwordTouched = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateUsername() {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _usernameError = '아이디를 입력해주세요';
    } else if (username.length < 4) {
      _usernameError = '아이디는 4자 이상이어야 해요';
    } else if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(username)) {
      _usernameError = '영문, 숫자, 밑줄만 사용할 수 있어요';
    } else {
      _usernameError = null;
    }
  }

  void _validatePassword() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      _passwordError = '비밀번호를 입력해주세요';
    } else if (password.length < 8) {
      _passwordError = '비밀번호는 8자 이상이어야 해요';
    } else {
      _passwordError = null;
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _usernameTouched = true;
      _passwordTouched = true;
      _validateUsername();
      _validatePassword();
    });

    if (_usernameError != null || _passwordError != null) return;

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      final success =
          await ref.read(authProvider.notifier).login(username, password);

      if (mounted) {
        if (success) {
          // 기기가 이미 등록되어 있는지 확인
          try {
            final measurementService = MeasurementService();
            final dashboard = await measurementService.getDashboard();
            if (mounted) {
              if (dashboard.devices.isNotEmpty) {
                context.go('/iv-status');  // 기기 있음 → 수액 화면
              } else {
                context.go('/setup-guide');  // 기기 없음 → 기기 등록
              }
            }
          } catch (_) {
            if (mounted) context.go('/setup-guide');
          }
        } else {
          final error = ref.read(authProvider).errorMessage ?? '아이디 또는 비밀번호가 올바르지 않아요';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('네트워크 오류가 발생했어요')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleKakaoLogin() {
    // TODO: 카카오 OAuth 로그인
  }

  void _handleGoogleLogin() {
    // TODO: 구글 OAuth 로그인
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 32),

                      // 아이디 입력
                      AppInput(
                        controller: _usernameController,
                        label: '아이디',
                        placeholder: '영문, 숫자 4자 이상',
                        keyboardType: TextInputType.text,
                        errorText: _usernameTouched ? _usernameError : null,
                        onChanged: (_) {
                          if (_usernameTouched) {
                            setState(() => _validateUsername());
                          } else {
                            setState(() {});
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // 비밀번호 입력
                      AppInput(
                        controller: _passwordController,
                        label: '비밀번호',
                        placeholder: '비밀번호를 입력하세요',
                        obscureText: _obscurePassword,
                        errorText: _passwordTouched ? _passwordError : null,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () {
                            setState(
                                () => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        onChanged: (_) {
                          if (_passwordTouched) {
                            setState(() => _validatePassword());
                          } else {
                            setState(() {});
                          }
                        },
                      ),

                      // 비밀번호 찾기
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // TODO: 비밀번호 찾기
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            '비밀번호 찾기',
                            style: AppTypography.small.copyWith(
                              color: AppColors.blue500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 로그인 버튼 — 항상 활성화, 누르면 검증
                      PrimaryButton(
                        text: '로그인',
                        onPressed: _handleLogin,
                        isEnabled: true,
                        isLoading: _isLoading,
                      ),

                      const SizedBox(height: 24),
                      const OrDivider(),
                      const SizedBox(height: 24),

                      SocialLoginButton(
                        type: SocialLoginType.kakao,
                        onPressed: _handleKakaoLogin,
                      ),
                      const SizedBox(height: 12),
                      SocialLoginButton(
                        type: SocialLoginType.google,
                        onPressed: _handleGoogleLogin,
                      ),

                      const SizedBox(height: 32),

                      // 회원가입 링크
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '계정이 없으신가요? ',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/signup'),
                            child: Text(
                              '회원가입',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.blue500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AnimatedIconButton(
              icon: LucideIcons.arrowLeft,
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
              iconColor: AppColors.textSecondary,
              activeIconColor: AppColors.blue500,
              activeBackgroundColor: AppColors.blue50,
            ),
          ),
          const SizedBox(height: 24),
          const IconBadge(
            icon: Icon(LucideIcons.logIn, color: AppColors.blue500),
            size: IconBadgeSize.large,
          ),
          const SizedBox(height: 16),
          Text(
            '로그인',
            style: AppTypography.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '계정에 로그인하여 시작하세요',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
