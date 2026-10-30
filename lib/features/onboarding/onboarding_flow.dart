import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models/user_profile.dart';
import 'onboarding_options.dart';

/// Seven short steps that build the user's [UserProfile].
/// Reused from Settings with [initial] to edit an existing profile.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, this.initial});

  final UserProfile? initial;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _steps = 7;
  final _pages = PageController();
  int _step = 0;

  late final TextEditingController _name;
  late final TextEditingController _occupation;
  final _commitmentInput = TextEditingController();

  AgeRange? _age;
  Lifestyle? _lifestyle;
  WorkPattern _workPattern = WorkPattern.fixed;
  Set<int> _workDays = {DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday};
  int _workStart = 9 * 60;
  int _workEnd = 17 * 60;
  int _bed = 23 * 60;
  int _wake = 7 * 60;
  List<String> _commitments = [];
  double _focusGoal = 90;
  Set<String> _goals = {};
  DayPart _focusTime = DayPart.morning;
  int _session = 25;
  int _break = 5;
  int _firstWeekday = DateTime.sunday;
  int _commute = 15;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p?.name ?? '');
    _occupation = TextEditingController(text: p?.occupation ?? '');
    if (p != null) {
      _age = p.ageRange;
      _lifestyle = p.lifestyle;
      _workPattern = p.workPattern;
      _workDays = {...p.workDays};
      _workStart = p.workStartMin;
      _workEnd = p.workEndMin;
      _bed = p.bedtimeMin;
      _wake = p.wakeMin;
      _commitments = [...p.commitments];
      _focusGoal = p.dailyFocusGoalMin.toDouble();
      _goals = {...p.weeklyGoals};
      _focusTime = p.preferredFocusTime;
      _session = p.focusSessionMin;
      _break = p.breakMin;
      _firstWeekday = p.firstWeekday;
      _commute = p.commuteBufferMin;
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    _occupation.dispose();
    _commitmentInput.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
        0 => _name.text.trim().isNotEmpty && _age != null,
        1 => _lifestyle != null,
        2 => _workPattern != WorkPattern.fixed || _workDays.isNotEmpty,
        _ => true,
      };

  void _go(int delta) {
    FocusScope.of(context).unfocus();
    final next = _step + delta;
    if (next < 0) {
      Navigator.of(context).maybePop();
      return;
    }
    if (next >= _steps) {
      _finish();
      return;
    }
    setState(() => _step = next);
    _pages.animateToPage(next, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    final profile = UserProfile(
      name: _name.text.trim(),
      ageRange: _age!,
      lifestyle: _lifestyle!,
      occupation: _occupation.text.trim(),
      workPattern: _workPattern,
      workDays: _workPattern == WorkPattern.fixed ? _workDays : const <int>{},
      workStartMin: _workStart,
      workEndMin: _workEnd,
      bedtimeMin: _bed,
      wakeMin: _wake,
      commitments: _commitments,
      dailyFocusGoalMin: _focusGoal.round(),
      weeklyGoals: _goals,
      preferredFocusTime: _focusTime,
      focusSessionMin: _session,
      breakMin: _break,
      firstWeekday: _firstWeekday,
      commuteBufferMin: _commute,
      homeTimeZone: DateTime.now().timeZoneName,
    );
    final navigator = Navigator.of(context);
    await AppScope.read(context).saveProfile(profile);
    if (!mounted) return;
    if (_editing) {
      navigator.pop();
    } else {
      navigator.popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
              child: Row(
                children: [
                  AppIconButton(
                    icon: _step == 0 && !_editing
                        ? Icons.close_rounded
                        : (context.isRtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded),
                    onTap: () => _go(-1),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: (_step + 1) / _steps),
                        duration: const Duration(milliseconds: 300),
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 5,
                          backgroundColor: p.surfaceAlt,
                          valueColor: AlwaysStoppedAnimation(p.accent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Text(
                    context.tr('onb.stepOf', {'n': '${_step + 1}', 'total': '$_steps'}),
                    style: context.text.labelMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _stepAbout(),
                  _stepLifestyle(),
                  _stepWork(),
                  _stepSleep(),
                  _stepCommitments(),
                  _stepGoals(),
                  _stepPreferences(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
              child: AppButton(
                label: context.tr(_step == _steps - 1 ? (_editing ? 'common.save' : 'onb.finish') : 'common.continue'),
                onPressed: _canContinue ? () => _go(1) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- steps

  Widget _page({required String title, required String subtitle, required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxl, Space.gutter, Space.xl),
      children: [
        Text(title, style: context.text.headlineSmall),
        const SizedBox(height: Space.sm),
        Text(subtitle, style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary)),
        const SizedBox(height: Space.lg),
        ...children,
      ],
    );
  }

  Widget _wrap(List<Widget> chips) => Wrap(spacing: Space.sm, runSpacing: Space.sm, children: chips);

  Widget _stepAbout() => _page(
        title: context.tr('onb.aboutTitle'),
        subtitle: context.tr('onb.aboutSubtitle'),
        children: [
          FieldLabel(context.tr('onb.name')),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
            decoration: InputDecoration(hintText: context.tr('onb.nameHint')),
            onChanged: (_) => setState(() {}),
          ),
          FieldLabel(context.tr('onb.age')),
          _wrap([
            for (final a in AgeRange.values)
              ChoiceChipX(
                label: context.tr(OnbOptions.ageKey(a)),
                selected: _age == a,
                onTap: () => setState(() => _age = a),
              ),
          ]),
        ],
      );

  Widget _stepLifestyle() => _page(
        title: context.tr('onb.lifestyleTitle'),
        subtitle: context.tr('onb.lifestyleSubtitle'),
        children: [
          _wrap([
            for (final l in Lifestyle.values)
              ChoiceChipX(
                label: context.tr('lifestyle.${l.name}'),
                icon: OnbOptions.lifestyleIcon(l),
                selected: _lifestyle == l,
                onTap: () => setState(() {
                  _lifestyle = l;
                  // Sensible default only; the user picks the actual pattern next.
                  if (_editing) return;
                  _workPattern = switch (l) {
                    Lifestyle.travelCrew => WorkPattern.variable,
                    Lifestyle.shiftWorker || Lifestyle.healthcare => WorkPattern.shifts,
                    Lifestyle.retired || Lifestyle.homeAndFamily => WorkPattern.none,
                    _ => WorkPattern.fixed,
                  };
                }),
              ),
          ]),
          FieldLabel(context.tr('onb.occupation')),
          TextField(
            controller: _occupation,
            decoration: InputDecoration(hintText: context.tr('onb.occupationHint')),
          ),
        ],
      );

  Widget _stepWork() {
    final order = OnbOptions.weekOrder(_firstWeekday);
    return _page(
      title: context.tr('onb.workTitle'),
      subtitle: context.tr('onb.workSubtitle'),
      children: [
        for (final w in WorkPattern.values)
          _RadioCard(
            title: context.tr('work.${w.name}'),
            subtitle: context.tr('work.${w.name}.desc'),
            selected: _workPattern == w,
            onTap: () => setState(() => _workPattern = w),
          ),
        if (_workPattern == WorkPattern.fixed) ...[
          FieldLabel(context.tr('onb.workDays')),
          _wrap([
            for (final d in order)
              ChoiceChipX(
                label: OnbOptions.weekdayShort(context, d),
                selected: _workDays.contains(d),
                onTap: () => setState(() {
                  if (!_workDays.remove(d)) _workDays.add(d);
                }),
              ),
          ]),
          const SizedBox(height: Space.lg),
          TimeField(
            label: context.tr('onb.workStart'),
            icon: Icons.work_outline_rounded,
            minutes: _workStart,
            onChanged: (v) => setState(() => _workStart = v),
          ),
          const SizedBox(height: Space.sm),
          TimeField(
            label: context.tr('onb.workEnd'),
            icon: Icons.home_outlined,
            minutes: _workEnd,
            onChanged: (v) => setState(() => _workEnd = v),
          ),
        ],
        if (_workPattern == WorkPattern.variable || _workPattern == WorkPattern.shifts)
          AppCard(
            margin: const EdgeInsets.only(top: Space.md),
            color: context.palette.accentSoft,
            child: Text(context.tr('onb.variableNote'), style: context.text.bodySmall?.copyWith(color: context.palette.textPrimary)),
          ),
      ],
    );
  }

  Widget _stepSleep() => _page(
        title: context.tr('onb.sleepTitle'),
        subtitle: context.tr('onb.sleepSubtitle'),
        children: [
          TimeField(
            label: context.tr('sleep.bedtime'),
            icon: Icons.bedtime_outlined,
            minutes: _bed,
            onChanged: (v) => setState(() => _bed = v),
          ),
          const SizedBox(height: Space.sm),
          TimeField(
            label: context.tr('sleep.wake'),
            icon: Icons.wb_sunny_outlined,
            minutes: _wake,
            onChanged: (v) => setState(() => _wake = v),
          ),
          const SizedBox(height: Space.lg),
          AppCard(
            child: Row(
              children: [
                Icon(Icons.nights_stay_outlined, color: context.palette.sleep),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    context.tr('onb.sleepWindow', {
                      'd': TimeUtils.duration(context, TimeUtils.spanAcrossMidnight(_bed, _wake)),
                    }),
                    style: context.text.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          Text(context.tr('onb.sleepNote'), style: context.text.bodySmall),
        ],
      );

  Widget _stepCommitments() {
    void add(String v) {
      final t = v.trim();
      if (t.isEmpty || _commitments.contains(t)) return;
      setState(() => _commitments.add(t));
      _commitmentInput.clear();
    }

    final quick = OnbOptions.commitmentSuggestions.map((k) => context.tr(k)).toList();
    return _page(
      title: context.tr('onb.commitTitle'),
      subtitle: context.tr('onb.commitSubtitle'),
      children: [
        TextField(
          controller: _commitmentInput,
          textInputAction: TextInputAction.done,
          onSubmitted: add,
          decoration: InputDecoration(
            hintText: context.tr('onb.commitHint'),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_circle_rounded),
              color: context.palette.accent,
              tooltip: context.tr('common.add'),
              onPressed: () => add(_commitmentInput.text),
            ),
          ),
        ),
        FieldLabel(context.tr('onb.suggestions')),
        _wrap([
          for (final q in quick)
            ChoiceChipX(
              label: q,
              selected: _commitments.contains(q),
              onTap: () => setState(() {
                if (!_commitments.remove(q)) _commitments.add(q);
              }),
            ),
        ]),
        if (_commitments.isNotEmpty) ...[
          FieldLabel(context.tr('onb.yourCommitments')),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
            child: Column(
              children: [
                for (final c in _commitments)
                  Row(
                    children: [
                      Expanded(child: Text(c, style: context.text.bodyLarge)),
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline_rounded, color: context.palette.danger),
                        tooltip: context.tr('common.remove'),
                        onPressed: () => setState(() => _commitments.remove(c)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _stepGoals() => _page(
        title: context.tr('onb.goalsTitle'),
        subtitle: context.tr('onb.goalsSubtitle'),
        children: [
          FieldLabel(context.tr('onb.dailyFocus')),
          AppCard(
            child: Column(
              children: [
                Text(TimeUtils.duration(context, _focusGoal.round()), style: context.text.titleLarge),
                Slider(
                  value: _focusGoal,
                  min: 15,
                  max: 360,
                  divisions: 23,
                  onChanged: (v) => setState(() => _focusGoal = v),
                ),
              ],
            ),
          ),
          FieldLabel(context.tr('onb.weeklyGoals')),
          _wrap([
            for (final g in OnbOptions.goalKeys)
              ChoiceChipX(
                label: context.tr(g),
                selected: _goals.contains(g),
                onTap: () => setState(() {
                  if (!_goals.remove(g)) _goals.add(g);
                }),
              ),
          ]),
        ],
      );

  Widget _stepPreferences() => _page(
        title: context.tr('onb.prefsTitle'),
        subtitle: context.tr('onb.prefsSubtitle'),
        children: [
          FieldLabel(context.tr('onb.bestFocusTime')),
          _wrap([
            for (final d in DayPart.values)
              ChoiceChipX(
                label: context.tr('daypart.${d.name}'),
                selected: _focusTime == d,
                onTap: () => setState(() => _focusTime = d),
              ),
          ]),
          FieldLabel(context.tr('onb.sessionLength')),
          _wrap([
            for (final m in const [25, 45, 60, 90])
              ChoiceChipX(
                label: TimeUtils.duration(context, m),
                selected: _session == m,
                onTap: () => setState(() => _session = m),
              ),
          ]),
          FieldLabel(context.tr('onb.breakLength')),
          _wrap([
            for (final m in const [5, 10, 15, 20])
              ChoiceChipX(
                label: TimeUtils.duration(context, m),
                selected: _break == m,
                onTap: () => setState(() => _break = m),
              ),
          ]),
          FieldLabel(context.tr('onb.commute')),
          _wrap([
            for (final m in const [0, 15, 30, 45, 60])
              ChoiceChipX(
                label: m == 0 ? context.tr('common.none') : TimeUtils.duration(context, m),
                selected: _commute == m,
                onTap: () => setState(() => _commute = m),
              ),
          ]),
          FieldLabel(context.tr('onb.weekStart')),
          _wrap([
            for (final d in const [DateTime.saturday, DateTime.sunday, DateTime.monday])
              ChoiceChipX(
                label: DateFormat.EEEE(context.localeTag).format(OnbOptions.dateForWeekday(d)),
                selected: _firstWeekday == d,
                onTap: () => setState(() => _firstWeekday = d),
              ),
          ]),
        ],
      );
}

class _RadioCard extends StatelessWidget {
  const _RadioCard({required this.title, required this.subtitle, required this.selected, required this.onTap});

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: Space.sm),
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: selected ? p.accent : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: context.text.bodySmall),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? p.accent : p.separator,
            ),
          ],
        ),
      ),
    );
  }
}
