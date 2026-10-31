import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../app/app_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models/planning_models.dart';

enum FocusPhase { focus, rest }

/// Focus timer. Fully working in Phase 1; sessions are kept for the current
/// app run and gain persistent history in Phase 2.
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
  final List<FocusSession> _sessions = [];

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
  }

  void _pause() {
    HapticFeedback.lightImpact();
    _ticker?.cancel();
    setState(() {
      _pausedRemaining = _remaining;
      _endsAt = null;
    });
  }

  void _reset() {
    _ticker?.cancel();
    if (_phase == FocusPhase.focus && _sessionStart != null) {
      final spent = DateTime.now().difference(_sessionStart!).inMinutes;
      if (spent >= 1) {
        _sessions.insert(
          0,
          FocusSession(start: _sessionStart!, plannedMin: _focusMin!, actualMin: spent, completed: false),
        );
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
        _sessions.insert(
          0,
          FocusSession(start: _sessionStart ?? DateTime.now(), plannedMin: _focusMin!, actualMin: _focusMin!),
        );
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
    final focusedToday = _sessions
        .where((s) => TimeUtils.isSameDay(s.start, DateTime.now()))
        .fold<int>(0, (sum, s) => sum + s.actualMin);

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
          onTap: () => showPhaseNotice(context, 2),
          child: Row(
            children: [
              IconBadge(icon: Icons.link_rounded, color: p.textSecondary, background: p.surfaceAlt),
              const SizedBox(width: Space.md),
              Expanded(child: Text(context.tr('focus.linkTask'), style: context.text.bodyLarge)),
              Text(context.tr('common.none'), style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
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
              Expanded(child: StatTile(value: '${_sessions.where((s) => s.completed).length}', label: context.tr('focus.sessions'), color: p.focus)),
              Expanded(child: StatTile(value: TimeUtils.duration(context, focusedToday), label: context.tr('focus.focused'))),
            ],
          ),
        ),
        if (_sessions.isEmpty)
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
                for (final s in _sessions)
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
                          child: Text(
                            DateFormat.jm(context.localeTag).format(s.start),
                            style: context.text.bodyLarge,
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
