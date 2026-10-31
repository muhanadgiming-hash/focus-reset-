import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../app/app_controller.dart';
import '../../app/planner_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/surfaces.dart';
import '../../domain/scheduling/day_agenda.dart';
import 'block_style.dart';
import 'commitment_sheet.dart';
import 'smart_scheduler_view.dart' show openAgendaItem;

/// Seven-day overview: sleep, work, commitments and planned tasks.
class WeeklyScheduleView extends StatefulWidget {
  const WeeklyScheduleView({super.key});

  @override
  State<WeeklyScheduleView> createState() => _WeeklyScheduleViewState();
}

class _WeeklyScheduleViewState extends State<WeeklyScheduleView> {
  int _weekOffset = 0;

  @override
  Widget build(BuildContext context) {
    final profile = AppScope.of(context).profile;
    if (profile == null) return const SizedBox.shrink();
    final planner = PlannerScope.of(context);
    final p = context.palette;
    final tag = context.localeTag;

    final base = TimeUtils.startOfWeek(DateTime.now(), profile.firstWeekday);
    final start = DateTime(base.year, base.month, base.day + 7 * _weekOffset);
    final days = List.generate(7, (i) => DateTime(start.year, start.month, start.day + i));
    final weekEnd = DateTime(start.year, start.month, start.day + 7);
    final range = '${DateFormat.MMMd(tag).format(start)} – ${DateFormat.MMMd(tag).format(days.last)}';
    final weekCommitments =
        planner.commitments.where((c) => c.end.isAfter(start) && c.start.isBefore(weekEnd)).toList();

    const hourH = 22.0;
    const labelW = 34.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppIconButton(
              icon: context.isRtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
              semanticLabel: context.tr('week.previous'),
              onTap: () => setState(() => _weekOffset--),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _weekOffset = 0),
                child: Column(
                  children: [
                    Text(range, style: context.text.titleSmall),
                    if (_weekOffset != 0)
                      Text(context.tr('week.backToThis'), style: context.text.labelMedium?.copyWith(color: p.accent)),
                  ],
                ),
              ),
            ),
            AppIconButton(
              icon: context.isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              semanticLabel: context.tr('week.next'),
              onTap: () => setState(() => _weekOffset++),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        AppCard(
          padding: const EdgeInsets.fromLTRB(Space.sm, Space.md, Space.sm, Space.md),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: labelW),
                  for (final d in days)
                    Expanded(
                      child: Column(
                        children: [
                          Text(DateFormat.E(tag).format(d), style: context.text.labelSmall),
                          const SizedBox(height: 4),
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: TimeUtils.isSameDay(d, DateTime.now()) ? p.accent : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              DateFormat.d(tag).format(d),
                              style: context.text.labelLarge?.copyWith(
                                fontSize: 13,
                                color: TimeUtils.isSameDay(d, DateTime.now()) ? Colors.white : p.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
              SizedBox(
                height: hourH * 24,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: labelW,
                      child: Stack(
                        children: [
                          for (var h = 0; h < 24; h += 3)
                            PositionedDirectional(
                              top: h * hourH,
                              start: 0,
                              child: Text(
                                DateFormat.j(tag).format(DateTime(2000, 1, 1, h)),
                                style: context.text.labelSmall?.copyWith(fontSize: 9.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final d in days)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: p.surfaceAlt.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Stack(
                            children: [
                              for (final it in (DayAgenda.build(
                                profile: profile,
                                commitments: planner.commitments,
                                tasks: planner.tasks,
                                day: d,
                              )..sort((a, b) => a.kind.index.compareTo(b.kind.index))))
                                PositionedDirectional(
                                  top: it.startMin / 60 * hourH,
                                  height: (it.lengthMin / 60 * hourH).clamp(2.0, hourH * 24),
                                  start: it.kind == AgendaKind.task ? 3 : 0,
                                  end: it.kind == AgendaKind.task ? 3 : 0,
                                  child: GestureDetector(
                                    onTap: () => openAgendaItem(context, it),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AgendaStyle.of(context, it)
                                            .color
                                            .withValues(alpha: it.kind == AgendaKind.task ? (it.done ? 0.4 : 1.0) : 0.7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.md),
              Wrap(
                spacing: Space.lg,
                runSpacing: Space.xs,
                alignment: WrapAlignment.center,
                children: [
                  for (final k in const [AgendaKind.sleep, AgendaKind.work, AgendaKind.commute, AgendaKind.task])
                    _Legend(kind: k),
                ],
              ),
            ],
          ),
        ),
        SectionHeader(
          context.tr('week.commitments'),
          actionLabel: context.tr('common.add'),
          onAction: () => showCommitmentSheet(context, day: start.isAfter(DateTime.now()) ? start : null),
        ),
        if (weekCommitments.isEmpty)
          AppCard(
            child: EmptyState(
              icon: Icons.flight_takeoff_rounded,
              color: p.work,
              title: context.tr('week.noCommitments'),
              message: context.tr('week.noCommitmentsBody'),
              actionLabel: context.tr('plan.addCommitment'),
              onAction: () => showCommitmentSheet(context),
            ),
          )
        else
          for (final c in weekCommitments)
            AppCard(
              onTap: () => showCommitmentSheet(context, initial: c),
              child: Row(
                children: [
                  IconBadge(icon: commitmentIcon(c.type), color: p.work, background: p.workSoft, size: 40),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          '${TimeUtils.dayTime(context, c.start)} → ${DateFormat.jm(tag).format(c.end)}',
                          style: context.text.bodySmall,
                        ),
                        if (c.utcOffsetMin != null)
                          Text(
                            context.tr('commitment.inZone', {
                              'z': utcOffsetLabel(c.utcOffsetMin!),
                              't': DateFormat.jm(tag).format(instantToWall(c.start, c.utcOffsetMin)),
                            }),
                            style: context.text.bodySmall?.copyWith(color: p.accent),
                          ),
                      ],
                    ),
                  ),
                  const ForwardChevron(),
                ],
              ),
            ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.kind});

  final AgendaKind kind;

  @override
  Widget build(BuildContext context) {
    final s = AgendaStyle.forKind(context, kind);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(s.label, style: context.text.labelMedium),
      ],
    );
  }
}
