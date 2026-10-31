import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/account_controller.dart';
import '../../app/app_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/services/auth_service.dart';
import '../onboarding/onboarding_flow.dart';

enum AuthMode { signIn, signUp, verify, forgot, reset }

/// Sign in and create an account with email + password. No emails are sent:
/// sign-up is instant (turn off "Confirm email" in Supabase). The code-based
/// verify/reset modes remain only as a fallback if confirmation is enabled.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.mode, this.fromSettings = false});

  final AuthMode mode;

  /// Opened from Profile & Settings (return there when done).
  final bool fromSettings;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  late AuthMode _mode = widget.mode;
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _needsPassword => _mode == AuthMode.signIn || _mode == AuthMode.signUp || _mode == AuthMode.reset;
  bool get _needsConfirm => _mode == AuthMode.signUp || _mode == AuthMode.reset;
  bool get _needsCode => _mode == AuthMode.verify || _mode == AuthMode.reset;

  void _switch(AuthMode m, {String? info}) {
    setState(() {
      _mode = m;
      _error = null;
      _info = info;
      _code.clear();
      if (m != AuthMode.signIn) _confirm.clear();
    });
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final account = AccountScope.read(context);
    final email = _email.text.trim();
    final password = _password.text;
    final code = _code.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (_mode) {
        case AuthMode.signIn:
          await account.signIn(email, password);
          _done();
        case AuthMode.signUp:
          final now = await account.signUp(email, password);
          if (now) {
            _done();
          } else if (mounted) {
            _switch(AuthMode.verify, info: context.tr('auth.codeSent', {'e': email}));
          }
        case AuthMode.verify:
          await account.verifySignUp(email, code);
          _done();
        case AuthMode.forgot:
          await account.sendPasswordReset(email);
          if (mounted) _switch(AuthMode.reset, info: context.tr('auth.codeSent', {'e': email}));
        case AuthMode.reset:
          await account.resetPassword(email, code, password);
          _done();
      }
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = context.tr('auth.err.${e.code}'));
      if (e.code == AuthFailure.emailNotConfirmed) _switch(AuthMode.verify, info: context.tr('auth.err.emailNotConfirmed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _done() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (widget.fromSettings) {
      navigator.pop();
      return;
    }
    if (AppScope.read(context).isOnboarded) {
      // Profile came down from the account: go straight into the app.
      navigator.popUntil((r) => r.isFirst);
    } else {
      navigator.pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingFlow()));
    }
  }

  void _continueLocally() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingFlow()));
  }

  String? _validateEmail(String? v) {
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim());
    return ok ? null : context.tr('auth.errorEmail');
  }

  String? _validatePassword(String? v) => (v ?? '').length >= 8 ? null : context.tr('auth.errorPassword');

  String? _validateConfirm(String? v) => v == _password.text ? null : context.tr('auth.errorMatch');

  String? _validateCode(String? v) =>
      RegExp(r'^\d{6,10}$').hasMatch((v ?? '').trim()) ? null : context.tr('auth.errorCode');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final account = AccountScope.of(context);
    final configured = account.configured;

    final (titleKey, buttonKey) = switch (_mode) {
      AuthMode.signIn => ('auth.signInTitle', 'auth.signInButton'),
      AuthMode.signUp => ('auth.createTitle', 'auth.createButton'),
      AuthMode.verify => ('auth.verifyTitle', 'auth.verifyButton'),
      AuthMode.forgot => ('auth.forgotTitle', 'auth.sendCode'),
      AuthMode.reset => ('auth.resetTitle', 'auth.resetButton'),
    };

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter + 4),
            children: [
              Text(context.tr(titleKey), style: context.text.displaySmall),
              const SizedBox(height: Space.sm),
              Text(
                context.tr(_mode == AuthMode.verify || _mode == AuthMode.reset ? 'auth.codeSubtitle' : 'auth.subtitle'),
                style: context.text.bodyMedium?.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: Space.xxl),
              if (!configured)
                AppCard(
                  color: p.habitSoft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.cloud_off_rounded, color: p.habit),
                      const SizedBox(width: Space.md),
                      Expanded(child: Text(context.tr('auth.notConfigured'), style: context.text.bodySmall?.copyWith(color: p.textPrimary))),
                    ],
                  ),
                ),
              if (_info != null)
                AppCard(
                  color: p.accentSoft,
                  child: Text(_info!, style: context.text.bodySmall?.copyWith(color: p.textPrimary)),
                ),
              TextFormField(
                controller: _email,
                enabled: _mode != AuthMode.verify && _mode != AuthMode.reset,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.ltr,
                autocorrect: false,
                decoration: InputDecoration(hintText: context.tr('auth.email')),
                validator: _validateEmail,
              ),
              if (_needsCode) ...[
                const SizedBox(height: Space.md),
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textDirection: TextDirection.ltr,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  style: context.text.titleLarge?.copyWith(letterSpacing: 6),
                  decoration: InputDecoration(hintText: context.tr('auth.code')),
                  validator: _validateCode,
                ),
              ],
              if (_needsPassword) ...[
                const SizedBox(height: Space.md),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: [_mode == AuthMode.signIn ? AutofillHints.password : AutofillHints.newPassword],
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: context.tr(_mode == AuthMode.reset ? 'auth.newPassword' : 'auth.password'),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                      tooltip: context.tr(_obscure ? 'auth.show' : 'auth.hide'),
                    ),
                  ),
                  validator: _validatePassword,
                ),
              ],
              if (_needsConfirm) ...[
                const SizedBox(height: Space.md),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(hintText: context.tr('auth.confirm')),
                  validator: _validateConfirm,
                ),
              ],
              if (_mode == AuthMode.signUp)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4, top: Space.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.key_rounded, size: 16, color: p.habit),
                      const SizedBox(width: Space.sm),
                      Expanded(child: Text(context.tr('auth.noRecovery'), style: context.text.bodySmall)),
                    ],
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: Text(_error!, style: context.text.bodyMedium?.copyWith(color: p.danger)),
                ),
              const SizedBox(height: Space.xl),
              _busy
                  ? const Center(child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator.adaptive()))
                  : AppButton(label: context.tr(buttonKey), onPressed: configured ? _submit : null),
              const SizedBox(height: Space.sm),
              if (_mode == AuthMode.signIn)
                AppButton(
                  label: context.tr('auth.noAccount'),
                  tone: ButtonTone.plain,
                  onPressed: () => _switch(AuthMode.signUp),
                )
              else if (_mode == AuthMode.signUp)
                AppButton(
                  label: context.tr('welcome.haveAccount'),
                  tone: ButtonTone.plain,
                  onPressed: () => _switch(AuthMode.signIn),
                )
              else if (_mode == AuthMode.verify)
                AppButton(
                  label: context.tr('auth.resend'),
                  tone: ButtonTone.plain,
                  onPressed: _busy ? null : () => _switch(AuthMode.signUp, info: context.tr('auth.resendHint')),
                )
              else
                AppButton(
                  label: context.tr('auth.backToSignIn'),
                  tone: ButtonTone.plain,
                  onPressed: () => _switch(AuthMode.signIn),
                ),
              if (!widget.fromSettings) ...[
                const SizedBox(height: Space.lg),
                AppCard(
                  color: p.surface,
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
              ],
              const SizedBox(height: Space.xl),
              Text(context.tr('auth.privacyLine'), textAlign: TextAlign.center, style: context.text.bodySmall),
              const SizedBox(height: Space.xl),
            ],
          ),
        ),
      ),
    );
  }
}
