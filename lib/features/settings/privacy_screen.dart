import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/surfaces.dart';

/// Plain-language privacy summary shown in-app. The full legal privacy
/// policy URL is added to App Store Connect in Phase 6.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = [
      (Icons.phone_iphone_rounded, 'privacy.p1'),
      (Icons.money_off_rounded, 'privacy.p2'),
      (Icons.filter_alt_outlined, 'privacy.p3'),
      (Icons.verified_user_outlined, 'privacy.p4'),
      (Icons.delete_outline_rounded, 'privacy.p5'),
      (Icons.block_rounded, 'privacy.p6'),
    ];
    return PageScaffold(
      showBack: true,
      title: context.tr('settings.privacy'),
      children: [
        for (final (icon, key) in items)
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(icon: icon, color: p.success, background: p.success.withValues(alpha: 0.12)),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('$key.title'), style: context.text.titleSmall),
                      const SizedBox(height: 2),
                      Text(context.tr('$key.body'), style: context.text.bodySmall),
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
