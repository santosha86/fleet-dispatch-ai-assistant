import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handlePinSubmit() async {
    final pin = _pinController.text;
    if (pin.length < 4) return;

    final success = await ref.read(authProvider.notifier).verifyPin(pin);
    if (!success) {
      _pinController.clear();
      _focusNode.requestFocus();
    }
  }

  Future<void> _handleBiometrics() async {
    await ref.read(authProvider.notifier).authenticateWithBiometrics();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.userBubbleGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  l10n.appTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your PIN to continue',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 40),

                // PIN Input
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _pinController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    obscureText: _obscurePin,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '----',
                      hintStyle: TextStyle(
                        letterSpacing: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePin
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _obscurePin = !_obscurePin);
                        },
                      ),
                    ),
                    onSubmitted: (_) => _handlePinSubmit(),
                  ),
                ),
                const SizedBox(height: 16),

                // Error message
                if (authState.error != null) ...[
                  Text(
                    authState.error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],

                // Locked message
                if (authState.isLocked) ...[
                  const Icon(Icons.lock, color: Colors.redAccent, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Account locked. Too many failed attempts.',
                    style: TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ],

                // Submit button
                if (!authState.isLocked) ...[
                  SizedBox(
                    width: 200,
                    child: FilledButton(
                      onPressed: _handlePinSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.indigo600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(l10n.ok),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Biometrics button
                if (authState.canUseBiometrics &&
                    authState.isBiometricsEnabled &&
                    !authState.isLocked) ...[
                  TextButton.icon(
                    onPressed: _handleBiometrics,
                    icon: const Icon(Icons.fingerprint, size: 28),
                    label: const Text('Use Biometrics'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
