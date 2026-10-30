import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/surfaces.dart';
import '../../domain/scheduling/fixed_blocks.dart';
import 'block_style.dart';
import 'commitment_sheet.dart';

/// Seven-day overview of protected time (sleep, work, commute) and,
/// from Phase 2, commitments and scheduled tasks.
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
    final p = context.palette;
    final tag = context.localeTag;

    final start = TimeUtils.startOfWeek(DateTime.now(), profile.firstWeekday).add(Duration(days: 7 * _weekOffset));
    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    final end = days.last;
    final range = '${DateFormat.MMMd(tag).format(start)} – ${DateFormat.MMMd(tag).format(end)}';

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
                              for (final b in FixedBlocks.forDay(profile, d))
                                PositionedDirectional(
                                  top: b.startMin / 60 * hourH,
                                  height: b.lengthMin / 60 * hourH,
                                  start: 0,
                                  end: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: BlockStyle.of(context, b.kind).color.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(4),
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
                  for (final k in BlockKind.values) _Legend(kind: k),
                ],
              ),
            ],
          ),
        ),
        SectionHeader(
          context.tr('week.commitments'),
          actionLabel: context.tr('common.add'),
          onAction: () => showCommitmentSheet(context),
        ),
        AppCard(
          child: EmptyState(
            icon: Icons.flight_takeoff_rounded,
            color: p.work,
            title: context.tr('week.noCommitments'),
            message: context.tr('week.noCommitmentsBody'),
            actionLabel: context.tr('plan.addCommitment'),
            onAction: () => showCommitmentSheet(context),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.kind});

  final BlockKind kind;

  @override
  Widget build(BuildContext context) {
    final s = BlockStyle.of(context, kind);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(context.tr(s.labelKey), style: context.text.labelMedium),
      ],
    );
  }
}
