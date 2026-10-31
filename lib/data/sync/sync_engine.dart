import 'dart:collection';
import 'dart:convert';

import '../models/planning_models.dart';
import '../models/user_profile.dart';
import '../repositories/planner_repository.dart';
import '../repositories/profile_repository.dart';
import '../services/preferences_service.dart';
import 'remote_store.dart';

/// Stable JSON with sorted keys, so the same data always hashes the same
/// (the database may reorder keys).
String canonicalJson(Object? value) {
  Object? canon(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: canon(v[k])};
    }
    if (v is List) return v.map(canon).toList();
    return v;
  }

  return jsonEncode(canon(value));
}

/// 32-bit FNV-1a hash, hex encoded.
String fnv1a(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16);
}

class _Entry {
  const _Entry({required this.hash, required this.updatedAt, required this.dirty, required this.deleted});

  final String hash;
  final DateTime updatedAt;
  final bool dirty;
  final bool deleted;

  Map<String, dynamic> toJson() => {'h': hash, 'u': updatedAt.toUtc().toIso8601String(), 'd': dirty, 'x': deleted};

  static _Entry? fromJson(Object? j) {
    if (j is! Map) return null;
    final u = j['u'];
    final t = u is String ? DateTime.tryParse(u) : null;
    if (t == null) return null;
    return _Entry(hash: '${j['h'] ?? ''}', updatedAt: t.toUtc(), dirty: j['d'] == true, deleted: j['x'] == true);
  }
}

class _Rec {
  const _Rec(this.kind, this.id, this.data);
  final String kind;
  final String id;
  final Map<String, dynamic> data;
}

abstract final class SyncKinds {
  static const task = 'task';
  static const commitment = 'commitment';
  static const habit = 'habit';
  static const habitLog = 'habit_log';
  static const focus = 'focus';
  static const sleep = 'sleep';
  static const profile = 'profile';

  static const all = [task, commitment, habit, habitLog, focus, sleep, profile];
}

/// Offline-first, record-level synchronisation.
///
/// The device is always the working copy. Each run:
///  1. finds what changed locally since the last run (by content hash),
///  2. pushes those records (deletions as tombstones),
///  3. pulls records other devices wrote, keeping whichever version was
///     changed most recently (last write wins, per record).
class SyncEngine {
  SyncEngine({
    required this.local,
    required this.profiles,
    required this.store,
    required this.remote,
  });

  final PlannerRepository local;
  final ProfileRepository profiles;
  final KeyValueStore store;
  final RemoteStore remote;

  static const _kLedger = 'sync.ledger.v1';
  static const _kLastPull = 'sync.lastPull.v1';
  static const _kOwner = 'sync.owner.v1';

