import 'package:flutter_test/flutter_test.dart';
import 'package:focus_reset/data/models/user_profile.dart';
import 'package:focus_reset/domain/scheduling/fixed_blocks.dart';

UserProfile _profile({
  int bed = 23 * 60,
  int wake = 7 * 60,
  WorkPattern pattern = WorkPattern.fixed,
  Set<int> days = const {DateTime.sunday, DateTime.monday},
  int start = 9 * 60,
  int end = 17 * 60,
  int commute = 30,
}) =>
    UserProfile(
      name: 'Test',
      ageRange: AgeRange.r25to34,
      lifestyle: Lifestyle.office,
      workPattern: pattern,
      workDays: days,
      workStartMin: start,
      workEndMin: end,
      bedtimeMin: bed,
      wakeMin: wake,
      commuteBufferMin: commute,
    );

// 2024-01-01 is a Monday; 2024-01-02 Tuesday; 2024-01-07 Sunday.
final monday = DateTime(2024, 1, 1);
final tuesday = DateTime(2024, 1, 2);

void main() {
  group('Sleep', () {
    test('overnight sleep is split across midnight', () {
      final blocks = FixedBlocks.forDay(_profile(pattern: WorkPattern.none), tuesday);
      expect(blocks, [
        const TimeBlock(0, 420, BlockKind.sleep),
        const TimeBlock(1380, 1440, BlockKind.sleep),
      ]);
    });

    test('daytime sleep after a night shift stays one block', () {
      final blocks = FixedBlocks.forDay(_profile(bed: 8 * 60, wake: 15 * 60, pattern: WorkPattern.none), tuesday);
      expect(blocks, [const TimeBlock(480, 900, BlockKind.sleep)]);
    });

    test('midnight bedtime produces a single morning block', () {
      final blocks = FixedBlocks.forDay(_profile(bed: 0, wake: 6 * 60, pattern: WorkPattern.none), tuesday);
      expect(blocks, [const TimeBlock(0, 360, BlockKind.sleep)]);
    });
  });

  group('Work', () {
    test('fixed workday adds work and commute buffers', () {
      final blocks = FixedBlocks.forDay(_profile(), monday);
      expect(blocks, contains(const TimeBlock(510, 540, BlockKind.commute)));
      expect(blocks, contains(const TimeBlock(540, 1020, BlockKind.work)));
      expect(blocks, contains(const TimeBlock(1020, 1050, BlockKind.commute)));
    });

    test('non-working day has no work block', () {
      final blocks = FixedBlocks.forDay(_profile(), tuesday);
      expect(blocks.where((b) => b.kind == BlockKind.work), isEmpty);
    });

    test('variable / shift patterns add no fixed work (entered as commitments)', () {
      for (final p in [WorkPattern.variable, WorkPattern.shifts, WorkPattern.none]) {
        final blocks = FixedBlocks.forDay(_profile(pattern: p), monday);
        expect(blocks.where((b) => b.kind != BlockKind.sleep), isEmpty, reason: '$p');
      }
    });

    test('overnight shift continues into the next morning', () {
      final p = _profile(
        days: const {DateTime.monday},
        start: 22 * 60,
        end: 6 * 60,
        bed: 8 * 60,
        wake: 15 * 60,
        commute: 0,
      );
      expect(FixedBlocks.forDay(p, monday), contains(const TimeBlock(1320, 1440, BlockKind.work)));
      expect(FixedBlocks.forDay(p, tuesday), contains(const TimeBlock(0, 360, BlockKind.work)));
    });
  });

  test('protected minutes count overlaps once', () {
    final blocks = [
      const TimeBlock(0, 100, BlockKind.sleep),
      const TimeBlock(50, 150, BlockKind.work),
    ];
    expect(FixedBlocks.protectedMinutes(blocks), 150);
  });

  test('blocks never overlap for a normal day profile', () {
    final blocks = FixedBlocks.forDay(_profile(), monday);
    for (var i = 0; i < blocks.length; i++) {
      for (var j = i + 1; j < blocks.length; j++) {
        expect(blocks[i].overlaps(blocks[j]), isFalse, reason: '${blocks[i]} vs ${blocks[j]}');
      }
    }
  });

  test('profile JSON round-trips', () {
    final p = _profile();
    final back = UserProfile.fromJson(p.toJson());
    expect(back.toJson(), p.toJson());
  });
}
