import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';

enum ButtonTone { primary, secondary, plain, destructive }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = ButtonTone.primary,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonTone tone;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, fg) = switch (tone) {
      ButtonTone.primary => (p.textPrimary, p.background),
      ButtonTone.secondary => (p.surface, p.textPrimary),
      ButtonTone.plain => (Colors.transparent, p.accent),
      ButtonTone.destructive => (p.danger.withValues(alpha: 0.12), p.danger),
    };
    final enabled = onPressed != null;

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: Space.sm)],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelLarge?.copyWith(color: fg, fontSize: 16),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.4,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.md)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Selectable chip used for single and multi choice.
class ChoiceChipX extends StatelessWidget {
  const ChoiceChipX({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? p.textPrimary : p.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? p.textPrimary : p.separator, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: selected ? p.background : p.textSecondary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: context.text.labelLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? p.background : p.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS-native sliding segmented control, mirrored correctly in RTL.
class Segmented<T extends Object> extends StatelessWidget {
  const Segmented({super.key, required this.value, required this.items, required this.onChanged});

  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        backgroundColor: p.surfaceAlt,
        thumbColor: p.surface,
        padding: const EdgeInsets.all(3),
        children: {
          for (final e in items.entries)
            e.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                e.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelLarge?.copyWith(fontSize: 13.5),
              ),
            ),
        },
        onValueChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// A row that shows a clock time and opens an iOS wheel picker.
class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.label, required this.minutes, required this.onChanged, this.icon});

  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;
  final IconData? icon;

  Future<void> _pick(BuildContext context) async {
    var temp = minutes;
    final p = context.palette;
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: ctx.text.titleMedium),
            SizedBox(
              height: 216,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(ctx).brightness,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(fontSize: 22, color: p.textPrimary),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  minuteInterval: 5,
                  initialDateTime: DateTime(2000, 1, 1, minutes ~/ 60, (minutes % 60) ~/ 5 * 5),
                  onDateTimeChanged: (d) => temp = d.hour * 60 + d.minute,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
              child: AppButton(label: ctx.tr('common.done'), onPressed: () => Navigator.pop(ctx, temp)),
            ),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(Radii.md)),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 20, color: p.textSecondary), const SizedBox(width: Space.md)],
            Expanded(child: Text(label, style: context.text.bodyLarge)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(8)),
              child: Text(TimeUtils.clock(context, minutes), style: context.text.labelLarge),
            ),
          ],
        ),
      ),
    );
  }
}

/// Labelled form section used in sheets and onboarding.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, top: Space.lg, bottom: Space.sm),
        child: Text(text, style: context.text.labelMedium),
      );
}

/// Honest notice for features scheduled for a later build phase.
void showPhaseNotice(BuildContext context, int phase) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(context.tr('phase.notice', {'n': '$phase'}))));
}
