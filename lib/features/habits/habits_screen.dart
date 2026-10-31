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
import '../../core/widgets/sheet.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models/planning_models.dart';
import '../../domain/habits/habit_logic.dart';
import '../onboarding/onboarding_options.dart';

/// A starting point for a habit. Users can change every value.
class HabitTemplate {
  const HabitTemplate(this.key, this.icon, this.amount, this.unitKey);
  final String key;
  final IconData icon;
  final int amount;
  final String unitKey;

  static const all = <HabitTemplate>[
    HabitTemplate('habit.reading', Icons.menu_book_rounded, 20, 'unit.pages'),
    HabitTemplate('habit.exercise', Icons.fitness_center_rounded, 30, 'unit.minutes'),
    HabitTemplate('habit.walking', Icons.directions_walk_rounded, 6000, 'unit.steps'),
    HabitTemplate('habit.language', Icons.translate_rounded, 15, 'unit.minutes'),
    HabitTemplate('habit.water', Icons.water_drop_outlined, 8, 'unit.glasses'),
    HabitTemplate('habit.sleep', Icons.bedtime_outlined, 1, 'unit.times'),
    HabitTemplate('habit.learning', Icons.school_outlined, 20, 'unit.minutes'),
    HabitTemplate('habit.meditation', Icons.self_improvement_rounded, 10, 'unit.minutes'),
  ];

