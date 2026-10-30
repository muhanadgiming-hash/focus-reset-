import 'package:flutter_test/flutter_test.dart';
import 'package:focus_reset/core/l10n/strings_ar.dart';
import 'package:focus_reset/core/l10n/strings_en.dart';

void main() {
  test('English and Arabic define exactly the same keys', () {
    final onlyEn = kStringsEn.keys.toSet().difference(kStringsAr.keys.toSet());
    final onlyAr = kStringsAr.keys.toSet().difference(kStringsEn.keys.toSet());
    expect(onlyEn, isEmpty, reason: 'Missing in Arabic: $onlyEn');
    expect(onlyAr, isEmpty, reason: 'Missing in English: $onlyAr');
  });

  test('No empty translations', () {
    for (final e in [...kStringsEn.entries, ...kStringsAr.entries]) {
      expect(e.value.trim(), isNotEmpty, reason: 'Empty value for ${e.key}');
    }
  });

  test('Placeholders match between languages', () {
    final re = RegExp(r'\{(\w+)\}');
    for (final key in kStringsEn.keys) {
      final en = re.allMatches(kStringsEn[key]!).map((m) => m.group(1)).toSet();
      final ar = re.allMatches(kStringsAr[key]!).map((m) => m.group(1)).toSet();
      expect(ar, en, reason: 'Placeholder mismatch for $key');
    }
  });
}
