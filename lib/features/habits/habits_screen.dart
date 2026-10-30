import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/sheet.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models/planning_models.dart';
import '../onboarding/onboarding_options.dart';
import '../../app/app_controller.dart';

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
}

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PageScaffold(
      title: context.tr('habits.title'),
      actions: [
        AppIconButton(
          icon: Icons.add_rounded,
          semanticLabel: context.tr('habits.new'),
          onTap: () => showHabitEditor(context, null),
        ),
      ],
      children: [
        AppCard(
          child: EmptyState(
            icon: Icons.local_fire_department_outlined,
            color: p.habit,
            title: context.tr('habits.emptyTitle'),
            message: context.tr('habits.emptyBody'),
          ),
        ),
        SectionHeader(context.tr('habits.templates')),
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
                onTap: () => showHabitEditor(context, t),
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

Future<void> showHabitEditor(BuildContext context, HabitTemplate? template) {
  return showEditorSheet<void>(
    context,
    title: context.tr(template == null ? 'habits.new' : template.key),
    actionLabel: context.tr('habits.add'),
    bodyBuilder: (_) => _HabitForm(template: template),
    onAction: (sheetContext) {
      Navigator.of(sheetContext).pop();
      showPhaseNotice(context, 2);
    },
  );
}

class _HabitForm extends StatefulWidget {
  const _HabitForm({this.template});
  final HabitTemplate? template;

  @override
  State<_HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends State<_HabitForm> {
  late final TextEditingController _name;
  late int _amount;
  late String _unit;
  HabitFrequency _freq = HabitFrequency.daily;
  final Set<int> _days = {};
  int _perWeek = 3;
  bool _remind = false;
  int _remindAt = 20 * 60;
  bool _initialised = false;

  static const _units = ['unit.minutes', 'unit.pages', 'unit.steps', 'unit.glasses', 'unit.times'];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _amount = widget.template?.amount ?? 1;
    _unit = widget.template?.unitKey ?? 'unit.times';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised && widget.template != null) {
      _name.text = context.tr(widget.template!.key);
    }
    _initialised = true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  int get _step => _amount >= 1000 ? 500 : (_amount >= 20 ? 5 : 1);

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
          decoration: InputDecoration(hintText: context.tr('habits.nameHint')),
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
        if (_freq == HabitFrequency.specificDays)
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
      ],
    );
  }
}
