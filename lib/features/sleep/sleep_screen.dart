import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../app/app_controller.dart';
import '../../app/integrations_controller.dart';
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
import '../onboarding/onboarding_options.dart';

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final planner = PlannerScope.of(context);
    final ix = IntegrationsScope.of(context);
    final profile = app.profile;
    if (profile == null) return const SizedBox.shrink();
    final p = context.palette;
    final tag = context.localeTag;

    final weekStart = startOfWeekDate(DateTime.now(), profile.firstWeekday);
    final order = OnbOptions.weekOrder(profile.firstWeekday);
    final entries = planner.sleepEntries;
    final weekValues = List<double>.filled(7, 0);
    for (final e in entries) {
      final idx = e.date.difference(weekStart).inHours ~/ 24;
      if (idx >= 0 && idx < 7) weekValues[idx] = e.durationMin / 60;
    }
    final weekLogged = weekValues.where((v) => v > 0).toList();
    final avg = weekLogged.isEmpty ? null : weekLogged.reduce((a, b) => a + b) / weekLogged.length;
    final todayIdx = dateOnly(DateTime.now()).difference(weekStart).inHours ~/ 24;

    return PageScaffold(
      showBack: true,
      title: context.tr('sleep.title'),
      children: [
        AppCard(
          padding: const EdgeInsets.all(Space.xl),
          child: Row(
            children: [
              ProgressRing(
                value: (profile.sleepDurationMin / (9 * 60)).clamp(0.0, 1.0),
                color: p.sleep,
                size: 92,
                center: Icon(Icons.bedtime_rounded, color: p.sleep, size: 30),
              ),
              const SizedBox(width: Space.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('sleep.target'), style: context.text.bodySmall),
                    Text(TimeUtils.duration(context, profile.sleepDurationMin), style: context.text.headlineSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${TimeUtils.clock(context, profile.bedtimeMin)} → ${TimeUtils.clock(context, profile.wakeMin)}',
                      style: context.text.bodyMedium?.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionHeader(context.tr('sleep.schedule')),
        TimeField(
          label: context.tr('sleep.bedtime'),
          icon: Icons.bedtime_outlined,
          minutes: profile.bedtimeMin,
          onChanged: (v) => app.saveProfile(profile.copyWith(bedtimeMin: v)),
        ),
        const SizedBox(height: Space.sm),
        TimeField(
          label: context.tr('sleep.wake'),
          icon: Icons.wb_sunny_outlined,
          minutes: profile.wakeMin,
          onChanged: (v) => app.saveProfile(profile.copyWith(wakeMin: v)),
        ),
        const SizedBox(height: Space.md),
        GroupBox(children: [
          SwitchRow(
            label: context.tr('sleep.reminder'),
            subtitle: context.tr('sleep.reminderSub'),
            value: ix.notificationPrefs.enabled && ix.notificationPrefs.bedtime,
            onChanged: (v) async {
              if (v && !ix.notificationPrefs.enabled) {
                if (!await ix.setNotificationsEnabled(true)) return;
              }
              await ix.updateNotificationPrefs(ix.notificationPrefs.copyWith(bedtime: v));
            },
          ),
        ]),
        SectionHeader(
          context.tr('sleep.log'),
          actionLabel: context.tr('sleep.logNow'),
          onAction: () => showSleepLog(context),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(context.tr('sleep.thisWeek'), style: context.text.titleSmall)),
                  if (avg != null)
                    Text(
                      context.tr('sleep.average', {'d': TimeUtils.duration(context, (avg * 60).round())}),
                      style: context.text.labelMedium,
                    ),
                ],
              ),
              const SizedBox(height: Space.lg),
              MiniBarChart(
                values: weekValues,
                labels: [for (final d in order) OnbOptions.weekdayShort(context, d)],
                color: p.sleep,
                height: 90,
                highlightIndex: todayIdx >= 0 && todayIdx < 7 ? todayIdx : null,
              ),
              if (weekLogged.isEmpty) ...[
                const SizedBox(height: Space.sm),
                Text(context.tr('sleep.noLogs'), style: context.text.bodySmall),
              ],
            ],
          ),
        ),
        if (entries.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
            child: Column(
              children: [
                for (final e in entries.take(14))
                  InkWell(
                    onTap: () => showSleepLog(context, entry: e),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat.MMMEd(tag).format(e.date), style: context.text.bodyLarge),
                                Text(
                                  '${TimeUtils.clock(context, e.bedtimeMin)} → ${TimeUtils.clock(context, e.wakeMin)}',
                                  style: context.text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (e.quality != null)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: Space.md),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, size: 16, color: p.habit),
                                  Text('${e.quality}', style: context.text.labelMedium),
                                ],
                              ),
                            ),
                          Text(TimeUtils.duration(context, e.durationMin), style: context.text.labelLarge),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: Space.sm),
        Text(context.tr('sleep.disclaimer'), style: context.text.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }
}

