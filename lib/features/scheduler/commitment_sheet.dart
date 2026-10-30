import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/sheet.dart';
import '../../data/models/planning_models.dart';

IconData commitmentIcon(CommitmentType t) => switch (t) {
      CommitmentType.workShift => Icons.work_outline_rounded,
      CommitmentType.flight => Icons.flight_rounded,
      CommitmentType.meeting => Icons.groups_outlined,
      CommitmentType.appointment => Icons.event_outlined,
      CommitmentType.commute => Icons.directions_car_outlined,
      CommitmentType.family => Icons.family_restroom_rounded,
      CommitmentType.personal => Icons.person_outline_rounded,
    };

/// Editor for a fixed commitment (shift, flight, meeting…). The full form is
/// in place; persistence and re-planning arrive with the Phase 2 engine.
Future<void> showCommitmentSheet(BuildContext context) {
  return showEditorSheet<void>(
    context,
    title: context.tr('commitment.new'),
    actionLabel: context.tr('common.save'),
    bodyBuilder: (_) => const _CommitmentForm(),
    onAction: (sheetContext) {
      Navigator.of(sheetContext).pop();
      showPhaseNotice(context, 2);
    },
  );
}

class _CommitmentForm extends StatefulWidget {
  const _CommitmentForm();

  @override
  State<_CommitmentForm> createState() => _CommitmentFormState();
}

class _CommitmentFormState extends State<_CommitmentForm> {
  CommitmentType _type = CommitmentType.workShift;
  DateTime _date = DateTime.now();
  int _start = 9 * 60;
  int _end = 17 * 60;
  int _prep = 30;
  int _travel = 30;
  bool _fixed = true;
  final _title = TextEditingController();
  final _tz = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _tz.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(context.tr('commitment.type')),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final t in CommitmentType.values)
              ChoiceChipX(
                label: context.tr('commitment.${t.name}'),
                icon: commitmentIcon(t),
                selected: _type == t,
                onTap: () => setState(() => _type = t),
              ),
          ],
        ),
        FieldLabel(context.tr('commitment.title')),
        TextField(
          controller: _title,
          decoration: InputDecoration(
            hintText: context.tr(_type == CommitmentType.flight ? 'commitment.flightHint' : 'commitment.titleHint'),
          ),
        ),
        FieldLabel(context.tr('commitment.when')),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
            decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(Radii.md)),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 20, color: p.textSecondary),
                const SizedBox(width: Space.md),
                Expanded(child: Text(context.tr('commitment.date'), style: context.text.bodyLarge)),
                Text(DateFormat.yMMMEd(context.localeTag).format(_date), style: context.text.labelLarge),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        TimeField(label: context.tr('commitment.start'), minutes: _start, onChanged: (v) => setState(() => _start = v)),
        const SizedBox(height: Space.sm),
        TimeField(label: context.tr('commitment.end'), minutes: _end, onChanged: (v) => setState(() => _end = v)),
        if (_end <= _start)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, top: Space.sm),
            child: Text(context.tr('commitment.overnight'), style: context.text.bodySmall?.copyWith(color: p.accent)),
          ),
        FieldLabel(context.tr('commitment.timezone')),
        TextField(
          controller: _tz,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(hintText: context.tr('commitment.timezoneHint')),
        ),
        FieldLabel(context.tr('commitment.prep')),
        _MinuteChips(values: const [0, 15, 30, 45, 60, 90], value: _prep, onChanged: (v) => setState(() => _prep = v)),
        FieldLabel(context.tr('commitment.travel')),
        _MinuteChips(values: const [0, 15, 30, 45, 60, 90], value: _travel, onChanged: (v) => setState(() => _travel = v)),
        const SizedBox(height: Space.lg),
        GroupBox(children: [
          SwitchRow(
            label: context.tr('commitment.fixed'),
            subtitle: context.tr('commitment.fixedSub'),
            value: _fixed,
            onChanged: (v) => setState(() => _fixed = v),
          ),
        ]),
      ],
    );
  }
}

class _MinuteChips extends StatelessWidget {
  const _MinuteChips({required this.values, required this.value, required this.onChanged});

  final List<int> values;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (final m in values)
          ChoiceChipX(
            label: m == 0 ? context.tr('common.none') : context.tr('unit.minutesShort', {'m': '$m'}),
            selected: value == m,
            onTap: () => onChanged(m),
          ),
      ],
    );
  }
}
