import 'package:flutter/material.dart';

import '../../app/planner_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_key.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models/planning_models.dart';
import '../scheduler/plan_review.dart';
import 'task_widgets.dart';

export 'task_widgets.dart' show showTaskEditor;

enum TaskFilter { today, upcoming, unscheduled, done }

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  TaskFilter _filter = TaskFilter.today;

  List<TaskItem> _visible(List<TaskItem> all) {
    final now = DateTime.now();
    final today = dateOnly(now);
    final tomorrow = addDays(today, 1);
    int byTime(TaskItem a, TaskItem b) {
      final sa = a.scheduledStart;
      final sb = b.scheduledStart;
      if (sa != null && sb != null) return sa.compareTo(sb);
      if (sa != null) return -1;
      if (sb != null) return 1;
      return b.priority.index.compareTo(a.priority.index);
    }

    switch (_filter) {
      case TaskFilter.today:
        final open = all.where((t) {
          if (t.isDone) return false;
          final s = t.scheduledStart;
          if (s != null) return s.isBefore(tomorrow);
          final dl = t.deadline;
          return dl != null && dl.isBefore(tomorrow);
        }).toList()
          ..sort(byTime);
        final doneToday = all.where((t) => t.isDone && t.completedAt != null && !t.completedAt!.isBefore(today)).toList()
          ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
        return [...open, ...doneToday];
      case TaskFilter.upcoming:
        return all.where((t) => !t.isDone && t.scheduledStart != null && !t.scheduledStart!.isBefore(tomorrow)).toList()
          ..sort(byTime);
      case TaskFilter.unscheduled:
        return all.where((t) => !t.isDone && t.scheduledStart == null).toList()..sort(byTime);
      case TaskFilter.done:
        return all.where((t) => t.isDone).toList()
          ..sort((a, b) => (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final planner = PlannerScope.of(context);
    final all = planner.tasks;
    final visible = _visible(all);
    final unplanned = all.where((t) => !t.isDone && t.isFlexible && t.scheduledStart == null).length;

    return PageScaffold(
      title: context.tr('tasks.title'),
      actions: [
        AppIconButton(
          icon: Icons.add_rounded,
          semanticLabel: context.tr('tasks.new'),
          onTap: () => showTaskEditor(context),
        ),
      ],
      children: [
        Segmented<TaskFilter>(
          value: _filter,
          items: {for (final f in TaskFilter.values) f: context.tr('tasks.filter.${f.name}')},
          onChanged: (v) => setState(() => _filter = v),
        ),
        const SizedBox(height: Space.lg),
        if (unplanned > 0 && _filter != TaskFilter.done)
          AppCard(
            color: p.accentSoft,
            onTap: () => reviewPlan(context),
            child: Row(
              children: [
                Icon(Icons.auto_fix_high_rounded, color: p.accent),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    context.tr('tasks.unplannedBanner', {'n': '$unplanned'}),
                    style: context.text.bodyMedium,
                  ),
                ),
                Text(context.tr('smart.generate'), style: context.text.labelLarge?.copyWith(color: p.accent)),
              ],
            ),
          ),
        if (visible.isEmpty)
          AppCard(
            child: EmptyState(
              icon: _filter == TaskFilter.done ? Icons.task_alt_rounded : Icons.checklist_rounded,
              title: context.tr('tasks.empty.${_filter.name}'),
              message: context.tr('tasks.emptyBody'),
              actionLabel: _filter == TaskFilter.done ? null : context.tr('tasks.new'),
              onAction: () => showTaskEditor(context),
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) Divider(height: 0.5, color: p.separator),
                  TaskTile(task: visible[i], showDate: _filter != TaskFilter.today),
                ],
              ],
            ),
          ),
        if (all.isEmpty) ...[
          SectionHeader(context.tr('tasks.howTitle')),
          AppCard(
            child: Column(
              children: [
                _Hint(icon: Icons.check_circle_outline_rounded, color: p.success, text: context.tr('tasks.how1')),
                _Hint(icon: Icons.schedule_rounded, color: p.accent, text: context.tr('tasks.how2')),
                _Hint(icon: Icons.redo_rounded, color: p.habit, text: context.tr('tasks.how3'), last: true),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.color, required this.text, this.last = false});

  final IconData icon;
  final Color color;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : Space.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: Space.md),
            Expanded(child: Text(text, style: context.text.bodyMedium)),
          ],
        ),
      );
}
