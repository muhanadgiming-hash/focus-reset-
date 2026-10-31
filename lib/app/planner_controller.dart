import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/utils/date_key.dart';
import '../data/models/planning_models.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/planner_repository.dart';
import '../domain/scheduling/rule_based_scheduler.dart';
import '../domain/scheduling/scheduling_engine.dart';
import '../domain/tasks/recurrence.dart';

/// Owns all planning data (tasks, commitments, habits, focus, sleep) and
/// persists every change through [PlannerRepository].
class PlannerController extends ChangeNotifier {
  PlannerController({required PlannerRepository repository, SchedulingEngine engine = const RuleBasedScheduler()})
      : _repo = repository,
        _engine = engine;

  final PlannerRepository _repo;
  final SchedulingEngine _engine;

  final List<TaskItem> _tasks = [];
  final List<Commitment> _commitments = [];

  /// Read-only events from Apple Calendar. Kept in memory only: never
  /// stored, never synced, never edited.
  List<Commitment> _external = const [];
  final List<Habit> _habits = [];
  final HabitLogs _habitLogs = {};
  final List<FocusSession> _sessions = [];
  final List<SleepEntry> _sleep = [];

  /// Why a task could not be placed in the most recent plan.
  final Map<String, UnscheduledReason> _unscheduledReasons = {};

  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  List<Commitment> get commitments => List.unmodifiable(_commitments);

  /// The user's own commitments plus calendar events — what the scheduler
  /// and the timelines plan around.
  List<Commitment> get allCommitments => List.unmodifiable([..._commitments, ..._external]);

  bool isExternal(String? id) => id != null && id.startsWith('cal:');

  void setExternalCommitments(List<Commitment> items) {
    _external = List.unmodifiable(items);
    notifyListeners();
  }
  List<Habit> get habits => List.unmodifiable(_habits);
  HabitLogs get habitLogs => _habitLogs;
  List<FocusSession> get focusSessions => List.unmodifiable(_sessions);
  List<SleepEntry> get sleepEntries => List.unmodifiable(_sleep);
  Map<String, UnscheduledReason> get unscheduledReasons => Map.unmodifiable(_unscheduledReasons);

