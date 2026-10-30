import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/user_profile.dart';

/// Static option sets shared by onboarding, settings and the planner.
abstract final class OnbOptions {
  static String ageKey(AgeRange a) => switch (a) {
        AgeRange.r13to17 => 'age.13_17',
        AgeRange.r18to24 => 'age.18_24',
        AgeRange.r25to34 => 'age.25_34',
        AgeRange.r35to44 => 'age.35_44',
        AgeRange.r45to54 => 'age.45_54',
        AgeRange.r55plus => 'age.55',
      };

  static IconData lifestyleIcon(Lifestyle l) => switch (l) {
        Lifestyle.student => Icons.school_outlined,
        Lifestyle.office => Icons.business_center_outlined,
        Lifestyle.shiftWorker => Icons.schedule_rounded,
        Lifestyle.travelCrew => Icons.flight_rounded,
        Lifestyle.healthcare => Icons.local_hospital_outlined,
        Lifestyle.freelancer => Icons.laptop_mac_rounded,
        Lifestyle.homeAndFamily => Icons.family_restroom_rounded,
        Lifestyle.retired => Icons.park_outlined,
        Lifestyle.other => Icons.more_horiz_rounded,
      };

  static const commitmentSuggestions = <String>[
    'commit.family',
    'commit.exercise',
    'commit.study',
    'commit.school',
    'commit.appointments',
    'commit.social',
  ];

  static const goalKeys = <String>[
    'goal.readMore',
    'goal.exercise',
    'goal.sleepBetter',
    'goal.language',
    'goal.lessScreen',
    'goal.balance',
    'goal.career',
    'goal.family',
  ];

  /// 2024-01-01 is a Monday, so day N of January 2024 has weekday N.
  static DateTime dateForWeekday(int weekday) => DateTime(2024, 1, weekday);

  static String weekdayShort(BuildContext context, int weekday) =>
      DateFormat.E(context.localeTag).format(dateForWeekday(weekday));

  /// The seven weekdays starting from [first] (DateTime constants).
  static List<int> weekOrder(int first) =>
      List<int>.generate(7, (i) => ((first - 1 + i) % 7) + 1);
}
