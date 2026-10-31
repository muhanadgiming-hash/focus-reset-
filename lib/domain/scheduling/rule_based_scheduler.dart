import '../../core/utils/date_key.dart';
import '../../data/models/planning_models.dart';
import '../../data/models/user_profile.dart';
import 'fixed_blocks.dart';
import 'scheduling_engine.dart';

/// Half-open time range [start, end).
class Span {
  const Span(this.start, this.end);

  final DateTime start;
  final DateTime end;

  int get minutes => end.difference(start).inMinutes;

  bool overlaps(Span o) => start.isBefore(o.end) && o.start.isBefore(end);

  bool contains(Span o) => !o.start.isBefore(start) && !o.end.isAfter(end);

  @override
  String toString() => 'Span($start → $end)';
}

/// Sorts and unions overlapping or touching spans.
List<Span> mergeSpans(Iterable<Span> spans) {
  final sorted = spans.where((s) => s.end.isAfter(s.start)).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final out = <Span>[];
  for (final s in sorted) {
    if (out.isNotEmpty && !s.start.isAfter(out.last.end)) {
      final last = out.removeLast();
      out.add(Span(last.start, s.end.isAfter(last.end) ? s.end : last.end));
    } else {
      out.add(s);
    }
  }
  return out;
}

/// Free spans inside [window] not covered by [busy] (must be merged).
List<Span> freeWithin(Span window, List<Span> busy) {
  final out = <Span>[];
  var cursor = window.start;
  for (final b in busy) {
    if (!b.end.isAfter(cursor)) continue;
    if (!b.start.isBefore(window.end)) break;
    if (b.start.isAfter(cursor)) out.add(Span(cursor, b.start));
    if (b.end.isAfter(cursor)) cursor = b.end;
  }
  if (cursor.isBefore(window.end)) out.add(Span(cursor, window.end));
  return out;
}

/// Removes [cut] from every span in [free].
List<Span> carve(List<Span> free, Span cut) {
  final out = <Span>[];
  for (final f in free) {
    if (!f.overlaps(cut)) {
      out.add(f);
      continue;
    }
    if (f.start.isBefore(cut.start)) out.add(Span(f.start, cut.start));
    if (cut.end.isBefore(f.end)) out.add(Span(cut.end, f.end));
  }
  return out;
}

class SchedulerSettings {
  const SchedulerSettings({
    this.stepMin = 15,
    this.windDownMin = 30,
    this.wakeUpMin = 30,
    this.maxDailyLoad = 0.7,
    this.preferencePenaltyHours = 4,
  });

  /// Candidate start times are aligned to this grid.
  final int stepMin;

  /// Kept free before bedtime (rule 3).
  final int windDownMin;

  /// Kept free after waking (rule 3).
  final int wakeUpMin;

  /// At most this share of a day's free time is filled with tasks (rule 4).
  final double maxDailyLoad;

  /// How many hours later a medium-priority task may land to reach the
  /// user's preferred time of day (rule 6).
  final double preferencePenaltyHours;
}

class RuleBasedScheduler implements SchedulingEngine {
  const RuleBasedScheduler({this.settings = const SchedulerSettings()});

  final SchedulerSettings settings;

  static DateTime _at(DateTime day, int minutes) => DateTime(day.year, day.month, day.day, 0, minutes);

  DateTime _ceil(DateTime t) {
    final step = settings.stepMin;
    final base = DateTime(t.year, t.month, t.day, t.hour, t.minute);
    final adjusted = (t.second > 0 || t.millisecond > 0 || t.microsecond > 0) ? base.add(const Duration(minutes: 1)) : base;
    final rem = adjusted.minute % step;
    return rem == 0 ? adjusted : adjusted.add(Duration(minutes: step - rem));
  }

  /// Everything the scheduler must never place a task over.
  List<Span> protectedSpans({
    required UserProfile profile,
    required List<Commitment> commitments,
    required List<TaskItem> tasks,
    required DateTime from,
    required DateTime to,
  }) {
    final out = <Span>[];
    final last = dateOnly(to);
    for (var d = addDays(dateOnly(from), -1); !d.isAfter(last); d = addDays(d, 1)) {
      // Sleep, widened by wind-down and wake-up buffers.
      final bed = _at(d, profile.bedtimeMin);
      final wake = bed.add(Duration(minutes: profile.sleepDurationMin));
      out.add(Span(
        bed.subtract(Duration(minutes: settings.windDownMin)),
        wake.add(Duration(minutes: settings.wakeUpMin)),
      ));
      // Fixed working hours and their commute buffers.
      for (final b in FixedBlocks.forDay(profile, d)) {
        if (b.kind == BlockKind.sleep) continue;
        out.add(Span(_at(d, b.startMin), _at(d, b.endMin)));
      }
    }
    for (final c in commitments) {
      out.add(Span(c.busyStart, c.busyEnd));
    }
    for (final t in tasks) {
      final s = t.scheduledStart;
      if (!t.isFlexible && !t.isDone && s != null) out.add(Span(s, t.scheduledEnd!));
    }
    return out;
  }

  static int compareTasks(TaskItem a, TaskItem b) {
    final p = b.priority.index.compareTo(a.priority.index);
    if (p != 0) return p;
    final da = a.deadline;
    final db = b.deadline;
    if (da != null || db != null) {
      if (da == null) return 1;
      if (db == null) return -1;
      final c = da.compareTo(db);
      if (c != 0) return c;
    }
    final d = b.durationMin.compareTo(a.durationMin);
    if (d != 0) return d;
    final c = a.createdAt.compareTo(b.createdAt);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  }

