import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over on-device key/value storage.
///
/// Holds only app settings and the local profile. Nothing here leaves the
/// device. Phase 3 adds Supabase sync behind the repository interfaces.
class PreferencesService {
  PreferencesService._(this._prefs);

  final SharedPreferences _prefs;

  static Future<PreferencesService> create() async =>
      PreferencesService._(await SharedPreferences.getInstance());

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) => _prefs.setString(key, value);
  Future<void> remove(String key) => _prefs.remove(key);

  /// Wipes every value Focus Reset stored on this device.
  Future<void> clearAll() => _prefs.clear();
}

abstract final class PrefKeys {
  static const locale = 'settings.locale';
  static const themeMode = 'settings.themeMode';
  static const profile = 'profile.v1';
}
