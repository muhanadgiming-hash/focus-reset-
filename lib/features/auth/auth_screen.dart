import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/surfaces.dart';
import '../onboarding/onboarding_flow.dart';

enum AuthMode { signIn, signUp }

/// Account screen. The form and validation are final; the Supabase call is
/// wired in Phase 3. Until then the user can continue with data kept only
/// on this device — and the screen says so plainly.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.mode});

  final AuthMode mode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  bool get _isSignUp => widget.mode == AuthMode.signUp;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    showPhaseNotice(context, 3);
  }

  void _continueLocally() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingFlow()));
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    return ok ? null : context.tr('auth.errorEmail');
  }

  String? _validatePassword(String? v) =>
      (v ?? '').length >= 8 ? null : context.tr('auth.errorPassword');

  String? _validateConfirm(String? v) =>
      v == _password.text ? null : context.tr('auth.errorMatch');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter + 4),
            children: [
              Text(
                context.tr(_isSignUp ? 'auth.createTitle' : 'auth.signInTitle'),
                style: context.text.displaySmall,
              ),
              const SizedBox(height: Space.sm),
              Text(context.tr('auth.subtitle'), style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
              const SizedBox(height: Space.xxl),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(hintText: context.tr('auth.email')),
                validator: _validateEmail,
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: [_isSignUp ? AutofillHints.newPassword : AutofillHints.password],
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: context.tr('auth.password'),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                    tooltip: context.tr(_obscure ? 'auth.show' : 'auth.hide'),
                  ),
                ),
                validator: _validatePassword,
              ),
              if (_isSignUp) ...[
                const SizedBox(height: Space.md),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(hintText: context.tr('auth.confirm')),
                  validator: _validateConfirm,
                ),
              ],
              if (!_isSignUp)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => showPhaseNotice(context, 3),
                    child: Text(context.tr('auth.forgot'), style: TextStyle(color: p.accent)),
                  ),
                ),
              const SizedBox(height: Space.xl),
              AppButton(
                label: context.tr(_isSignUp ? 'auth.createButton' : 'auth.signInButton'),
                onPressed: _submit,
              ),
              const SizedBox(height: Space.xl),
              AppCard(
                color: p.accentSoft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.phone_iphone_rounded, color: p.accent),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('auth.localTitle'), style: context.text.titleSmall),
                          const SizedBox(height: 4),
                          Text(context.tr('auth.localBody'), style: context.text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AppButton(
                label: context.tr('auth.continueLocal'),
                tone: ButtonTone.secondary,
                onPressed: _continueLocally,
              ),
              const SizedBox(height: Space.xl),
              Text(
                context.tr('auth.privacyLine'),
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
              const SizedBox(height: Space.xl),
            ],
          ),
        ),
      ),
    );
  }
}
