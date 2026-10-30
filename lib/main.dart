import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/app_controller.dart';
import 'data/repositories/profile_repository.dart';
import 'data/services/preferences_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await PreferencesService.create();
  final controller = AppController(
    prefs: prefs,
    profiles: LocalProfileRepository(prefs),
  );
  await controller.load();

  runApp(FocusResetApp(controller: controller));
}
