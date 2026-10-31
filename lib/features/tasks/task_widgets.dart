import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../app/app_controller.dart';
import '../../app/planner_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_key.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/sheet.dart';
import '../../data/models/planning_models.dart';
import '../scheduler/plan_review.dart';

Color priorityColor(BuildContext context, TaskPriority p) {
  final c = context.palette;
  return switch (p) {
    TaskPriority.low => c.textTertiary,
    TaskPriority.medium => c.focus,
    TaskPriority.high => c.habit,
    TaskPriority.urgent => c.danger,
  };
}

/// One task row with a completion circle.
class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, this.showDate = false});

  final TaskItem task;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final planner = PlannerScope.of(context);
    final reason = planner.unscheduledReasons[task.id];
    final s = task.scheduledStart;

    final parts = <String>[
      if (s != null)
        showDate || !TimeUtils.isSameDay(s, DateTime.now())
            ? TimeUtils.dayTime(context, s)
            : TimeUtils.range(context, s, task.scheduledEnd!)
      else
        context.tr('tasks.notPlanned'),
      TimeUtils.duration(context, task.durationMin),
      if (task.deadline != null)
        context.tr('tasks.due', {'d': DateFormat.MMMd(context.localeTag).format(task.deadline!)}),
      if (task.repeat != RepeatRule.none) context.tr('repeat.${task.repeat.name}'),
    ];

    return InkWell(
      onTap: () => showTaskActions(context, task),
      borderRadius: BorderRadius.circular(Radii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              checked: task.isDone,
              label: context.tr(task.isDone ? 'tasks.markUndone' : 'tasks.markDone'),
              child: GestureDetector(
                onTap: () => planner.toggleTaskDone(task.id, AppScope.read(context).profile),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isDone ? p.success : Colors.transparent,
                    border: Border.all(color: task.isDone ? p.success : priorityColor(context, task.priority), width: 2),
                  ),
                  child: task.isDone ? const Icon(Icons.check_rounded, size: 17, color: Colors.white) : null,
                ),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge?.copyWith(
                      decoration: task.isDone ? TextDecoration.lineThrough : null,
                      color: task.isDone ? p.textTertiary : p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(parts.join(' · '), style: context.text.bodySmall),
                  if (!task.isDone && s == null && reason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        unscheduledReasonText(context, reason),
                        style: context.text.bodySmall?.copyWith(color: p.habit),
                      ),
                    ),
                ],
              ),
            ),
            if (!task.isFlexible)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: Space.sm, top: 3),
                child: Icon(Icons.lock_outline_rounded, size: 16, color: p.textTertiary),
              ),
          ],
        ),
      ),
    );
  }
}

enum _TaskAction { edit, toggle, postpone, reschedule, delete }

Future<void> showTaskActions(BuildContext context, TaskItem task) async {
  final planner = PlannerScope.read(context);
  final profile = AppScope.read(context).profile;
  final messenger = ScaffoldMessenger.of(context);
  final deletedLabel = context.tr('tasks.deleted');
  final undoLabel = context.tr('common.undo');

  final action = await showActionSheet<_TaskAction>(
    context,
    title: task.title,
    actions: [
      (Icons.edit_outlined, context.tr('common.edit'), _TaskAction.edit, false),
      (
        task.isDone ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
        context.tr(task.isDone ? 'tasks.markUndone' : 'tasks.markDone'),
        _TaskAction.toggle,
        false
      ),
      if (!task.isDone) (Icons.next_plan_outlined, context.tr('tasks.postpone'), _TaskAction.postpone, false),
      if (!task.isDone && task.isFlexible)
        (Icons.auto_fix_high_rounded, context.tr('tasks.reschedule'), _TaskAction.reschedule, false),
      (Icons.delete_outline_rounded, context.tr('common.delete'), _TaskAction.delete, true),
    ],
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case _TaskAction.edit:
      await showTaskEditor(context, task: task);
    case _TaskAction.toggle:
      await planner.toggleTaskDone(task.id, profile);
    case _TaskAction.postpone:
      await planner.postponeTask(task.id);
    case _TaskAction.reschedule:
      await planner.unscheduleTask(task.id);
      if (context.mounted) await reviewPlan(context);
    case _TaskAction.delete:
      await planner.deleteTask(task.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(deletedLabel),
          action: SnackBarAction(label: undoLabel, onPressed: () => planner.saveTask(task)),
        ));
  }
}

