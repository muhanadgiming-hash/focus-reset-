import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../app/planner_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_key.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/sheet.dart';
import '../../data/models/planning_models.dart';
import 'block_style.dart';
import 'plan_review.dart';

/// "UTC+3", "UTC−4:30"…
String utcOffsetLabel(int offsetMin) {
  final sign = offsetMin < 0 ? '−' : '+';
  final a = offsetMin.abs();
  final h = a ~/ 60;
  final m = a % 60;
  return m == 0 ? 'UTC$sign$h' : 'UTC$sign$h:${m.toString().padLeft(2, '0')}';
}

/// Common UTC offsets in minutes.
const List<int> kUtcOffsets = [
  -600, -540, -480, -420, -360, -300, -240, -180, -120, -60, 0, 60, 120, 180, 210, 240, 270, 300, 330, 345, 360,
  420, 480, 540, 570, 600, 660, 720,
];

/// Converts a wall-clock time in a given UTC offset (or device time when
/// null) to an absolute local DateTime.
DateTime wallToInstant(DateTime date, int minutes, int? utcOffsetMin) {
  if (utcOffsetMin == null) return DateTime(date.year, date.month, date.day, 0, minutes);
  return DateTime.utc(date.year, date.month, date.day, 0, minutes).subtract(Duration(minutes: utcOffsetMin)).toLocal();
}

/// The wall-clock time of [t] in the given offset (or device time).
DateTime instantToWall(DateTime t, int? utcOffsetMin) {
  if (utcOffsetMin == null) return t.toLocal();
  final w = t.toUtc().add(Duration(minutes: utcOffsetMin));
  return DateTime(w.year, w.month, w.day, w.hour, w.minute);
}

/// Add or edit a fixed commitment (shift, flight, meeting…). After saving,
/// the user can review how flexible tasks would move around it.
Future<void> showCommitmentSheet(BuildContext context, {Commitment? initial, DateTime? day}) {
  final key = GlobalKey<_CommitmentFormState>();
  return showEditorSheet<void>(
    context,
    title: context.tr(initial == null ? 'commitment.new' : 'commitment.edit'),
    actionLabel: context.tr('common.save'),
    bodyBuilder: (_) => _CommitmentForm(key: key, initial: initial, day: day, hostContext: context),
    onAction: (sheetContext) {
      if (key.currentState?.submit() ?? false) Navigator.of(sheetContext).pop();
    },
  );
}

class _CommitmentForm extends StatefulWidget {
  const _CommitmentForm({super.key, this.initial, this.day, required this.hostContext});

  final Commitment? initial;
  final DateTime? day;
  final BuildContext hostContext;

  @override
  State<_CommitmentForm> createState() => _CommitmentFormState();
}

