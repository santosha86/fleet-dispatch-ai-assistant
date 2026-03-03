import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_colors.dart';
import '../providers/auth_provider.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _pinFocus = FocusNode();
  final _confirmFocus = FocusNode();
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    _pinFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSetup() async {
    final pin = _pinController.text;
    final confirm = _confirmController.text;

    if (pin.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits.');
      return;
    }

    if (pin != confirm) {
      setState(() => _error = 'PINs do not match. Please try again.');
      _confirmController.clear();
      _confirmFocus.requestFocus();
      return;
    }

    await ref.read(authProvider.notifier).setupPin(pin);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up PIN'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.userBubbleGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pin_outlined,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Create a PIN',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a 4-6 digit PIN to secure the app.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // PIN field
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _pinController,
                    focusNode: _pinFocus,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    obscureText: _obscure,
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
                      labelText: 'Enter PIN',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onSubmitted: (_) => _confirmFocus.requestFocus(),
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm PIN field
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _confirmController,
                    focusNode: _confirmFocus,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    obscureText: _obscure,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      labelText: 'Confirm PIN',
                    ),
                    onSubmitted: (_) => _handleSetup(),
                  ),
                ),
                const SizedBox(height: 16),

                // Error
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],

                // Submit
                SizedBox(
                  width: 200,
                  child: FilledButton(
                    onPressed: _handleSetup,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.indigo600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Set PIN'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
