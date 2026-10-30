import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/sheet.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models/planning_models.dart';

enum TaskFilter { today, upcoming, unscheduled, done }

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  TaskFilter _filter = TaskFilter.today;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
          items: {
            for (final f in TaskFilter.values) f: context.tr('tasks.filter.${f.name}'),
          },
          onChanged: (v) => setState(() => _filter = v),
        ),
        const SizedBox(height: Space.lg),
        AppCard(
          child: EmptyState(
            icon: _filter == TaskFilter.done ? Icons.task_alt_rounded : Icons.checklist_rounded,
            title: context.tr('tasks.empty.${_filter.name}'),
            message: context.tr('tasks.emptyBody'),
            actionLabel: _filter == TaskFilter.done ? null : context.tr('tasks.new'),
            onAction: () => showTaskEditor(context),
          ),
        ),
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

Future<void> showTaskEditor(BuildContext context) {
  return showEditorSheet<void>(
    context,
    title: context.tr('tasks.new'),
    actionLabel: context.tr('common.save'),
    bodyBuilder: (_) => const _TaskForm(),
    onAction: (sheetContext) {
      Navigator.of(sheetContext).pop();
      showPhaseNotice(context, 2);
    },
  );
}

class _TaskForm extends StatefulWidget {
  const _TaskForm();

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  int _duration = 30;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _deadline;
  RepeatRule _repeat = RepeatRule.none;
  bool _flexible = true;
  String? _goal;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: TimeUtils.dateOnly(now),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final goals = AppScope.of(context).profile?.weeklyGoals.toList() ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.sm),
        TextField(
          controller: _title,
          autofocus: true,
          style: context.text.titleMedium,
          decoration: InputDecoration(hintText: context.tr('tasks.titleHint')),
        ),
        FieldLabel(context.tr('tasks.duration')),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final m in const [15, 30, 45, 60, 90, 120])
              ChoiceChipX(
                label: TimeUtils.duration(context, m),
                selected: _duration == m,
                onTap: () => setState(() => _duration = m),
              ),
          ],
        ),
        FieldLabel(context.tr('tasks.priority')),
        Segmented<TaskPriority>(
          value: _priority,
          items: {for (final pr in TaskPriority.values) pr: context.tr('priority.${pr.name}')},
          onChanged: (v) => setState(() => _priority = v),
        ),
        FieldLabel(context.tr('tasks.details')),
        GroupBox(children: [
          _TapRow(
            icon: Icons.flag_outlined,
            label: context.tr('tasks.deadline'),
            value: _deadline == null
                ? context.tr('common.none')
                : DateFormat.yMMMd(context.localeTag).format(_deadline!),
            onTap: _pickDeadline,
            onClear: _deadline == null ? null : () => setState(() => _deadline = null),
          ),
          _MenuRow<RepeatRule>(
            icon: Icons.repeat_rounded,
            label: context.tr('tasks.repeat'),
            value: _repeat,
            options: {for (final r in RepeatRule.values) r: context.tr('repeat.${r.name}')},
            onChanged: (v) => setState(() => _repeat = v),
          ),
          _MenuRow<String>(
            icon: Icons.track_changes_rounded,
            label: context.tr('tasks.linkGoal'),
            value: _goal ?? '',
            options: {
              '': context.tr('common.none'),
              for (final g in goals) g: context.tr(g),
            },
            onChanged: (v) => setState(() => _goal = v.isEmpty ? null : v),
          ),
          SwitchRow(
            label: context.tr('tasks.flexible'),
            subtitle: context.tr('tasks.flexibleSub'),
            value: _flexible,
            onChanged: (v) => setState(() => _flexible = v),
          ),
        ]),
        FieldLabel(context.tr('tasks.notes')),
        TextField(
          controller: _notes,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(hintText: context.tr('tasks.notesHint'), fillColor: p.surface),
        ),
      ],
    );
  }
}

class _TapRow extends StatelessWidget {
  const _TapRow({required this.icon, required this.label, required this.value, required this.onTap, this.onClear});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: p.textSecondary),
            const SizedBox(width: Space.md),
            Expanded(child: Text(label, style: context.text.bodyLarge)),
            Text(value, style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: Space.sm),
                  child: Icon(Icons.cancel_rounded, size: 18, color: p.textTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.value, required this.options, required this.onChanged});

  final IconData icon;
  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      itemBuilder: (_) => [
        for (final e in options.entries) PopupMenuItem<T>(value: e.key, child: Text(e.value)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: p.textSecondary),
            const SizedBox(width: Space.md),
            Expanded(child: Text(label, style: context.text.bodyLarge)),
            Text(options[value] ?? '', style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
            const SizedBox(width: 4),
            Icon(Icons.unfold_more_rounded, size: 18, color: p.textTertiary),
          ],
        ),
      ),
    );
  }
}
