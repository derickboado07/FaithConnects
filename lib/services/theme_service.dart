// ─────────────────────────────────────────────────────────────────────────────
// THEME SERVICE — Nag-ma-manage ng app-wide dark/light mode theme.
// Gumagamit ng overlay-based crossfade transition (parang Facebook)
// para sa smooth na theme switch na walang visible color morphing.
//
// Persistence: SharedPreferences ('faith_connect_theme_mode')
// State: ValueNotifier<ThemeMode> — i-listen via ValueListenableBuilder
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton na nag-pe-persist at nag-e-expose ng app-wide ThemeMode.
/// I-listen ang [themeMode] gamit ang ValueListenableBuilder para mag-react sa changes.
///
/// Gumagamit ng overlay-based crossfade transition para sa smooth na
/// theme switch — walang visible color morphing.
class ThemeService {
  ThemeService._(); // Private constructor para sa Singleton
  static final ThemeService instance = ThemeService._(); // Global instance

  static const _prefKey = 'faith_connect_theme_mode'; // SharedPreferences key

  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light); // Current theme (default: light)

  /// True habang naka-active ang fade overlay sa theme switch.
  final isTransitioning = ValueNotifier<bool>(false);

  /// Direction ng current transition (true = papuntang dark mode).
  bool _goingDark = false;
  bool get goingDark => _goingDark;

  /// Nilo-load ang saved theme mula sa SharedPreferences.
  /// Kapag 'dark' ang stored value, gagamitin ang dark mode; otherwise light.
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

  bool get isDark => themeMode.value == ThemeMode.dark; // Shortcut para ma-check kung dark mode

  /// Nag-to-toggle ng theme (dark ↔ light) with smooth overlay transition.
  /// Ang proseso:
  ///   1. Ipakita ang overlay (fade-in)
  ///   2. Hintayin ang overlay na maging fully opaque
  ///   3. I-switch ang theme instantly (naka-tago sa likod ng overlay)
  ///   4. Hintayin ang widget tree na mag-rebuild
  ///   5. I-dismiss ang overlay (fade-out para i-reveal ang bagong theme)
  Future<void> toggle() async {
    _goingDark = !isDark;

    // 1. Ipakita ang overlay (fade-in).
    isTransitioning.value = true;

    // 2. Hintayin ang overlay na maging full opacity.
    await Future.delayed(const Duration(milliseconds: 180));

    // 3. I-switch ang theme instantly (naka-tago sa likod ng overlay).
    final nowDark = themeMode.value == ThemeMode.dark;
    themeMode.value = nowDark ? ThemeMode.light : ThemeMode.dark;

    // 4. Hintayin ng dalawang frame para mag-rebuild ang widget tree.
    await Future.delayed(const Duration(milliseconds: 50));

    // 5. I-dismiss ang overlay (fade-out para i-reveal ang bagong theme).
    isTransitioning.value = false;

    // I-persist ang bagong theme sa background.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, nowDark ? 'light' : 'dark');
    } catch (_) {}
  }
}
