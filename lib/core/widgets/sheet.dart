import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import 'controls.dart';

/// Presents a tall iOS-style editor sheet with a title, a scrollable body
/// and a pinned primary action.
Future<T?> showEditorSheet<T>(
  BuildContext context, {
  required String title,
  required String actionLabel,
  required WidgetBuilder bodyBuilder,
  required void Function(BuildContext sheetContext) onAction,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final height = MediaQuery.sizeOf(sheetContext).height * 0.88;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(
                        sheetContext.tr('common.cancel'),
                        style: TextStyle(color: sheetContext.palette.textSecondary, fontSize: 16),
                      ),
                    ),
                    Expanded(
                      child: Text(title, textAlign: TextAlign.center, style: sheetContext.text.titleMedium),
                    ),
                    const SizedBox(width: 64),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
                  children: [Builder(builder: bodyBuilder)],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
                child: AppButton(label: actionLabel, onPressed: () => onAction(sheetContext)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Grouped container for a set of sheet rows (iOS "inset grouped" list).
class GroupBox extends StatelessWidget {
  const GroupBox({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(Radii.md)),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: Space.lg),
                child: Divider(height: 0.5, color: p.separator),
              ),
          ],
        ],
      ),
    );
  }
}

class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.label, required this.value, required this.onChanged, this.subtitle});

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: Space.lg, end: Space.sm, top: 6, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.bodyLarge),
                if (subtitle != null) Text(subtitle!, style: context.text.bodySmall),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Row that opens a picker or sheet when tapped, showing the current value.
class TapRow extends StatelessWidget {
  const TapRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: p.textSecondary),
            const SizedBox(width: Space.md),
            Expanded(child: Text(label, style: context.text.bodyLarge)),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(color: p.textSecondary),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: Space.sm),
                  child: Icon(Icons.cancel_rounded, size: 18, color: p.textTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Row with a pop-up menu of options.
class MenuRow<T> extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      itemBuilder: (_) => [
        for (final e in options.entries) PopupMenuItem<T>(value: e.key, child: Text(e.value)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: p.textSecondary),
            const SizedBox(width: Space.md),
            Expanded(child: Text(label, style: context.text.bodyLarge)),
            Flexible(
              child: Text(
                options[value] ?? '',
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(color: p.textSecondary),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.unfold_more_rounded, size: 18, color: p.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// A tappable action line inside an action sheet.
class ActionRow extends StatelessWidget {
  const ActionRow({super.key, required this.icon, required this.label, required this.onTap, this.destructive = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = destructive ? p.danger : p.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 21, color: destructive ? p.danger : p.textSecondary),
            const SizedBox(width: Space.md),
            Expanded(child: Text(label, style: context.text.bodyLarge?.copyWith(color: color))),
          ],
        ),
      ),
    );
  }
}

/// Shows a compact sheet of actions and returns the chosen value.
Future<T?> showActionSheet<T>(BuildContext context, {required String title, String? subtitle, required List<(IconData, String, T, bool)> actions}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: ctx.text.titleMedium, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle, style: ctx.text.bodySmall, textAlign: TextAlign.center),
              ),
            const SizedBox(height: Space.lg),
            GroupBox(children: [
              for (final (icon, label, value, destructive) in actions)
                ActionRow(icon: icon, label: label, destructive: destructive, onTap: () => Navigator.pop(ctx, value)),
            ]),
          ],
        ),
      ),
    ),
  );
}