  @override
  ScheduleProposal plan({
    required UserProfile profile,
    required List<Commitment> commitments,
    required List<TaskItem> tasks,
    required DateTime from,
    required DateTime to,
    bool keepValid = true,
  }) {
    final start0 = _ceil(from);
    if (!to.isAfter(start0)) return const ScheduleProposal(placed: [], unscheduled: []);

    final gapMin = profile.breakMin.clamp(5, 30).toInt();
    final gap = Duration(minutes: gapMin);
    final step = Duration(minutes: settings.stepMin);

    // Rule 1–4: protected time, widened by the breathing gap.
    final busy = mergeSpans([
      for (final s in protectedSpans(profile: profile, commitments: commitments, tasks: tasks, from: start0, to: to))
        Span(s.start.subtract(gap), s.end.add(gap)),
    ]);
    var free = freeWithin(Span(start0, to), busy);

    // Rule 4: daily load cap based on each day's free time.
    final caps = <String, int>{};
    for (final f in free) {
      var s = f.start;
      while (s.isBefore(f.end)) {
        final next = DateTime(s.year, s.month, s.day + 1);
        final e = next.isBefore(f.end) ? next : f.end;
        final k = dateKey(s);
        caps[k] = (caps[k] ?? 0) + e.difference(s).inMinutes;
        s = e;
      }
    }
    caps.updateAll((_, v) => (v * settings.maxDailyLoad).floor());
    final maxCap = caps.values.fold<int>(0, (a, b) => a > b ? a : b);
    final used = <String, int>{};

    // Rule 5: most important first.
    final flexible = tasks.where((t) => !t.isDone && t.isFlexible).toList()..sort(compareTasks);

    final placed = <ScheduledTask>[];
    final unscheduled = <UnscheduledTask>[];
    final handled = <String>{};

    DateTime earliestFor(TaskItem t) {
      final nb = t.notBefore;
      return (nb != null && nb.isAfter(start0)) ? _ceil(nb) : start0;
    }

    DateTime latestFor(TaskItem t) {
      final dl = t.deadline;
      if (dl == null) return to;
      final end = DateTime(dl.year, dl.month, dl.day + 1);
      // A missed deadline no longer limits the window — do it as soon as possible.
      if (!end.isAfter(start0)) return to;
      return end.isBefore(to) ? end : to;
    }

    bool overdue(TaskItem t) {
      final dl = t.deadline;
      return dl != null && !DateTime(dl.year, dl.month, dl.day + 1).isAfter(start0);
    }

    void reserve(TaskItem t, DateTime s) {
      final e = s.add(Duration(minutes: t.durationMin));
      placed.add(ScheduledTask(t, s, e, previousStart: t.scheduledStart));
      free = carve(free, Span(s.subtract(gap), e.add(gap)));
      final k = dateKey(s);
      used[k] = (used[k] ?? 0) + t.durationMin;
      handled.add(t.id);
    }

    bool fitsCap(DateTime s, int minutes) {
      final k = dateKey(s);
      return (used[k] ?? 0) + minutes <= (caps[k] ?? 0);
    }

    // Rule 8: keep every existing time that is still valid.
    if (keepValid) {
      for (final t in flexible) {
        final s = t.scheduledStart;
        if (s == null || s.isBefore(start0) || s.isBefore(earliestFor(t))) continue;
        final span = Span(s, s.add(Duration(minutes: t.durationMin)));
        if (span.end.isAfter(latestFor(t))) continue;
        if (!free.any((f) => f.contains(span))) continue;
        if (!fitsCap(s, t.durationMin)) continue;
        reserve(t, s);
      }
    }

    final weights = <TaskPriority, double>{
      TaskPriority.low: 0.5,
      TaskPriority.medium: 1,
      TaskPriority.high: 2,
      TaskPriority.urgent: 4,
    };

    for (final t in flexible) {
      if (handled.contains(t.id)) continue;
      final dur = Duration(minutes: t.durationMin);
      final earliest = earliestFor(t);
      final latest = latestFor(t);
      final weight = overdue(t) ? 6.0 : weights[t.priority]!;

      DateTime? bestStart;
      var bestCost = double.infinity;
      for (final f in free) {
        if (!f.end.isAfter(earliest)) continue;
        var s = _ceil(f.start.isBefore(earliest) ? earliest : f.start);
        while (true) {
          final e = s.add(dur);
          if (e.isAfter(f.end) || e.isAfter(latest)) break;
          if (fitsCap(s, t.durationMin)) {
            final hours = s.difference(earliest).inMinutes / 60;
            final preferred = dayPartOfHour(s.hour) == profile.preferredFocusTime;
            final cost = hours * weight + (preferred ? 0 : settings.preferencePenaltyHours);
            if (cost < bestCost) {
              bestCost = cost;
              bestStart = s;
            }
          }
          s = s.add(step);
        }
      }

      if (bestStart != null) {
        reserve(t, bestStart);
      } else {
        final reason = t.durationMin > maxCap
            ? UnscheduledReason.tooLong
            : (latest.isBefore(to) ? UnscheduledReason.noTimeBeforeDeadline : UnscheduledReason.noSuitableTime);
        unscheduled.add(UnscheduledTask(t, reason));
      }
    }

    placed.sort((a, b) => a.start.compareTo(b.start));
    return ScheduleProposal(placed: placed, unscheduled: unscheduled);
  }
}
