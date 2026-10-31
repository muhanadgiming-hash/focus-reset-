import '../../core/utils/date_key.dart';
import '../../data/models/planning_models.dart';

/// Pure habit rules: what is due, what counts as done, and streaks.
abstract final class HabitLogic {
  static bool isScheduledOn(Habit h, DateTime day) => switch (h.frequency) {
        HabitFrequency.daily => true,
        HabitFrequency.specificDays => h.days.contains(day.weekday),
        HabitFrequency.timesPerWeek => true,
      };

  static int amountOn(Map<String, int>? log, DateTime day) => log?[dateKey(day)] ?? 0;

  static bool doneOn(Habit h, Map<String, int>? log, DateTime day) => amountOn(log, day) >= h.targetAmount;

  static int doneDaysBetween(Habit h, Map<String, int>? log, DateTime start, DateTime endExclusive) {
    var n = 0;
    for (var d = dateOnly(start); d.isBefore(endExclusive); d = addDays(d, 1)) {
      if (doneOn(h, log, d)) n++;
    }
    return n;
  }

  /// (done, due) for the days in [start, endExclusive) — never counting days
  /// before the habit existed or after [today].
  static (int, int) doneAndDue(
    Habit h,
    Map<String, int>? log,
    DateTime start,
    DateTime endExclusive,
    DateTime today,
  ) {
    final created = dateOnly(h.createdAt);
    final from = start.isBefore(created) ? created : dateOnly(start);
    final tomorrow = addDays(dateOnly(today), 1);
    final to = endExclusive.isBefore(tomorrow) ? endExclusive : tomorrow;
    if (!from.isBefore(to)) return (0, 0);

    if (h.frequency == HabitFrequency.timesPerWeek) {
      final days = to.difference(from).inHours ~/ 24;
      final weeks = (days / 7).ceil().clamp(1, 1000).toInt();
      final due = h.timesPerWeek * weeks;
      final done = doneDaysBetween(h, log, from, to);
      return (done > due ? due : done, due);
    }

    var due = 0;
    var done = 0;
    for (var d = from; d.isBefore(to); d = addDays(d, 1)) {
      if (!isScheduledOn(h, d)) continue;
      due++;
      if (doneOn(h, log, d)) done++;
    }
    return (done, due);
  }

  /// Current streak: consecutive scheduled days completed (or, for
  /// "X per week" habits, consecutive weeks that reached the target).
  /// Today only breaks the streak once it is over.
  static int streak(Habit h, Map<String, int>? log, DateTime today, int firstWeekday) {
    final created = dateOnly(h.createdAt);
    if (h.frequency == HabitFrequency.timesPerWeek) {
      var week = startOfWeekDate(today, firstWeekday);
      var count = 0;
      if (doneDaysBetween(h, log, week, addDays(week, 7)) >= h.timesPerWeek) count++;
      for (var i = 0; i < 520; i++) {
        week = addDays(week, -7);
        if (!addDays(week, 7).isAfter(created)) break;
        if (doneDaysBetween(h, log, week, addDays(week, 7)) >= h.timesPerWeek) {
          count++;
        } else {
          break;
        }
      }
      return count;
    }

    var d = dateOnly(today);
    if (!doneOn(h, log, d)) d = addDays(d, -1);
    var count = 0;
    for (var i = 0; i < 3660 && !d.isBefore(created); i++) {
      if (isScheduledOn(h, d)) {
        if (!doneOn(h, log, d)) break;
        count++;
      }
      d = addDays(d, -1);
    }
    return count;
  }

  /// Suggested "+" step for a target (8 glasses → 1, 20 pages → 5, 6000 steps → 500).
  static int stepFor(int target) {
    if (target >= 2000) return 500;
    if (target >= 200) return 50;
    if (target >= 20) return 5;
    return 1;
  }
}
