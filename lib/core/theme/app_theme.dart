import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Spacing and radius scale. Use these instead of magic numbers.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;

  /// Horizontal page gutter used by every screen.
  static const double gutter = 20;
}

abstract final class Radii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, AppPalette.light);
  static ThemeData dark() => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: brightness == Brightness.light ? Colors.white : Colors.black,
      secondary: c.focus,
      onSecondary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.surfaceAlt,
      outline: c.separator,
      outlineVariant: c.separator,
    );

    final text = _textTheme(c);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[c],
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: c.textPrimary,
        centerTitle: true,
        titleTextStyle: text.titleMedium,
      ),
      dividerTheme: DividerThemeData(color: c.separator, thickness: 0.5, space: 0.5),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceAlt,
        hintStyle: TextStyle(color: c.textTertiary),
        labelStyle: TextStyle(color: c.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: c.accent, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: c.danger, width: 1.2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.separator,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.textPrimary,
        contentTextStyle: TextStyle(color: c.background, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : c.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.surfaceAlt,
        thumbColor: c.accent,
        overlayColor: c.accent.withValues(alpha: 0.12),
      ),
    );
  }

  static TextTheme _textTheme(AppPalette c) {
    // On iOS the default family resolves to SF Pro / SF Arabic, which is
    // exactly what we want for an Apple-native look in both languages.
    return TextTheme(
      displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: c.textPrimary, height: 1.15),
      headlineSmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: c.textPrimary),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: c.textPrimary),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: c.textPrimary),
      titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
      bodyLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: c.textPrimary, height: 1.35),
      bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: c.textPrimary, height: 1.35),
      bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: c.textSecondary, height: 1.35),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.textSecondary),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: c.textTertiary),
    );
  }
}
