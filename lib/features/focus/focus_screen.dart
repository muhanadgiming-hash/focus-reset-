import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../app/app_controller.dart';
import '../../app/integrations_controller.dart';
import '../../app/planner_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/sheet.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models/planning_models.dart';

enum FocusPhase { focus, rest }

/// Focus timer. Every session (finished or ended early) is saved to the
/// history and can be linked to a task.
///
/// The countdown is computed from a wall-clock end time, so it stays accurate
/// when the app is backgrounded or the tab is switched.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  FocusPhase _phase = FocusPhase.focus;
  int? _focusMin;
  int? _breakMin;
  DateTime? _endsAt;
  Duration? _pausedRemaining;
  DateTime? _sessionStart;
  Timer? _ticker;
  String? _taskId;

  bool get _running => _endsAt != null;
  bool get _paused => _pausedRemaining != null;
  bool get _idle => !_running && !_paused;

  int get _phaseMinutes => _phase == FocusPhase.focus ? _focusMin! : _breakMin!;

  Duration get _remaining {
    if (_endsAt != null) {
      final r = _endsAt!.difference(DateTime.now());
      return r.isNegative ? Duration.zero : r;
    }
    return _pausedRemaining ?? Duration(minutes: _phaseMinutes);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = AppScope.of(context).profile;
    _focusMin ??= profile?.focusSessionMin ?? 25;
    _breakMin ??= profile?.breakMin ?? 5;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    HapticFeedback.mediumImpact();
    setState(() {
      final remaining = _pausedRemaining ?? Duration(minutes: _phaseMinutes);
      _sessionStart ??= DateTime.now();
      _endsAt = DateTime.now().add(remaining);
      _pausedRemaining = null;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
    IntegrationsScope.read(context).scheduleTimerEnd(_endsAt!, focus: _phase == FocusPhase.focus);
  }

  void _pause() {
    HapticFeedback.lightImpact();
    _ticker?.cancel();
    IntegrationsScope.read(context).cancelTimerEnd();
    setState(() {
      _pausedRemaining = _remaining;
      _endsAt = null;
    });
  }

  void _reset() {
    _ticker?.cancel();
    IntegrationsScope.read(context).cancelTimerEnd();
    if (_phase == FocusPhase.focus && _sessionStart != null) {
      final spent = DateTime.now().difference(_sessionStart!).inMinutes;
      if (spent >= 1) {
        PlannerScope.read(context).addFocusSession(FocusSession(
          id: PlannerController.newId(),
          start: _sessionStart!,
          plannedMin: _focusMin!,
          actualMin: spent,
          taskId: _taskId,
          completed: false,
        ));
      }
    }
    setState(() {
      _endsAt = null;
      _pausedRemaining = null;
      _sessionStart = null;
    });
  }

  void _tick() {
    if (!mounted) return;
    if (_remaining == Duration.zero) {
      _complete();
    } else {
      setState(() {});
    }
  }

  void _complete() {
    _ticker?.cancel();
    HapticFeedback.heavyImpact();
    setState(() {
      if (_phase == FocusPhase.focus) {
        PlannerScope.read(context).addFocusSession(FocusSession(
          id: PlannerController.newId(),
          start: _sessionStart ?? DateTime.now().subtract(Duration(minutes: _focusMin!)),
          plannedMin: _focusMin!,
          actualMin: _focusMin!,
          taskId: _taskId,
        ));
        _phase = FocusPhase.rest;
      } else {
        _phase = FocusPhase.focus;
      }
      _endsAt = null;
      _pausedRemaining = null;
      _sessionStart = null;
    });
  }

  void _switchPhase(FocusPhase phase) {
    if (!_idle) return;
    setState(() => _phase = phase);
  }

  Future<void> _pickTask() async {
    final planner = PlannerScope.read(context);
    final open = planner.tasks.where((t) => !t.isDone).toList()
      ..sort((a, b) => (a.scheduledStart ?? DateTime(9999)).compareTo(b.scheduledStart ?? DateTime(9999)));
    final picked = await showActionSheet<String>(
      context,
      title: context.tr('focus.linkTask'),
      actions: [
        (Icons.link_off_rounded, context.tr('common.none'), '', false),
        for (final t in open.take(12)) (Icons.check_circle_outline_rounded, t.title, t.id, false),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _taskId = picked.isEmpty ? null : picked);
  }

  String _mmss(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = _phase == FocusPhase.focus ? p.focus : p.accent;
    final total = Duration(minutes: _phaseMinutes).inSeconds;
    final progress = total == 0 ? 0.0 : 1 - _remaining.inSeconds / total;
    final planner = PlannerScope.of(context);
    final linked = planner.taskById(_taskId);
    final todaySessions = planner.focusSessions.where((s) => TimeUtils.isSameDay(s.start, DateTime.now())).toList();
    final focusedToday = todaySessions.fold<int>(0, (sum, s) => sum + s.actualMin);

    return PageScaffold(
      title: context.tr('focus.title'),
      children: [
        Segmented<FocusPhase>(
          value: _phase,
          items: {
            FocusPhase.focus: context.tr('focus.focus'),
            FocusPhase.rest: context.tr('focus.break'),
          },
          onChanged: _switchPhase,
        ),
        const SizedBox(height: Space.xl),
        Center(
          child: ProgressRing(
            value: _idle ? 0 : progress,
            color: color,
            size: 248,
            stroke: 14,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    _mmss(_remaining),
                    style: context.text.displaySmall?.copyWith(
                      fontSize: 56,
                      fontWeight: FontWeight.w300,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(
                  context.tr(_paused
                      ? 'focus.paused'
                      : (_phase == FocusPhase.focus ? 'focus.stayWith' : 'focus.restNow')),
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.xl),
        if (_idle) ...[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final m in _phase == FocusPhase.focus ? const [15, 25, 45, 60, 90] : const [5, 10, 15, 20])
                ChoiceChipX(
                  label: TimeUtils.duration(context, m),
                  selected: _phaseMinutes == m,
                  onTap: () => setState(() {
                    if (_phase == FocusPhase.focus) {
                      _focusMin = m;
                    } else {
                      _breakMin = m;
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
        ],
        Row(
          children: [
            if (!_idle) ...[
              Expanded(
                child: AppButton(label: context.tr('focus.end'), tone: ButtonTone.secondary, onPressed: _reset),
              ),
              const SizedBox(width: Space.md),
            ],
            Expanded(
              flex: 2,
              child: AppButton(
                label: context.tr(_running ? 'focus.pause' : (_paused ? 'focus.resume' : 'focus.start')),
                icon: _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                onPressed: _running ? _pause : _start,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        AppCard(
          onTap: _pickTask,
          child: Row(
            children: [
              IconBadge(
                icon: Icons.link_rounded,
                color: linked == null ? p.textSecondary : p.focus,
                background: linked == null ? p.surfaceAlt : p.focusSoft,
              ),
              const SizedBox(width: Space.md),
              Expanded(child: Text(context.tr('focus.linkTask'), style: context.text.bodyLarge)),
              Flexible(
                child: Text(
                  linked?.title ?? context.tr('common.none'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: context.text.bodyMedium?.copyWith(color: linked == null ? p.textSecondary : p.focus),
                ),
              ),
            ],
          ),
        ),
        AppCard(
          child: Row(
            children: [
              IconBadge(icon: Icons.block_rounded, color: p.textSecondary, background: p.surfaceAlt),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('focus.blockTitle'), style: context.text.titleSmall),
                    const SizedBox(height: 2),
                    Text(context.tr('focus.blockBody'), style: context.text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              StatusPill(context.tr('status.notActive')),
            ],
          ),
        ),
        SectionHeader(context.tr('focus.today')),
        AppCard(
          child: Row(
            children: [
              Expanded(child: StatTile(value: '${todaySessions.where((s) => s.completed).length}', label: context.tr('focus.sessions'), color: p.focus)),
              Expanded(child: StatTile(value: TimeUtils.duration(context, focusedToday), label: context.tr('focus.focused'))),
            ],
          ),
        ),
        if (todaySessions.isEmpty)
          AppCard(
            child: EmptyState(
              icon: Icons.history_rounded,
              color: p.focus,
              title: context.tr('focus.historyEmpty'),
              message: context.tr('focus.historyBody'),
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
            child: Column(
              children: [
                for (final s in todaySessions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.sm),
                    child: Row(
                      children: [
                        Icon(
                          s.completed ? Icons.check_circle_rounded : Icons.stop_circle_outlined,
                          color: s.completed ? p.success : p.textTertiary,
                          size: 20,
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat.jm(context.localeTag).format(s.start), style: context.text.bodyLarge),
                              if (planner.taskById(s.taskId) != null)
                                Text(
                                  planner.taskById(s.taskId)!.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        Text(TimeUtils.duration(context, s.actualMin), style: context.text.labelLarge),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
