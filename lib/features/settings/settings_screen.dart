import 'package:flutter/material.dart';

import '../../app/account_controller.dart';
import '../../app/app_controller.dart';
import '../../app/integrations_controller.dart';
import '../../app/planner_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/sheet.dart';
import '../../core/widgets/surfaces.dart';
import '../onboarding/onboarding_flow.dart';
import 'account_screen.dart';
import 'integrations_screens.dart';
import 'privacy_screen.dart';

/// Profile & Settings.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final account = AccountScope.of(context);
    final ix = IntegrationsScope.of(context);
    final profile = app.profile;
    if (profile == null) return const SizedBox.shrink();
    final p = context.palette;

    final languageLabel = switch (app.locale?.languageCode) {
      'ar' => 'العربية',
      'en' => 'English',
      _ => context.tr('settings.system'),
    };
    final themeLabel = context.tr('theme.${app.themeMode.name}');

    return PageScaffold(
      showBack: true,
      title: context.tr('settings.title'),
      children: [
        AppCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => OnboardingFlow(initial: profile)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: p.accentSoft,
                child: Text(
                  profile.name.isEmpty ? '?' : profile.name.characters.first.toUpperCase(),
                  style: context.text.titleLarge?.copyWith(color: p.accent),
                ),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: context.text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      profile.occupation.isNotEmpty
                          ? profile.occupation
                          : context.tr('lifestyle.${profile.lifestyle.name}'),
                      style: context.text.bodySmall,
                    ),
                    Text(context.tr('settings.editProfile'), style: context.text.labelMedium?.copyWith(color: p.accent)),
                  ],
                ),
              ),
              const ForwardChevron(),
            ],
          ),
        ),

        _GroupTitle(context.tr('settings.mySetup')),
        GroupBox(children: [
          _InfoRow(icon: Icons.work_outline_rounded, color: p.work, label: context.tr('settings.work'), value: context.tr('work.${profile.workPattern.name}')),
          _InfoRow(
            icon: Icons.bedtime_outlined,
            color: p.sleep,
            label: context.tr('settings.sleep'),
            value: '${TimeUtils.clock(context, profile.bedtimeMin)} – ${TimeUtils.clock(context, profile.wakeMin)}',
          ),
          _InfoRow(
            icon: Icons.timer_outlined,
            color: p.focus,
            label: context.tr('settings.focusGoal'),
            value: TimeUtils.duration(context, profile.dailyFocusGoalMin),
          ),
        ]),

        _GroupTitle(context.tr('settings.preferences')),
        GroupBox(children: [
          _NavRow(
            icon: Icons.language_rounded,
            color: p.accent,
            label: context.tr('settings.language'),
            value: languageLabel,
            onTap: () => _pickLanguage(context),
          ),
          _NavRow(
            icon: Icons.contrast_rounded,
            color: p.textSecondary,
            label: context.tr('settings.appearance'),
            value: themeLabel,
            onTap: () => _pickTheme(context),
          ),
        ]),

        _GroupTitle(context.tr('settings.integrations')),
        GroupBox(children: [
          _NavRow(
            icon: Icons.notifications_none_rounded,
            color: p.danger,
            label: context.tr('settings.notifications'),
            value: context.tr(ix.notificationPrefs.enabled ? 'common.on' : 'common.off'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          _NavRow(
            icon: Icons.calendar_month_outlined,
            color: p.danger,
            label: context.tr('settings.calendar'),
            value: context.tr(ix.calendarEnabled ? 'common.on' : 'common.off'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
          ),
          _NavRow(
            icon: Icons.hourglass_empty_rounded,
            color: p.focus,
            label: context.tr('settings.screenTime'),
            value: context.tr('phase.label', {'n': '5'}),
            onTap: () => showPhaseNotice(context, 5),
          ),
        ]),

        _GroupTitle(context.tr('settings.account')),
        GroupBox(children: [
          _NavRow(
            icon: Icons.cloud_outlined,
            color: p.accent,
            label: context.tr('settings.sync'),
            value: !account.configured
                ? context.tr('settings.thisDeviceOnly')
                : (account.signedIn ? (account.email ?? '') : context.tr('settings.notSignedIn')),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
          ),
          _NavRow(
            icon: Icons.privacy_tip_outlined,
            color: p.success,
            label: context.tr('settings.privacy'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
          ),
        ]),

        const SizedBox(height: Space.xl),
        if (account.signedIn)
          Text(context.tr('settings.deleteViaAccount'), style: context.text.bodySmall, textAlign: TextAlign.center)
        else ...[
          AppButton(
            label: context.tr('settings.deleteData'),
            tone: ButtonTone.destructive,
            onPressed: () => _confirmDelete(context),
          ),
          const SizedBox(height: Space.sm),
          Text(context.tr('settings.deleteDataSub'), style: context.text.bodySmall, textAlign: TextAlign.center),
        ],
        const SizedBox(height: Space.xl),
        Text('Focus Reset ${SettingsScreen.appVersion}', style: context.text.labelSmall, textAlign: TextAlign.center),
      ],
    );
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final app = AppScope.read(context);
    final current = app.locale?.languageCode ?? 'system';
    final choice = await _choiceSheet(context, context.tr('settings.language'), {
      'system': context.tr('settings.system'),
      'en': 'English',
      'ar': 'العربية',
    }, current);
    if (choice == null) return;
    await app.setLocale(choice == 'system' ? null : Locale(choice));
  }

  Future<void> _pickTheme(BuildContext context) async {
    final app = AppScope.read(context);
    final choice = await _choiceSheet(context, context.tr('settings.appearance'), {
      for (final m in ThemeMode.values) m.name: context.tr('theme.${m.name}'),
    }, app.themeMode.name);
    if (choice == null) return;
    await app.setThemeMode(ThemeMode.values.byName(choice));
  }

  Future<String?> _choiceSheet(BuildContext context, String title, Map<String, String> options, String current) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: ctx.text.titleMedium),
              const SizedBox(height: Space.lg),
              GroupBox(children: [
                for (final e in options.entries)
                  InkWell(
                    onTap: () => Navigator.pop(ctx, e.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 15),
                      child: Row(
                        children: [
                          Expanded(child: Text(e.value, style: ctx.text.bodyLarge)),
                          if (e.key == current) Icon(Icons.check_rounded, color: ctx.palette.accent),
                        ],
                      ),
                    ),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final app = AppScope.read(context);
    final planner = PlannerScope.read(context);
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: Text(ctx.tr('settings.deleteConfirmTitle')),
        content: Text(ctx.tr('settings.deleteConfirmBody')),
        actions: [
          adaptiveAction(ctx, ctx.tr('common.cancel'), () => Navigator.pop(ctx, false)),
          adaptiveAction(ctx, ctx.tr('common.delete'), () => Navigator.pop(ctx, true), destructive: true),
        ],
      ),
    );
    if (ok != true) return;
    navigator.popUntil((r) => r.isFirst);
    await planner.clearAll();
    await app.deleteAllLocalData();
  }
}

Widget adaptiveAction(BuildContext context, String label, VoidCallback onPressed, {bool destructive = false}) {
  final color = destructive ? context.palette.danger : null;
  return TextButton(
    onPressed: onPressed,
    child: Text(label, style: TextStyle(color: color, fontWeight: destructive ? FontWeight.w600 : null)),
  );
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: Space.lg, top: Space.xl, bottom: Space.sm),
        child: Text(text.toUpperCase(), style: context.text.labelMedium),
      );
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.color, required this.label, this.value, required this.onTap});

  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 12),
        child: Row(
          children: [
            IconBadge(icon: icon, color: Colors.white, background: color, size: 30),
            const SizedBox(width: Space.md),
            Expanded(child: Text(label, style: context.text.bodyLarge)),
            if (value != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: Space.sm),
                child: Text(value!, style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary)),
              ),
            const ForwardChevron(),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.color, required this.label, required this.value});

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 12),
      child: Row(
        children: [
          IconBadge(icon: icon, color: Colors.white, background: color, size: 30),
          const SizedBox(width: Space.md),
          Expanded(child: Text(label, style: context.text.bodyLarge)),
          Text(value, style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary)),
        ],
      ),
    );
  }
}