  Map<String, _Entry> _loadLedger() {
    final raw = store.getString(_kLedger);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, _Entry>{};
      decoded.forEach((k, v) {
        final e = _Entry.fromJson(v);
        if (k is String && e != null) out[k] = e;
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveLedger(Map<String, _Entry> ledger) =>
      store.setString(_kLedger, jsonEncode({for (final e in ledger.entries) e.key: e.value.toJson()}));

  /// Forgets all sync state (after sign-out or account deletion).
  Future<void> reset() async {
    await store.remove(_kLedger);
    await store.remove(_kLastPull);
    await store.remove(_kOwner);
  }

  static Map<String, dynamic>? normalize(String kind, Map<String, dynamic> data) {
    try {
      switch (kind) {
        case SyncKinds.task:
          return TaskItem.fromJson(data).toJson();
        case SyncKinds.commitment:
          return Commitment.fromJson(data).toJson();
        case SyncKinds.habit:
          return Habit.fromJson(data).toJson();
        case SyncKinds.focus:
          return FocusSession.fromJson(data).toJson();
        case SyncKinds.sleep:
          return SleepEntry.fromJson(data).toJson();
        case SyncKinds.habitLog:
          return {
            for (final e in data.entries)
              if (e.value is num) e.key: (e.value as num).toInt(),
          };
        case SyncKinds.profile:
          return UserProfile.fromJson(data).toJson();
      }
    } catch (_) {
      // Unreadable record (e.g. from a newer app version): ignore it.
    }
    return null;
  }

  static LinkedHashMap<String, _Rec> _collect(PlannerSnapshot s, UserProfile? p) {
    final m = LinkedHashMap<String, _Rec>();
    void add(String kind, String id, Map<String, dynamic> data) => m['$kind/$id'] = _Rec(kind, id, data);
    for (final t in s.tasks) {
      add(SyncKinds.task, t.id, t.toJson());
    }
    for (final c in s.commitments) {
      add(SyncKinds.commitment, c.id, c.toJson());
    }
    for (final h in s.habits) {
      add(SyncKinds.habit, h.id, h.toJson());
    }
    s.habitLogs.forEach((habitId, log) => add(SyncKinds.habitLog, habitId, Map<String, dynamic>.from(log)));
    for (final f in s.focusSessions) {
      add(SyncKinds.focus, f.id, f.toJson());
    }
    for (final e in s.sleep) {
      add(SyncKinds.sleep, e.id, e.toJson());
    }
    if (p != null) add(SyncKinds.profile, 'me', p.toJson());
    return m;
  }

  /// Runs one full sync for [userId]. Returns true when data on this
  /// device changed because of records from other devices.
  Future<bool> run({required String userId, DateTime? now}) async {
    if (store.getString(_kOwner) != userId) {
      // Another account (or none) owned this device's sync state: start fresh
      // so everything on the device is uploaded to this account.
      await reset();
      await store.setString(_kOwner, userId);
    }
    final stamp = (now ?? DateTime.now()).toUtc();
    final ledger = _loadLedger();
    final current = _collect(await local.load(), await profiles.load());

    // 1. Detect local changes.
    current.forEach((key, rec) {
      final h = fnv1a(canonicalJson(rec.data));
      final e = ledger[key];
      if (e == null || e.deleted || e.hash != h) {
        ledger[key] = _Entry(hash: h, updatedAt: stamp, dirty: true, deleted: false);
      }
    });
    for (final key in ledger.keys.toList()) {
      final e = ledger[key]!;
      if (!e.deleted && !current.containsKey(key)) {
        ledger[key] = _Entry(hash: '', updatedAt: stamp, dirty: true, deleted: true);
      }
    }

    // 2. Push.
    final dirty = ledger.entries.where((e) => e.value.dirty).toList();
    if (dirty.isNotEmpty) {
      await remote.push([
        for (final e in dirty)
          RemoteRecord(
            kind: e.key.substring(0, e.key.indexOf('/')),
            id: e.key.substring(e.key.indexOf('/') + 1),
            data: e.value.deleted ? null : current[e.key]?.data,
            updatedAt: e.value.updatedAt,
            deleted: e.value.deleted,
          ),
      ]);
      for (final e in dirty) {
        ledger[e.key] = _Entry(hash: e.value.hash, updatedAt: e.value.updatedAt, dirty: false, deleted: e.value.deleted);
      }
      await _saveLedger(ledger);
    }

    // 3. Pull.
    final lastRaw = store.getString(_kLastPull);
    var lastPull = lastRaw == null ? null : DateTime.tryParse(lastRaw)?.toUtc();
    final rows = await remote.pullSince(lastPull);
    final applied = <String, Map<String, dynamic>?>{};

    for (final r in rows) {
      final synced = r.syncedAt?.toUtc();
      if (synced != null && (lastPull == null || synced.isAfter(lastPull))) lastPull = synced;
      if (!SyncKinds.all.contains(r.kind)) continue;
      final key = '${r.kind}/${r.id}';
      final e = ledger[key];
      final remoteTime = r.updatedAt.toUtc();
      if (e != null && !e.updatedAt.isBefore(remoteTime)) continue; // ours is as new or newer

      if (r.deleted || r.data == null) {
        applied[key] = null;
        ledger[key] = _Entry(hash: '', updatedAt: remoteTime, dirty: false, deleted: true);
      } else {
        final data = normalize(r.kind, r.data!);
        if (data == null) continue;
        applied[key] = data;
        ledger[key] = _Entry(hash: fnv1a(canonicalJson(data)), updatedAt: remoteTime, dirty: false, deleted: false);
      }
    }

    if (applied.isNotEmpty) await _writeBack(applied);
    await _saveLedger(ledger);
    if (lastPull != null) await store.setString(_kLastPull, lastPull.toIso8601String());
    return applied.isNotEmpty;
  }

  /// Applies remote changes on top of a fresh read of local data, so edits
  /// made while syncing are not lost.
  Future<void> _writeBack(Map<String, Map<String, dynamic>?> applied) async {
    final profile = await profiles.load();
    final m = _collect(await local.load(), profile);
    applied.forEach((key, data) {
      if (data == null) {
        m.remove(key);
      } else {
        final i = key.indexOf('/');
        m[key] = _Rec(key.substring(0, i), key.substring(i + 1), data);
      }
    });

    Iterable<Map<String, dynamic>> of(String kind) => m.values.where((r) => r.kind == kind).map((r) => r.data);

    await local.saveTasks([for (final j in of(SyncKinds.task)) TaskItem.fromJson(j)]);
    await local.saveCommitments([for (final j in of(SyncKinds.commitment)) Commitment.fromJson(j)]);
    await local.saveHabits([for (final j in of(SyncKinds.habit)) Habit.fromJson(j)]);
    await local.saveFocusSessions([for (final j in of(SyncKinds.focus)) FocusSession.fromJson(j)]);
    await local.saveSleep([for (final j in of(SyncKinds.sleep)) SleepEntry.fromJson(j)]);
    await local.saveHabitLogs({
      for (final r in m.values.where((r) => r.kind == SyncKinds.habitLog))
        r.id: {
          for (final e in r.data.entries)
            if (e.value is num) e.key: (e.value as num).toInt(),
        },
    });

    final p = m['${SyncKinds.profile}/me'];
    if (p != null) {
      await profiles.save(UserProfile.fromJson(p.data));
    } else if (profile != null && applied.containsKey('${SyncKinds.profile}/me')) {
      await profiles.clear();
    }
  }
}
