import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Persistence key
// ─────────────────────────────────────────────────────────────────────────────
const _kThemeModeKey = 'app_theme_mode';

// ─────────────────────────────────────────────────────────────────────────────
// ThemeNotifier — stores ThemeMode + persists with SharedPreferences
// ─────────────────────────────────────────────────────────────────────────────
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _load();
  }

  // Load persisted value from disk.
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeModeKey);
    if (saved != null) {
      state = _fromString(saved);
    }
  }

  // Persist and apply a new ThemeMode.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, _toString(mode));
  }

  // Convenience: cycle Light → Dark → System → Light …
  Future<void> toggle() async {
    switch (state) {
      case ThemeMode.light:
        await setThemeMode(ThemeMode.dark);
      case ThemeMode.dark:
        await setThemeMode(ThemeMode.system);
      case ThemeMode.system:
        await setThemeMode(ThemeMode.light);
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  static String _toString(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  static ThemeMode _fromString(String s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  /// Returns the icon that best represents the *current* mode.
  static IconData iconFor(ThemeMode m) => switch (m) {
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
        ThemeMode.system => Icons.brightness_auto_rounded,
      };

  /// Human-readable label.
  static String labelFor(ThemeMode m) => switch (m) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider  (global singleton — survives navigation)
// ─────────────────────────────────────────────────────────────────────────────
final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) => ThemeNotifier());
