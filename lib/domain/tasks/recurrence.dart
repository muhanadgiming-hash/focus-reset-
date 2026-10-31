import '../../core/utils/date_key.dart';
import '../../data/models/planning_models.dart';

/// Creates the next occurrence of a repeating task once it is completed.
abstract final class Recurrence {
  /// The next calendar day after [day] for [rule].
  static DateTime nextDay(DateTime day, RepeatRule rule, Set<int> workDays) {
    final d = dateOnly(day);
    switch (rule) {
      case RepeatRule.none:
        return d;
      case RepeatRule.daily:
        return addDays(d, 1);
      case RepeatRule.weekly:
        return addDays(d, 7);
      case RepeatRule.monthly:
        final lastDay = DateTime(d.year, d.month + 2, 0).day;
        return DateTime(d.year, d.month + 1, d.day > lastDay ? lastDay : d.day);
      case RepeatRule.weekdays:
        var n = addDays(d, 1);
        for (var i = 0; i < 7 && workDays.isNotEmpty && !workDays.contains(n.weekday); i++) {
          n = addDays(n, 1);
        }
        return n;
    }
  }

  static TaskItem? next(
    TaskItem t, {
    required DateTime completedAt,
    required Set<int> workDays,
    required String newId,
  }) {
    if (t.repeat == RepeatRule.none) return null;
    final base = dateOnly(t.scheduledStart ?? completedAt);
    final next = nextDay(base, t.repeat, workDays);
    final shiftDays = (next.difference(base).inHours / 24).round();
    final s = t.scheduledStart;

    return TaskItem(
      id: newId,
      title: t.title,
      durationMin: t.durationMin,
      priority: t.priority,
      deadline: t.deadline == null ? null : addDays(t.deadline!, shiftDays),
      repeat: t.repeat,
      linkedGoal: t.linkedGoal,
      linkedHabitId: t.linkedHabitId,
      isFlexible: t.isFlexible,
      status: (!t.isFlexible && s != null) ? TaskStatus.scheduled : TaskStatus.pending,
      notes: t.notes,
      scheduledStart: (!t.isFlexible && s != null) ? DateTime(next.year, next.month, next.day, s.hour, s.minute) : null,
      notBefore: t.isFlexible ? next : null,
      createdAt: completedAt,
    );
  }
}
