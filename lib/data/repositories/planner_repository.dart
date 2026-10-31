import 'dart:convert';

import '../models/planning_models.dart';
import '../services/preferences_service.dart';

/// habitId → (yyyy-mm-dd → amount done that day)
typedef HabitLogs = Map<String, Map<String, int>>;

class PlannerSnapshot {
  const PlannerSnapshot({
    this.tasks = const [],
    this.commitments = const [],
    this.habits = const [],
    this.habitLogs = const {},
    this.focusSessions = const [],
    this.sleep = const [],
  });

  final List<TaskItem> tasks;
  final List<Commitment> commitments;
  final List<Habit> habits;
  final HabitLogs habitLogs;
  final List<FocusSession> focusSessions;
  final List<SleepEntry> sleep;
}

/// Storage contract for planning data. Phase 3 adds a Supabase-backed
/// implementation; the controller and UI stay unchanged.
abstract interface class PlannerRepository {
  Future<PlannerSnapshot> load();
  Future<void> saveTasks(List<TaskItem> items);
  Future<void> saveCommitments(List<Commitment> items);
  Future<void> saveHabits(List<Habit> items);
  Future<void> saveHabitLogs(HabitLogs logs);
  Future<void> saveFocusSessions(List<FocusSession> items);
  Future<void> saveSleep(List<SleepEntry> items);
  Future<void> clear();
}

class LocalPlannerRepository implements PlannerRepository {
  LocalPlannerRepository(this._prefs);

  final PreferencesService _prefs;

  static const _kTasks = 'planner.tasks.v1';
  static const _kCommitments = 'planner.commitments.v1';
  static const _kHabits = 'planner.habits.v1';
  static const _kHabitLogs = 'planner.habitLogs.v1';
  static const _kFocus = 'planner.focus.v1';
  static const _kSleep = 'planner.sleep.v1';

  List<T> _list<T>(String key, T Function(Map<String, dynamic>) parse) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <T>[];
      final out = <T>[];
      for (final e in decoded) {
        if (e is Map<String, dynamic>) {
          try {
            out.add(parse(e));
          } catch (_) {
            // Skip a single corrupt entry instead of losing everything.
          }
        }
      }
      return out;
    } catch (_) {
      return <T>[];
    }
  }

  HabitLogs _logs() {
    final raw = _prefs.getString(_kHabitLogs);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, Map<String, int>>{};
      decoded.forEach((habitId, days) {
        if (habitId is String && days is Map) {
          final m = <String, int>{};
          days.forEach((k, v) {
            if (k is String && v is num) m[k] = v.toInt();
          });
          out[habitId] = m;
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(String key, Object value) => _prefs.setString(key, jsonEncode(value));

  @override
  Future<PlannerSnapshot> load() async => PlannerSnapshot(
        tasks: _list(_kTasks, TaskItem.fromJson),
        commitments: _list(_kCommitments, Commitment.fromJson),
        habits: _list(_kHabits, Habit.fromJson),
        habitLogs: _logs(),
        focusSessions: _list(_kFocus, FocusSession.fromJson),
        sleep: _list(_kSleep, SleepEntry.fromJson),
      );

  @override
  Future<void> saveTasks(List<TaskItem> items) => _save(_kTasks, [for (final e in items) e.toJson()]);

  @override
  Future<void> saveCommitments(List<Commitment> items) => _save(_kCommitments, [for (final e in items) e.toJson()]);

  @override
  Future<void> saveHabits(List<Habit> items) => _save(_kHabits, [for (final e in items) e.toJson()]);

  @override
  Future<void> saveHabitLogs(HabitLogs logs) => _save(_kHabitLogs, logs);

  @override
  Future<void> saveFocusSessions(List<FocusSession> items) => _save(_kFocus, [for (final e in items) e.toJson()]);

  @override
  Future<void> saveSleep(List<SleepEntry> items) => _save(_kSleep, [for (final e in items) e.toJson()]);

  @override
  Future<void> clear() async {
    for (final k in const [_kTasks, _kCommitments, _kHabits, _kHabitLogs, _kFocus, _kSleep]) {
      await _prefs.remove(k);
    }
  }
}
