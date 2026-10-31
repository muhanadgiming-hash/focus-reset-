import 'package:flutter/foundation.dart';

/// How the user's working time is organised.
enum WorkPattern { fixed, variable, shifts, none }

/// Broad lifestyle category. Used for sensible defaults only — never to
/// restrict features.
enum Lifestyle {
  student,
  office,
  shiftWorker,
  travelCrew,
  healthcare,
  freelancer,
  homeAndFamily,
  retired,
  other,
}

enum AgeRange { r13to17, r18to24, r25to34, r35to44, r45to54, r55plus }

enum DayPart { morning, afternoon, evening, night }

/// The user's personal setup collected during onboarding and editable from
/// Settings. All clock times are minutes since midnight in the user's
/// home timezone ([homeTimeZone]).
@immutable
class UserProfile {
  const UserProfile({
    required this.name,
    required this.ageRange,
    required this.lifestyle,
    this.occupation = '',
    required this.workPattern,
    this.workDays = const <int>{},
    this.workStartMin = 9 * 60,
    this.workEndMin = 17 * 60,
    required this.bedtimeMin,
    required this.wakeMin,
    this.commitments = const <String>[],
    this.dailyFocusGoalMin = 90,
    this.weeklyGoals = const <String>{},
    this.preferredFocusTime = DayPart.morning,
    this.focusSessionMin = 25,
    this.breakMin = 5,
    this.firstWeekday = DateTime.sunday,
    this.commuteBufferMin = 15,
    this.homeTimeZone = '',
  });

  final String name;
  final AgeRange ageRange;
  final Lifestyle lifestyle;
  final String occupation;

  final WorkPattern workPattern;

  /// Weekdays using DateTime constants (1 = Monday … 7 = Sunday).
  /// Only meaningful when [workPattern] is [WorkPattern.fixed].
  final Set<int> workDays;
  final int workStartMin;
  final int workEndMin;

  final int bedtimeMin;
  final int wakeMin;

  /// Free-text recurring personal commitments (e.g. "Family dinner").
  final List<String> commitments;

  final int dailyFocusGoalMin;

  /// Keys of selected weekly goals (see `goal.*` localisation keys).
  final Set<String> weeklyGoals;

  final DayPart preferredFocusTime;
  final int focusSessionMin;
  final int breakMin;
  final int firstWeekday;
  final int commuteBufferMin;

  /// Device timezone captured at setup (currently the platform abbreviation,
  /// e.g. "+03"). Phase 4 switches this to the IANA name (e.g. "Asia/Riyadh")
  /// via the native timezone API for travel-crew timezone handling.
  final String homeTimeZone;

  int get sleepDurationMin {
    final diff = wakeMin - bedtimeMin;
    return diff > 0 ? diff : diff + 1440;
  }