Future<void> showTaskEditor(BuildContext context, {TaskItem? task}) {
  final key = GlobalKey<_TaskFormState>();
  return showEditorSheet<void>(
    context,
    title: context.tr(task == null ? 'tasks.new' : 'tasks.edit'),
    actionLabel: context.tr('common.save'),
    bodyBuilder: (_) => _TaskForm(key: key, initial: task, hostContext: context),
    onAction: (sheetContext) {
      if (key.currentState?.submit() ?? false) Navigator.of(sheetContext).pop();
    },
  );
}

class _TaskForm extends StatefulWidget {
  const _TaskForm({super.key, this.initial, required this.hostContext});

  final TaskItem? initial;

  /// The screen that opened the editor, used for the follow-up snackbar.
  final BuildContext hostContext;

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late int _duration;
  late TaskPriority _priority;
  DateTime? _deadline;
  late RepeatRule _repeat;
  late bool _flexible;
  String? _goal;
  String? _habitId;
  late DateTime _fixedDate;
  late int _fixedTime;
  bool _showError = false;

  static const _durations = [15, 30, 45, 60, 90, 120, 180];

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _title = TextEditingController(text: t?.title ?? '');
    _notes = TextEditingController(text: t?.notes ?? '');
    _duration = t?.durationMin ?? 30;
    _priority = t?.priority ?? TaskPriority.medium;
    _deadline = t?.deadline;
    _repeat = t?.repeat ?? RepeatRule.none;
    _flexible = t?.isFlexible ?? true;
    _goal = t?.linkedGoal;
    _habitId = t?.linkedHabitId;
    final now = DateTime.now();
    final s = t?.scheduledStart ?? DateTime(now.year, now.month, now.day, now.hour + 1);
    _fixedDate = dateOnly(s);
    _fixedTime = s.hour * 60 + s.minute;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Validates and saves. Returns true when the sheet can close.
  bool submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _showError = true);
      return false;
    }
    final planner = PlannerScope.read(context);
    final fixedStart = DateTime(_fixedDate.year, _fixedDate.month, _fixedDate.day, 0, _fixedTime);
    final base = widget.initial;
    final keepSlot = base != null && base.isFlexible && _flexible && base.durationMin == _duration;

    final TaskItem result;
    if (base == null) {
      result = TaskItem(
        id: PlannerController.newId(),
        title: title,
        durationMin: _duration,
        priority: _priority,
        deadline: _deadline,
        repeat: _repeat,
        linkedGoal: _goal,
        linkedHabitId: _habitId,
        isFlexible: _flexible,
        status: _flexible ? TaskStatus.pending : TaskStatus.scheduled,
        notes: _notes.text.trim(),
        scheduledStart: _flexible ? null : fixedStart,
        createdAt: DateTime.now(),
      );
    } else {
      final DateTime? start = _flexible ? (keepSlot ? base.scheduledStart : null) : fixedStart;
      result = base.copyWith(
        title: title,
        durationMin: _duration,
        priority: _priority,
        deadline: _deadline,
        repeat: _repeat,
        linkedGoal: _goal,
        linkedHabitId: _habitId,
        isFlexible: _flexible,
        notes: _notes.text.trim(),
        scheduledStart: start,
        status: base.isDone ? TaskStatus.done : (start == null ? TaskStatus.pending : TaskStatus.scheduled),
      );
    }
    planner.saveTask(result);

    if (result.isFlexible && result.scheduledStart == null && !result.isDone) {
      final host = widget.hostContext;
      final messenger = ScaffoldMessenger.of(host);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(context.tr('tasks.savedUnplanned')),
          action: SnackBarAction(
            label: context.tr('smart.generate'),
            onPressed: () {
              if (host.mounted) reviewPlan(host);
            },
          ),
        ));
    }
    return true;
  }

  Future<void> _pickDate({required bool deadline}) async {
    final now = DateTime.now();
    final initial = deadline ? (_deadline ?? now) : _fixedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(dateOnly(now)) ? now : initial,
      firstDate: dateOnly(now),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (deadline) {
        _deadline = picked;
      } else {
        _fixedDate = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final planner = PlannerScope.of(context);
    final goals = AppScope.of(context).profile?.weeklyGoals.toList() ?? const <String>[];
    final tag = context.localeTag;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.sm),
        TextField(
          controller: _title,
          autofocus: widget.initial == null,
          style: context.text.titleMedium,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (_showError) setState(() => _showError = false);
          },
          decoration: InputDecoration(
            hintText: context.tr('tasks.titleHint'),
            errorText: _showError ? context.tr('tasks.titleRequired') : null,
          ),
        ),
        FieldLabel(context.tr('tasks.duration')),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final m in {..._durations, _duration}.toList()..sort())
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
        FieldLabel(context.tr('tasks.timing')),
        GroupBox(children: [
          SwitchRow(
            label: context.tr('tasks.flexible'),
            subtitle: context.tr(_flexible ? 'tasks.flexibleSub' : 'tasks.fixedSub'),
            value: _flexible,
            onChanged: (v) => setState(() => _flexible = v),
          ),
          if (!_flexible)
            TapRow(
              icon: Icons.calendar_today_outlined,
              label: context.tr('commitment.date'),
              value: DateFormat.yMMMEd(tag).format(_fixedDate),
              onTap: () => _pickDate(deadline: false),
            ),
        ]),
        if (!_flexible) ...[
          const SizedBox(height: Space.sm),
          TimeField(
            label: context.tr('commitment.start'),
            minutes: _fixedTime,
            onChanged: (v) => setState(() => _fixedTime = v),
          ),
        ],
        FieldLabel(context.tr('tasks.details')),
        GroupBox(children: [
          TapRow(
            icon: Icons.flag_outlined,
            label: context.tr('tasks.deadline'),
            value: _deadline == null ? context.tr('common.none') : DateFormat.yMMMd(tag).format(_deadline!),
            onTap: () => _pickDate(deadline: true),
            onClear: _deadline == null ? null : () => setState(() => _deadline = null),
          ),
          MenuRow<RepeatRule>(
            icon: Icons.repeat_rounded,
            label: context.tr('tasks.repeat'),
            value: _repeat,
            options: {for (final r in RepeatRule.values) r: context.tr('repeat.${r.name}')},
            onChanged: (v) => setState(() => _repeat = v),
          ),
          MenuRow<String>(
            icon: Icons.track_changes_rounded,
            label: context.tr('tasks.linkGoal'),
            value: _goal ?? '',
            options: {
              '': context.tr('common.none'),
              for (final g in goals) g: context.tr(g),
              if (_goal != null && !goals.contains(_goal)) _goal!: context.tr(_goal!),
            },
            onChanged: (v) => setState(() => _goal = v.isEmpty ? null : v),
          ),
          MenuRow<String>(
            icon: Icons.local_fire_department_outlined,
            label: context.tr('tasks.linkHabit'),
            value: (_habitId != null && planner.habitById(_habitId) != null) ? _habitId! : '',
            options: {
              '': context.tr('common.none'),
              for (final h in planner.habits) h.id: h.name,
            },
            onChanged: (v) => setState(() => _habitId = v.isEmpty ? null : v),
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
