import 'package:flutter_test/flutter_test.dart';
import 'package:focus_reset/data/models/planning_models.dart';
import 'package:focus_reset/data/models/user_profile.dart';
import 'package:focus_reset/data/services/native_bridge.dart';
import 'package:focus_reset/domain/notifications/notification_planner.dart';

String tr(String key, [Map<String, String>? args]) => key;
String clock(DateTime t) => '${t.hour}:${t.minute}';

const profile = UserProfile(
  name: 'T',
  ageRange: AgeRange.r25to34,
  lifestyle: Lifestyle.office,
  workPattern: WorkPattern.none,
  bedtimeMin: 15, // 00:15 → reminder at 23:45 the evening before
  wakeMin: 7 * 60,
);

final now = DateTime(2024, 1, 1, 8);

TaskItem task(String id, DateTime? start, {bool done = false}) => TaskItem(
      id: id,
      title: id,
      durationMin: 30,
      scheduledStart: start,
      status: done ? TaskStatus.done : TaskStatus.scheduled,
      createdAt: DateTime(2023),
    );

List<LocalNotification> build({
  NotificationPrefs prefs = const NotificationPrefs(enabled: true),
  List<TaskItem> tasks = const [],
  List<Habit> habits = const [],
}) =>
    NotificationPlanner.build(
      prefs: prefs,
      profile: profile,
      tasks: tasks,
      habits: habits,
      now: now,
      tr: tr,
      clock: clock,
    );

void main() {
  test('nothing is scheduled while reminders are off', () {
    expect(build(prefs: const NotificationPrefs(enabled: false)), isEmpty);
  });

  test('bedtime reminder is 30 minutes before, wrapping past midnight', () {
    final bed = build().singleWhere((n) => n.id == 'fr.bed');
    expect((bed.hour, bed.minute), (23, 45));
    expect(bed.isRepeating, isTrue);
  });

  test('task reminders: only future, not done, inside 7 days, with lead time', () {
    final list = build(tasks: [
      task('past', DateTime(2024, 1, 1, 8, 5)), // reminder 07:55 already passed
      task('soon', DateTime(2024, 1, 1, 9)),
      task('done', DateTime(2024, 1, 1, 10), done: true),
      task('far', DateTime(2024, 1, 20, 9)),
      task('unplanned', null),
    ]).where((n) => n.id.startsWith('fr.task.')).toList();
    expect(list.map((n) => n.id), ['fr.task.soon']);
    expect(list.single.at, DateTime(2024, 1, 1, 8, 50));
  });

  test('habit on specific days becomes one weekly reminder per day', () {
    final h = Habit(
      id: 'h',
      templateKey: 'habit.reading',
      name: 'Read',
      targetAmount: 20,
      unitKey: 'unit.pages',
      frequency: HabitFrequency.specificDays,
      days: const {DateTime.monday, DateTime.sunday},
      reminderMin: 20 * 60 + 30,
      createdAt: DateTime(2023),
    );
    final list = build(habits: [h]).where((n) => n.id.startsWith('fr.habit.')).toList();
    expect(list.length, 2);
    expect(list.every((n) => n.hour == 20 && n.minute == 30), isTrue);
    // Apple weekdays: Sunday = 1, Monday = 2.
    expect(list.map((n) => n.toMap()['weekday']).toSet(), {1, 2});
  });

  test('never more than iOS allows', () {
    final many = [for (var i = 0; i < 200; i++) task('t$i', now.add(Duration(hours: i + 1)))];
    expect(build(tasks: many).length, NotificationPlanner.maxPending);
  });

  test('settings round-trip', () {
    const p = NotificationPrefs(enabled: true, tasks: false, taskLeadMin: 30, habits: true, bedtime: false);
    expect(NotificationPrefs.fromJson(p.toJson()).toJson(), p.toJson());
  });
}
