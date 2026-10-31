import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../app/account_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/services/auth_service.dart';
import '../auth/auth_screen.dart';

/// Account & sync: sign in/out, sync status and account deletion.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final p = context.palette;

    return PageScaffold(
      showBack: true,
      title: context.tr('account.title'),
      children: [
        if (!account.configured)
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(icon: Icons.phone_iphone_rounded, color: p.accent, background: p.accentSoft),
                const SizedBox(width: Space.md),
                Expanded(child: Text(context.tr('auth.notConfigured'), style: context.text.bodyMedium)),
              ],
            ),
          )
        else if (!account.signedIn) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(icon: Icons.cloud_outlined, color: p.accent, background: p.accentSoft, size: 44),
                const SizedBox(height: Space.md),
                Text(context.tr('account.why'), style: context.text.titleMedium),
                const SizedBox(height: Space.xs),
                Text(context.tr('account.whyBody'), style: context.text.bodySmall),
              ],
            ),
          ),
          AppButton(
            label: context.tr('auth.signInButton'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AuthScreen(mode: AuthMode.signIn, fromSettings: true),
            )),
          ),
          const SizedBox(height: Space.sm),
          AppButton(
            label: context.tr('auth.createButton'),
            tone: ButtonTone.secondary,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AuthScreen(mode: AuthMode.signUp, fromSettings: true),
            )),
          ),
        ] else ...[
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: p.accentSoft,
                  child: Icon(Icons.person_rounded, color: p.accent),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('account.signedInAs'), style: context.text.bodySmall),
                      Text(
                        account.email ?? '',
                        style: context.text.titleSmall,
                        textDirection: TextDirection.ltr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppCard(
            child: Row(
              children: [
                _StatusIcon(status: account.status),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('sync.${account.status.name}'), style: context.text.titleSmall),
                      if (account.lastSyncedAt != null)
                        Text(
                          context.tr('sync.lastAt', {
                            't': DateFormat.jm(context.localeTag).format(account.lastSyncedAt!),
                          }),
                          style: context.text.bodySmall,
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: account.status == SyncStatus.syncing ? null : account.syncNow,
                  child: Text(context.tr('sync.now'), style: TextStyle(color: p.accent)),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          AppButton(
            label: context.tr('account.signOut'),
            tone: ButtonTone.secondary,
            onPressed: () => _signOut(context),
          ),
          const SizedBox(height: Space.sm),
          Text(context.tr('account.signOutNote'), style: context.text.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: Space.xxl),
          AppButton(
            label: context.tr('account.delete'),
            tone: ButtonTone.destructive,
            onPressed: () => _delete(context),
          ),
          const SizedBox(height: Space.sm),
          Text(context.tr('account.deleteNote'), style: context.text.bodySmall, textAlign: TextAlign.center),
        ],
      ],
    );
  }

  Future<bool> _confirm(BuildContext context, String titleKey, String bodyKey, String actionKey) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: Text(ctx.tr(titleKey)),
        content: Text(ctx.tr(bodyKey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('common.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr(actionKey), style: TextStyle(color: ctx.palette.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _signOut(BuildContext context) async {
    final account = AccountScope.read(context);
    final navigator = Navigator.of(context);
    if (!await _confirm(context, 'account.signOutTitle', 'account.signOutBody', 'account.signOut')) return;
    if (!context.mounted) return;
    final ok = await _run(context, () => account.signOut());
    if (ok) navigator.popUntil((r) => r.isFirst);
  }

  Future<void> _delete(BuildContext context) async {
    final account = AccountScope.read(context);
    final navigator = Navigator.of(context);
    if (!await _confirm(context, 'account.deleteTitle', 'account.deleteBody', 'common.delete')) return;
    if (!context.mounted) return;
    final ok = await _run(context, () => account.deleteAccount());
    if (ok) navigator.popUntil((r) => r.isFirst);
  }

  /// Runs [action] behind a blocking progress indicator; shows failures.
  Future<bool> _run(BuildContext context, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final errorPrefix = context.tr('account.failed');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator.adaptive()),
    );
    try {
      await action();
      return true;
    } on AuthFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$errorPrefix (${e.code})')));
      return false;
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(errorPrefix)));
      return false;
    } finally {
      navigator.pop();
    }
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (icon, color) = switch (status) {
      SyncStatus.syncing => (Icons.sync_rounded, p.accent),
      SyncStatus.offline => (Icons.cloud_off_rounded, p.habit),
      SyncStatus.idle => (Icons.cloud_done_rounded, p.success),
      SyncStatus.signedOut || SyncStatus.localOnly => (Icons.phone_iphone_rounded, p.textSecondary),
    };
    return IconBadge(icon: icon, color: color, background: color.withValues(alpha: 0.12));
  }
}
