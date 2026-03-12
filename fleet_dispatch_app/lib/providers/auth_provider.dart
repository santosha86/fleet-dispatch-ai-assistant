import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

enum AuthStatus {
  unknown,
  loggedOut,
  authenticated,
  unauthenticated,
  pinSetupRequired,
  mfaRequired,
}

class AuthState {
  final AuthStatus status;
  final bool isLoggedIn;
  final bool isPinEnabled;
  final bool isBiometricsEnabled;
  final bool canUseBiometrics;
  final String? error;
  final int failedAttempts;
  final String? username;
  final String? mfaToken; // Temporary token for MFA verification
  final String? role;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.isLoggedIn = false,
    this.isPinEnabled = false,
    this.isBiometricsEnabled = false,
    this.canUseBiometrics = false,
    this.error,
    this.failedAttempts = 0,
    this.username,
    this.mfaToken,
    this.role,
  });

  AuthState copyWith({
    AuthStatus? status,
    bool? isLoggedIn,
    bool? isPinEnabled,
    bool? isBiometricsEnabled,
    bool? canUseBiometrics,
    String? error,
    int? failedAttempts,
    String? username,
    String? mfaToken,
    String? role,
  }) {
    return AuthState(
      status: status ?? this.status,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isPinEnabled: isPinEnabled ?? this.isPinEnabled,
      isBiometricsEnabled: isBiometricsEnabled ?? this.isBiometricsEnabled,
      canUseBiometrics: canUseBiometrics ?? this.canUseBiometrics,
      error: error,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      username: username ?? this.username,
      mfaToken: mfaToken,
      role: role ?? this.role,
    );
  }

  bool get isLocked => failedAttempts >= 5;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  static const int maxAttempts = 5;

  AuthNotifier(this._authService) : super(const AuthState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Check login state first — must be logged in before anything else
    final loggedIn = await _authService.isLoggedIn();
    if (!loggedIn) {
      state = state.copyWith(status: AuthStatus.loggedOut);
      return;
    }

    final storedUsername = await _authService.getUsername();
    final pinEnabled = await _authService.isPinEnabled();
    final pinSetup = await _authService.isPinSetup();
    final biometricsEnabled = await _authService.isBiometricsEnabled();
    final canBio = await _authService.canUseBiometrics();

    if (!pinEnabled || !pinSetup) {
      // No PIN set up - go straight to app
      state = state.copyWith(
        status: AuthStatus.authenticated,
        isLoggedIn: true,
        username: storedUsername,
        isPinEnabled: false,
        isBiometricsEnabled: biometricsEnabled,
        canUseBiometrics: canBio,
      );
    } else {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoggedIn: true,
        username: storedUsername,
        isPinEnabled: true,
        isBiometricsEnabled: biometricsEnabled,
        canUseBiometrics: canBio,
      );

      // Try biometrics first if enabled
      if (biometricsEnabled && canBio) {
        await authenticateWithBiometrics();
      }
    }
  }

  /// Verify PIN entered by user
  Future<bool> verifyPin(String pin) async {
    if (state.isLocked) {
      state = state.copyWith(
        error: 'Too many failed attempts. Please try again later.',
      );
      return false;
    }

    final verified = await _authService.verifyPin(pin);
    if (verified) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        error: null,
        failedAttempts: 0,
      );
      return true;
    } else {
      final attempts = state.failedAttempts + 1;
      state = state.copyWith(
        error: 'Incorrect PIN. ${maxAttempts - attempts} attempts remaining.',
        failedAttempts: attempts,
      );
      return false;
    }
  }

  /// Authenticate using biometrics
  Future<bool> authenticateWithBiometrics() async {
    final success = await _authService.authenticateWithBiometrics();
    if (success) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        error: null,
        failedAttempts: 0,
      );
    }
    return success;
  }

  /// Set up a new PIN
  Future<void> setupPin(String pin) async {
    await _authService.setupPin(pin);
    state = state.copyWith(
      status: AuthStatus.authenticated,
      isPinEnabled: true,
      error: null,
    );
  }

  /// Change PIN
  Future<bool> changePin(String oldPin, String newPin) async {
    final success = await _authService.changePin(oldPin, newPin);
    if (!success) {
      state = state.copyWith(error: 'Current PIN is incorrect.');
    } else {
      state = state.copyWith(error: null);
    }
    return success;
  }

  /// Toggle PIN on/off
  Future<void> togglePin(bool enabled) async {
    if (!enabled) {
      await _authService.removePin();
      state = state.copyWith(isPinEnabled: false);
    }
  }

  /// Toggle biometrics on/off
  Future<void> toggleBiometrics(bool enabled) async {
    await _authService.setBiometricsEnabled(enabled);
    state = state.copyWith(isBiometricsEnabled: enabled);
  }

  /// Login with username and password via backend API
  Future<bool> login(String username, String password) async {
    try {
      final result = await _authService.loginRemote(username, password);

      // Check if MFA is required
      if (result['requires_mfa'] == true) {
        state = state.copyWith(
          status: AuthStatus.mfaRequired,
          mfaToken: result['mfa_token'] as String?,
          username: result['username'] as String?,
          error: null,
        );
        return false; // Not fully logged in yet
      }

      final returnedUsername = result['username'] as String;
      final role = result['role'] as String?;
      await _authService.setLoggedIn(true);
      await _authService.setUsername(returnedUsername);
      state = state.copyWith(
        isLoggedIn: true,
        username: returnedUsername,
        role: role,
        error: null,
      );
      // Continue with PIN check flow
      await _initialize();
      return true;
    } catch (e) {
      String errorMsg = 'Invalid username or password.';
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection') ||
          e.toString().contains('timeout')) {
        errorMsg = 'Cannot reach server. Check your connection.';
      }
      state = state.copyWith(error: errorMsg);
      return false;
    }
  }

  /// Complete MFA login with TOTP code
  Future<bool> verifyMfa(String totpCode) async {
    final mfaToken = state.mfaToken;
    if (mfaToken == null) {
      state = state.copyWith(error: 'MFA session expired. Please login again.');
      return false;
    }
    try {
      final result = await _authService.loginMfa(mfaToken, totpCode);
      final returnedUsername = result['username'] as String;
      final role = result['role'] as String?;
      await _authService.setLoggedIn(true);
      await _authService.setUsername(returnedUsername);
      state = state.copyWith(
        isLoggedIn: true,
        username: returnedUsername,
        role: role,
        mfaToken: null,
        error: null,
      );
      await _initialize();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Invalid verification code.');
      return false;
    }
  }

  /// Logout — clears login state and token, returns to login screen
  Future<void> logout() async {
    await _authService.setLoggedIn(false);
    await _authService.clearToken();
    state = const AuthState(status: AuthStatus.loggedOut);
  }

  /// Lock the app (e.g., when backgrounded)
  void lock() {
    if (state.isPinEnabled) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: null,
        failedAttempts: 0,
      );
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});