class _CommitmentFormState extends State<_CommitmentForm> {
  late CommitmentType _type;
  late DateTime _date;
  late int _start;
  late int _end;
  late int _prep;
  late int _travel;
  late int _rest;
  int? _offset;
  late final TextEditingController _title;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _title = TextEditingController(text: c?.title ?? '');
    _type = c?.type ?? CommitmentType.workShift;
    _offset = c?.utcOffsetMin;
    _prep = c?.prepMin ?? 30;
    _travel = c?.travelMin ?? 30;
    _rest = c?.restAfterMin ?? 0;
    if (c != null) {
      final ws = instantToWall(c.start, _offset);
      final we = instantToWall(c.end, _offset);
      _date = dateOnly(ws);
      _start = ws.hour * 60 + ws.minute;
      _end = we.hour * 60 + we.minute;
    } else {
      _date = dateOnly(widget.day ?? DateTime.now());
      _start = 9 * 60;
      _end = 17 * 60;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _showError = true);
      return false;
    }
    final start = wallToInstant(_date, _start, _offset);
    // An end time at or before the start means the next day (overnight).
    final endDate = _end <= _start ? addDays(_date, 1) : _date;
    final end = wallToInstant(endDate, _end, _offset);

    final c = Commitment(
      id: widget.initial?.id ?? PlannerController.newId(),
      type: _type,
      title: title,
      start: start,
      end: end,
      utcOffsetMin: _offset,
      prepMin: _prep,
      travelMin: _travel,
      restAfterMin: _rest,
    );
    PlannerScope.read(context).saveCommitment(c);

    final host = widget.hostContext;
    ScaffoldMessenger.of(host)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(context.tr('commitment.saved')),
        action: SnackBarAction(
          label: context.tr('commitment.reviewPlan'),
          onPressed: () {
            if (host.mounted) reviewPlan(host);
          },
        ),
      ));
    return true;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tag = context.localeTag;
    final previewStart = wallToInstant(_date, _start, _offset);
    final previewEnd = wallToInstant(_end <= _start ? addDays(_date, 1) : _date, _end, _offset);

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
                onTap: () => setState(() {
                  _type = t;
                  if (t == CommitmentType.flight && widget.initial == null) {
                    _prep = 90;
                    _rest = 120;
                  }
                }),
              ),
          ],
        ),
        FieldLabel(context.tr('commitment.title')),
        TextField(
          controller: _title,
          onChanged: (_) {
            if (_showError) setState(() => _showError = false);
          },
          decoration: InputDecoration(
            hintText: context.tr(_type == CommitmentType.flight ? 'commitment.flightHint' : 'commitment.titleHint'),
            errorText: _showError ? context.tr('tasks.titleRequired') : null,
          ),
        ),
        FieldLabel(context.tr('commitment.when')),
        GroupBox(children: [
          TapRow(
            icon: Icons.calendar_today_outlined,
            label: context.tr('commitment.date'),
            value: DateFormat.yMMMEd(tag).format(_date),
            onTap: _pickDate,
          ),
          MenuRow<int>(
            icon: Icons.public_rounded,
            label: context.tr('commitment.timezone'),
            value: _offset ?? -99999,
            options: {
              -99999: context.tr('commitment.deviceTime'),
              for (final o in kUtcOffsets) o: utcOffsetLabel(o),
            },
            onChanged: (v) => setState(() => _offset = v == -99999 ? null : v),
          ),
        ]),
        const SizedBox(height: Space.sm),
        TimeField(label: context.tr('commitment.start'), minutes: _start, onChanged: (v) => setState(() => _start = v)),
        const SizedBox(height: Space.sm),
        TimeField(label: context.tr('commitment.end'), minutes: _end, onChanged: (v) => setState(() => _end = v)),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, top: Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_end <= _start)
                Text(context.tr('commitment.overnight'), style: context.text.bodySmall?.copyWith(color: p.accent)),
              if (_offset != null)
                Text(
                  context.tr('commitment.localPreview', {
                    't': '${DateFormat.MMMEd(tag).add_jm().format(previewStart)} – ${DateFormat.MMMEd(tag).add_jm().format(previewEnd)}',
                  }),
                  style: context.text.bodySmall,
                ),
            ],
          ),
        ),
        FieldLabel(context.tr('commitment.prep')),
        _MinuteChips(values: const [0, 15, 30, 45, 60, 90, 120], value: _prep, onChanged: (v) => setState(() => _prep = v)),
        FieldLabel(context.tr('commitment.travel')),
        _MinuteChips(values: const [0, 15, 30, 45, 60, 90], value: _travel, onChanged: (v) => setState(() => _travel = v)),
        FieldLabel(context.tr('commitment.rest')),
        _MinuteChips(values: const [0, 30, 60, 120, 240, 480], value: _rest, onChanged: (v) => setState(() => _rest = v)),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, top: Space.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: p.textSecondary),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(context.tr('commitment.fixedSub'), style: context.text.bodySmall)),
            ],
          ),
        ),
        if (widget.initial != null) ...[
          const SizedBox(height: Space.xl),
          AppButton(
            label: context.tr('common.delete'),
            tone: ButtonTone.destructive,
            onPressed: () {
              PlannerScope.read(context).deleteCommitment(widget.initial!.id);
              Navigator.of(context).pop();
            },
          ),
        ],
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
    final all = {...values, value}.toList()..sort();
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (final m in all)
          ChoiceChipX(
            label: m == 0
                ? context.tr('common.none')
                : (m >= 60 && m % 60 == 0
                    ? context.tr('unit.hoursShort', {'h': '${m ~/ 60}'})
                    : context.tr('unit.minutesShort', {'m': '$m'})),
            selected: value == m,
            onTap: () => onChanged(m),
          ),
      ],
    );
  }
}
