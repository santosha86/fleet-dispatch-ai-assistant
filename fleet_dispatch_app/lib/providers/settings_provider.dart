import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final Locale locale;
  final ThemeMode themeMode;

  const SettingsState({
    this.locale = const Locale('en'),
    this.themeMode = ThemeMode.dark,
  });

  SettingsState copyWith({Locale? locale, ThemeMode? themeMode}) {
    return SettingsState(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  bool get isArabic => locale.languageCode == 'ar';
  bool get isDark => themeMode == ThemeMode.dark;
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('locale') ?? 'en';
    final isDark = prefs.getBool('darkMode') ?? true;

    state = SettingsState(
      locale: Locale(langCode),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    );
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
  }

  Future<void> toggleTheme() async {
    final newMode = state.isDark ? ThemeMode.light : ThemeMode.dark;
    state = state.copyWith(themeMode: newMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', newMode == ThemeMode.dark);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
