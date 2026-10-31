import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../app/app_controller.dart';
import '../../app/planner_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/surfaces.dart';
import '../../domain/scheduling/day_agenda.dart';
import '../tasks/task_widgets.dart';
import 'block_style.dart';
import 'commitment_sheet.dart';
import 'plan_review.dart';

/// Opens the right editor for a tapped timeline item.
void openAgendaItem(BuildContext context, AgendaItem item) {
  final planner = PlannerScope.read(context);
  switch (item.kind) {
    case AgendaKind.task:
      final t = planner.taskById(item.refId);
      if (t != null) showTaskActions(context, t);
    case AgendaKind.commitment:
    case AgendaKind.commute:
      final c = planner.commitmentById(item.refId);
      if (c != null) showCommitmentSheet(context, initial: c);
    case AgendaKind.sleep:
    case AgendaKind.work:
      break;
  }
}

class SmartSchedulerView extends StatefulWidget {
  const SmartSchedulerView({super.key});

  @override
  State<SmartSchedulerView> createState() => _SmartSchedulerViewState();
}

class _SmartSchedulerViewState extends State<SmartSchedulerView> {
  DateTime _day = TimeUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final profile = AppScope.of(context).profile;
    if (profile == null) return const SizedBox.shrink();
    final planner = PlannerScope.of(context);
    final p = context.palette;

