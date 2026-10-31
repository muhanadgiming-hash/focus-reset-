import 'package:flutter_test/flutter_test.dart';
import 'package:focus_reset/data/models/planning_models.dart';
import 'package:focus_reset/data/models/user_profile.dart';
import 'package:focus_reset/domain/scheduling/rule_based_scheduler.dart';
import 'package:focus_reset/domain/scheduling/scheduling_engine.dart';

// 2024-01-01 is a Monday.
DateTime mon(int h, [int m = 0]) => DateTime(2024, 1, 1, h, m);
DateTime tue(int h, [int m = 0]) => DateTime(2024, 1, 2, h, m);

UserProfile profile({DayPart preferred = DayPart.morning}) => UserProfile(
      name: 'T',
      ageRange: AgeRange.r25to34,
      lifestyle: Lifestyle.travelCrew,
      workPattern: WorkPattern.variable,
      bedtimeMin: 23 * 60,
      wakeMin: 7 * 60,
      breakMin: 5,
      preferredFocusTime: preferred,
    );

var _n = 0;
TaskItem task({
  int minutes = 60,
  TaskPriority priority = TaskPriority.medium,
  DateTime? deadline,
  DateTime? scheduledStart,
  DateTime? notBefore,
  bool flexible = true,
  TaskStatus status = TaskStatus.pending,
}) =>
    TaskItem(
      id: 't${_n++}',
      title: 'task',
      durationMin: minutes,
      priority: priority,
      deadline: deadline,
      scheduledStart: scheduledStart,
      notBefore: notBefore,
      isFlexible: flexible,
      status: status,
      createdAt: DateTime(2023, 12, 1),
    );

Commitment commitment(DateTime start, DateTime end, {int prep = 0, int travel = 0, int rest = 0}) => Commitment(
      id: 'c${_n++}',
      type: CommitmentType.flight,
      title: 'Flight',
      start: start,
      end: end,
      prepMin: prep,
      travelMin: travel,
      restAfterMin: rest,
    );

const engine = RuleBasedScheduler();

ScheduleProposal run(
  List<TaskItem> tasks, {
  List<Commitment> commitments = const [],
  DateTime? from,
  UserProfile? p,
  bool keepValid = true,
}) {
  final f = from ?? mon(8);
  return engine.plan(
    profile: p ?? profile(),
    commitments: commitments,
    tasks: tasks,
    from: f,
    to: DateTime(f.year, f.month, f.day + 8),
    keepValid: keepValid,
  );
}

bool overlaps(DateTime aS, DateTime aE, DateTime bS, DateTime bE) => aS.isBefore(bE) && bS.isBefore(aE);

/// Sleep is 23:00–07:00 with 30 min wind-down / wake-up buffers.
bool inSleep(DateTime s, DateTime e) {
  for (var d = 0; d < 10; d++) {
    final bed = DateTime(2023, 12, 31 + d, 22, 30);
    final wake = DateTime(2024, 1, 1 + d, 7, 30);
    if (overlaps(s, e, bed, wake)) return true;
  }
  return false;
}

