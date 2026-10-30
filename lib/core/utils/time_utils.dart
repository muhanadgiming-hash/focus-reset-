import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';

/// Time is stored throughout the app as "minutes since midnight" (0–1439)
/// for clock times, and as plain minutes for durations. This keeps models
/// timezone-agnostic and makes the scheduling engine pure arithmetic.
abstract final class TimeUtils {
  static const int minutesPerDay = 24 * 60;

  static TimeOfDay toTimeOfDay(int minutes) =>
      TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60);

  static int fromTimeOfDay(TimeOfDay t) => t.hour * 60 + t.minute;

  /// Duration between two clock times, wrapping past midnight.
  /// e.g. 23:00 → 07:00 = 480.
  static int spanAcrossMidnight(int startMin, int endMin) {
    final diff = endMin - startMin;
    return diff > 0 ? diff : diff + minutesPerDay;
  }

  /// Localised clock string, e.g. "7:30 AM" / "٧:٣٠ ص".
  static String clock(BuildContext context, int minutes) {
    final t = toTimeOfDay(minutes);
    final dt = DateTime(2000, 1, 1, t.hour, t.minute);
    return DateFormat.jm(context.localeTag).format(dt);
  }

  /// Localised duration, e.g. "7h 30m" / "7س 30د".
  static String duration(BuildContext context, int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return context.tr('unit.minutesShort', {'m': '$m'});
    if (m == 0) return context.tr('unit.hoursShort', {'h': '$h'});
    return context.tr('unit.hoursMinutesShort', {'h': '$h', 'm': '$m'});
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Start of the week containing [day], where [firstWeekday] uses
  /// DateTime constants (DateTime.saturday / sunday / monday).
  static DateTime startOfWeek(DateTime day, int firstWeekday) {
    final d = dateOnly(day);
    final diff = (d.weekday - firstWeekday + 7) % 7;
    return d.subtract(Duration(days: diff));
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
