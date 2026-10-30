import 'package:flutter/material.dart';

import '../data/models/user_profile.dart';
import '../data/repositories/profile_repository.dart';
import '../data/services/preferences_service.dart';

/// App-wide state: language, appearance and the user's profile.
///
/// Feature state (tasks, habits, schedule) gets its own controllers in
/// Phase 2 so this class stays small.
class AppController extends ChangeNotifier {
  AppController({required PreferencesService prefs, required ProfileRepository profiles})
      : _prefs = prefs,
        _profiles = profiles;

  final PreferencesService _prefs;
  final ProfileRepository _profiles;

  Locale? _locale; // null → follow the device language
  ThemeMode _themeMode = ThemeMode.system;
  UserProfile? _profile;

  Locale? get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  UserProfile? get profile => _profile;
  bool get isOnboarded => _profile != null;

  Future<void> load() async {
    final code = _prefs.getString(PrefKeys.locale);
    _locale = (code == 'ar' || code == 'en') ? Locale(code!) : null;

    _themeMode = switch (_prefs.getString(PrefKeys.themeMode)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    _profile = await _profiles.load();
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    if (locale == null) {
      await _prefs.remove(PrefKeys.locale);
    } else {
      await _prefs.setString(PrefKeys.locale, locale.languageCode);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(PrefKeys.themeMode, mode.name);
  }

  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    notifyListeners();
    await _profiles.save(profile);
  }

  /// Deletes everything Focus Reset stored on this device and returns the
  /// app to the welcome screen.
  Future<void> deleteAllLocalData() async {
    await _profiles.clear();
    await _prefs.clearAll();
    _profile = null;
    _locale = null;
    _themeMode = ThemeMode.system;
    notifyListeners();
  }
}

/// Exposes [AppController] to the widget tree and rebuilds dependants on change.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child})
      : super(notifier: controller);

  /// Subscribe to changes.
  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read once without subscribing (use in callbacks).
  static AppController read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AppScope>()!.widget as AppScope).notifier!;
}
