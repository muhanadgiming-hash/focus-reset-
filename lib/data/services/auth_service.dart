/// Account operations used by the app. `SupabaseAuthService` implements it;
/// when the build has no Supabase configuration there is no AuthService and
/// the app runs in on-device mode.
abstract interface class AuthService {
  String? get userId;
  String? get email;

  /// Fires whenever the signed-in user or session changes.
  Stream<void> get changes;

  /// Returns true when the user is signed in straight away, false when the
  /// email must be confirmed with a code first.
  Future<bool> signUp(String email, String password);
  Future<void> verifySignUp(String email, String code);
  Future<void> signIn(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> resetPassword(String email, String code, String newPassword);
  Future<void> signOut();

  /// Permanently deletes the account and all of its cloud data.
  Future<void> deleteAccount();
}

/// A user-facing failure. [code] maps to the `auth.err.<code>` string.
class AuthFailure implements Exception {
  const AuthFailure(this.code, [this.detail]);

  final String code;
  final String? detail;

  static const invalidCredentials = 'invalidCredentials';
  static const emailNotConfirmed = 'emailNotConfirmed';
  static const invalidCode = 'invalidCode';
  static const weakPassword = 'weakPassword';
  static const rateLimited = 'rateLimited';
  static const network = 'network';
  static const unknown = 'unknown';

  @override
  String toString() => 'AuthFailure($code${detail == null ? '' : ': $detail'})';
}
