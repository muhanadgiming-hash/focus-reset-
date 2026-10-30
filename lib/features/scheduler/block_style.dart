import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../domain/scheduling/fixed_blocks.dart';

class BlockStyle {
  const BlockStyle(this.color, this.soft, this.icon, this.labelKey);
  final Color color;
  final Color soft;
  final IconData icon;
  final String labelKey;

  static BlockStyle of(BuildContext context, BlockKind kind) {
    final p = context.palette;
    return switch (kind) {
      BlockKind.sleep => BlockStyle(p.sleep, p.sleepSoft, Icons.bedtime_rounded, 'block.sleep'),
      BlockKind.work => BlockStyle(p.work, p.workSoft, Icons.work_rounded, 'block.work'),
      BlockKind.commute => BlockStyle(p.textSecondary, p.surfaceAlt, Icons.directions_car_rounded, 'block.commute'),
    };
  }
}
