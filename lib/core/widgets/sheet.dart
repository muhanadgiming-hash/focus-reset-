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
