import 'package:shared_preferences/shared_preferences.dart';

/// Minimal key/value storage contract used by local repositories and the
/// sync engine. [PreferencesService] is the on-device implementation;
/// [MemoryStore] is used in tests.
abstract interface class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// On-device storage (NSUserDefaults on iOS).
class PreferencesService implements KeyValueStore {
  PreferencesService._(this._prefs);

  final SharedPreferences _prefs;

  static Future<PreferencesService> create() async =>
      PreferencesService._(await SharedPreferences.getInstance());

  /// Key prefixes owned by Focus Reset (the auth session is managed separately).
  static const _ownPrefixes = ['settings.', 'profile.', 'planner.', 'sync.'];

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  /// Wipes every value Focus Reset stored on this device.
  Future<void> clearAll() async {
    for (final k in _prefs.getKeys().toList()) {
      if (_ownPrefixes.any(k.startsWith)) await _prefs.remove(k);
    }
  }
}

/// In-memory store for tests.
class MemoryStore implements KeyValueStore {
  final Map<String, String> _values = {};

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}

abstract final class PrefKeys {
  static const locale = 'settings.locale';
  static const themeMode = 'settings.themeMode';
  static const profile = 'profile.v1';
}
