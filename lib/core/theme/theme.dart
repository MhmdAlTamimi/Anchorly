// App theme: the palette and Material 3 configuration live here ONLY.
//
// Design-token approach: colors are defined once (navy / teal / soft gold) and
// every widget reads them from Theme.of(context).colorScheme. No widget should
// hardcode a Color — change the palette here and the whole app updates.

import 'package:flutter/material.dart';
import 'tokens.dart';

class AppColors {
  const AppColors._();

  static const Color navy = Color(0xFF1E2A44); // primary
  static const Color teal = Color(0xFF2E9E8F); // secondary
  static const Color gold = Color(0xFFD8A657); // accent

  // Journal day-state colors (kept here so both light/dark reference one source).
  static const Color success = Color(0xFF3E9E6B); // green
  static const Color relapse = Color(0xFFC65B57); // red
  static const Color neutral = Color(0xFF9AA0AA); // grey
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: brightness,
      // Pin the exact brand colors in LIGHT mode. In DARK mode we intentionally
      // leave these null so the scheme derives lighter, legible tones from the
      // same navy seed: a dark-navy primary on a dark surface is nearly
      // invisible, which made text buttons ("Add", "Cancel"), filled buttons
      // and focused field labels ("What happened today?") disappear.
      primary: isDark ? null : AppColors.navy,
      secondary: isDark ? null : AppColors.teal,
      tertiary: isDark ? null : AppColors.gold,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardTheme(
        elevation: Elevations.card,
        shape: const RoundedRectangleBorder(borderRadius: Radii.card),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: Radii.card),
        filled: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: Radii.card),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: Elevations.raised,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(borderRadius: Radii.sheet),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }
}
