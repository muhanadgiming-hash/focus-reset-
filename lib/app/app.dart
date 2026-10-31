import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/welcome_screen.dart';
import '../features/shell/main_shell.dart';
import 'account_controller.dart';
import 'app_controller.dart';
import 'integrations_controller.dart';
import 'planner_controller.dart';

class FocusResetApp extends StatelessWidget {
  const FocusResetApp({
    super.key,
    required this.controller,
    required this.planner,
    required this.account,
    required this.integrations,
  });

  final AppController controller;
  final PlannerController planner;
  final AccountController account;
  final IntegrationsController integrations;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: PlannerScope(
        controller: planner,
        child: AccountScope(
          controller: account,
          child: IntegrationsScope(
            controller: integrations,
            child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          title: 'Focus Reset',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: controller.themeMode,
          locale: controller.locale,
          supportedLocales: AppStrings.supportedLocales,
          localeResolutionCallback: AppStrings.resolve,
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const _RootGate(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows onboarding until a profile exists, then the main app.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final onboarded = AppScope.of(context).isOnboarded;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: onboarded
          ? const MainShell(key: ValueKey('shell'))
          : const WelcomeScreen(key: ValueKey('welcome')),
    );
  }
}
