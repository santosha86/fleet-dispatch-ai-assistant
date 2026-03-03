import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  static const _pinHashKey = 'fleet_pin_hash';
  static const _pinEnabledKey = 'fleet_pin_enabled';
  static const _biometricsEnabledKey = 'fleet_biometrics_enabled';
  static const _loggedInKey = 'fleet_logged_in';
  static const _usernameKey = 'fleet_username';

  /// All valid users (case-insensitive usernames)
  static const _users = {
    'pb': 'admin1234',
    'user1': 'user1pass',
    'user2': 'user2pass',
    'user3': 'user3pass',
    'user4': 'user4pass',
  };

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

  /// Validate login credentials (case-insensitive username)
  bool validateCredentials(String username, String password) {
    final normalizedUsername = username.trim().toLowerCase();
    final expectedPassword = _users[normalizedUsername];
    return expectedPassword != null && expectedPassword == password;
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
  }
}
