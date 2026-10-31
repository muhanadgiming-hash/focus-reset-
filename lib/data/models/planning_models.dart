import 'package:flutter/foundation.dart';

import '../../core/utils/date_key.dart';

/// Core planning entities, serialisable to JSON for local storage now and
/// Supabase tables in Phase 3.

enum TaskPriority { low, medium, high, urgent }

enum RepeatRule { none, daily, weekdays, weekly, monthly }

enum TaskStatus { pending, scheduled, done }

enum CommitmentType { workShift, flight, meeting, appointment, commute, family, personal }

enum HabitFrequency { daily, specificDays, timesPerWeek }

/// Sentinel for copyWith: distinguishes "leave unchanged" from "set to null".
const Object _keep = Object();

T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return fallback;
}

String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

DateTime? _time(Object? raw) => raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

int _int(Object? raw, int fallback) => raw is num ? raw.toInt() : fallback;

int? _intOrNull(Object? raw) => raw is num ? raw.toInt() : null;

String _str(Object? raw, [String fallback = '']) => raw is String ? raw : fallback;

// ----------------------------------------------------------------------------

@immutable
class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.durationMin,
    this.priority = TaskPriority.medium,
    this.deadline,
    this.repeat = RepeatRule.none,
    this.linkedGoal,
    this.linkedHabitId,
    this.isFlexible = true,
    this.status = TaskStatus.pending,
    this.notes = '',
    this.scheduledStart,
    this.notBefore,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final int durationMin;
  final TaskPriority priority;

  /// Calendar day the task must be finished by (inclusive).
  final DateTime? deadline;
  final RepeatRule repeat;
  final String? linkedGoal;
  final String? linkedHabitId;

  /// Flexible tasks may be placed and moved by the scheduler. Fixed tasks
  /// keep the time the user chose and are never moved.
  final bool isFlexible;
  final TaskStatus status;
  final String notes;
  final DateTime? scheduledStart;

  /// Earliest calendar day the task may be scheduled (set by "postpone").
  final DateTime? notBefore;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isDone => status == TaskStatus.done;

  DateTime? get scheduledEnd => scheduledStart?.add(Duration(minutes: durationMin));

  TaskItem copyWith({
    String? title,
    int? durationMin,
    TaskPriority? priority,
    Object? deadline = _keep,
    RepeatRule? repeat,
    Object? linkedGoal = _keep,
    Object? linkedHabitId = _keep,
    bool? isFlexible,
    TaskStatus? status,
    String? notes,
    Object? scheduledStart = _keep,
    Object? notBefore = _keep,
    Object? completedAt = _keep,
  }) {
    return TaskItem(
      id: id,
      title: title ?? this.title,
      durationMin: durationMin ?? this.durationMin,
      priority: priority ?? this.priority,
      deadline: identical(deadline, _keep) ? this.deadline : deadline as DateTime?,
      repeat: repeat ?? this.repeat,
      linkedGoal: identical(linkedGoal, _keep) ? this.linkedGoal : linkedGoal as String?,
      linkedHabitId: identical(linkedHabitId, _keep) ? this.linkedHabitId : linkedHabitId as String?,
      isFlexible: isFlexible ?? this.isFlexible,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      scheduledStart: identical(scheduledStart, _keep) ? this.scheduledStart : scheduledStart as DateTime?,
      notBefore: identical(notBefore, _keep) ? this.notBefore : notBefore as DateTime?,
      createdAt: createdAt,
      completedAt: identical(completedAt, _keep) ? this.completedAt : completedAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'durationMin': durationMin,
        'priority': priority.name,
        'deadline': deadline == null ? null : dateKey(deadline!),
        'repeat': repeat.name,
        'linkedGoal': linkedGoal,
        'linkedHabitId': linkedHabitId,
        'isFlexible': isFlexible,
        'status': status.name,
        'notes': notes,
        'scheduledStart': _iso(scheduledStart),
        'notBefore': notBefore == null ? null : dateKey(notBefore!),
        'createdAt': _iso(createdAt),
        'completedAt': _iso(completedAt),
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: _str(j['id']),
        title: _str(j['title']),
        durationMin: _int(j['durationMin'], 30),
        priority: _enum(TaskPriority.values, j['priority'], TaskPriority.medium),
        deadline: parseDateKey(j['deadline']),
        repeat: _enum(RepeatRule.values, j['repeat'], RepeatRule.none),
        linkedGoal: j['linkedGoal'] as String?,
        linkedHabitId: j['linkedHabitId'] as String?,
        isFlexible: j['isFlexible'] != false,
        status: _enum(TaskStatus.values, j['status'], TaskStatus.pending),
        notes: _str(j['notes']),
        scheduledStart: _time(j['scheduledStart']),
        notBefore: parseDateKey(j['notBefore']),
        createdAt: _time(j['createdAt']) ?? DateTime.now(),
        completedAt: _time(j['completedAt']),
      );
}

// ----------------------------------------------------------------------------

/// A time-bound commitment the scheduler plans *around* and never moves.
///
/// [start] and [end] are absolute instants. When the commitment happens in
/// another time zone (e.g. a flight leaving London), [utcOffsetMin] records
/// that zone so the UI can show both local and destination time.
@immutable
class Commitment {
  const Commitment({
    required this.id,
    required this.type,
    required this.title,
    required this.start,
    required this.end,
    this.utcOffsetMin,
    this.prepMin = 0,
    this.travelMin = 0,
    this.restAfterMin = 0,
  });

