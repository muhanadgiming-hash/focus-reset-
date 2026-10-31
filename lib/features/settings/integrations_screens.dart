import 'package:flutter/material.dart';

import '../../app/integrations_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/sheet.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/services/native_bridge.dart';

/// Shown when iOS permission was refused; links to the app's iOS settings.
class _DeniedCard extends StatelessWidget {
  const _DeniedCard({required this.messageKey});

  final String messageKey;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      color: p.habitSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, color: p.habit),
              const SizedBox(width: Space.md),
              Expanded(child: Text(context.tr(messageKey), style: context.text.bodySmall?.copyWith(color: p.textPrimary))),
            ],
          ),
          const SizedBox(height: Space.md),
          AppButton(
            label: context.tr('perm.openSettings'),
            tone: ButtonTone.secondary,
            onPressed: () => IntegrationsScope.read(context).openSystemSettings(),
          ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ix = IntegrationsScope.of(context);
    final prefs = ix.notificationPrefs;
    final denied = ix.notificationPermission == PermissionState.denied;
    final on = prefs.enabled && !denied;

    return PageScaffold(
      showBack: true,
      title: context.tr('settings.notifications'),
      children: [
        GroupBox(children: [
          SwitchRow(
            label: context.tr('notif.enable'),
            subtitle: context.tr('notif.enableSub'),
            value: on,
            onChanged: (v) => ix.setNotificationsEnabled(v),
          ),
        ]),
        if (denied) ...[
          const SizedBox(height: Space.md),
          const _DeniedCard(messageKey: 'notif.denied'),
        ],
        if (on) ...[
          FieldLabel(context.tr('notif.what')),
          GroupBox(children: [
            SwitchRow(
              label: context.tr('notif.tasks'),
              subtitle: context.tr('notif.tasksSub'),
              value: prefs.tasks,
              onChanged: (v) => ix.updateNotificationPrefs(prefs.copyWith(tasks: v)),
            ),
            SwitchRow(
              label: context.tr('notif.habits'),
              subtitle: context.tr('notif.habitsSub'),
              value: prefs.habits,
              onChanged: (v) => ix.updateNotificationPrefs(prefs.copyWith(habits: v)),
            ),
            SwitchRow(
              label: context.tr('notif.bedtime'),
              subtitle: context.tr('sleep.reminderSub'),
              value: prefs.bedtime,
              onChanged: (v) => ix.updateNotificationPrefs(prefs.copyWith(bedtime: v)),
            ),
          ]),
          if (prefs.tasks) ...[
            FieldLabel(context.tr('notif.lead')),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final m in const [0, 5, 10, 15, 30, 60])
                  ChoiceChipX(
                    label: m == 0 ? context.tr('notif.atStart') : context.tr('unit.minutesShort', {'m': '$m'}),
                    selected: prefs.taskLeadMin == m,
                    onTap: () => ix.updateNotificationPrefs(prefs.copyWith(taskLeadMin: m)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Space.lg),
          Text(
            context.tr('notif.pending', {'n': '${ix.pendingReminders}'}),
            style: context.text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  Color _parse(String hex, Color fallback) {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? fallback : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final ix = IntegrationsScope.of(context);
    final p = context.palette;
    final denied = ix.calendarPermission == PermissionState.denied ||
        ix.calendarPermission == PermissionState.restricted;
    final on = ix.calendarEnabled && !denied;

    return PageScaffold(
      showBack: true,
      title: context.tr('settings.calendar'),
      children: [
        GroupBox(children: [
          SwitchRow(
            label: context.tr('calendar.use'),
            subtitle: context.tr('calendar.useSub'),
            value: on,
            onChanged: (v) => ix.setCalendarEnabled(v),
          ),
        ]),
        if (denied) ...[
          const SizedBox(height: Space.md),
          const _DeniedCard(messageKey: 'calendar.denied'),
        ],
        if (on) ...[
          FieldLabel(context.tr('calendar.which')),
          if (ix.calendars.isEmpty)
            AppCard(child: Text(context.tr('calendar.none'), style: context.text.bodySmall))
          else
            GroupBox(children: [
              for (final c in ix.calendars)
                InkWell(
                  onTap: () => ix.toggleCalendar(c.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 13),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: _parse(c.color, p.textTertiary), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.title, style: context.text.bodyLarge),
                              if (c.source.isNotEmpty) Text(c.source, style: context.text.bodySmall),
                            ],
                          ),
                        ),
                        Icon(
                          ix.isCalendarSelected(c.id) ? Icons.check_circle_rounded : Icons.circle_outlined,
                          color: ix.isCalendarSelected(c.id) ? p.accent : p.separator,
                        ),
                      ],
                    ),
                  ),
                ),
            ]),
        ],
        const SizedBox(height: Space.lg),
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.visibility_outlined, color: p.success, size: 20),
              const SizedBox(width: Space.md),
              Expanded(child: Text(context.tr('calendar.privacy'), style: context.text.bodySmall)),
            ],
          ),
        ),
        if (ix.timeZone != null)
          AppCard(
            child: Row(
              children: [
                Icon(Icons.public_rounded, color: p.textSecondary, size: 20),
                const SizedBox(width: Space.md),
                Expanded(child: Text(context.tr('calendar.timeZone'), style: context.text.bodyMedium)),
                Text(ix.timeZone!, textDirection: TextDirection.ltr, style: context.text.labelLarge),
              ],
            ),
          ),
      ],
    );
  }
}
