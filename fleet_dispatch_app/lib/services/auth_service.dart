import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../core/config/app_config.dart';

class AuthService {
  static const _pinHashKey = 'fleet_pin_hash';
  static const _pinEnabledKey = 'fleet_pin_enabled';
  static const _biometricsEnabledKey = 'fleet_biometrics_enabled';
  static const _loggedInKey = 'fleet_logged_in';
  static const _usernameKey = 'fleet_username';
  static const _tokenKey = 'fleet_auth_token';
  static const _refreshTokenKey = 'fleet_refresh_token';
  static const _roleKey = 'fleet_user_role';

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  AuthService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  /// Hash a PIN using SHA-256
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// Check if a PIN has been set up
  Future<bool> isPinSetup() async {
    final hash = await _storage.read(key: _pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Check if PIN authentication is enabled
  Future<bool> isPinEnabled() async {
    final enabled = await _storage.read(key: _pinEnabledKey);
    return enabled == 'true';
  }

  /// Check if biometrics are enabled in settings
  Future<bool> isBiometricsEnabled() async {
    final enabled = await _storage.read(key: _biometricsEnabledKey);
    return enabled == 'true';
  }

  /// Set up a new PIN
  Future<void> setupPin(String pin) async {
    final hash = _hashPin(pin);
    await _storage.write(key: _pinHashKey, value: hash);
    await _storage.write(key: _pinEnabledKey, value: 'true');
  }

  /// Verify a PIN against stored hash
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinHashKey);
    if (storedHash == null) return false;
    return _hashPin(pin) == storedHash;
  }

  /// Change PIN (requires old PIN verification)
  Future<bool> changePin(String oldPin, String newPin) async {
    final verified = await verifyPin(oldPin);
    if (!verified) return false;
    await setupPin(newPin);
    return true;
  }

  /// Remove PIN (disable PIN authentication)
  Future<void> removePin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.write(key: _pinEnabledKey, value: 'false');
  }

  /// Enable/disable biometrics
  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricsEnabledKey,
      value: enabled.toString(),
    );
  }

  /// Check if device supports biometrics
  Future<bool> canUseBiometrics() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Fleet Dispatch Assistant',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final value = await _storage.read(key: _loggedInKey);
    return value == 'true';
  }

  /// Set login state
  Future<void> setLoggedIn(bool loggedIn) async {
    await _storage.write(key: _loggedInKey, value: loggedIn.toString());
  }

  /// Login via backend API — returns login result map or throws
  /// Result may contain 'requires_mfa' flag for MFA flow.
  Future<Map<String, dynamic>> loginRemote(String username, String password) async {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    final response = await dio.post('/api/login', data: {
      'username': username,
      'password': password,
    });

    final data = response.data as Map<String, dynamic>;

    // Check if MFA is required
    if (data['requires_mfa'] == true) {
      return data; // Caller handles MFA flow
    }

    // Full login — store tokens
    final token = data['access_token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    if (data['refresh_token'] != null) {
      await _storage.write(key: _refreshTokenKey, value: data['refresh_token'] as String);
    }
    if (data['role'] != null) {
      await _storage.write(key: _roleKey, value: data['role'] as String);
    }
    return data;
  }

  /// Complete MFA login with TOTP code
  Future<Map<String, dynamic>> loginMfa(String mfaToken, String totpCode) async {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    final response = await dio.post('/api/mfa/login', data: {
      'mfa_token': mfaToken,
      'totp_code': totpCode,
    });

    final data = response.data as Map<String, dynamic>;
    final token = data['access_token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    if (data['refresh_token'] != null) {
      await _storage.write(key: _refreshTokenKey, value: data['refresh_token'] as String);
    }
    if (data['role'] != null) {
      await _storage.write(key: _roleKey, value: data['role'] as String);
    }
    return data;
  }

  /// Get stored JWT token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Get stored refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// Get stored user role
  Future<String?> getRole() async {
    return await _storage.read(key: _roleKey);
  }

  /// Clear JWT token
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Clear refresh token
  Future<void> clearRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
  }

  /// Store the logged-in username
  Future<void> setUsername(String username) async {
    await _storage.write(key: _usernameKey, value: username.trim().toLowerCase());
  }

  /// Get the logged-in username
  Future<String?> getUsername() async {
    return await _storage.read(key: _usernameKey);
  }

  /// Clear all auth data (for logout/reset)
  Future<void> clearAll() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinEnabledKey);
    await _storage.delete(key: _biometricsEnabledKey);
    await _storage.delete(key: _loggedInKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _roleKey);
  }
}
