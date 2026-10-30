import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'strings_ar.dart';
import 'strings_en.dart';

/// Lightweight, dependency-free localisation for Focus Reset.
///
/// * All UI text lives in [kStringsEn] and [kStringsAr].
/// * `test/l10n_parity_test.dart` fails the build if a key exists in one
///   language but not the other.
/// * Layout direction (RTL for Arabic) is applied automatically by
///   `GlobalWidgetsLocalizations`, and every widget in the app uses
///   directional padding/alignment so the mirroring is real, not cosmetic.
class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[Locale('en'), Locale('ar')];

  static const LocalizationsDelegate<AppStrings> delegate = _AppStringsDelegate();

  static const Map<String, Map<String, String>> _values = {
    'en': kStringsEn,
    'ar': kStringsAr,
  };

  @visibleForTesting
  static Map<String, Map<String, String>> get allValues => _values;

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ?? AppStrings(const Locale('en'));

  bool get isArabic => locale.languageCode == 'ar';

  String get(String key, [Map<String, String>? args]) {
    final table = _values[locale.languageCode] ?? kStringsEn;
    var value = table[key] ?? kStringsEn[key] ?? key;
    if (args != null) {
      args.forEach((k, v) => value = value.replaceAll('{$k}', v));
    }
    return value;
  }

  /// Picks Arabic when the device language is Arabic, English otherwise.
  static Locale resolve(Locale? device, Iterable<Locale> supported) {
    if (device != null && device.languageCode == 'ar') return const Locale('ar');
    return const Locale('en');
  }
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => const ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) => SynchronousFuture(AppStrings(locale));

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

extension TrContext on BuildContext {
  /// Translate [key] in the current locale. `{name}` style placeholders are
  /// replaced from [args].
  String tr(String key, [Map<String, String>? args]) => AppStrings.of(this).get(key, args);

  String get localeTag => AppStrings.of(this).locale.languageCode;
}
