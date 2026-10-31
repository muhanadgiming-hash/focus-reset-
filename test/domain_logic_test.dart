import 'package:flutter_test/flutter_test.dart';
import 'package:focus_reset/core/utils/date_key.dart';
import 'package:focus_reset/data/models/planning_models.dart';
import 'package:focus_reset/data/models/user_profile.dart';
import 'package:focus_reset/domain/habits/habit_logic.dart';
import 'package:focus_reset/domain/scheduling/day_agenda.dart';
import 'package:focus_reset/domain/stats/progress_stats.dart';
import 'package:focus_reset/domain/tasks/recurrence.dart';

const sunThu = {DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday};

TaskItem _task({
  RepeatRule repeat = RepeatRule.daily,
  bool flexible = true,
  DateTime? scheduledStart,
  DateTime? deadline,
  TaskStatus status = TaskStatus.pending,
  DateTime? completedAt,
}) =>
    TaskItem(
      id: 'a',
      title: 'Read',
      durationMin: 30,
      repeat: repeat,
      isFlexible: flexible,
      scheduledStart: scheduledStart,
      deadline: deadline,
      status: status,
      completedAt: completedAt,
      createdAt: DateTime(2024, 1, 1),
    );

Habit _habit({HabitFrequency f = HabitFrequency.daily, Set<int> days = const {}, int perWeek = 3}) => Habit(
      id: 'h',
      templateKey: 'habit.water',
      name: 'Water',
      targetAmount: 8,
      unitKey: 'unit.glasses',
      frequency: f,
      days: days,
      timesPerWeek: perWeek,
      createdAt: DateTime(2023, 12, 1),
    );

Map<String, int> _log(List<DateTime> doneDays) => {for (final d in doneDays) dateKey(d): 8};

