import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Activity-style progress ring. [value] is 0…1, or null for "no data".
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 96,
    this.stroke = 10,
    this.center,
  });

  final double? value;
  final Color color;
  final double size;
  final double stroke;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (value ?? 0.0).clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(
            value: v,
            color: color,
            track: color.withValues(alpha: 0.14),
            stroke: stroke,
            rtl: context.isRtl,
          ),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color, required this.track, required this.stroke, required this.rtl});

  final double value;
  final Color color;
  final Color track;
  final double stroke;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, 0, math.pi * 2, false, base..color = track);
    if (value <= 0) return;
    final sweep = math.pi * 2 * value * (rtl ? -1 : 1);
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, base..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track || old.rtl != rtl;
}

/// Minimal vertical bar chart. Bars with value 0 render as a faint
/// baseline so an empty week reads as "no data yet", not as broken UI.
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
    this.height = 120,
    this.highlightIndex,
  }) : assert(values.length == labels.length);

  final List<double> values;
  final List<String> labels;
  final Color color;
  final double height;
  final int? highlightIndex;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxV = values.fold<double>(0, math.max);
    return SizedBox(
      height: height + 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: maxV == 0 ? 0 : values[i] / maxV),
                      duration: Duration(milliseconds: 500 + i * 60),
                      curve: Curves.easeOutCubic,
                      builder: (context, f, _) => Container(
                        height: math.max(4.0, f * height),
                        decoration: BoxDecoration(
                          color: values[i] == 0
                              ? p.surfaceAlt
                              : (highlightIndex == null || highlightIndex == i
                                  ? color
                                  : color.withValues(alpha: 0.35)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: context.text.labelSmall?.copyWith(
                        color: i == highlightIndex ? p.textPrimary : p.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact metric: big number + caption.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: context.text.titleLarge?.copyWith(
            color: color ?? context.palette.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: context.text.bodySmall, maxLines: 2),
      ],
    );
  }
}

/// Neutral empty-state block: icon, title, one line, optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.lg, horizontal: Space.sm),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: c, size: 26),
          ),
          const SizedBox(height: Space.md),
          Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: Space.xs),
          Text(message, style: context.text.bodySmall, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: Space.md),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
                child: Text(actionLabel!, style: context.text.labelLarge?.copyWith(color: c, fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
