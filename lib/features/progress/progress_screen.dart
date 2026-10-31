import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/planner_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_key.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/surfaces.dart';
import '../../domain/stats/progress_stats.dart';
import '../onboarding/onboarding_options.dart';

enum ProgressRange { week, month }

/// Progress & Reports. Every figure is computed from the user's own
/// records; with no activity the screen shows "—" — never sample numbers.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressRange _range = ProgressRange.week;

  String _pct(double? v) => v == null ? '—' : '${(v * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final planner = PlannerScope.of(context);
    final first = AppScope.of(context).profile?.firstWeekday ?? DateTime.sunday;
    final now = DateTime.now();

    final weekStart = startOfWeekDate(now, first);
    final weekEnd = addDays(weekStart, 7);
    final lastWeekStart = addDays(weekStart, -7);
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);

    PeriodStats stats(DateTime s, DateTime e) => ProgressStats.forPeriod(
          tasks: planner.tasks,
          sessions: planner.focusSessions,
          habits: planner.habits,
          habitLogs: planner.habitLogs,
          start: s,
          end: e,
          now: now,
        );

    final current = _range == ProgressRange.week ? stats(weekStart, weekEnd) : stats(monthStart, monthEnd);
    final thisWeek = stats(weekStart, weekEnd);
    final lastWeek = stats(lastWeekStart, weekStart);

    final dayLabels = [for (final d in OnbOptions.weekOrder(first)) OnbOptions.weekdayShort(context, d)];
    final tasksPerDay = ProgressStats.tasksPerDay(planner.tasks, weekStart);
    final focusPerDay = ProgressStats.focusPerDay(planner.focusSessions, weekStart);
    final todayIdx = dateOnly(now).difference(weekStart).inHours ~/ 24;
    final parts = ProgressStats.byDayPart(planner.tasks, planner.focusSessions, addDays(dateOnly(now), -28));
    final bestPart = parts.every((v) => v == 0) ? null : parts.indexOf(parts.reduce((a, b) => a > b ? a : b));
    final partKeys = ['daypart.morning', 'daypart.afternoon', 'daypart.evening', 'daypart.night'];

    final hasAny = planner.tasks.any((t) => t.isDone) || planner.focusSessions.isNotEmpty || planner.habitLogs.isNotEmpty;

    String delta(int a, int b) {
      if (b == 0) return a == 0 ? '—' : '+$a';
      final d = ((a - b) / b * 100).round();
      return d >= 0 ? '+$d%' : '$d%';
    }

    return PageScaffold(
      showBack: true,
      title: context.tr('progress.title'),
      children: [
        Segmented<ProgressRange>(
          value: _range,
          items: {
            ProgressRange.week: context.tr('progress.week'),
            ProgressRange.month: context.tr('progress.month'),
          },
          onChanged: (v) => setState(() => _range = v),
        ),
        const SizedBox(height: Space.lg),
        if (!hasAny)
          AppCard(
            color: p.accentSoft,
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: p.accent, size: 20),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(context.tr('progress.noData'), style: context.text.bodySmall?.copyWith(color: p.textPrimary)),
                ),
              ],
            ),
          ),
        AppCard(
          padding: const EdgeInsets.all(Space.xl),
          child: Row(
            children: [
              _RingStat(label: context.tr('progress.tasks'), color: p.accent, value: current.taskRate, text: _pct(current.taskRate)),
              _RingStat(
                label: context.tr('progress.focus'),
                color: p.focus,
                value: null,
                text: TimeUtils.duration(context, current.focusMinutes),
              ),
              _RingStat(label: context.tr('progress.habits'), color: p.habit, value: current.habitRate, text: _pct(current.habitRate)),
            ],
          ),
        ),
        AppCard(
          child: Row(
            children: [
              Expanded(child: StatTile(value: '${current.focusSessions}', label: context.tr('progress.sessions'), color: p.focus)),
              Expanded(
                child: StatTile(value: '${current.tasksDone}', label: context.tr('progress.tasksDone'), color: p.accent),
              ),
              Expanded(
                child: StatTile(
                  value: current.habitsDue == 0 ? '—' : '${current.habitsDone}/${current.habitsDue}',
                  label: context.tr('progress.habitChecks'),
                  color: p.habit,
                ),
              ),
            ],
          ),
        ),
        SectionHeader(context.tr('progress.daily')),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('progress.tasksDone'), style: context.text.labelMedium),
              const SizedBox(height: Space.md),
              MiniBarChart(
                values: tasksPerDay,
                labels: dayLabels,
                color: p.accent,
                height: 90,
                highlightIndex: todayIdx >= 0 && todayIdx < 7 ? todayIdx : null,
              ),
              const SizedBox(height: Space.lg),
              Text(context.tr('progress.focusMinutes'), style: context.text.labelMedium),
              const SizedBox(height: Space.md),
              MiniBarChart(
                values: focusPerDay,
                labels: dayLabels,
                color: p.focus,
                height: 90,
                highlightIndex: todayIdx >= 0 && todayIdx < 7 ? todayIdx : null,
              ),
            ],
          ),
        ),
        SectionHeader(context.tr('progress.compare')),
        AppCard(
          child: Column(
            children: [
              _CompareRow(
                label: context.tr('progress.tasksDone'),
                thisWeek: '${thisWeek.tasksDone}',
                lastWeek: '${lastWeek.tasksDone}',
                delta: delta(thisWeek.tasksDone, lastWeek.tasksDone),
              ),
              const SizedBox(height: Space.md),
              _CompareRow(
                label: context.tr('progress.focusTime'),
                thisWeek: TimeUtils.duration(context, thisWeek.focusMinutes),
                lastWeek: TimeUtils.duration(context, lastWeek.focusMinutes),
                delta: delta(thisWeek.focusMinutes, lastWeek.focusMinutes),
              ),
            ],
          ),
        ),
        SectionHeader(context.tr('progress.bestTime')),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bestPart == null
                    ? context.tr('progress.bestTimeEmpty')
                    : context.tr('progress.bestTimeIs', {'p': context.tr(partKeys[bestPart])}),
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: Space.md),
              MiniBarChart(
                values: parts,
                labels: [for (final k in partKeys) context.tr(k)],
                color: p.focus,
                height: 80,
                highlightIndex: bestPart,
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        AppButton(
          label: context.tr('progress.export'),
          tone: ButtonTone.secondary,
          icon: Icons.ios_share_rounded,
          onPressed: () => showPhaseNotice(context, 3),
        ),
      ],
    );
  }
}

class _RingStat extends StatelessWidget {
  const _RingStat({required this.label, required this.color, required this.value, required this.text});

  final String label;
  final Color color;
  final double? value;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          ProgressRing(
            value: value,
            color: color,
            size: 78,
            stroke: 8,
            center: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(child: Text(text, style: context.text.titleSmall)),
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(label, style: context.text.labelMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.label, required this.thisWeek, required this.lastWeek, required this.delta});

  final String label;
  final String thisWeek;
  final String lastWeek;
  final String delta;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final positive = delta.startsWith('+');
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.titleSmall),
              Text(context.tr('progress.vsLast', {'v': lastWeek}), style: context.text.bodySmall),
            ],
          ),
        ),
        Expanded(flex: 2, child: Text(thisWeek, style: context.text.titleMedium, textAlign: TextAlign.end)),
        const SizedBox(width: Space.md),
        StatusPill(
          delta,
          color: delta == '—' ? null : (positive ? p.success : p.danger),
          background: delta == '—' ? null : (positive ? p.success : p.danger).withValues(alpha: 0.12),
        ),
      ],
    );
  }
}
