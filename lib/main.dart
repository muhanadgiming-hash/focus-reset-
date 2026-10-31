import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/account_controller.dart';
import 'app/app.dart';
import 'app/app_controller.dart';
import 'app/integrations_controller.dart';
import 'app/planner_controller.dart';
import 'core/config/env.dart';
import 'data/repositories/planner_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/services/preferences_service.dart';
import 'data/services/supabase_services.dart';
import 'data/sync/sync_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await PreferencesService.create();
  final profileRepo = LocalProfileRepository(prefs);
  final plannerRepo = LocalPlannerRepository(prefs);
  final controller = AppController(prefs: prefs, profiles: profileRepo);
  final planner = PlannerController(repository: plannerRepo);
  await Future.wait([controller.load(), planner.load()]);

  // Cloud account features are enabled only when the build provides keys.
  SupabaseClient? client;
  if (Env.hasSupabase) {
    try {
      await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
      client = Supabase.instance.client;
    } catch (e) {
      debugPrint('Supabase unavailable, running on-device only: $e');
    }
  }

  final account = AccountController(
    app: controller,
    planner: planner,
    auth: client == null ? null : SupabaseAuthService(client),
    engine: client == null
        ? null
        : SyncEngine(
            local: plannerRepo,
            profiles: profileRepo,
            store: prefs,
            remote: SupabaseRemoteStore(client),
          ),
  )..start();

  final integrations = IntegrationsController(app: controller, planner: planner, store: prefs);

  runApp(FocusResetApp(controller: controller, planner: planner, account: account, integrations: integrations));
  // Permissions are only checked here; nothing is requested until the user
  // turns a feature on.
  integrations.start();
}