    final items = DayAgenda.build(
      profile: profile,
      commitments: planner.commitments,
      tasks: planner.tasks,
      day: _day,
    );
    final protectedMin = DayAgenda.protectedMinutes(items);
    final taskMin = items.where((i) => i.kind == AgendaKind.task).fold<int>(0, (a, i) => a + i.lengthMin);
    final freeMin = (TimeUtils.minutesPerDay - protectedMin - taskMin).clamp(0, TimeUtils.minutesPerDay).toInt();
    final waiting = planner.tasks.where((t) => !t.isDone && t.scheduledStart == null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DayStrip(selected: _day, onSelect: (d) => setState(() => _day = d)),
        const SizedBox(height: Space.md),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: StatTile(
                  value: TimeUtils.duration(context, protectedMin),
                  label: context.tr('smart.protected'),
                  color: p.sleep,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: TimeUtils.duration(context, taskMin),
                  label: context.tr('smart.planned'),
                  color: p.accent,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: TimeUtils.duration(context, freeMin),
                  label: context.tr('smart.available'),
                ),
              ),
            ],
          ),
        ),
        AppCard(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.lg, Space.lg, Space.lg),
          child: DayTimeline(
            items: items,
            showNow: TimeUtils.isSameDay(_day, DateTime.now()),
            onTap: (i) => openAgendaItem(context, i),
          ),
        ),
        AppButton(
          label: context.tr('smart.generate'),
          icon: Icons.auto_fix_high_rounded,
          onPressed: () => reviewPlan(context),
        ),
        const SizedBox(height: Space.sm),
        AppButton(
          label: context.tr('smart.reshuffle'),
          tone: ButtonTone.plain,
          onPressed: () => reviewPlan(context, reshuffle: true),
        ),
        Text(context.tr('smart.generateNote'), style: context.text.bodySmall, textAlign: TextAlign.center),
        SectionHeader(context.tr('smart.unscheduled')),
        AppCard(
          padding: waiting.isEmpty
              ? const EdgeInsets.all(Space.lg)
              : const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
          child: waiting.isEmpty
              ? EmptyState(
                  icon: Icons.inbox_outlined,
                  title: context.tr('smart.unscheduledEmpty'),
                  message: context.tr('smart.unscheduledBody'),
                )
              : Column(children: [for (final t in waiting) TaskTile(task: t)]),
        ),
        SectionHeader(context.tr('smart.rulesTitle')),
        AppCard(
          child: Column(
            children: [
              _Rule(icon: Icons.lock_outline_rounded, color: p.work, text: context.tr('smart.rule1')),
              _Rule(icon: Icons.bedtime_outlined, color: p.sleep, text: context.tr('smart.rule2')),
              _Rule(icon: Icons.priority_high_rounded, color: p.danger, text: context.tr('smart.rule3')),
              _Rule(icon: Icons.air_rounded, color: p.accent, text: context.tr('smart.rule4')),
              _Rule(icon: Icons.fact_check_outlined, color: p.focus, text: context.tr('smart.rule5'), last: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.color, required this.text, this.last = false});

  final IconData icon;
  final Color color;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: Space.md),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.selected, required this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final today = TimeUtils.dateOnly(DateTime.now());
    final tag = context.localeTag;
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
        itemBuilder: (context, i) {
          final d = DateTime(today.year, today.month, today.day + i);
          final isSel = TimeUtils.isSameDay(d, selected);
          return GestureDetector(
            onTap: () => onSelect(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 52,
              decoration: BoxDecoration(
                color: isSel ? p.textPrimary : p.surface,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.E(tag).format(d),
                    style: context.text.labelSmall?.copyWith(color: isSel ? p.background : p.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.d(tag).format(d),
                    style: context.text.titleMedium?.copyWith(color: isSel ? p.background : p.textPrimary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Vertical 24-hour timeline with positioned items. Mirrors in RTL.
class DayTimeline extends StatelessWidget {
  const DayTimeline({super.key, required this.items, this.hourHeight = 44, this.showNow = true, this.onTap});

  final List<AgendaItem> items;
  final double hourHeight;
  final bool showNow;
  final ValueChanged<AgendaItem>? onTap;

  static const double _labelWidth = 52;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final total = hourHeight * 24;

    // Background items first, then commitments, then tasks on top.
    final ordered = [...items]..sort((a, b) => a.kind.index.compareTo(b.kind.index));

    return SizedBox(
      height: total,
      child: Stack(
        children: [
          for (var h = 0; h <= 23; h++)
            PositionedDirectional(
              top: h * hourHeight,
              start: 0,
              end: 0,
              height: hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _labelWidth,
                    child: Transform.translate(
                      offset: const Offset(0, -7),
                      child: Text(
                        h == 0 ? '' : TimeUtils.clock(context, h * 60),
                        style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  Expanded(child: Container(height: 0.5, color: p.separator)),
                ],
              ),
            ),
          for (final it in ordered)
            PositionedDirectional(
              top: it.startMin / 60 * hourHeight + 1,
              height: (it.lengthMin / 60 * hourHeight - 2).clamp(6.0, total),
              start: _labelWidth + 4 + (it.kind == AgendaKind.task ? 14 : 0),
              end: 0,
              child: GestureDetector(
                onTap: onTap == null ? null : () => onTap!(it),
                child: _ItemTile(item: it),
              ),
            ),
          if (showNow)
            PositionedDirectional(
              top: nowMin / 60 * hourHeight - 4,
              start: _labelWidth - 4,
              end: 0,
              height: 8,
              child: IgnorePointer(
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: p.danger, shape: BoxShape.circle)),
                    Expanded(child: Container(height: 1.5, color: p.danger)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final AgendaItem item;

  @override
  Widget build(BuildContext context) {
    final s = AgendaStyle.of(context, item);
    final tall = item.lengthMin >= 30;
    final faded = item.done;
    return Opacity(
      opacity: faded ? 0.5 : 1,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: item.kind == AgendaKind.task ? s.color.withValues(alpha: 0.16) : s.soft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(width: 3, color: s.color),
            const SizedBox(width: 8),
            if (tall) ...[
              Icon(item.done ? Icons.check_circle_rounded : s.icon, size: 14, color: s.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${s.label} · ${TimeUtils.clock(context, item.startMin)}–${TimeUtils.clock(context, item.endMin % 1440)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: s.color,
                    fontWeight: FontWeight.w600,
                    decoration: item.done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}