  UserProfile copyWith({
    String? name,
    AgeRange? ageRange,
    Lifestyle? lifestyle,
    String? occupation,
    WorkPattern? workPattern,
    Set<int>? workDays,
    int? workStartMin,
    int? workEndMin,
    int? bedtimeMin,
    int? wakeMin,
    List<String>? commitments,
    int? dailyFocusGoalMin,
    Set<String>? weeklyGoals,
    DayPart? preferredFocusTime,
    int? focusSessionMin,
    int? breakMin,
    int? firstWeekday,
    int? commuteBufferMin,
    String? homeTimeZone,
  }) {
    return UserProfile(
      name: name ?? this.name,
      ageRange: ageRange ?? this.ageRange,
      lifestyle: lifestyle ?? this.lifestyle,
      occupation: occupation ?? this.occupation,
      workPattern: workPattern ?? this.workPattern,
      workDays: workDays ?? this.workDays,
      workStartMin: workStartMin ?? this.workStartMin,
      workEndMin: workEndMin ?? this.workEndMin,
      bedtimeMin: bedtimeMin ?? this.bedtimeMin,
      wakeMin: wakeMin ?? this.wakeMin,
      commitments: commitments ?? this.commitments,
      dailyFocusGoalMin: dailyFocusGoalMin ?? this.dailyFocusGoalMin,
      weeklyGoals: weeklyGoals ?? this.weeklyGoals,
      preferredFocusTime: preferredFocusTime ?? this.preferredFocusTime,
      focusSessionMin: focusSessionMin ?? this.focusSessionMin,
      breakMin: breakMin ?? this.breakMin,
      firstWeekday: firstWeekday ?? this.firstWeekday,
      commuteBufferMin: commuteBufferMin ?? this.commuteBufferMin,
      homeTimeZone: homeTimeZone ?? this.homeTimeZone,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'name': name,
        'ageRange': ageRange.name,
        'lifestyle': lifestyle.name,
        'occupation': occupation,
        'workPattern': workPattern.name,
        'workDays': workDays.toList()..sort(),
        'workStartMin': workStartMin,
        'workEndMin': workEndMin,
        'bedtimeMin': bedtimeMin,
        'wakeMin': wakeMin,
        'commitments': commitments,
        'dailyFocusGoalMin': dailyFocusGoalMin,
        'weeklyGoals': weeklyGoals.toList(),
        'preferredFocusTime': preferredFocusTime.name,
        'focusSessionMin': focusSessionMin,
        'breakMin': breakMin,
        'firstWeekday': firstWeekday,
        'commuteBufferMin': commuteBufferMin,
        'homeTimeZone': homeTimeZone,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    T byName<T extends Enum>(List<T> values, Object? raw, T fallback) {
      for (final v in values) {
        if (v.name == raw) return v;
      }
      return fallback;
    }

    return UserProfile(
      name: (j['name'] as String?) ?? '',
      ageRange: byName(AgeRange.values, j['ageRange'], AgeRange.r25to34),
      lifestyle: byName(Lifestyle.values, j['lifestyle'], Lifestyle.other),
      occupation: (j['occupation'] as String?) ?? '',
      workPattern: byName(WorkPattern.values, j['workPattern'], WorkPattern.none),
      workDays: ((j['workDays'] as List?) ?? const []).map((e) => e as int).toSet(),
      workStartMin: (j['workStartMin'] as int?) ?? 540,
      workEndMin: (j['workEndMin'] as int?) ?? 1020,
      bedtimeMin: (j['bedtimeMin'] as int?) ?? 1380,
      wakeMin: (j['wakeMin'] as int?) ?? 420,
      commitments: ((j['commitments'] as List?) ?? const []).map((e) => e.toString()).toList(),
      dailyFocusGoalMin: (j['dailyFocusGoalMin'] as int?) ?? 90,
      weeklyGoals: ((j['weeklyGoals'] as List?) ?? const []).map((e) => e.toString()).toSet(),
      preferredFocusTime: byName(DayPart.values, j['preferredFocusTime'], DayPart.morning),
      focusSessionMin: (j['focusSessionMin'] as int?) ?? 25,
      breakMin: (j['breakMin'] as int?) ?? 5,
      firstWeekday: (j['firstWeekday'] as int?) ?? DateTime.sunday,
      commuteBufferMin: (j['commuteBufferMin'] as int?) ?? 15,
      homeTimeZone: (j['homeTimeZone'] as String?) ?? '',
    );
  }
}

/// Maps a clock hour (0–23) to a part of the day.
DayPart dayPartOfHour(int hour) {
  if (hour >= 5 && hour < 12) return DayPart.morning;
  if (hour >= 12 && hour < 17) return DayPart.afternoon;
  if (hour >= 17 && hour < 21) return DayPart.evening;
  return DayPart.night;
}

/// Working days used for "every working day" repeats. Falls back to the
/// regional work week implied by the user's first weekday.
Set<int> effectiveWorkDays(UserProfile? p) {
  if (p != null && p.workDays.isNotEmpty) return p.workDays;
  if (p != null && p.firstWeekday == DateTime.monday) {
    return const {DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday};
  }
  return const {DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday};
}