void main() {
  group('Rule 1 · no two items at the same time', () {
    test('placed tasks never overlap and keep a breathing gap', () {
      final p = run([for (var i = 0; i < 12; i++) task(minutes: 45)]);
      expect(p.placed.length, 12);
      for (var i = 0; i < p.placed.length; i++) {
        for (var j = i + 1; j < p.placed.length; j++) {
          final a = p.placed[i];
          final b = p.placed[j];
          expect(overlaps(a.start, a.end, b.start, b.end), isFalse);
        }
        if (i > 0) {
          final gap = p.placed[i].start.difference(p.placed[i - 1].end).inMinutes;
          expect(gap, greaterThanOrEqualTo(5));
        }
      }
    });
  });

  group('Rule 2 · fixed items never move', () {
    test('tasks avoid a commitment including prep and travel time', () {
      final c = commitment(mon(8, 30), mon(12), prep: 15, travel: 15);
      final p = run([task()], commitments: [c]);
      final s = p.placed.single;
      expect(overlaps(s.start, s.end, c.busyStart, c.busyEnd), isFalse);
      expect(s.start, mon(12, 30));
    });

    test('fixed tasks are treated as busy and never appear in the proposal', () {
      final fixed = task(flexible: false, scheduledStart: mon(8), status: TaskStatus.scheduled);
      final flex = task();
      final p = run([fixed, flex]);
      expect(p.placed.map((e) => e.task.id), [flex.id]);
      expect(p.unscheduled, isEmpty);
      expect(overlaps(p.placed.single.start, p.placed.single.end, mon(8), mon(9)), isFalse);
    });

    test('rest after a flight is protected', () {
      final c = commitment(mon(8), mon(14), rest: 120);
      final p = run([task()], commitments: [c]);
      expect(p.placed.single.start.isBefore(mon(16)), isFalse);
    });
  });

  group('Rule 3 · sleep is protected', () {
    test('a task created late in the evening goes to the next morning', () {
      final p = run([task()], from: mon(22));
      final s = p.placed.single;
      expect(inSleep(s.start, s.end), isFalse);
      expect(s.start, tue(7, 45));
    });

    test('no placement ever touches sleep', () {
      final p = run([for (var i = 0; i < 25; i++) task(minutes: 90)]);
      for (final s in p.placed) {
        expect(inSleep(s.start, s.end), isFalse, reason: '${s.start}');
      }
    });
  });

  group('Rule 4 · breathing room', () {
    test('a day is never filled beyond the load cap', () {
      final p = run([for (var i = 0; i < 14; i++) task()]);
      final monday = p.placed.where((s) => s.start.day == 1).fold<int>(0, (a, s) => a + s.task.durationMin);
      // Free Monday time is 08:00–22:25 = 865 min; cap is 70%.
      expect(monday, lessThanOrEqualTo((865 * 0.7).floor()));
      expect(p.placed.length, 14);
    });
  });

  group('Rule 5 · important first', () {
    test('urgent task takes the only slot today, low waits', () {
      final low = task(minutes: 45, priority: TaskPriority.low);
      final urgent = task(minutes: 45, priority: TaskPriority.urgent);
      final p = run([low, urgent], from: mon(21));
      final byId = {for (final s in p.placed) s.task.id: s};
      expect(byId[urgent.id]!.start, mon(21));
      expect(byId[low.id]!.start.day, 2);
    });

    test('earlier deadline wins at equal priority', () {
      final later = task(deadline: DateTime(2024, 1, 5));
      final sooner = task(deadline: DateTime(2024, 1, 3));
      expect(RuleBasedScheduler.compareTasks(sooner, later), lessThan(0));
    });
  });

  group('Rule 6 · suitable time, not just free time', () {
    test('low priority waits for the preferred part of the day', () {
      final p = run([task(priority: TaskPriority.low)], p: profile(preferred: DayPart.afternoon));
      expect(p.placed.single.start, mon(12));
    });

    test('urgent work does not wait for the preferred time', () {
      final p = run([task(priority: TaskPriority.urgent)], p: profile(preferred: DayPart.afternoon));
      expect(p.placed.single.start, mon(8));
    });

    test('postponed tasks respect their earliest day', () {
      final p = run([task(notBefore: DateTime(2024, 1, 3))]);
      expect(p.placed.single.start.isBefore(DateTime(2024, 1, 3)), isFalse);
    });
  });

  group('Rule 7 · unscheduled instead of forced', () {
    test('no time before the deadline', () {
      final p = run([task(deadline: DateTime(2024, 1, 1))], from: mon(22));
      expect(p.placed, isEmpty);
      expect(p.unscheduled.single.reason, UnscheduledReason.noTimeBeforeDeadline);
    });

    test('longer than any day can hold', () {
      final p = run([task(minutes: 900)]);
      expect(p.unscheduled.single.reason, UnscheduledReason.tooLong);
    });
  });

  group('Rule 8 · re-planning moves only what must move', () {
    test('a still-valid time is kept and nothing changes', () {
      final t = task(scheduledStart: tue(10), status: TaskStatus.scheduled);
      final p = run([t]);
      expect(p.placed.single.start, tue(10));
      expect(p.hasChanges, isFalse);
    });

    test('a new shift moves only the conflicting task', () {
      final hit = task(scheduledStart: tue(10), status: TaskStatus.scheduled);
      final safe = task(scheduledStart: tue(16), status: TaskStatus.scheduled);
      final shift = commitment(tue(9, 30), tue(11));
      final p = run([hit, safe], commitments: [shift]);
      final byId = {for (final s in p.placed) s.task.id: s};
      expect(byId[safe.id]!.isMoved, isFalse);
      expect(byId[hit.id]!.isMoved, isTrue);
      expect(overlaps(byId[hit.id]!.start, byId[hit.id]!.end, shift.busyStart, shift.busyEnd), isFalse);
      expect(p.moved.length, 1);
    });

    test('a missed task is planned again in the future', () {
      final missed = task(scheduledStart: mon(6), status: TaskStatus.scheduled);
      final p = run([missed]);
      expect(p.placed.single.isMoved, isTrue);
      expect(p.placed.single.start.isBefore(mon(8)), isFalse);
    });

    test('completed tasks are ignored', () {
      final done = task(scheduledStart: mon(8), status: TaskStatus.done);
      final p = run([done]);
      expect(p.placed, isEmpty);
      expect(p.unscheduled, isEmpty);
    });
  });

  group('Span helpers', () {
    test('merge and free time', () {
      final busy = mergeSpans([Span(mon(9), mon(10)), Span(mon(9, 30), mon(11)), Span(mon(13), mon(14))]);
      expect(busy.length, 2);
      final free = freeWithin(Span(mon(8), mon(15)), busy);
      expect(free.map((s) => s.minutes), [60, 120, 60]);
    });
  });
}
