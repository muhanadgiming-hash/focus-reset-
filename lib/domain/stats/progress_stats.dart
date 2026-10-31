import '../../core/utils/date_key.dart';
import '../../data/models/planning_models.dart';
import '../../data/models/user_profile.dart';
import '../habits/habit_logic.dart';

class PeriodStats {
  const PeriodStats({
    required this.tasksDone,
    required this.tasksOpen,
    required this.focusSessions,
    required this.focusMinutes,
    required this.habitsDone,
    required this.habitsDue,
  });

  final int tasksDone;

  /// Tasks planned or due in the period that are not done yet.
  final int tasksOpen;
  final int focusSessions;
  final int focusMinutes;
  final int habitsDone;
  final int habitsDue;

  double? get taskRate => tasksDone + tasksOpen == 0 ? null : tasksDone / (tasksDone + tasksOpen);
  double? get habitRate => habitsDue == 0 ? null : habitsDone / habitsDue;
}

/// All report figures, computed only from the user's own records.
abstract final class ProgressStats {
  static PeriodStats forPeriod({
    required List<TaskItem> tasks,
    required List<FocusSession> sessions,
    required List<Habit> habits,
    required Map<String, Map<String, int>> habitLogs,
    required DateTime start,
    required DateTime end,
    required DateTime now,
  }) {
    var done = 0;
    var open = 0;
    for (final t in tasks) {
      if (t.isDone) {
        final c = t.completedAt;
        if (c != null && inRange(c, start, end)) done++;
      } else {
        final s = t.scheduledStart;
        final dl = t.deadline;
        if ((s != null && inRange(s, start, end)) || (s == null && dl != null && inRange(dl, start, end))) open++;
      }
    }

    var count = 0;
    var minutes = 0;
    for (final s in sessions) {
      if (!inRange(s.start, start, end)) continue;
      minutes += s.actualMin;
      if (s.completed) count++;
    }

    var hDone = 0;
    var hDue = 0;
    for (final h in habits) {
      final (d, due) = HabitLogic.doneAndDue(h, habitLogs[h.id], start, end, now);
      hDone += d;
      hDue += due;
    }

    return PeriodStats(
      tasksDone: done,
      tasksOpen: open,
      focusSessions: count,
      focusMinutes: minutes,
      habitsDone: hDone,
      habitsDue: hDue,
    );
  }

  /// Tasks completed on each of the 7 days starting at [weekStart].
  static List<double> tasksPerDay(List<TaskItem> tasks, DateTime weekStart) {
    final out = List<double>.filled(7, 0);
    for (final t in tasks) {
      final c = t.completedAt;
      if (!t.isDone || c == null) continue;
      final idx = dateOnly(c).difference(weekStart).inHours ~/ 24;
      if (idx >= 0 && idx < 7) out[idx] += 1;
    }
    return out;
  }

  /// Focus minutes on each of the 7 days starting at [weekStart].
  static List<double> focusPerDay(List<FocusSession> sessions, DateTime weekStart) {
    final out = List<double>.filled(7, 0);
    for (final s in sessions) {
      final idx = dateOnly(s.start).difference(weekStart).inHours ~/ 24;
      if (idx >= 0 && idx < 7) out[idx] += s.actualMin;
    }
    return out;
  }

  /// Productive minutes per part of day (morning, afternoon, evening, night)
  /// since [since]: focus time plus the length of tasks completed then.
  static List<double> byDayPart(List<TaskItem> tasks, List<FocusSession> sessions, DateTime since) {
    final out = List<double>.filled(DayPart.values.length, 0);
    for (final s in sessions) {
      if (s.start.isBefore(since)) continue;
      out[dayPartOfHour(s.start.hour).index] += s.actualMin;
    }
    for (final t in tasks) {
      final c = t.completedAt;
      if (!t.isDone || c == null || c.isBefore(since)) continue;
      out[dayPartOfHour(c.hour).index] += t.durationMin;
    }
    return out;
  }
}
