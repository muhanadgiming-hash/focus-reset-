/// One synced record as stored in the cloud (`user_records` table).
class RemoteRecord {
  const RemoteRecord({
    required this.kind,
    required this.id,
    required this.data,
    required this.updatedAt,
    required this.deleted,
    this.syncedAt,
  });

  final String kind;
  final String id;

  /// The record's JSON, or null for a deletion (tombstone).
  final Map<String, dynamic>? data;

  /// When the user last changed it, on the device that changed it.
  final DateTime updatedAt;
  final bool deleted;

  /// Server time the row was last written; used to pull only new changes.
  final DateTime? syncedAt;
}

/// Cloud storage contract. Implemented by `SupabaseRemoteStore`; tests use
/// an in-memory fake.
abstract interface class RemoteStore {
  Future<void> push(List<RemoteRecord> records);

  /// Records written after [since] (server time), oldest first.
  Future<List<RemoteRecord>> pullSince(DateTime? since);
}
