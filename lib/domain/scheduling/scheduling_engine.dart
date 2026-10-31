import '../../data/models/planning_models.dart';
import '../../data/models/user_profile.dart';

/// Contract for the Smart Life Scheduler.
///
/// The engine is deterministic, rule-based constraint scheduling — no AI,
/// no network. It never mutates state: it returns a [ScheduleProposal] that
/// the UI shows to the user, and nothing is applied until the user approves
/// it (rules 9 and 10).
///
/// Rules (each covered by `test/scheduler_test.dart`):
///  1. Never place two items at the same time.
///  2. Never move fixed commitments or fixed tasks.
///  3. Never schedule into sleep / rest (incl. wind-down and wake-up buffers).
///  4. Keep breathing room: buffers between items and a daily load cap.
///  5. Important and urgent tasks are placed first.
///  6. Prefer the user's best time of day; free time alone is not enough.
///  7. If no suitable slot exists, the task is returned as unscheduled.
///  8. Re-planning keeps still-valid times; only conflicting flexible
///     tasks move.
abstract interface class SchedulingEngine {
  ScheduleProposal plan({
    required UserProfile profile,
    required List<Commitment> commitments,
    required List<TaskItem> tasks,
    required DateTime from,
    required DateTime to,
    bool keepValid = true,
  });
}

class ScheduledTask {
  const ScheduledTask(this.task, this.start, this.end, {this.previousStart});

  final TaskItem task;
  final DateTime start;
  final DateTime end;
  final DateTime? previousStart;

  bool get isNew => previousStart == null;
  bool get isMoved => previousStart != null && !previousStart!.isAtSameMomentAs(start);
}

enum UnscheduledReason {
  /// No suitable slot before the task's deadline.
  noTimeBeforeDeadline,

  /// No suitable slot in the planning window.
  noSuitableTime,

  /// Longer than the free time of any single day.
  tooLong,
}

class UnscheduledTask {
  const UnscheduledTask(this.task, this.reason);

  final TaskItem task;
  final UnscheduledReason reason;

  /// It had a time before this plan, so the user loses that slot.
  bool get wasScheduled => task.scheduledStart != null;
}

class ScheduleProposal {
  const ScheduleProposal({required this.placed, required this.unscheduled});

  final List<ScheduledTask> placed;
  final List<UnscheduledTask> unscheduled;

  Iterable<ScheduledTask> get added => placed.where((p) => p.isNew);
  Iterable<ScheduledTask> get moved => placed.where((p) => p.isMoved);
  Iterable<UnscheduledTask> get removed => unscheduled.where((u) => u.wasScheduled);

  /// True when applying the proposal would change any task's time.
  bool get hasChanges => added.isNotEmpty || moved.isNotEmpty || removed.isNotEmpty;
}
