import '../../data/models/planning_models.dart';
import '../../data/models/user_profile.dart';
import '../../data/services/native_bridge.dart';

/// User choices for reminders (stored on this device only).
class NotificationPrefs {
  const NotificationPrefs({
    this.enabled = false,
    this.tasks = true,
    this.taskLeadMin = 10,
    this.habits = true,
    this.bedtime = true,
  });

  final bool enabled;
  final bool tasks;
  final int taskLeadMin;
  final bool habits;
  final bool bedtime;

  NotificationPrefs copyWith({bool? enabled, bool? tasks, int? taskLeadMin, bool? habits, bool? bedtime}) =>
      NotificationPrefs(
        enabled: enabled ?? this.enabled,
        tasks: tasks ?? this.tasks,
        taskLeadMin: taskLeadMin ?? this.taskLeadMin,
        habits: habits ?? this.habits,
        bedtime: bedtime ?? this.bedtime,
      );

  Map<String, Object> toJson() =>
      {'enabled': enabled, 'tasks': tasks, 'taskLeadMin': taskLeadMin, 'habits': habits, 'bedtime': bedtime};

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) => NotificationPrefs(
        enabled: j['enabled'] == true,
        tasks: j['tasks'] != false,
        taskLeadMin: j['taskLeadMin'] is num ? (j['taskLeadMin'] as num).toInt() : 10,
        habits: j['habits'] != false,
        bedtime: j['bedtime'] != false,
      );
}

typedef Translate = String Function(String key, [Map<String, String>? args]);

/// Turns the user's data into the exact set of local notifications that
/// should be pending. Pure and deterministic — the app replaces all pending
/// Focus Reset reminders with this list whenever data changes.
abstract final class NotificationPlanner {
  /// iOS keeps at most 64 pending notifications per app; leave headroom.
  static const maxPending = 60;
  static const prefix = 'fr.';
  static const windDownMin = 30;

  static List<LocalNotification> build({
    required NotificationPrefs prefs,
    required UserProfile? profile,
    required List<TaskItem> tasks,
    required List<Habit> habits,
    required DateTime now,
    required Translate tr,
    required String Function(DateTime) clock,
    String Function(String unitKey)? unit,
  }) {
    if (!prefs.enabled) return const [];
    final out = <LocalNotification>[];

    if (prefs.bedtime && profile != null) {
      final m = (profile.bedtimeMin - windDownMin + 1440) % 1440;
      out.add(LocalNotification.repeating(
        id: '${prefix}bed',
        title: tr('notif.bedTitle'),
        body: tr('notif.bedBody', {'t': clock(DateTime(2000, 1, 1, 0, profile.bedtimeMin))}),
        hour: m ~/ 60,
        minute: m % 60,
      ));
    }

    if (prefs.habits) {
      for (final h in habits) {
        final r = h.reminderMin;
        if (r == null) continue;
        final body = tr('notif.habitBody', {
          'n': '${h.targetAmount}',
          'u': unit == null ? '' : unit(h.unitKey),
        }).trim();
        if (h.frequency == HabitFrequency.specificDays) {
          for (final d in h.days.toList()..sort()) {
            out.add(LocalNotification.repeating(
              id: '${prefix}habit.${h.id}.$d',
              title: h.name,
              body: body,
              hour: r ~/ 60,
              minute: r % 60,
              weekday: d,
            ));
          }
        } else {
          out.add(LocalNotification.repeating(
            id: '${prefix}habit.${h.id}',
            title: h.name,
            body: body,
            hour: r ~/ 60,
            minute: r % 60,
          ));
        }
      }
    }

    if (prefs.tasks) {
      final horizon = now.add(const Duration(days: 7));
      final upcoming = <(DateTime, TaskItem)>[];
      for (final t in tasks) {
        final s = t.scheduledStart;
        if (t.isDone || s == null || s.isAfter(horizon)) continue;
        final at = s.subtract(Duration(minutes: prefs.taskLeadMin));
        if (!at.isAfter(now)) continue;
        upcoming.add((at, t));
      }
      upcoming.sort((a, b) => a.$1.compareTo(b.$1));
      final budget = maxPending - out.length;
      for (final (at, t) in upcoming.take(budget < 0 ? 0 : budget)) {
        out.add(LocalNotification.once(
          id: '${prefix}task.${t.id}',
          title: t.title,
          body: tr('notif.taskBody', {'t': clock(t.scheduledStart!), 'm': '${prefs.taskLeadMin}'}),
          at: at,
        ));
      }
    }

    return out.length > maxPending ? out.sublist(0, maxPending) : out;
  }
}
