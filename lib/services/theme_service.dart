import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton that persists and exposes the app-wide [ThemeMode].
/// Listen to [themeMode] via [ValueListenableBuilder] to react to changes.
///
/// Uses an overlay-based crossfade transition (like Facebook) for a smooth
/// theme switch with no visible color morphing.
class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _prefKey = 'faith_connect_theme_mode';

  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

  /// True while the fade overlay is active during a theme switch.
  final isTransitioning = ValueNotifier<bool>(false);

  /// The direction of the current transition (true = switching TO dark).
  bool _goingDark = false;
  bool get goingDark => _goingDark;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefKey);
      if (stored == 'dark') {
        themeMode.value = ThemeMode.dark;
      } else {
        themeMode.value = ThemeMode.light;
      }
    } catch (_) {
      themeMode.value = ThemeMode.light;
    }
  }

  bool get isDark => themeMode.value == ThemeMode.dark;

  Future<void> toggle() async {
    _goingDark = !isDark;

    // 1. Show the overlay (fade-in).
    isTransitioning.value = true;

    // 2. Wait for the overlay to reach full opacity.
    await Future.delayed(const Duration(milliseconds: 180));

    // 3. Switch the theme instantly (hidden behind the overlay).
    final nowDark = themeMode.value == ThemeMode.dark;
    themeMode.value = nowDark ? ThemeMode.light : ThemeMode.dark;

    // 4. Wait two frames for the widget tree to rebuild under the overlay.
    await Future.delayed(const Duration(milliseconds: 50));

    // 5. Dismiss the overlay (fade-out reveals the new theme).
    isTransitioning.value = false;

    // Persist in background.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, nowDark ? 'light' : 'dark');
    } catch (_) {}
  }
}
