import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? patient;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.patient,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    Map<String, dynamic>? user,
    Map<String, dynamic>? patient,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      patient: patient ?? this.patient,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService = AuthService();

  AuthNotifier() : super(const AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final loggedIn = await _authService.isLoggedIn();
    state = state.copyWith(
      status: loggedIn ? AuthStatus.authenticated : AuthStatus.unauthenticated,
    );
  }

  Future<bool> signup(String username, String password) async {
    try {
      final data = await _authService.signup(username, password);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: data['user'],
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: AuthService.getErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      final data = await _authService.login(username, password);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: data['user'],
        patient: data['patient'],
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: AuthService.getErrorMessage(e),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