Future<void> showSleepLog(BuildContext context, {SleepEntry? entry}) {
  final profile = AppScope.read(context).profile;
  final key = GlobalKey<_SleepLogFormState>();
  return showEditorSheet<void>(
    context,
    title: context.tr('sleep.logTitle'),
    actionLabel: context.tr('common.save'),
    bodyBuilder: (_) => _SleepLogForm(
      key: key,
      initial: entry,
      bed: profile?.bedtimeMin ?? 23 * 60,
      wake: profile?.wakeMin ?? 7 * 60,
    ),
    onAction: (sheetContext) {
      key.currentState?.submit();
      Navigator.of(sheetContext).pop();
    },
  );
}

class _SleepLogForm extends StatefulWidget {
  const _SleepLogForm({super.key, this.initial, required this.bed, required this.wake});

  final SleepEntry? initial;
  final int bed;
  final int wake;

  @override
  State<_SleepLogForm> createState() => _SleepLogFormState();
}

class _SleepLogFormState extends State<_SleepLogForm> {
  late DateTime _date = widget.initial?.date ?? dateOnly(DateTime.now());
  late int _bed = widget.initial?.bedtimeMin ?? widget.bed;
  late int _wake = widget.initial?.wakeMin ?? widget.wake;
  late int? _quality = widget.initial?.quality;

  void submit() {
    PlannerScope.read(context).saveSleep(SleepEntry(
      id: widget.initial?.id ?? PlannerController.newId(),
      date: _date,
      bedtimeMin: _bed,
      wakeMin: _wake,
      quality: _quality,
    ));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(context.tr('sleep.morningOf')),
        GroupBox(children: [
          TapRow(
            icon: Icons.calendar_today_outlined,
            label: context.tr('commitment.date'),
            value: DateFormat.yMMMEd(context.localeTag).format(_date),
            onTap: _pickDate,
          ),
        ]),
        const SizedBox(height: Space.md),
        TimeField(label: context.tr('sleep.wentToBed'), minutes: _bed, onChanged: (v) => setState(() => _bed = v)),
        const SizedBox(height: Space.sm),
        TimeField(label: context.tr('sleep.wokeUp'), minutes: _wake, onChanged: (v) => setState(() => _wake = v)),
        const SizedBox(height: Space.md),
        Text(
          context.tr('sleep.total', {'d': TimeUtils.duration(context, TimeUtils.spanAcrossMidnight(_bed, _wake))}),
          style: context.text.titleSmall,
          textAlign: TextAlign.center,
        ),
        FieldLabel(context.tr('sleep.howRested')),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var q = 1; q <= 5; q++)
              GestureDetector(
                onTap: () => setState(() => _quality = _quality == q ? null : q),
                child: Icon(
                  (_quality ?? 0) >= q ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 36,
                  color: (_quality ?? 0) >= q ? p.habit : p.textTertiary,
                ),
              ),
          ],
        ),
        if (widget.initial != null) ...[
          const SizedBox(height: Space.xl),
          AppButton(
            label: context.tr('common.delete'),
            tone: ButtonTone.destructive,
            onPressed: () {
              PlannerScope.read(context).deleteSleep(widget.initial!.id);
              Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}
