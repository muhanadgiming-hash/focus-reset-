import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/sheet.dart';
import '../../core/widgets/surfaces.dart';
import '../onboarding/onboarding_options.dart';

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final profile = app.profile;
    if (profile == null) return const SizedBox.shrink();
    final p = context.palette;
    final order = OnbOptions.weekOrder(profile.firstWeekday);

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
            value: false,
            onChanged: (_) => showPhaseNotice(context, 4),
          ),
        ]),
        SectionHeader(
          context.tr('sleep.log'),
          actionLabel: context.tr('sleep.logNow'),
          onAction: () => _showLogSheet(context, profile.bedtimeMin, profile.wakeMin),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('sleep.thisWeek'), style: context.text.titleSmall),
              const SizedBox(height: Space.lg),
              MiniBarChart(
                values: List.filled(7, 0.0),
                labels: [for (final d in order) OnbOptions.weekdayShort(context, d)],
                color: p.sleep,
                height: 90,
              ),
              const SizedBox(height: Space.sm),
              Text(context.tr('sleep.noLogs'), style: context.text.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(context.tr('sleep.disclaimer'), style: context.text.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }

  void _showLogSheet(BuildContext context, int bed, int wake) {
    showEditorSheet<void>(
      context,
      title: context.tr('sleep.logTitle'),
      actionLabel: context.tr('common.save'),
      bodyBuilder: (_) => _SleepLogForm(bed: bed, wake: wake),
      onAction: (sheetContext) {
        Navigator.of(sheetContext).pop();
        showPhaseNotice(context, 2);
      },
    );
  }
}

class _SleepLogForm extends StatefulWidget {
  const _SleepLogForm({required this.bed, required this.wake});
  final int bed;
  final int wake;

  @override
  State<_SleepLogForm> createState() => _SleepLogFormState();
}

class _SleepLogFormState extends State<_SleepLogForm> {
  late int _bed = widget.bed;
  late int _wake = widget.wake;
  int? _quality;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(context.tr('sleep.lastNight')),
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
                onTap: () => setState(() => _quality = q),
                child: Icon(
                  (_quality ?? 0) >= q ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 36,
                  color: (_quality ?? 0) >= q ? p.habit : p.textTertiary,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
