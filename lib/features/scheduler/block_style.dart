import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../data/models/planning_models.dart';
import '../../domain/scheduling/day_agenda.dart';

IconData commitmentIcon(CommitmentType t) => switch (t) {
      CommitmentType.workShift => Icons.work_outline_rounded,
      CommitmentType.flight => Icons.flight_rounded,
      CommitmentType.meeting => Icons.groups_outlined,
      CommitmentType.appointment => Icons.event_outlined,
      CommitmentType.commute => Icons.directions_car_outlined,
      CommitmentType.family => Icons.family_restroom_rounded,
      CommitmentType.personal => Icons.person_outline_rounded,
    };

/// Colour, icon and label for every kind of timeline item.
class AgendaStyle {
  const AgendaStyle(this.color, this.soft, this.icon, this.label);

  final Color color;
  final Color soft;
  final IconData icon;
  final String label;

  static AgendaStyle of(BuildContext context, AgendaItem item) =>
      forKind(context, item.kind, title: item.title, type: item.commitmentType);

  static AgendaStyle forKind(BuildContext context, AgendaKind kind, {String? title, CommitmentType? type}) {
    final p = context.palette;
    String named(String key) => (title != null && title.isNotEmpty) ? title : context.tr(key);
    return switch (kind) {
      AgendaKind.sleep => AgendaStyle(p.sleep, p.sleepSoft, Icons.bedtime_rounded, context.tr('block.sleep')),
      AgendaKind.work => AgendaStyle(p.work, p.workSoft, Icons.work_rounded, context.tr('block.work')),
      AgendaKind.commute =>
        AgendaStyle(p.textSecondary, p.surfaceAlt, Icons.directions_car_rounded, context.tr('block.commute')),
      AgendaKind.commitment => AgendaStyle(
          p.work,
          p.workSoft,
          type == null ? Icons.event_rounded : commitmentIcon(type),
          named(type == null ? 'block.work' : 'commitment.${type.name}'),
        ),
      AgendaKind.task => AgendaStyle(p.accent, p.accentSoft, Icons.check_circle_outline_rounded, named('tasks.title')),
    };
  }
}
