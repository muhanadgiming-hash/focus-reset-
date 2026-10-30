import '../../data/models/planning_models.dart';
import '../../data/models/user_profile.dart';

/// Contract for the Smart Life Scheduler (implemented in Phase 2).
///
/// The engine is deterministic, rule-based constraint scheduling — no AI,
/// no network calls. It never mutates state: it returns a [ScheduleProposal]
/// that the UI shows to the user, and nothing is applied until the user
/// approves it (rules 9 and 10).
///
/// Hard rules the implementation must satisfy (each covered by tests):
///  1. Never place two items in the same time.
///  2. Never move fixed commitments.
///  3. Never schedule into sleep / rest.
///  4. Keep breathing room — do not fill every free gap.
///  5. Important and urgent tasks first.
///  6. Respect preferred time-of-day; free time alone is not "suitable".
///  7. If no suitable slot exists, return the task as unscheduled.
///  8. When work hours change, only flexible tasks are recalculated.
abstract interface class SchedulingEngine {
  ScheduleProposal plan({
    required UserProfile profile,
    required List<Commitment> commitments,
    required List<TaskItem> tasks,
    required DateTime from,
    required DateTime to,
  });
}

class ScheduledTask {
  const ScheduledTask(this.task, this.start, this.end);
  final TaskItem task;
  final DateTime start;
  final DateTime end;
}

class ScheduleProposal {
  const ScheduleProposal({
    required this.placed,
    required this.unscheduled,
    required this.moved,
  });

  final List<ScheduledTask> placed;

  /// Tasks the engine could not place in a suitable slot (rule 7).
  final List<TaskItem> unscheduled;

  /// Previously scheduled flexible tasks that changed time — shown to the
  /// user as a diff before approval.
  final List<ScheduledTask> moved;
}
