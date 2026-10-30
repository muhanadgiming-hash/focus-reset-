import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Large-title page in the style of iOS system apps.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.children,
    this.floatingAction,
    this.showBack = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  final Widget? floatingAction;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: floatingAction,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.sm, Space.gutter, 120),
          children: [
            if (showBack)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppIconButton(
                  icon: context.isRtl ? CupertinoIcons.chevron_right : CupertinoIcons.chevron_left,
                  onTap: () => Navigator.of(context).maybePop(),
                  semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.sm, bottom: Space.xl),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(subtitle!.toUpperCase(), style: context.text.labelMedium),
                          ),
                        Text(title, style: context.text.displaySmall),
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Rounded surface card. All grouped content sits on one of these.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.onTap,
    this.color,
    this.margin = const EdgeInsets.only(bottom: Space.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.palette.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return _Pressable(onTap: onTap!, child: card);
  }
}

/// Subtle scale-down on press, like iOS cards.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.lg, bottom: Space.sm, start: 4, end: 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.titleMedium)),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!, style: context.text.labelLarge?.copyWith(color: context.palette.accent)),
            ),
        ],
      ),
    );
  }
}

/// Soft-tinted rounded icon used across lists and cards.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, required this.color, required this.background, this.size = 36});

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({super.key, required this.icon, required this.onTap, this.semanticLabel, this.filled = true});

  final IconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: filled ? context.palette.surface : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: context.palette.textPrimary),
        ),
      ),
    );
  }
}

/// Chevron that points "forward" in both LTR and RTL.
class ForwardChevron extends StatelessWidget {
  const ForwardChevron({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(
      context.isRtl ? CupertinoIcons.chevron_left : CupertinoIcons.chevron_right,
      size: 16,
      color: context.palette.textTertiary,
    );
  }
}

/// Small rounded status label, e.g. "Phase 4" or "Not active".
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.color, this.background});

  final String label;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: context.text.labelMedium?.copyWith(
          color: color ?? context.palette.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
