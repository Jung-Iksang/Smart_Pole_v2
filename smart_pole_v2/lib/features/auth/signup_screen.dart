import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/widgets/widgets.dart';

/// 회원가입 화면
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _usernameError;
  String? _passwordError;
  String? _confirmPasswordError;
  bool _usernameTouched = false;
  bool _passwordTouched = false;
  bool _confirmPasswordTouched = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  /// 비밀번호 확인 일치 여부 (초록 테두리용)
  bool get _isConfirmMatch {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    return confirm.isNotEmpty && confirm == password;
  }

  bool get _isReady {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    return username.length >= 4 &&
        password.length >= 8 &&
        confirmPassword == password;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateUsername() {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _usernameError = '아이디를 입력해주세요';
    } else if (username.length < 4) {
      _usernameError = '아이디는 4자 이상이어야 해요';
    } else if (username.length > 20) {
      _usernameError = '아이디는 20자 이하여야 해요';
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
    } else if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$').hasMatch(password)) {
      _passwordError = '영문과 숫자를 모두 포함해주세요';
    } else {
      _passwordError = null;
    }
  }

  void _validateConfirmPassword() {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (confirmPassword.isEmpty) {
      _confirmPasswordError = '비밀번호를 다시 입력해주세요';
    } else if (confirmPassword != password) {
      _confirmPasswordError = '비밀번호가 일치하지 않아요';
    } else {
      _confirmPasswordError = null;
    }
  }

  Future<void> _handleSignup() async {
    setState(() {
      _usernameTouched = true;
      _passwordTouched = true;
      _confirmPasswordTouched = true;
      _validateUsername();
      _validatePassword();
      _validateConfirmPassword();
    });

    if (_usernameError == null &&
        _passwordError == null &&
        _confirmPasswordError == null) {
      setState(() => _isLoading = true);

      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      final success =
          await ref.read(authProvider.notifier).signup(username, password);

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          context.go('/setup-guide');
        } else {
          final error = ref.read(authProvider).errorMessage;
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
        }
      }
    }
  }

  void _handleKakaoSignup() {
    // TODO: 카카오 OAuth 가입
  }

  void _handleGoogleSignup() {
    // TODO: 구글 OAuth 가입
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
                        placeholder: '영문, 숫자 4~20자',
                        keyboardType: TextInputType.text,
                        errorText: _usernameTouched ? _usernameError : null,
                        onChanged: (_) {
                          if (_usernameTouched) {
                            setState(() => _validateUsername());
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
                        helperText:
                            _passwordTouched ? null : '8자 이상, 영문과 숫자 조합',
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
                          }
                          // 비밀번호 변경 시 확인 필드도 재검증
                          if (_confirmPasswordController.text.isNotEmpty) {
                            setState(() => _validateConfirmPassword());
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // 비밀번호 확인 — 실시간 일치 시 초록 테두리
                      AppInput(
                        controller: _confirmPasswordController,
                        label: '비밀번호 확인',
                        placeholder: '비밀번호를 다시 입력하세요',
                        obscureText: _obscureConfirmPassword,
                        errorText: _confirmPasswordTouched
                            ? _confirmPasswordError
                            : null,
                        showSuccess: _isConfirmMatch,
                        successText: '비밀번호가 일치해요',
                        suffixIcon: _isConfirmMatch
                            ? const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(
                                  LucideIcons.checkCircle,
                                  size: 20,
                                  color: AppColors.statusNormal,
                                ),
                              )
                            : IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? LucideIcons.eyeOff
                                      : LucideIcons.eye,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                                onPressed: () {
                                  setState(() => _obscureConfirmPassword =
                                      !_obscureConfirmPassword);
                                },
                              ),
                        onChanged: (_) {
                          setState(() {
                            _confirmPasswordTouched = true;
                            _validateConfirmPassword();
                          });
                        },
                      ),

                      const SizedBox(height: 24),

                      // 회원가입 버튼
                      PrimaryButton(
                        text: '회원가입',
                        onPressed: _handleSignup,
                        isEnabled: _isReady,
                        isLoading: _isLoading,
                      ),

                      const SizedBox(height: 24),
                      const OrDivider(),
                      const SizedBox(height: 24),

                      SocialLoginButton(
                        type: SocialLoginType.kakao,
                        label: '카카오로 가입하기',
                        onPressed: _handleKakaoSignup,
                      ),
                      const SizedBox(height: 12),
                      SocialLoginButton(
                        type: SocialLoginType.google,
                        label: 'Google로 가입하기',
                        onPressed: _handleGoogleSignup,
                      ),

                      const SizedBox(height: 32),

                      // 로그인 링크
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '이미 계정이 있으신가요? ',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/login'),
                            child: Text(
                              '로그인',
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
            icon: Icon(LucideIcons.userPlus, color: AppColors.blue500),
            size: IconBadgeSize.large,
          ),
          const SizedBox(height: 16),
          Text(
            '회원가입',
            style: AppTypography.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새 계정을 만들어 시작하세요',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
