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
import '../progress/progress_screen.dart';
import '../settings/settings_screen.dart';
import '../shell/main_shell.dart';
import '../sleep/sleep_screen.dart';

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

    final p = context.palette;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final dateLabel = DateFormat.MMMMEEEEd(context.localeTag).format(now);
    final shell = ShellScope.maybeOf(context);

    final blocks = FixedBlocks.forDay(profile, now);
    final upcoming = blocks.where((b) => b.endMin > nowMin && b.kind != BlockKind.commute).toList();
    final next = upcoming.isEmpty ? null : upcoming.first;
    final untilBed = (profile.bedtimeMin - nowMin + 1440) % 1440;

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
        // Today summary — real counts; zero until the user creates items.
        AppCard(
          padding: const EdgeInsets.all(Space.xl),
          child: Row(
            children: [
              ProgressRing(
                value: null,
                color: p.accent,
                size: 92,
                center: Text('—', style: context.text.titleLarge),
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
                        Expanded(child: StatTile(value: '0', label: context.tr('home.tasksDone'))),
                        Expanded(
                          child: StatTile(
                            value: '0/${profile.dailyFocusGoalMin}',
                            label: context.tr('home.focusMin'),
                            color: p.focus,
                          ),
                        ),
                      ],
                    ),
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
          child: next == null
              ? EmptyState(
                  icon: Icons.event_available_rounded,
                  title: context.tr('home.clearTitle'),
                  message: context.tr('home.clearBody'),
                  actionLabel: context.tr('home.addTask'),
                  onAction: () => shell?.select(AppTab.tasks),
                )
              : _BlockRow(block: next),
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
              onTap: () => shell?.select(AppTab.tasks),
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

class _BlockRow extends StatelessWidget {
  const _BlockRow({required this.block});

  final TimeBlock block;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (icon, color, soft, key) = switch (block.kind) {
      BlockKind.sleep => (Icons.bedtime_rounded, p.sleep, p.sleepSoft, 'block.sleep'),
      BlockKind.work => (Icons.work_rounded, p.work, p.workSoft, 'block.work'),
      BlockKind.commute => (Icons.directions_car_rounded, p.textSecondary, p.surfaceAlt, 'block.commute'),
    };
    return Row(
      children: [
        IconBadge(icon: icon, color: color, background: soft, size: 44),
        const SizedBox(width: Space.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr(key), style: context.text.titleSmall),
              const SizedBox(height: 2),
              Text(
                '${TimeUtils.clock(context, block.startMin)} – ${TimeUtils.clock(context, block.endMin % 1440)}',
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
        StatusPill(context.tr('block.fixed')),
      ],
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
