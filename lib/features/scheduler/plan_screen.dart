import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/surfaces.dart';
import 'commitment_sheet.dart';
import 'smart_scheduler_view.dart';
import 'weekly_schedule_view.dart';

enum PlanView { smart, week }

/// "Plan" tab — hosts Smart Life Scheduler and the Weekly Schedule.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  PlanView _view = PlanView.smart;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: context.tr('plan.title'),
      actions: [
        AppIconButton(
          icon: Icons.add_rounded,
          semanticLabel: context.tr('plan.addCommitment'),
          onTap: () => showCommitmentSheet(context),
        ),
      ],
      children: [
        Segmented<PlanView>(
          value: _view,
          items: {
            PlanView.smart: context.tr('plan.smart'),
            PlanView.week: context.tr('plan.week'),
          },
          onChanged: (v) => setState(() => _view = v),
        ),
        const SizedBox(height: Space.lg),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _view == PlanView.smart
              ? const SmartSchedulerView(key: ValueKey('smart'))
              : const WeeklyScheduleView(key: ValueKey('week')),
        ),
      ],
    );
  }
}
