// Pure date helpers with no Flutter dependency, shared by models and the
// domain layer (scheduler, habits, statistics).

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Adds calendar days while keeping the wall-clock time (DST-safe).
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days, d.hour, d.minute, d.second);

String _two(int n) => n.toString().padLeft(2, '0');

/// Stable "yyyy-mm-dd" key for a calendar day.
String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

DateTime? parseDateKey(Object? raw) {
  if (raw is! String) return null;
  final parts = raw.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// First day of the week containing [day]; [firstWeekday] uses DateTime
/// constants (DateTime.saturday / sunday / monday).
DateTime startOfWeekDate(DateTime day, int firstWeekday) {
  final d = dateOnly(day);
  final diff = (d.weekday - firstWeekday + 7) % 7;
  return DateTime(d.year, d.month, d.day - diff);
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// True when [t] is within [start, end).
bool inRange(DateTime t, DateTime start, DateTime end) => !t.isBefore(start) && t.isBefore(end);
