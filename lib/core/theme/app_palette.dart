import 'package:flutter/material.dart';

/// Semantic colour tokens for Focus Reset.
///
/// Every screen reads colours from here (via `context.palette`) — never
/// hard-coded hex values — so light and dark mode stay consistent.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.separator,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentSoft,
    required this.focus,
    required this.focusSoft,
    required this.sleep,
    required this.sleepSoft,
    required this.habit,
    required this.habitSoft,
    required this.work,
    required this.workSoft,
    required this.danger,
    required this.success,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color separator;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Brand accent — calm deep teal.
  final Color accent;
  final Color accentSoft;

  /// Focus sessions — indigo.
  final Color focus;
  final Color focusSoft;

  /// Sleep & rest — muted violet-blue.
  final Color sleep;
  final Color sleepSoft;

  /// Habits — warm amber.
  final Color habit;
  final Color habitSoft;

  /// Work / fixed commitments — slate.
  final Color work;
  final Color workSoft;

  final Color danger;
  final Color success;

  static const light = AppPalette(
    background: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEDEDF0),
    separator: Color(0xFFDCDCE0),
    textPrimary: Color(0xFF111114),
    textSecondary: Color(0xFF6B6B73),
    textTertiary: Color(0xFFA1A1A8),
    accent: Color(0xFF1F7A6B),
    accentSoft: Color(0xFFE2F1EE),
    focus: Color(0xFF4F55D8),
    focusSoft: Color(0xFFE8E9FB),
    sleep: Color(0xFF6A5ACD),
    sleepSoft: Color(0xFFEDEAFB),
    habit: Color(0xFFC4862F),
    habitSoft: Color(0xFFF8EEDF),
    work: Color(0xFF4A5568),
    workSoft: Color(0xFFE6E9EE),
    danger: Color(0xFFD64545),
    success: Color(0xFF2E9E5B),
  );

  static const dark = AppPalette(
    background: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceAlt: Color(0xFF2C2C2E),
    separator: Color(0xFF38383A),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFF9E9EA6),
    textTertiary: Color(0xFF66666D),
    accent: Color(0xFF4FC2AD),
    accentSoft: Color(0xFF15302B),
    focus: Color(0xFF8D92FF),
    focusSoft: Color(0xFF22243F),
    sleep: Color(0xFFA295F2),
    sleepSoft: Color(0xFF26223F),
    habit: Color(0xFFE5A955),
    habitSoft: Color(0xFF35291A),
    work: Color(0xFFA7B1C2),
    workSoft: Color(0xFF262A31),
    danger: Color(0xFFFF6B6B),
    success: Color(0xFF4CC985),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      separator: l(separator, other.separator),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      focus: l(focus, other.focus),
      focusSoft: l(focusSoft, other.focusSoft),
      sleep: l(sleep, other.sleep),
      sleepSoft: l(sleepSoft, other.sleepSoft),
      habit: l(habit, other.habit),
      habitSoft: l(habitSoft, other.habitSoft),
      work: l(work, other.work),
      workSoft: l(workSoft, other.workSoft),
      danger: l(danger, other.danger),
      success: l(success, other.success),
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
}
