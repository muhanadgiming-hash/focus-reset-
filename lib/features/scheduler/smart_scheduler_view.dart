import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/surfaces.dart';
import '../../domain/scheduling/fixed_blocks.dart';
import 'block_style.dart';

class SmartSchedulerView extends StatefulWidget {
  const SmartSchedulerView({super.key});

  @override
  State<SmartSchedulerView> createState() => _SmartSchedulerViewState();
}

class _SmartSchedulerViewState extends State<SmartSchedulerView> {
  DateTime _day = TimeUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final profile = AppScope.of(context).profile;
    if (profile == null) return const SizedBox.shrink();
    final p = context.palette;

    final blocks = FixedBlocks.forDay(profile, _day);
    final protectedMin = FixedBlocks.protectedMinutes(blocks);
    final freeMin = TimeUtils.minutesPerDay - protectedMin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DayStrip(selected: _day, onSelect: (d) => setState(() => _day = d)),
        const SizedBox(height: Space.md),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: StatTile(
                  value: TimeUtils.duration(context, protectedMin),
                  label: context.tr('smart.protected'),
                  color: p.sleep,
                ),
              ),
              Container(width: 0.5, height: 36, color: p.separator),
              const SizedBox(width: Space.lg),
              Expanded(
                child: StatTile(
                  value: TimeUtils.duration(context, freeMin),
                  label: context.tr('smart.available'),
                  color: p.accent,
                ),
              ),
            ],
          ),
        ),
        AppCard(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.lg, Space.lg, Space.lg),
          child: DayTimeline(blocks: blocks),
        ),
        AppButton(
          label: context.tr('smart.generate'),
          icon: Icons.auto_fix_high_rounded,
          onPressed: () => showPhaseNotice(context, 2),
        ),
        Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: Text(context.tr('smart.generateNote'), style: context.text.bodySmall, textAlign: TextAlign.center),
        ),
        SectionHeader(context.tr('smart.unscheduled')),
        AppCard(
          child: EmptyState(
            icon: Icons.inbox_outlined,
            title: context.tr('smart.unscheduledEmpty'),
            message: context.tr('smart.unscheduledBody'),
          ),
        ),
        SectionHeader(context.tr('smart.rulesTitle')),
        AppCard(
          child: Column(
            children: [
              _Rule(icon: Icons.lock_outline_rounded, color: p.work, text: context.tr('smart.rule1')),
              _Rule(icon: Icons.bedtime_outlined, color: p.sleep, text: context.tr('smart.rule2')),
              _Rule(icon: Icons.priority_high_rounded, color: p.danger, text: context.tr('smart.rule3')),
              _Rule(icon: Icons.air_rounded, color: p.accent, text: context.tr('smart.rule4')),
              _Rule(icon: Icons.fact_check_outlined, color: p.focus, text: context.tr('smart.rule5'), last: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.color, required this.text, this.last = false});

  final IconData icon;
  final Color color;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: Space.md),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.selected, required this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final today = TimeUtils.dateOnly(DateTime.now());
    final tag = context.localeTag;
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
        itemBuilder: (context, i) {
          final d = today.add(Duration(days: i));
          final isSel = TimeUtils.isSameDay(d, selected);
          return GestureDetector(
            onTap: () => onSelect(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 52,
              decoration: BoxDecoration(
                color: isSel ? p.textPrimary : p.surface,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.E(tag).format(d),
                    style: context.text.labelSmall?.copyWith(color: isSel ? p.background : p.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.d(tag).format(d),
                    style: context.text.titleMedium?.copyWith(color: isSel ? p.background : p.textPrimary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Vertical 24-hour timeline with positioned blocks. Mirrors in RTL.
class DayTimeline extends StatelessWidget {
  const DayTimeline({super.key, required this.blocks, this.hourHeight = 40});

  final List<TimeBlock> blocks;
  final double hourHeight;

  static const double _labelWidth = 52;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final total = hourHeight * 24;

    return SizedBox(
      height: total,
      child: Stack(
        children: [
          for (var h = 0; h <= 23; h++)
            PositionedDirectional(
              top: h * hourHeight,
              start: 0,
              end: 0,
              height: hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _labelWidth,
                    child: Transform.translate(
                      offset: const Offset(0, -7),
                      child: Text(
                        h == 0 ? '' : TimeUtils.clock(context, h * 60),
                        style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  Expanded(child: Container(height: 0.5, color: p.separator)),
                ],
              ),
            ),
          for (final b in blocks)
            PositionedDirectional(
              top: b.startMin / 60 * hourHeight + 1,
              height: (b.lengthMin / 60 * hourHeight - 2).clamp(6.0, total),
              start: _labelWidth + 4,
              end: 0,
              child: _BlockTile(block: b),
            ),
          PositionedDirectional(
            top: nowMin / 60 * hourHeight - 4,
            start: _labelWidth - 4,
            end: 0,
            height: 8,
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: p.danger, shape: BoxShape.circle)),
                Expanded(child: Container(height: 1.5, color: p.danger)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({required this.block});

  final TimeBlock block;

  @override
  Widget build(BuildContext context) {
    final s = BlockStyle.of(context, block.kind);
    final tall = block.lengthMin >= 45;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: s.soft, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(width: 3, color: s.color),
          const SizedBox(width: 8),
          if (tall) ...[
            Icon(s.icon, size: 14, color: s.color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${context.tr(s.labelKey)} · ${TimeUtils.clock(context, block.startMin)}–${TimeUtils.clock(context, block.endMin % 1440)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(color: s.color, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
