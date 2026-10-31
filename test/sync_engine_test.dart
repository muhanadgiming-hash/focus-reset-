import 'package:flutter_test/flutter_test.dart';
import 'package:focus_reset/data/models/planning_models.dart';
import 'package:focus_reset/data/models/user_profile.dart';
import 'package:focus_reset/data/repositories/planner_repository.dart';
import 'package:focus_reset/data/repositories/profile_repository.dart';
import 'package:focus_reset/data/services/preferences_service.dart';
import 'package:focus_reset/data/sync/remote_store.dart';
import 'package:focus_reset/data/sync/sync_engine.dart';

/// In-memory stand-in for the `user_records` table. Like Postgres jsonb, it
/// does not preserve key order, so it reverses keys on the way in.
class FakeRemote implements RemoteStore {
  final Map<String, RemoteRecord> rows = {};
  int pushes = 0;
  int _clock = 0;

  static Object? _scramble(Object? v) {
    if (v is Map) return {for (final k in v.keys.toList().reversed) k.toString(): _scramble(v[k])};
    if (v is List) return v.map(_scramble).toList();
    return v;
  }

  @override
  Future<void> push(List<RemoteRecord> records) async {
    pushes += records.length;
    for (final r in records) {
      // Mirrors the database trigger: an older write never replaces a newer one.
      final existing = rows['${r.kind}/${r.id}'];
      if (existing != null && existing.updatedAt.isAfter(r.updatedAt)) continue;
      _clock++;
      rows['${r.kind}/${r.id}'] = RemoteRecord(
        kind: r.kind,
        id: r.id,
        data: r.data == null ? null : Map<String, dynamic>.from(_scramble(r.data) as Map),
        updatedAt: r.updatedAt,
        deleted: r.deleted,
        syncedAt: DateTime.utc(2030).add(Duration(seconds: _clock)),
      );
    }
  }

  @override
  Future<List<RemoteRecord>> pullSince(DateTime? since) async {
    final list = rows.values.where((r) => since == null || r.syncedAt!.isAfter(since)).toList()
      ..sort((a, b) => a.syncedAt!.compareTo(b.syncedAt!));
    return list;
  }
}

class Device {
  Device(RemoteStore remote) {
    final store = MemoryStore();
    planner = LocalPlannerRepository(store);
    profiles = LocalProfileRepository(store);
    engine = SyncEngine(local: planner, profiles: profiles, store: store, remote: remote);
  }

  late final LocalPlannerRepository planner;
  late final LocalProfileRepository profiles;
  late final SyncEngine engine;

  Future<List<TaskItem>> tasks() async => (await planner.load()).tasks;

  Future<bool> sync(DateTime at) => engine.run(userId: 'user-1', now: at);
}

TaskItem task(String id, String title) => TaskItem(
      id: id,
      title: title,
      durationMin: 30,
      createdAt: DateTime.utc(2024, 1, 1),
    );

final t1 = DateTime.utc(2024, 1, 1, 10);
final t2 = DateTime.utc(2024, 1, 1, 11);
final t3 = DateTime.utc(2024, 1, 1, 12);
final t4 = DateTime.utc(2024, 1, 1, 13);

void main() {
  late FakeRemote remote;
  late Device a;
  late Device b;

  setUp(() {
    remote = FakeRemote();
    a = Device(remote);
    b = Device(remote);
  });

  test('a new device receives data and profile from the account', () async {
    await a.planner.saveTasks([task('x', 'Read')]);
    await a.profiles.save(const UserProfile(
      name: 'Sara',
      ageRange: AgeRange.r25to34,
      lifestyle: Lifestyle.travelCrew,
      workPattern: WorkPattern.variable,
      bedtimeMin: 1380,
      wakeMin: 420,
    ));
    await a.sync(t1);

    expect(await b.sync(t2), isTrue);
    expect((await b.tasks()).single.title, 'Read');
    expect((await b.profiles.load())!.name, 'Sara');
  });

  test('edits and deletions travel between devices', () async {
    await a.planner.saveTasks([task('x', 'Read')]);
    await a.sync(t1);
    await b.sync(t1);

    await b.planner.saveTasks([task('x', 'Read 20 pages')]);
    await b.sync(t2);
    await a.sync(t2);
    expect((await a.tasks()).single.title, 'Read 20 pages');

    await a.planner.saveTasks([]);
    await a.sync(t3);
    await b.sync(t3);
    expect(await b.tasks(), isEmpty);
  });

  test('the most recent change wins a conflict', () async {
    await a.planner.saveTasks([task('x', 'v0')]);
    await a.sync(t1);
    await b.sync(t1);

    await a.planner.saveTasks([task('x', 'from A (older)')]);
    await b.planner.saveTasks([task('x', 'from B (newer)')]);
    await a.sync(t2);
    await b.sync(t3);
    await a.sync(t4);

    expect((await a.tasks()).single.title, 'from B (newer)');
    expect((await b.tasks()).single.title, 'from B (newer)');
  });

  test('syncing again without changes uploads nothing (no ping-pong)', () async {
    await a.planner.saveTasks([task('x', 'Read'), task('y', 'Walk')]);
    await a.planner.saveHabitLogs({
      'h1': {'2024-01-01': 3},
    });
    await a.sync(t1);
    await b.sync(t1);
    final before = remote.pushes;

    expect(await a.sync(t2), isFalse);
    expect(await b.sync(t3), isFalse);
    expect(await a.sync(t4), isFalse);
    expect(remote.pushes, before);
  });

  test('a device with reset sync state re-downloads the account', () async {
    await a.planner.saveTasks([task('x', 'Mine')]);
    await a.sync(t1);
    await a.engine.reset();
    await a.planner.saveTasks([]);

    expect(await a.sync(t2), isTrue);
    expect((await a.tasks()).single.title, 'Mine');
  });

  test('an older offline edit never overwrites a newer one', () async {
    await a.planner.saveTasks([task('x', 'v0')]);
    await a.sync(t1);
    await b.sync(t1);

    await b.planner.saveTasks([task('x', 'newer from B')]);
    await b.sync(t3);
    // A edited earlier (t2) but only syncs afterwards.
    await a.planner.saveTasks([task('x', 'older from A')]);
    await a.sync(t2);
    await b.sync(t4);

    expect((await a.tasks()).single.title, 'newer from B');
    expect((await b.tasks()).single.title, 'newer from B');
  });

  test('canonical JSON ignores key order', () {
    expect(canonicalJson({'b': 1, 'a': {'d': 2, 'c': 3}}), canonicalJson({'a': {'c': 3, 'd': 2}, 'b': 1}));
  });
}
