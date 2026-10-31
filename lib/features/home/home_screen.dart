import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../app/app_controller.dart';
import '../../app/planner_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_key.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/surfaces.dart';
import '../../domain/habits/habit_logic.dart';
import '../../domain/scheduling/day_agenda.dart';
import '../progress/progress_screen.dart';
import '../scheduler/block_style.dart';
import '../scheduler/smart_scheduler_view.dart' show openAgendaItem;
import '../settings/settings_screen.dart';
import '../shell/main_shell.dart';
import '../sleep/sleep_screen.dart';
import '../tasks/task_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greetingKey(DateTime now) {
    if (now.hour >= 5 && now.hour < 12) return 'home.goodMorning';
    if (now.hour >= 12 && now.hour < 17) return 'home.goodAfternoon';
    return 'home.goodEvening';
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppScope.of(context).profile;
    if (profile == null) return const SizedBox.shrink();
    final planner = PlannerScope.of(context);

    final p = context.palette;
    final now = DateTime.now();
    final today = dateOnly(now);
    final tomorrow = addDays(today, 1);
    final nowMin = now.hour * 60 + now.minute;
    final dateLabel = DateFormat.MMMMEEEEd(context.localeTag).format(now);
    final shell = ShellScope.maybeOf(context);

    // Today's numbers — from the user's own records only.
    final plannedToday = planner.tasks.where((t) {
      final s = t.scheduledStart;
      final c = t.completedAt;
      return (s != null && !s.isBefore(today) && s.isBefore(tomorrow)) ||
          (t.isDone && c != null && !c.isBefore(today));
    }).toList();
    final doneToday = plannedToday.where((t) => t.isDone).length;
    final focusToday = planner.focusSessions
        .where((s) => !s.start.isBefore(today))
        .fold<int>(0, (a, s) => a + s.actualMin);
    final habitsDue = planner.habits.where((h) => HabitLogic.isScheduledOn(h, today)).toList();
    final habitsDone = habitsDue.where((h) => HabitLogic.doneOn(h, planner.habitLog(h.id), today)).length;
    final overall = [
      if (plannedToday.isNotEmpty) doneToday / plannedToday.length,
      if (profile.dailyFocusGoalMin > 0) (focusToday / profile.dailyFocusGoalMin).clamp(0.0, 1.0).toDouble(),
      if (habitsDue.isNotEmpty) habitsDone / habitsDue.length,
    ];
    final ring = (overall.isEmpty || (plannedToday.isEmpty && focusToday == 0 && habitsDone == 0))
        ? null
        : overall.reduce((a, b) => a + b) / overall.length;

    final agenda = DayAgenda.build(
      profile: profile,
      commitments: planner.commitments,
      tasks: planner.tasks,
      day: today,
    );
    final upcoming = agenda
        .where((i) => i.endMin > nowMin && i.kind != AgendaKind.sleep && i.kind != AgendaKind.commute && !i.done)
        .take(4)
        .toList();
    final untilBed = (profile.bedtimeMin - nowMin + 1440) % 1440;
    final waiting = planner.tasks.where((t) => !t.isDone && t.scheduledStart == null).length;

    return PageScaffold(
      subtitle: dateLabel,
      title: context.tr(_greetingKey(now), {'name': profile.name}),
      actions: [
        AppIconButton(
          icon: Icons.insights_rounded,
          semanticLabel: context.tr('progress.title'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProgressScreen())),
        ),
        const SizedBox(width: Space.sm),
        AppIconButton(
          icon: Icons.person_outline_rounded,
          semanticLabel: context.tr('settings.title'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ],
      children: [
        AppCard(
          padding: const EdgeInsets.all(Space.xl),
          child: Row(
            children: [
              ProgressRing(
                value: ring,
                color: p.accent,
                size: 92,
                center: Text(ring == null ? '—' : '${(ring * 100).round()}%', style: context.text.titleLarge),
              ),
              const SizedBox(width: Space.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('home.todayProgress'), style: context.text.titleMedium),
                    const SizedBox(height: Space.md),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            value: '$doneToday/${plannedToday.length}',
                            label: context.tr('home.tasksDone'),
                          ),
                        ),
                        Expanded(
                          child: StatTile(
                            value: '$focusToday/${profile.dailyFocusGoalMin}',
                            label: context.tr('home.focusMin'),
                            color: p.focus,
                          ),
                        ),
                      ],
                    ),
                    if (habitsDue.isNotEmpty) ...[
                      const SizedBox(height: Space.sm),
                      Text(
                        context.tr('home.habitsLine', {'n': '$habitsDone', 'total': '${habitsDue.length}'}),
                        style: context.text.bodySmall?.copyWith(color: p.habit),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        SectionHeader(
          context.tr('home.upNext'),
          actionLabel: context.tr('home.openPlan'),
          onAction: () => shell?.select(AppTab.plan),
        ),
        AppCard(
          padding: upcoming.isEmpty
              ? const EdgeInsets.all(Space.lg)
              : const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
          child: upcoming.isEmpty
              ? EmptyState(
                  icon: Icons.event_available_rounded,
                  title: context.tr('home.clearTitle'),
                  message: context.tr('home.clearBody'),
                  actionLabel: context.tr('home.addTask'),
                  onAction: () => showTaskEditor(context),
                )
              : Column(
                  children: [
                    for (final i in upcoming) _AgendaRow(item: i, isNow: i.startMin <= nowMin),
                  ],
                ),
        ),
        if (waiting > 0)
          AppCard(
            onTap: () => shell?.select(AppTab.plan),
            child: Row(
              children: [
                IconBadge(icon: Icons.inbox_outlined, color: p.habit, background: p.habitSoft),
                const SizedBox(width: Space.md),
                Expanded(child: Text(context.tr('home.waiting', {'n': '$waiting'}), style: context.text.bodyMedium)),
                const ForwardChevron(),
              ],
            ),
          ),

        SectionHeader(context.tr('home.tonight')),
        AppCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SleepScreen())),
          child: Row(
            children: [
              IconBadge(icon: Icons.bedtime_rounded, color: p.sleep, background: p.sleepSoft, size: 44),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('home.bedtimeAt', {'t': TimeUtils.clock(context, profile.bedtimeMin)}),
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('home.windDownIn', {'d': TimeUtils.duration(context, untilBed)}),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              const ForwardChevron(),
            ],
          ),
        ),

        SectionHeader(context.tr('home.quickActions')),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.md,
          crossAxisSpacing: Space.md,
          childAspectRatio: 1.7,
          children: [
            _QuickAction(
              icon: Icons.timer_rounded,
              color: p.focus,
              soft: p.focusSoft,
              label: context.tr('home.qaFocus'),
              onTap: () => shell?.select(AppTab.focus),
            ),
            _QuickAction(
              icon: Icons.add_task_rounded,
              color: p.accent,
              soft: p.accentSoft,
              label: context.tr('home.qaTask'),
              onTap: () => showTaskEditor(context),
            ),
            _QuickAction(
              icon: Icons.view_week_rounded,
              color: p.work,
              soft: p.workSoft,
              label: context.tr('home.qaWeek'),
              onTap: () => shell?.select(AppTab.plan),
            ),
            _QuickAction(
              icon: Icons.local_fire_department_rounded,
              color: p.habit,
              soft: p.habitSoft,
              label: context.tr('home.qaHabits'),
              onTap: () => shell?.select(AppTab.habits),
            ),
          ],
        ),
      ],
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.item, required this.isNow});

  final AgendaItem item;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final s = AgendaStyle.of(context, item);
    return InkWell(
      onTap: () => openAgendaItem(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          children: [
            IconBadge(icon: s.icon, color: s.color, background: s.soft, size: 40),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.label, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${TimeUtils.clock(context, item.startMin)} – ${TimeUtils.clock(context, item.endMin % 1440)}',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            if (isNow)
              StatusPill(context.tr('home.now'), color: s.color, background: s.soft)
            else if (item.kind != AgendaKind.task)
              StatusPill(context.tr('block.fixed')),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.color, required this.soft, required this.label, required this.onTap});

  final IconData icon;
  final Color color;
  final Color soft;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconBadge(icon: icon, color: color, background: soft, size: 32),
          Text(label, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
