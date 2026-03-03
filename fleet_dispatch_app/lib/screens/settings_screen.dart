import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import 'pin_setup_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme toggle
          Card(
            child: ListTile(
              leading: Icon(
                settings.isDark ? Icons.dark_mode : Icons.light_mode,
              ),
              title: Text(l10n.theme),
              subtitle: Text(settings.isDark ? l10n.darkMode : l10n.lightMode),
              trailing: Switch(
                value: settings.isDark,
                onChanged: (_) =>
                    ref.read(settingsProvider.notifier).toggleTheme(),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Language selection
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.language),
              subtitle: Text(settings.isArabic ? l10n.arabic : l10n.english),
              trailing: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'en',
                    label: Text(l10n.english),
                  ),
                  ButtonSegment(
                    value: 'ar',
                    label: Text(l10n.arabic),
                  ),
                ],
                selected: {settings.locale.languageCode},
                onSelectionChanged: (selected) {
                  ref.read(settingsProvider.notifier).setLocale(
                        Locale(selected.first),
                      );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Security section header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Security',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          // PIN lock toggle
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('PIN Lock'),
              subtitle: Text(
                authState.isPinEnabled ? 'Enabled' : 'Disabled',
              ),
              trailing: Switch(
                value: authState.isPinEnabled,
                onChanged: (enabled) async {
                  if (enabled) {
                    // Navigate to PIN setup
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const PinSetupScreen(),
                      ),
                    );
                    if (result != true) {
                      // User cancelled - no action needed
                    }
                  } else {
                    // Disable PIN
                    ref.read(authProvider.notifier).togglePin(false);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Biometrics toggle (only shown if device supports it and PIN is enabled)
          if (authState.canUseBiometrics && authState.isPinEnabled) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.fingerprint),
                title: const Text('Biometric Login'),
                subtitle: Text(
                  authState.isBiometricsEnabled
                      ? 'Fingerprint / Face ID enabled'
                      : 'Disabled',
                ),
                trailing: Switch(
                  value: authState.isBiometricsEnabled,
                  onChanged: (enabled) {
                    ref.read(authProvider.notifier).toggleBiometrics(enabled);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Change PIN (only shown if PIN is enabled)
          if (authState.isPinEnabled) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Change PIN'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PinSetupScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 16),

          // App info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version 1.0.0',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Logout button
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: Text(
                l10n.logout,
                style: const TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                ref.read(chatProvider.notifier).clearChat();
                ref.read(authProvider.notifier).logout();
              },
            ),
          ),
        ],
      ),
    );
  }
}
