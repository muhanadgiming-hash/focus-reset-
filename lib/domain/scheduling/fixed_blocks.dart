import '../../data/models/user_profile.dart';

/// Pure scheduling-domain code. No widgets, no I/O — fully unit-testable.

enum BlockKind { sleep, work, commute }

/// A half-open interval [startMin, endMin) within a single calendar day,
/// in minutes since midnight.
class TimeBlock {
  const TimeBlock(this.startMin, this.endMin, this.kind)
      : assert(startMin >= 0 && endMin <= 1440 && startMin < endMin);

  final int startMin;
  final int endMin;
  final BlockKind kind;

  int get lengthMin => endMin - startMin;

  bool overlaps(TimeBlock other) => startMin < other.endMin && other.startMin < endMin;

  @override
  bool operator ==(Object other) =>
      other is TimeBlock && other.startMin == startMin && other.endMin == endMin && other.kind == kind;

  @override
  int get hashCode => Object.hash(startMin, endMin, kind);

  @override
  String toString() => 'TimeBlock($kind $startMin-$endMin)';
}

/// Derives the protected, non-movable blocks for a given day from the
/// user's profile: sleep, fixed working hours and commute buffers.
///
/// These are the "hard constraints" the Phase 2 scheduler plans around.
/// Overnight ranges (e.g. sleep 23:00 → 07:00 or a 22:00 → 06:00 shift)
/// are split correctly across the two calendar days.
abstract final class FixedBlocks {
  static List<TimeBlock> forDay(UserProfile p, DateTime day) {
    final blocks = <TimeBlock>[
      ..._sleep(p),
      ..._work(p, day),
    ];
    blocks.sort((a, b) => a.startMin.compareTo(b.startMin));
    return blocks;
  }

  static List<TimeBlock> _sleep(UserProfile p) {
    final bed = p.bedtimeMin % 1440;
    final wake = p.wakeMin % 1440;
    if (bed == wake) return const [];
    if (bed > wake) {
      // Overnight: tail of last night + start of tonight.
      return [
        if (wake > 0) TimeBlock(0, wake, BlockKind.sleep),
        TimeBlock(bed, 1440, BlockKind.sleep),
      ];
    }
    // Daytime sleeper, e.g. after a night shift.
    return [TimeBlock(bed, wake, BlockKind.sleep)];
  }

  static List<TimeBlock> _work(UserProfile p, DateTime day) {
    if (p.workPattern != WorkPattern.fixed || p.workDays.isEmpty) return const [];
    final start = p.workStartMin % 1440;
    final end = p.workEndMin % 1440;
    if (start == end) return const [];

    final buffer = p.commuteBufferMin.clamp(0, 180);
    final today = day.weekday;
    final yesterday = today == DateTime.monday ? DateTime.sunday : today - 1;
    final out = <TimeBlock>[];

    if (start < end) {
      if (p.workDays.contains(today)) {
        if (buffer > 0 && start - buffer >= 0) {
          out.add(TimeBlock(start - buffer, start, BlockKind.commute));
        }
        out.add(TimeBlock(start, end, BlockKind.work));
        if (buffer > 0 && end + buffer <= 1440) {
          out.add(TimeBlock(end, end + buffer, BlockKind.commute));
        }
      }
      return out;
    }

    // Overnight shift: starts today, ends tomorrow.
    if (p.workDays.contains(yesterday) && end > 0) {
      out.add(TimeBlock(0, end, BlockKind.work));
      if (buffer > 0 && end + buffer <= 1440) {
        out.add(TimeBlock(end, end + buffer, BlockKind.commute));
      }
    }
    if (p.workDays.contains(today)) {
      if (buffer > 0 && start - buffer >= 0) {
        out.add(TimeBlock(start - buffer, start, BlockKind.commute));
      }
      out.add(TimeBlock(start, 1440, BlockKind.work));
    }
    return out;
  }

  /// Total protected minutes for the day (overlaps counted once).
  static int protectedMinutes(List<TimeBlock> blocks) {
    final covered = List<bool>.filled(1440, false);
    for (final b in blocks) {
      for (var i = b.startMin; i < b.endMin; i++) {
        covered[i] = true;
      }
    }
    return covered.where((c) => c).length;
  }
}
