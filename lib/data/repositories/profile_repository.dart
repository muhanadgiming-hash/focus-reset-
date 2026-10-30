import 'dart:convert';

import '../models/user_profile.dart';
import '../services/preferences_service.dart';

/// Abstraction over where the profile lives. Phase 3 adds a
/// `SupabaseProfileRepository` implementing the same interface, so the UI
/// and business logic do not change.
abstract interface class ProfileRepository {
  Future<UserProfile?> load();
  Future<void> save(UserProfile profile);
  Future<void> clear();
}

class LocalProfileRepository implements ProfileRepository {
  LocalProfileRepository(this._prefs);

  final PreferencesService _prefs;

  @override
  Future<UserProfile?> load() async {
    final raw = _prefs.getString(PrefKeys.profile);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt or incompatible data: treat as no profile rather than crash.
      return null;
    }
  }

  @override
  Future<void> save(UserProfile profile) =>
      _prefs.setString(PrefKeys.profile, jsonEncode(profile.toJson()));

  @override
  Future<void> clear() => _prefs.remove(PrefKeys.profile);
}
