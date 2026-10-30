import 'package:flutter/foundation.dart';

/// Core planning entities. In Phase 1 these define the shape the UI is
/// built around; Phase 2 adds persistence and the scheduling engine,
/// Phase 3 maps them to Supabase tables.

enum TaskPriority { low, medium, high, urgent }

enum RepeatRule { none, daily, weekdays, weekly, monthly }

enum TaskStatus { pending, scheduled, done, postponed }

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
  });

  final String id;
  final String title;
  final int durationMin;
  final TaskPriority priority;
  final DateTime? deadline;
  final RepeatRule repeat;
  final String? linkedGoal;
  final String? linkedHabitId;

  /// Flexible tasks may be moved by the scheduler; fixed ones never are.
  final bool isFlexible;
  final TaskStatus status;
  final String notes;
  final DateTime? scheduledStart;
}

enum CommitmentType { workShift, flight, meeting, appointment, commute, family, personal }

/// A time-bound commitment that the scheduler plans *around*.
@immutable
class Commitment {
  const Commitment({
    required this.id,
    required this.type,
    required this.title,
    required this.start,
    required this.end,
    this.timeZone = '',
    this.prepMin = 0,
    this.travelMin = 0,
    this.isFixed = true,
  });

  final String id;
  final CommitmentType type;
  final String title;
  final DateTime start;
  final DateTime end;

  /// IANA timezone of the commitment (e.g. a flight departing another city).
  final String timeZone;
  final int prepMin;
  final int travelMin;
  final bool isFixed;
}

enum HabitFrequency { daily, specificDays, timesPerWeek }

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
  });

  final String id;
  final String templateKey;
  final String name;
  final int targetAmount;
  final String unitKey;
  final HabitFrequency frequency;
  final Set<int> days;
  final int timesPerWeek;
  final int? reminderMin;
}

@immutable
class FocusSession {
  const FocusSession({
    required this.start,
    required this.plannedMin,
    required this.actualMin,
    this.taskId,
    this.completed = true,
  });

  final DateTime start;
  final int plannedMin;
  final int actualMin;
  final String? taskId;
  final bool completed;
}

@immutable
class SleepEntry {
  const SleepEntry({
    required this.date,
    required this.bedtimeMin,
    required this.wakeMin,
    this.quality,
  });

  final DateTime date;
  final int bedtimeMin;
  final int wakeMin;

  /// Optional self-reported 1–5 rating. Never interpreted medically.
  final int? quality;
}
