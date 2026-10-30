import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/surfaces.dart';
import '../onboarding/onboarding_options.dart';

enum ProgressRange { week, month }

/// Progress & Reports. Every figure here is computed from the user's own
/// activity; with no activity yet the screen shows zeros and says so —
/// never sample numbers.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressRange _range = ProgressRange.week;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final first = AppScope.of(context).profile?.firstWeekday ?? DateTime.sunday;
    final dayLabels = [for (final d in OnbOptions.weekOrder(first)) OnbOptions.weekdayShort(context, d)];
    final zeros = List<double>.filled(7, 0.0);

    return PageScaffold(
      showBack: true,
      title: context.tr('progress.title'),
      children: [
        Segmented<ProgressRange>(
          value: _range,
          items: {
            ProgressRange.week: context.tr('progress.week'),
            ProgressRange.month: context.tr('progress.month'),
          },
          onChanged: (v) => setState(() => _range = v),
        ),
        const SizedBox(height: Space.lg),
        AppCard(
          color: p.accentSoft,
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: p.accent, size: 20),
              const SizedBox(width: Space.md),
              Expanded(child: Text(context.tr('progress.noData'), style: context.text.bodySmall?.copyWith(color: p.textPrimary))),
            ],
          ),
        ),
        AppCard(
          padding: const EdgeInsets.all(Space.xl),
          child: Row(
            children: [
              _RingStat(label: context.tr('progress.tasks'), color: p.accent),
              _RingStat(label: context.tr('progress.focus'), color: p.focus),
              _RingStat(label: context.tr('progress.habits'), color: p.habit),
            ],
          ),
        ),
        AppCard(
          child: Row(
            children: [
              Expanded(child: StatTile(value: '0', label: context.tr('progress.sessions'), color: p.focus)),
              Expanded(child: StatTile(value: context.tr('unit.minutesShort', {'m': '0'}), label: context.tr('progress.focusTime'))),
              Expanded(child: StatTile(value: '0%', label: context.tr('progress.completion'), color: p.accent)),
            ],
          ),
        ),
        SectionHeader(context.tr('progress.daily')),
        AppCard(
          child: MiniBarChart(values: zeros, labels: dayLabels, color: p.accent),
        ),
        SectionHeader(context.tr('progress.compare')),
        AppCard(
          child: Row(
            children: [
              Expanded(child: StatTile(value: '—', label: context.tr('progress.thisWeek'))),
              Expanded(child: StatTile(value: '—', label: context.tr('progress.lastWeek'))),
              const StatusPill('—'),
            ],
          ),
        ),
        SectionHeader(context.tr('progress.bestTime')),
        AppCard(
          child: MiniBarChart(
            values: const [0.0, 0.0, 0.0, 0.0],
            labels: [
              context.tr('daypart.morning'),
              context.tr('daypart.afternoon'),
              context.tr('daypart.evening'),
              context.tr('daypart.night'),
            ],
            color: p.focus,
            height: 80,
          ),
        ),
        const SizedBox(height: Space.sm),
        AppButton(
          label: context.tr('progress.export'),
          tone: ButtonTone.secondary,
          icon: Icons.ios_share_rounded,
          onPressed: () => showPhaseNotice(context, 3),
        ),
      ],
    );
  }
}

class _RingStat extends StatelessWidget {
  const _RingStat({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          ProgressRing(
            value: null,
            color: color,
            size: 74,
            stroke: 8,
            center: Text('—', style: context.text.titleSmall),
          ),
          const SizedBox(height: Space.sm),
          Text(label, style: context.text.labelMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
