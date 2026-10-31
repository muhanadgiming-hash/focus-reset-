import 'package:supabase_flutter/supabase_flutter.dart';

import '../sync/remote_store.dart';
import 'auth_service.dart';

/// Supabase Auth (email + password, with emailed one-time codes for
/// confirmation and password reset — no deep links required).
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  String? get userId => _auth.currentUser?.id;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  Stream<void> get changes => _auth.onAuthStateChange.map((_) {});

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AuthException catch (e) {
      throw _map(e);
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw AuthFailure(AuthFailure.network, '$e');
    }
  }

  AuthFailure _map(AuthException e) {
    final m = e.message.toLowerCase();
    final status = e.statusCode;
    if (m.contains('invalid login credentials')) return const AuthFailure(AuthFailure.invalidCredentials);
    if (m.contains('email not confirmed')) return const AuthFailure(AuthFailure.emailNotConfirmed);
    if (m.contains('expired') || (m.contains('invalid') && (m.contains('token') || m.contains('otp')))) {
      return const AuthFailure(AuthFailure.invalidCode);
    }
    if (m.contains('password') && (m.contains('weak') || m.contains('at least') || m.contains('characters'))) {
      return const AuthFailure(AuthFailure.weakPassword);
    }
    if (status == '429' || m.contains('rate limit') || m.contains('security purposes')) {
      return const AuthFailure(AuthFailure.rateLimited);
    }
    if (status == null || m.contains('socket') || m.contains('host lookup') || m.contains('clientexception')) {
      return AuthFailure(AuthFailure.network, e.message);
    }
    return AuthFailure(AuthFailure.unknown, e.message);
  }

  @override
  Future<bool> signUp(String email, String password) => _guard(() async {
        final res = await _auth.signUp(email: email, password: password);
        return res.session != null;
      });

  @override
  Future<void> verifySignUp(String email, String code) => _guard(() async {
        await _auth.verifyOTP(email: email, token: code, type: OtpType.signup);
      });

  @override
  Future<void> signIn(String email, String password) => _guard(() async {
        await _auth.signInWithPassword(email: email, password: password);
      });

  @override
  Future<void> sendPasswordReset(String email) => _guard(() async {
        await _auth.resetPasswordForEmail(email);
      });

  @override
  Future<void> resetPassword(String email, String code, String newPassword) => _guard(() async {
        await _auth.verifyOTP(email: email, token: code, type: OtpType.recovery);
        await _auth.updateUser(UserAttributes(password: newPassword));
      });

  @override
  Future<void> signOut() => _guard(() async {
        await _auth.signOut();
      });

  @override
  Future<void> deleteAccount() => _guard(() async {
        // Server function (see supabase/schema.sql) deletes the auth user;
        // all rows in user_records are removed by ON DELETE CASCADE.
        await _client.rpc('delete_my_account');
        try {
          await _auth.signOut();
        } catch (_) {
          // The session is already invalid once the user is deleted.
        }
      });
}

/// Cloud copy of the user's records in the `user_records` table.
/// Row Level Security guarantees each user only sees their own rows.
class SupabaseRemoteStore implements RemoteStore {
  SupabaseRemoteStore(this._client);

  final SupabaseClient _client;

  static const _table = 'user_records';
  static const _pageSize = 500;

  @override
  Future<void> push(List<RemoteRecord> records) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    for (var i = 0; i < records.length; i += _pageSize) {
      final chunk = records.skip(i).take(_pageSize);
      await _client.from(_table).upsert(
        [
          for (final r in chunk)
            {
              'user_id': uid,
              'kind': r.kind,
              'id': r.id,
              'data': r.data,
              'updated_at': r.updatedAt.toUtc().toIso8601String(),
              'deleted': r.deleted,
            },
        ],
        onConflict: 'user_id,kind,id',
      );
    }
  }

  @override
  Future<List<RemoteRecord>> pullSince(DateTime? since) async {
    final out = <RemoteRecord>[];
    var cursor = since;
    while (true) {
      var query = _client.from(_table).select('kind,id,data,updated_at,deleted,synced_at');
      if (cursor != null) query = query.gt('synced_at', cursor.toUtc().toIso8601String());
      final rows = await query.order('synced_at', ascending: true).limit(_pageSize);
      for (final row in rows) {
        final synced = DateTime.parse(row['synced_at'] as String).toUtc();
        final data = row['data'];
        out.add(RemoteRecord(
          kind: row['kind'] as String,
          id: row['id'] as String,
          data: data is Map ? Map<String, dynamic>.from(data) : null,
          updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
          deleted: row['deleted'] == true,
          syncedAt: synced,
        ));
        cursor = synced;
      }
      if (rows.length < _pageSize) break;
    }
    return out;
  }
}