void main() {
  group('Recurrence', () {
    test('daily flexible task returns tomorrow as earliest day', () {
      final n = Recurrence.next(_task(), completedAt: DateTime(2024, 1, 1, 9), workDays: sunThu, newId: 'b')!;
      expect(n.notBefore, DateTime(2024, 1, 2));
      expect(n.status, TaskStatus.pending);
      expect(n.scheduledStart, isNull);
    });

    test('working-days repeat skips the weekend (Thursday → Sunday)', () {
      final n = Recurrence.next(_task(repeat: RepeatRule.weekdays),
          completedAt: DateTime(2024, 1, 4, 18), workDays: sunThu, newId: 'b')!;
      expect(n.notBefore, DateTime(2024, 1, 7));
    });

    test('monthly repeat clamps to the end of a short month', () {
      expect(Recurrence.nextDay(DateTime(2024, 1, 31), RepeatRule.monthly, sunThu), DateTime(2024, 2, 29));
    });

    test('fixed task keeps its clock time and shifts its deadline', () {
      final n = Recurrence.next(
        _task(repeat: RepeatRule.weekly, flexible: false, scheduledStart: DateTime(2024, 1, 1, 18, 30), deadline: DateTime(2024, 1, 1)),
        completedAt: DateTime(2024, 1, 1, 19),
        workDays: sunThu,
        newId: 'b',
      )!;
      expect(n.scheduledStart, DateTime(2024, 1, 8, 18, 30));
      expect(n.deadline, DateTime(2024, 1, 8));
      expect(n.status, TaskStatus.scheduled);
    });

    test('non-repeating tasks have no next occurrence', () {
      expect(Recurrence.next(_task(repeat: RepeatRule.none), completedAt: DateTime.now(), workDays: sunThu, newId: 'b'), isNull);
    });
  });

  group('Habits', () {
    final today = DateTime(2024, 1, 10);

    test('daily streak counts back from today', () {
      final log = _log([DateTime(2024, 1, 8), DateTime(2024, 1, 9), DateTime(2024, 1, 10)]);
      expect(HabitLogic.streak(_habit(), log, today, DateTime.sunday), 3);
    });

    test('an unfinished today does not break the streak yet', () {
      final log = _log([DateTime(2024, 1, 8), DateTime(2024, 1, 9)]);
      expect(HabitLogic.streak(_habit(), log, today, DateTime.sunday), 2);
    });

    test('a missed day breaks the streak', () {
      final log = _log([DateTime(2024, 1, 7), DateTime(2024, 1, 9), DateTime(2024, 1, 10)]);
      expect(HabitLogic.streak(_habit(), log, today, DateTime.sunday), 2);
    });

    test('specific-days habits ignore days they are not planned for', () {
      // Monday 8th and Wednesday 10th only.
      final h = _habit(f: HabitFrequency.specificDays, days: {DateTime.monday, DateTime.wednesday});
      final log = _log([DateTime(2024, 1, 3), DateTime(2024, 1, 8), DateTime(2024, 1, 10)]);
      expect(HabitLogic.streak(h, log, today, DateTime.sunday), 3);
    });

    test('times-per-week caps progress at the target', () {
      final h = _habit(f: HabitFrequency.timesPerWeek, perWeek: 2);
      final log = _log([DateTime(2024, 1, 7), DateTime(2024, 1, 8), DateTime(2024, 1, 9)]);
      final (done, due) = HabitLogic.doneAndDue(h, log, DateTime(2024, 1, 7), DateTime(2024, 1, 14), today);
      expect((done, due), (2, 2));
    });

    test('step size suits the target', () {
      expect(HabitLogic.stepFor(8), 1);
      expect(HabitLogic.stepFor(20), 5);
      expect(HabitLogic.stepFor(6000), 500);
    });
  });

  group('Progress statistics', () {
    test('completion rate uses only real records', () {
      final empty = ProgressStats.forPeriod(
        tasks: const [],
        sessions: const [],
        habits: const [],
        habitLogs: const {},
        start: DateTime(2024, 1, 7),
        end: DateTime(2024, 1, 14),
        now: DateTime(2024, 1, 10),
      );
      expect(empty.taskRate, isNull);
      expect(empty.habitRate, isNull);

      final s = ProgressStats.forPeriod(
        tasks: [
          _task(repeat: RepeatRule.none, status: TaskStatus.done, completedAt: DateTime(2024, 1, 8, 10)),
          _task(repeat: RepeatRule.none, scheduledStart: DateTime(2024, 1, 11, 10), status: TaskStatus.scheduled),
        ],
        sessions: [
          FocusSession(id: 'f', start: DateTime(2024, 1, 9, 9), plannedMin: 25, actualMin: 25),
          FocusSession(id: 'g', start: DateTime(2024, 1, 9, 15), plannedMin: 25, actualMin: 10, completed: false),
        ],
        habits: const [],
        habitLogs: const {},
        start: DateTime(2024, 1, 7),
        end: DateTime(2024, 1, 14),
        now: DateTime(2024, 1, 10),
      );
      expect(s.taskRate, 0.5);
      expect(s.focusSessions, 1);
      expect(s.focusMinutes, 35);
    });

    test('productivity by part of day', () {
      final parts = ProgressStats.byDayPart(
        const [],
        [FocusSession(id: 'f', start: DateTime(2024, 1, 9, 9), plannedMin: 25, actualMin: 25)],
        DateTime(2024, 1, 1),
      );
      expect(parts[DayPart.morning.index], 25);
    });
  });

  group('Day agenda', () {
    test('an overnight flight is split across both days', () {
      final p = UserProfile(
        name: 'T',
        ageRange: AgeRange.r25to34,
        lifestyle: Lifestyle.travelCrew,
        workPattern: WorkPattern.variable,
        bedtimeMin: 23 * 60,
        wakeMin: 7 * 60,
      );
      final flight = Commitment(
        id: 'c',
        type: CommitmentType.flight,
        title: 'JED-LHR',
        start: DateTime(2024, 1, 1, 22),
        end: DateTime(2024, 1, 2, 4),
      );
      List<AgendaItem> flightOn(DateTime d) => DayAgenda.build(profile: p, commitments: [flight], tasks: const [], day: d)
          .where((i) => i.kind == AgendaKind.commitment)
          .toList();
      expect(flightOn(DateTime(2024, 1, 1)).single.startMin, 22 * 60);
      expect(flightOn(DateTime(2024, 1, 1)).single.endMin, 1440);
      expect(flightOn(DateTime(2024, 1, 2)).single.endMin, 4 * 60);
    });
  });

  group('JSON', () {
    test('task round-trips', () {
      final t = _task(scheduledStart: DateTime(2024, 1, 2, 9, 15), deadline: DateTime(2024, 1, 3));
      expect(TaskItem.fromJson(t.toJson()).toJson(), t.toJson());
    });

    test('commitment round-trips with time zone', () {
      final c = Commitment(
        id: 'c',
        type: CommitmentType.flight,
        title: 'LHR-JED',
        start: DateTime(2024, 1, 1, 10),
        end: DateTime(2024, 1, 1, 16),
        utcOffsetMin: 0,
        prepMin: 60,
        restAfterMin: 120,
      );
      expect(Commitment.fromJson(c.toJson()).toJson(), c.toJson());
    });

    test('copyWith can clear nullable fields', () {
      final t = _task(scheduledStart: DateTime(2024, 1, 2, 9));
      expect(t.copyWith(scheduledStart: null).scheduledStart, isNull);
      expect(t.copyWith(title: 'x').scheduledStart, DateTime(2024, 1, 2, 9));
    });
  });
}
