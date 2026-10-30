import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/controls.dart';
import 'auth_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final app = AppScope.of(context);
    final isAr = AppStrings.of(context).isArabic;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: GestureDetector(
                    onTap: () => app.setLocale(Locale(isAr ? 'en' : 'ar')),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(99)),
                      child: Text(isAr ? 'English' : 'العربية', style: context.text.labelLarge?.copyWith(fontSize: 14)),
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              const BrandMark(size: 76),
              const SizedBox(height: Space.xxl),
              Text('Focus Reset', style: context.text.displaySmall),
              const SizedBox(height: Space.sm),
              Text(context.tr('welcome.tagline'), style: context.text.bodyLarge?.copyWith(color: p.textSecondary)),
              const SizedBox(height: Space.xxxl),
              _Point(icon: Icons.event_note_rounded, color: p.accent, text: context.tr('welcome.point1')),
              _Point(icon: Icons.self_improvement_rounded, color: p.focus, text: context.tr('welcome.point2')),
              _Point(icon: Icons.lock_outline_rounded, color: p.sleep, text: context.tr('welcome.point3')),
              const Spacer(flex: 3),
              AppButton(
                label: context.tr('welcome.getStarted'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AuthScreen(mode: AuthMode.signUp)),
                ),
              ),
              const SizedBox(height: Space.sm),
              AppButton(
                label: context.tr('welcome.haveAccount'),
                tone: ButtonTone.plain,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AuthScreen(mode: AuthMode.signIn)),
                ),
              ),
              const SizedBox(height: Space.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: Space.md),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}
