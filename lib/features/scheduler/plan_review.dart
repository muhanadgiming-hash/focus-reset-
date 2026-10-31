import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/planner_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/sheet.dart';
import '../../domain/scheduling/scheduling_engine.dart';

String unscheduledReasonText(BuildContext context, UnscheduledReason r) => context.tr('reason.${r.name}');

/// Runs the Smart Life Scheduler and shows every change for approval.
/// Nothing is applied unless the user taps "Apply" (rules 9 and 10).
Future<void> reviewPlan(BuildContext context, {bool reshuffle = false}) async {
  final profile = AppScope.read(context).profile;
  if (profile == null) return;
  final planner = PlannerScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final upToDate = context.tr('review.upToDate');
  final applied = context.tr('review.applied');

  final proposal = planner.proposeSchedule(profile, reshuffle: reshuffle);

  if (!proposal.hasChanges) {
    final waiting = proposal.unscheduled.length;
    final message = waiting == 0 ? upToDate : '$upToDate ${context.tr('review.waiting', {'n': '$waiting'})}';
    // Only records why waiting tasks don't fit — no task time changes.
    await planner.applyProposal(proposal);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    return;
  }

  if (!context.mounted) return;
  final approved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ProposalSheet(proposal: proposal),
  );
  if (approved != true) return;
  await planner.applyProposal(proposal);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(applied)));
}

class _ProposalSheet extends StatelessWidget {
  const _ProposalSheet({required this.proposal});

  final ScheduleProposal proposal;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final added = proposal.added.toList();
    final moved = proposal.moved.toList();
    final waiting = proposal.unscheduled.toList();

    Widget section(String title, List<Widget> rows) => rows.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldLabel(title),
              GroupBox(children: rows),
            ],
          );

    Widget row(IconData icon, Color color, String title, String subtitle) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(subtitle, style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Column(
              children: [
                Text(context.tr('review.title'), style: context.text.titleLarge),
                const SizedBox(height: 4),
                Text(context.tr('review.subtitle'), style: context.text.bodySmall, textAlign: TextAlign.center),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
              children: [
                section(context.tr('review.added', {'n': '${added.length}'}), [
                  for (final s in added)
                    row(Icons.add_circle_outline_rounded, p.accent, s.task.title, TimeUtils.dayTime(context, s.start)),
                ]),
                section(context.tr('review.moved', {'n': '${moved.length}'}), [
                  for (final s in moved)
                    row(
                      Icons.swap_horiz_rounded,
                      p.habit,
                      s.task.title,
                      '${TimeUtils.dayTime(context, s.previousStart!)}  →  ${TimeUtils.dayTime(context, s.start)}',
                    ),
                ]),
                section(context.tr('review.waitingTitle', {'n': '${waiting.length}'}), [
                  for (final u in waiting)
                    row(Icons.inbox_outlined, p.textSecondary, u.task.title, unscheduledReasonText(context, u.reason)),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: context.tr('common.cancel'),
                    tone: ButtonTone.secondary,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: context.tr('review.apply'),
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
