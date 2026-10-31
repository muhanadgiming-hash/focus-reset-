import '../../data/models/planning_models.dart';
import '../../data/models/user_profile.dart';
import 'fixed_blocks.dart';

enum AgendaKind { sleep, work, commute, commitment, task }

/// One item on a single day's timeline, in minutes since that midnight.
class AgendaItem {
  const AgendaItem({
    required this.startMin,
    required this.endMin,
    required this.kind,
    this.title,
    this.refId,
    this.done = false,
    this.commitmentType,
  });

  final int startMin;
  final int endMin;
  final AgendaKind kind;
  final String? title;

  /// Id of the task or commitment this item came from.
  final String? refId;
  final bool done;
  final CommitmentType? commitmentType;

  int get lengthMin => endMin - startMin;
}

/// Builds the timeline for one calendar day from the profile (sleep, fixed
/// work), commitments (with prep/travel) and scheduled tasks.
abstract final class DayAgenda {
  static List<AgendaItem> build({
    required UserProfile profile,
    required List<Commitment> commitments,
    required List<TaskItem> tasks,
    required DateTime day,
  }) {
    final items = <AgendaItem>[
      for (final b in FixedBlocks.forDay(profile, day))
        AgendaItem(
          startMin: b.startMin,
          endMin: b.endMin,
          kind: switch (b.kind) {
            BlockKind.sleep => AgendaKind.sleep,
            BlockKind.work => AgendaKind.work,
            BlockKind.commute => AgendaKind.commute,
          },
        ),
    ];

    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day + 1);

    void add(DateTime s, DateTime e, AgendaKind kind,
        {String? title, String? refId, bool done = false, CommitmentType? type}) {
      if (!e.isAfter(dayStart) || !s.isBefore(dayEnd)) return;
      final cs = s.isBefore(dayStart) ? dayStart : s;
      final ce = e.isAfter(dayEnd) ? dayEnd : e;
      final sm = cs.difference(dayStart).inMinutes;
      final em = ce.difference(dayStart).inMinutes.clamp(0, 1440).toInt();
      if (em <= sm) return;
      items.add(AgendaItem(
        startMin: sm,
        endMin: em,
        kind: kind,
        title: title,
        refId: refId,
        done: done,
        commitmentType: type,
      ));
    }

    for (final c in commitments) {
      add(c.busyStart, c.start, AgendaKind.commute, refId: c.id);
      add(c.start, c.end, AgendaKind.commitment, title: c.title, refId: c.id, type: c.type);
      add(c.end, c.end.add(Duration(minutes: c.travelMin)), AgendaKind.commute, refId: c.id);
    }
    for (final t in tasks) {
      final s = t.scheduledStart;
      if (s == null) continue;
      add(s, t.scheduledEnd!, AgendaKind.task, title: t.title, refId: t.id, done: t.isDone);
    }

    items.sort((a, b) => a.startMin.compareTo(b.startMin));
    return items;
  }

  /// Minutes of the day covered by any non-task item (overlaps once).
  static int protectedMinutes(List<AgendaItem> items) {
    final covered = List<bool>.filled(1440, false);
    for (final i in items) {
      if (i.kind == AgendaKind.task) continue;
      for (var m = i.startMin; m < i.endMin && m < 1440; m++) {
        covered[m] = true;
      }
    }
    return covered.where((c) => c).length;
  }
}