  static IconData iconFor(String key) {
    for (final t in all) {
      if (t.key == key) return t.icon;
    }
    return Icons.star_outline_rounded;
  }
}

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final planner = PlannerScope.of(context);
    final habits = planner.habits;
    final today = dateOnly(DateTime.now());
    final dueToday = habits.where((h) => HabitLogic.isScheduledOn(h, today)).toList();
    final doneToday = dueToday.where((h) => HabitLogic.doneOn(h, planner.habitLog(h.id), today)).length;

    return PageScaffold(
      title: context.tr('habits.title'),
      actions: [
        AppIconButton(
          icon: Icons.add_rounded,
          semanticLabel: context.tr('habits.new'),
          onTap: () => showHabitEditor(context),
        ),
      ],
      children: [
        if (habits.isEmpty)
          AppCard(
            child: EmptyState(
              icon: Icons.local_fire_department_outlined,
              color: p.habit,
              title: context.tr('habits.emptyTitle'),
              message: context.tr('habits.emptyBody'),
            ),
          )
        else ...[
          AppCard(
            child: Row(
              children: [
                ProgressRing(
                  value: dueToday.isEmpty ? null : doneToday / dueToday.length,
                  color: p.habit,
                  size: 64,
                  stroke: 7,
                  center: Text('$doneToday/${dueToday.length}', style: context.text.titleSmall),
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Text(
                    dueToday.isEmpty
                        ? context.tr('habits.noneToday')
                        : context.tr(doneToday == dueToday.length ? 'habits.allDone' : 'habits.todaySummary',
                            {'n': '$doneToday', 'total': '${dueToday.length}'}),
                    style: context.text.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
          for (final h in habits) HabitCard(habit: h),
        ],
        SectionHeader(context.tr(habits.isEmpty ? 'habits.templates' : 'habits.addMore')),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.md,
          crossAxisSpacing: Space.md,
          childAspectRatio: 1.45,
          children: [
            for (final t in HabitTemplate.all)
              AppCard(
                margin: EdgeInsets.zero,
                onTap: () => showHabitEditor(context, template: t),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconBadge(icon: t.icon, color: p.habit, background: p.habitSoft, size: 34),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr(t.key), style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          '${t.amount} ${context.tr(t.unitKey)} · ${context.tr('habits.daily')}',
                          style: context.text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Today's progress for one habit, with quick logging.
class HabitCard extends StatelessWidget {
  const HabitCard({super.key, required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final planner = PlannerScope.of(context);
    final profile = AppScope.of(context).profile;
    final today = dateOnly(DateTime.now());
    final log = planner.habitLog(habit.id);
    final amount = HabitLogic.amountOn(log, today);
    final due = HabitLogic.isScheduledOn(habit, today);
    final done = amount >= habit.targetAmount;
    final streak = HabitLogic.streak(habit, log, today, profile?.firstWeekday ?? DateTime.sunday);
    final step = HabitLogic.stepFor(habit.targetAmount);

    final String streakText;
    if (habit.frequency == HabitFrequency.timesPerWeek) {
      final weekStart = startOfWeekDate(today, profile?.firstWeekday ?? DateTime.sunday);
      final thisWeek = HabitLogic.doneDaysBetween(habit, log, weekStart, addDays(weekStart, 7));
      streakText = context.tr('habits.weekProgress', {'n': '$thisWeek', 'total': '${habit.timesPerWeek}'});
    } else {
      streakText = context.tr('habits.streakDays', {'n': '$streak'});
    }

    return AppCard(
      onTap: () => _actions(context),
      child: Opacity(
        opacity: due ? 1 : 0.55,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => planner.setHabitAmount(habit.id, today, done ? 0 : habit.targetAmount),
              child: ProgressRing(
                value: amount / habit.targetAmount,
                color: done ? p.success : p.habit,
                size: 52,
                stroke: 6,
                center: Icon(
                  done ? Icons.check_rounded : HabitTemplate.iconFor(habit.templateKey),
                  color: done ? p.success : p.habit,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit.name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    due
                        ? '$amount / ${habit.targetAmount} ${context.tr(habit.unitKey)}'
                        : context.tr('habits.notToday'),
                    style: context.text.bodySmall,
                  ),
                  Text(streakText, style: context.text.bodySmall?.copyWith(color: p.habit)),
                ],
              ),
            ),
            if (!done)
              Semantics(
                button: true,
                label: context.tr('habits.log', {'n': '$step'}),
                child: GestureDetector(
                  onTap: () => planner.setHabitAmount(habit.id, today, amount + step),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: p.habitSoft, borderRadius: BorderRadius.circular(99)),
                    child: Text('+$step', style: context.text.labelLarge?.copyWith(color: p.habit)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _actions(BuildContext context) async {
    final planner = PlannerScope.read(context);
    final today = dateOnly(DateTime.now());
    final choice = await showActionSheet<String>(
      context,
      title: habit.name,
      actions: [
        (Icons.edit_outlined, context.tr('common.edit'), 'edit', false),
        (Icons.restart_alt_rounded, context.tr('habits.resetToday'), 'reset', false),
        (Icons.delete_outline_rounded, context.tr('common.delete'), 'delete', true),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'edit':
        await showHabitEditor(context, habit: habit);
      case 'reset':
        await planner.setHabitAmount(habit.id, today, 0);
      case 'delete':
        await planner.deleteHabit(habit.id);
    }
  }
}

Future<void> showHabitEditor(BuildContext context, {HabitTemplate? template, Habit? habit}) {
  final key = GlobalKey<_HabitFormState>();
  final title = habit?.name ?? (template == null ? context.tr('habits.new') : context.tr(template.key));
  return showEditorSheet<void>(
    context,
    title: title,
    actionLabel: context.tr(habit == null ? 'habits.add' : 'common.save'),
    bodyBuilder: (_) => _HabitForm(key: key, template: template, initial: habit),
    onAction: (sheetContext) {
      if (key.currentState?.submit() ?? false) Navigator.of(sheetContext).pop();
    },
  );
}

class _HabitForm extends StatefulWidget {
  const _HabitForm({super.key, this.template, this.initial});

  final HabitTemplate? template;
  final Habit? initial;

  @override
  State<_HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends State<_HabitForm> {
  late final TextEditingController _name;
  late int _amount;
  late String _unit;
  late HabitFrequency _freq;
  late Set<int> _days;
  late int _perWeek;
  late bool _remind;
  late int _remindAt;
  bool _initialised = false;
  bool _showError = false;

  static const _units = ['unit.minutes', 'unit.pages', 'unit.steps', 'unit.glasses', 'unit.times'];

  @override
  void initState() {
    super.initState();
    final h = widget.initial;
    _name = TextEditingController(text: h?.name ?? '');
    _amount = h?.targetAmount ?? widget.template?.amount ?? 1;
    _unit = h?.unitKey ?? widget.template?.unitKey ?? 'unit.times';
    _freq = h?.frequency ?? HabitFrequency.daily;
    _days = {...?h?.days};
    _perWeek = h?.timesPerWeek ?? 3;
    _remind = h?.reminderMin != null;
    _remindAt = h?.reminderMin ?? 20 * 60;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised && widget.initial == null && widget.template != null) {
      _name.text = context.tr(widget.template!.key);
    }
    _initialised = true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  int get _step => HabitLogic.stepFor(_amount);

  bool submit() {
    final name = _name.text.trim();
    if (name.isEmpty || (_freq == HabitFrequency.specificDays && _days.isEmpty)) {
      setState(() => _showError = true);
      return false;
    }
    final base = widget.initial;
    PlannerScope.read(context).saveHabit(Habit(
      id: base?.id ?? PlannerController.newId(),
      templateKey: base?.templateKey ?? widget.template?.key ?? 'custom',
      name: name,
      targetAmount: _amount,
      unitKey: _unit,
      frequency: _freq,
      days: _days,
      timesPerWeek: _perWeek,
      reminderMin: _remind ? _remindAt : null,
      createdAt: base?.createdAt ?? DateTime.now(),
    ));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final first = AppScope.of(context).profile?.firstWeekday ?? DateTime.sunday;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.sm),
        TextField(
          controller: _name,
          style: context.text.titleMedium,
          onChanged: (_) {
            if (_showError) setState(() => _showError = false);
          },
          decoration: InputDecoration(
            hintText: context.tr('habits.nameHint'),
            errorText: _showError && _name.text.trim().isEmpty ? context.tr('tasks.titleRequired') : null,
          ),
        ),
        FieldLabel(context.tr('habits.target')),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(Radii.md)),
          child: Row(
            children: [
              IconButton(
                onPressed: _amount > _step ? () => setState(() => _amount -= _step) : null,
                icon: const Icon(Icons.remove_rounded),
                tooltip: context.tr('common.decrease'),
              ),
              Expanded(
                child: Text('$_amount', textAlign: TextAlign.center, style: context.text.titleLarge),
              ),
              IconButton(
                onPressed: () => setState(() => _amount += _step),
                icon: const Icon(Icons.add_rounded),
                tooltip: context.tr('common.increase'),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final u in _units)
              ChoiceChipX(label: context.tr(u), selected: _unit == u, onTap: () => setState(() => _unit = u)),
          ],
        ),
        FieldLabel(context.tr('habits.frequency')),
        Segmented<HabitFrequency>(
          value: _freq,
          items: {for (final f in HabitFrequency.values) f: context.tr('habits.freq.${f.name}')},
          onChanged: (v) => setState(() => _freq = v),
        ),
        const SizedBox(height: Space.md),
        if (_freq == HabitFrequency.specificDays) ...[
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final d in OnbOptions.weekOrder(first))
                ChoiceChipX(
                  label: OnbOptions.weekdayShort(context, d),
                  selected: _days.contains(d),
                  onTap: () => setState(() {
                    if (!_days.remove(d)) _days.add(d);
                  }),
                ),
            ],
          ),
          if (_showError && _days.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, top: Space.sm),
              child: Text(context.tr('habits.pickDays'), style: context.text.bodySmall?.copyWith(color: p.danger)),
            ),
        ],
        if (_freq == HabitFrequency.timesPerWeek)
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (var n = 1; n <= 6; n++)
                ChoiceChipX(
                  label: context.tr('habits.timesWeek', {'n': '$n'}),
                  selected: _perWeek == n,
                  onTap: () => setState(() => _perWeek = n),
                ),
            ],
          ),
        FieldLabel(context.tr('habits.reminder')),
        GroupBox(children: [
          SwitchRow(
            label: context.tr('habits.remindMe'),
            subtitle: context.tr('habits.remindSub'),
            value: _remind,
            onChanged: (v) => setState(() => _remind = v),
          ),
        ]),
        if (_remind) ...[
          const SizedBox(height: Space.sm),
          TimeField(
            label: context.tr('habits.remindAt'),
            minutes: _remindAt,
            onChanged: (v) => setState(() => _remindAt = v),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, top: Space.sm),
            child: Text(
              context.tr('habits.remindPreview', {'t': TimeUtils.clock(context, _remindAt)}),
              style: context.text.bodySmall,
            ),
          ),
        ],
        if (widget.initial != null) ...[
          const SizedBox(height: Space.xl),
          AppButton(
            label: context.tr('common.delete'),
            tone: ButtonTone.destructive,
            onPressed: () {
              PlannerScope.read(context).deleteHabit(widget.initial!.id);
              Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}
