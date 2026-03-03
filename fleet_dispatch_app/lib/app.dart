import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';

import 'core/config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

class FleetDispatchApp extends ConsumerStatefulWidget {
  const FleetDispatchApp({super.key});

  @override
  ConsumerState<FleetDispatchApp> createState() => _FleetDispatchAppState();
}

class _FleetDispatchAppState extends ConsumerState<FleetDispatchApp>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;

  /// Auto-lock timeout: lock after 5 minutes in background
  static const _lockTimeout = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!);
        if (elapsed > _lockTimeout) {
          ref.read(authProvider.notifier).lock();
        }
        _pausedAt = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Fleet Dispatch AI Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _buildHome(authState),
    );
  }

  Widget _buildHome(AuthState authState) {
    switch (authState.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.loggedOut:
        return const LoginScreen();
      case AuthStatus.unauthenticated:
        return const AuthScreen();
      case AuthStatus.pinSetupRequired:
      case AuthStatus.authenticated:
        return const HomeScreen();
    }
  }
}