  final String id;
  final CommitmentType type;
  final String title;
  final DateTime start;
  final DateTime end;
  final int? utcOffsetMin;
  final int prepMin;
  final int travelMin;

  /// Recovery time after the commitment (e.g. after a long flight).
  final int restAfterMin;

  /// Start of everything this commitment blocks, including preparation and travel.
  DateTime get busyStart => start.subtract(Duration(minutes: prepMin + travelMin));

  /// End of everything this commitment blocks, including travel and rest.
  DateTime get busyEnd => end.add(Duration(minutes: travelMin + restAfterMin));

  int get durationMin => end.difference(start).inMinutes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'start': _iso(start),
        'end': _iso(end),
        'utcOffsetMin': utcOffsetMin,
        'prepMin': prepMin,
        'travelMin': travelMin,
        'restAfterMin': restAfterMin,
      };

  factory Commitment.fromJson(Map<String, dynamic> j) {
    final start = _time(j['start']) ?? DateTime.now();
    return Commitment(
      id: _str(j['id']),
      type: _enum(CommitmentType.values, j['type'], CommitmentType.personal),
      title: _str(j['title']),
      start: start,
      end: _time(j['end']) ?? start.add(const Duration(hours: 1)),
      utcOffsetMin: _intOrNull(j['utcOffsetMin']),
      prepMin: _int(j['prepMin'], 0),
      travelMin: _int(j['travelMin'], 0),
      restAfterMin: _int(j['restAfterMin'], 0),
    );
  }
}

// ----------------------------------------------------------------------------

@immutable
class Habit {
  const Habit({
    required this.id,
    required this.templateKey,
    required this.name,
    required this.targetAmount,
    required this.unitKey,
    this.frequency = HabitFrequency.daily,
    this.days = const <int>{},
    this.timesPerWeek = 3,
    this.reminderMin,
    required this.createdAt,
  });

  final String id;

  /// Template the habit was created from ("custom" otherwise); picks the icon.
  final String templateKey;
  final String name;
  final int targetAmount;
  final String unitKey;
  final HabitFrequency frequency;

  /// Weekdays (DateTime constants) for [HabitFrequency.specificDays].
  final Set<int> days;
  final int timesPerWeek;

  /// Reminder time (minutes since midnight). Delivered from Phase 4.
  final int? reminderMin;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateKey': templateKey,
        'name': name,
        'targetAmount': targetAmount,
        'unitKey': unitKey,
        'frequency': frequency.name,
        'days': days.toList()..sort(),
        'timesPerWeek': timesPerWeek,
        'reminderMin': reminderMin,
        'createdAt': _iso(createdAt),
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: _str(j['id']),
        templateKey: _str(j['templateKey'], 'custom'),
        name: _str(j['name']),
        targetAmount: _int(j['targetAmount'], 1),
        unitKey: _str(j['unitKey'], 'unit.times'),
        frequency: _enum(HabitFrequency.values, j['frequency'], HabitFrequency.daily),
        days: ((j['days'] as List?) ?? const []).whereType<num>().map((e) => e.toInt()).toSet(),
        timesPerWeek: _int(j['timesPerWeek'], 3),
        reminderMin: _intOrNull(j['reminderMin']),
        createdAt: _time(j['createdAt']) ?? DateTime.now(),
      );
}

// ----------------------------------------------------------------------------

@immutable
class FocusSession {
  const FocusSession({
    required this.id,
    required this.start,
    required this.plannedMin,
    required this.actualMin,
    this.taskId,
    this.completed = true,
  });

  final String id;
  final DateTime start;
  final int plannedMin;
  final int actualMin;
  final String? taskId;

  /// False when the user ended the session early.
  final bool completed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': _iso(start),
        'plannedMin': plannedMin,
        'actualMin': actualMin,
        'taskId': taskId,
        'completed': completed,
      };

  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
        id: _str(j['id']),
        start: _time(j['start']) ?? DateTime.now(),
        plannedMin: _int(j['plannedMin'], 25),
        actualMin: _int(j['actualMin'], 0),
        taskId: j['taskId'] as String?,
        completed: j['completed'] != false,
      );
}

// ----------------------------------------------------------------------------

@immutable
class SleepEntry {
  const SleepEntry({
    required this.id,
    required this.date,
    required this.bedtimeMin,
    required this.wakeMin,
    this.quality,
  });

  final String id;

  /// The morning the user woke up (one entry per night).
  final DateTime date;
  final int bedtimeMin;
  final int wakeMin;

  /// Optional self-reported 1–5 rating. Never interpreted medically.
  final int? quality;

  int get durationMin {
    final diff = wakeMin - bedtimeMin;
    return diff > 0 ? diff : diff + 1440;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': dateKey(date),
        'bedtimeMin': bedtimeMin,
        'wakeMin': wakeMin,
        'quality': quality,
      };

  factory SleepEntry.fromJson(Map<String, dynamic> j) => SleepEntry(
        id: _str(j['id']),
        date: parseDateKey(j['date']) ?? dateOnly(DateTime.now()),
        bedtimeMin: _int(j['bedtimeMin'], 1380),
        wakeMin: _int(j['wakeMin'], 420),
        quality: _intOrNull(j['quality']),
      );
}
