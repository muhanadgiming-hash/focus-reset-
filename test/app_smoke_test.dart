import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_reset/app/app.dart';
import 'package:focus_reset/app/app_controller.dart';
import 'package:focus_reset/data/models/user_profile.dart';
import 'package:focus_reset/data/repositories/profile_repository.dart';
import 'package:focus_reset/data/services/preferences_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppController> _controller(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await PreferencesService.create();
  final c = AppController(prefs: prefs, profiles: LocalProfileRepository(prefs));
  await c.load();
  return c;
}

const _profile = UserProfile(
  name: 'Sara',
  ageRange: AgeRange.r25to34,
  lifestyle: Lifestyle.travelCrew,
  workPattern: WorkPattern.variable,
  bedtimeMin: 23 * 60,
  wakeMin: 7 * 60,
);

void main() {
  setUpAll(() async => initializeDateFormatting());

  testWidgets('first launch shows the welcome screen', (tester) async {
    final c = await _controller({'settings.locale': 'en'});
    await tester.pumpWidget(FocusResetApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('Focus Reset'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('Arabic switches layout to right-to-left', (tester) async {
    final c = await _controller({'settings.locale': 'ar'});
    await tester.pumpWidget(FocusResetApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('ابدأ الآن'), findsOneWidget);
    final ctx = tester.element(find.text('ابدأ الآن'));
    expect(Directionality.of(ctx), TextDirection.rtl);
  });

  testWidgets('saved profile opens the main app and every tab renders', (tester) async {
    final c = await _controller({
      'settings.locale': 'en',
      'profile.v1': jsonEncode(_profile.toJson()),
    });
    await tester.pumpWidget(FocusResetApp(controller: c));
    await tester.pump(const Duration(seconds: 1));

    for (final tab in ['Plan', 'Tasks', 'Habits', 'Focus', 'Today']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: 'Tab $tab threw');
    }
  });
}
