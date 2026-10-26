import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_error.dart';
import 'auth_validation.dart';
import 'authentication_state.dart';
import 'widgets/auth_form_widgets.dart';
import 'widgets/auth_scaffold.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _loading = false;
  bool _codeSent = false;
  bool _complete = false;
  bool _initialized = false;
  String? _error;
  int _resendSeconds = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final email = ModalRoute.of(context)?.settings.arguments;
      if (email is String) _email.text = email;
      _initialized = true;
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    _resendSeconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendSeconds--);
      if (_resendSeconds == 0) timer.cancel();
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_loading || (resend && _resendSeconds > 0)) return;
    if (!resend && !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authenticationStateProvider.notifier)
          .forgotPassword(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _startCooldown();
      });
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authenticationStateProvider.notifier).resetPassword(
            _email.text.trim(),
            _code.text,
            _password.text,
          );
      if (!mounted) return;
      TextInput.finishAutofillContext(shouldSave: false);
      _timer?.cancel();
      _code.clear();
      _password.clear();
      _confirmation.clear();
      setState(() => _complete = true);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _complete
          ? 'Un nouveau départ'
          : _codeSent
              ? 'Choisissez un mot de passe'
              : 'Mot de passe oublié ?',
      subtitle: _complete
          ? 'Votre mot de passe a été mis à jour. Vous pouvez vous connecter à votre compte.'
          : _codeSent
              ? 'Si un compte est associé à ${_email.text.trim()}, un code à 6 chiffres a été envoyé. Il est valable 10 minutes.'
              : 'Indiquez votre adresse email. Nous vous enverrons un code pour retrouver votre compte.',
      icon: _complete ? Icons.task_alt_rounded : Icons.lock_reset_rounded,
      showBack: true,
      busy: _loading,
      child: _complete
          ? FilledButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (_) => false),
              child: const Text('Revenir à la connexion'),
            )
          : AutofillGroup(
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) AuthFeedback(message: _error!),
                    if (!_codeSent)
                      TextFormField(
                        controller: _email,
                        enabled: !_loading,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: const InputDecoration(
                            labelText: 'Adresse email',
                            hintText: 'vous@exemple.fr',
                            prefixIcon: Icon(Icons.mail_outline_rounded)),
                        validator: AuthValidation.email,
                        onFieldSubmitted: (_) => _sendCode(),
                      )
                    else ...[
                      TextFormField(
                        controller: _code,
                        enabled: !_loading,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6)
                        ],
                        decoration: const InputDecoration(
                            labelText: 'Code de vérification',
                            hintText: '123456',
                            prefixIcon: Icon(Icons.password_rounded)),
                        validator: (value) =>
                            value == null || !RegExp(r'^\d{6}$').hasMatch(value)
                                ? 'Saisissez le code à 6 chiffres.'
                                : null,
                      ),
                      const SizedBox(height: 18),
                      AuthPasswordField(
                        controller: _password,
                        label: 'Nouveau mot de passe',
                        enabled: !_loading,
                        newPassword: true,
                        textInputAction: TextInputAction.next,
                        validator: AuthValidation.newPassword,
                      ),
                      PasswordStrengthIndicator(controller: _password),
                      const SizedBox(height: 18),
                      AuthPasswordField(
                        controller: _confirmation,
                        label: 'Confirmer le mot de passe',
                        enabled: !_loading,
                        newPassword: true,
                        validator: (value) => AuthValidation.confirmPassword(
                            value, _password.text),
                        onSubmitted: (_) => _resetPassword(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    AuthSubmitButton(
                      label: _codeSent
                          ? 'Enregistrer le mot de passe'
                          : 'Recevoir un code',
                      loadingLabel:
                          _codeSent ? 'Mise à jour…' : 'Envoi en cours…',
                      loading: _loading,
                      onPressed: _codeSent ? _resetPassword : _sendCode,
                    ),
                    const SizedBox(height: 12),
                    if (_codeSent) ...[
                      TextButton(
                        onPressed: _loading || _resendSeconds > 0
                            ? null
                            : () => _sendCode(resend: true),
                        child: Text(_resendSeconds > 0
                            ? 'Renvoyer un code dans ${_resendSeconds}s'
                            : 'Renvoyer un code'),
                      ),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                  _codeSent = false;
                                  _error = null;
                                  _code.clear();
                                  _password.clear();
                                  _confirmation.clear();
                                }),
                        child: const Text('Utiliser une autre adresse email'),
                      ),
                    ] else
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.pushNamedAndRemoveUntil(
                                context, '/login', (_) => false),
                        child: const Text('Revenir à la connexion'),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