  static final _rand = math.Random();
  static int _seq = 0;

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_seq++).toRadixString(36)}${_rand.nextInt(1 << 20).toRadixString(36)}';

  Future<void> load() async {
    final s = await _repo.load();
    _tasks
      ..clear()
      ..addAll(s.tasks);
    _commitments
      ..clear()
      ..addAll(s.commitments);
    _habits
      ..clear()
      ..addAll(s.habits);
    _habitLogs
      ..clear()
      ..addAll(s.habitLogs);
    _sessions
      ..clear()
      ..addAll(s.focusSessions);
    _sleep
      ..clear()
      ..addAll(s.sleep);
    notifyListeners();
  }

  // ------------------------------------------------------------------ tasks

  TaskItem? taskById(String? id) {
    if (id == null) return null;
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _put(TaskItem t) {
    final i = _tasks.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      _tasks[i] = t;
    } else {
      _tasks.add(t);
    }
  }

  Future<void> _commitTasks() async {
    notifyListeners();
    await _repo.saveTasks(_tasks);
  }

  Future<void> saveTask(TaskItem t) async {
    _put(t);
    _unscheduledReasons.remove(t.id);
    await _commitTasks();
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    _unscheduledReasons.remove(id);
    await _commitTasks();
  }

  /// Marks a task done (creating the next occurrence for repeating tasks),
  /// or reopens a completed task.
  Future<void> toggleTaskDone(String id, UserProfile? profile) async {
    final t = taskById(id);
    if (t == null) return;
    if (t.isDone) {
      _put(t.copyWith(
        status: t.scheduledStart != null ? TaskStatus.scheduled : TaskStatus.pending,
        completedAt: null,
      ));
    } else {
      final now = DateTime.now();
      _put(t.copyWith(status: TaskStatus.done, completedAt: now));
      _unscheduledReasons.remove(id);
      final next = Recurrence.next(t, completedAt: now, workDays: effectiveWorkDays(profile), newId: newId());
      if (next != null) _tasks.add(next);
    }
    await _commitTasks();
  }

  /// Moves a task to tomorrow or later. Flexible tasks lose their slot and
  /// wait for the next plan; fixed tasks keep their time on the next day.
  Future<void> postponeTask(String id) async {
    final t = taskById(id);
    if (t == null || t.isDone) return;
    final tomorrow = addDays(dateOnly(DateTime.now()), 1);
    final dl = t.deadline;
    final s = t.scheduledStart;
    if (t.isFlexible) {
      _put(t.copyWith(
        notBefore: tomorrow,
        scheduledStart: null,
        status: TaskStatus.pending,
        deadline: (dl != null && dl.isBefore(tomorrow)) ? tomorrow : dl,
      ));
    } else {
      final next = s == null
          ? null
          : (s.isBefore(tomorrow) ? DateTime(tomorrow.year, tomorrow.month, tomorrow.day, s.hour, s.minute) : addDays(s, 1));
      _put(t.copyWith(scheduledStart: next, deadline: (dl != null && dl.isBefore(tomorrow)) ? tomorrow : dl));
    }
    await _commitTasks();
  }

  /// Clears a flexible task's time so the next plan places it again.
  Future<void> unscheduleTask(String id) async {
    final t = taskById(id);
    if (t == null || !t.isFlexible) return;
    _put(t.copyWith(scheduledStart: null, status: TaskStatus.pending));
    await _commitTasks();
  }

  // -------------------------------------------------------------- scheduling

  /// Builds a proposal for the next 7 days. Nothing changes until
  /// [applyProposal] is called after the user approves.
  ScheduleProposal proposeSchedule(UserProfile profile, {bool reshuffle = false, DateTime? now}) {
    final n = now ?? DateTime.now();
    return _engine.plan(
      profile: profile,
      commitments: [..._commitments, ..._external],
      tasks: _tasks,
      from: n,
      to: DateTime(n.year, n.month, n.day + 8),
      keepValid: !reshuffle,
    );
  }

  Future<void> applyProposal(ScheduleProposal p) async {
    for (final s in p.placed) {
      final current = taskById(s.task.id);
      if (current == null || current.isDone) continue;
      _put(current.copyWith(scheduledStart: s.start, status: TaskStatus.scheduled));
      _unscheduledReasons.remove(current.id);
    }
    for (final u in p.unscheduled) {
      final current = taskById(u.task.id);
      if (current == null || current.isDone) continue;
      if (current.isFlexible) {
        _put(current.copyWith(scheduledStart: null, status: TaskStatus.pending));
      }
      _unscheduledReasons[current.id] = u.reason;
    }
    await _commitTasks();
  }

  // ------------------------------------------------------------ commitments

  Commitment? commitmentById(String? id) {
    for (final c in _commitments) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> saveCommitment(Commitment c) async {
    final i = _commitments.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      _commitments[i] = c;
    } else {
      _commitments.add(c);
    }
    _commitments.sort((a, b) => a.start.compareTo(b.start));
    notifyListeners();
    await _repo.saveCommitments(_commitments);
  }

  Future<void> deleteCommitment(String id) async {
    _commitments.removeWhere((c) => c.id == id);
    notifyListeners();
    await _repo.saveCommitments(_commitments);
  }

  // ------------------------------------------------------------------ habits

  Habit? habitById(String? id) {
    for (final h in _habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  Future<void> saveHabit(Habit h) async {
    final i = _habits.indexWhere((x) => x.id == h.id);
    if (i >= 0) {
      _habits[i] = h;
    } else {
      _habits.add(h);
    }
    notifyListeners();
    await _repo.saveHabits(_habits);
  }

  Future<void> deleteHabit(String id) async {
    _habits.removeWhere((h) => h.id == id);
    _habitLogs.remove(id);
    notifyListeners();
    await _repo.saveHabits(_habits);
    await _repo.saveHabitLogs(_habitLogs);
  }

  Map<String, int>? habitLog(String habitId) => _habitLogs[habitId];

  Future<void> setHabitAmount(String habitId, DateTime day, int amount) async {
    final log = _habitLogs.putIfAbsent(habitId, () => <String, int>{});
    if (amount <= 0) {
      log.remove(dateKey(day));
    } else {
      log[dateKey(day)] = amount;
    }
    notifyListeners();
    await _repo.saveHabitLogs(_habitLogs);
  }

  // ------------------------------------------------------------------- focus

  Future<void> addFocusSession(FocusSession s) async {
    _sessions.add(s);
    _sessions.sort((a, b) => b.start.compareTo(a.start));
    notifyListeners();
    await _repo.saveFocusSessions(_sessions);
  }

  // ------------------------------------------------------------------- sleep

  /// One entry per morning: logging the same date again replaces it.
  Future<void> saveSleep(SleepEntry e) async {
    _sleep.removeWhere((x) => x.id == e.id || sameDay(x.date, e.date));
    _sleep.add(e);
    _sleep.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await _repo.saveSleep(_sleep);
  }

  Future<void> deleteSleep(String id) async {
    _sleep.removeWhere((x) => x.id == id);
    notifyListeners();
    await _repo.saveSleep(_sleep);
  }

  // -------------------------------------------------------------------- all

  Future<void> clearAll() async {
    _tasks.clear();
    _commitments.clear();
    _habits.clear();
    _habitLogs.clear();
    _sessions.clear();
    _sleep.clear();
    _unscheduledReasons.clear();
    notifyListeners();
    await _repo.clear();
  }
}

class PlannerScope extends InheritedNotifier<PlannerController> {
  const PlannerScope({super.key, required PlannerController controller, required super.child})
      : super(notifier: controller);

  static PlannerController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlannerScope>()!.notifier!;

  static PlannerController read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<PlannerScope>()!.widget as PlannerScope).notifier!;
}
