import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart';
import 'auth_error.dart';
import 'authentication_state.dart';
import 'widgets/auth_form_widgets.dart';
import 'widgets/auth_scaffold.dart';

class VerificationPage extends ConsumerStatefulWidget {
  const VerificationPage(
      {super.key,
      required this.challenge,
      this.securityAction = false,
      this.recoveryLogin});
  final AuthSession challenge;
  final bool securityAction;
  final Future<AuthSession> Function(String code)? recoveryLogin;
  @override
  ConsumerState<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends ConsumerState<VerificationPage> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _recovery = TextEditingController();
  late AuthSession _challenge = widget.challenge;
  bool _loading = false;
  bool _useRecovery = false;
  String? _error;
  int _remaining = 60;
  Timer? _timer;
  bool get _passwordless => _challenge.challengeType == 'PASSWORDLESS';

  @override
  void initState() {
    super.initState();
    _useRecovery = widget.recoveryLogin != null;
    if (widget.recoveryLogin == null) _cooldown();
  }

  void _cooldown() {
    _timer?.cancel();
    _remaining = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining == 0) timer.cancel();
    });
  }

  Future<void> _submit() async {
    if (_loading || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = widget.recoveryLogin != null
          ? await widget.recoveryLogin!(_code.text.trim())
          : await ref.read(authRepositoryProvider).verifyChallenge(
                _challenge.challengeId!,
                _code.text.trim(),
                recoveryCode: _recovery.text.trim(),
                useRecoveryCode: _useRecovery,
                securityAction: widget.securityAction,
              );
      await ref
          .read(authenticationStateProvider.notifier)
          .acceptSession(session);
      if (!mounted) return;
      _timer?.cancel();
      if (session.recoveryCodes.isNotEmpty) {
        await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) => PopScope(
                  canPop: false,
                  child: AlertDialog(
                    title: const Text('Conservez vos codes de récupération'),
                    content: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text(
                              'Chaque code remplace une vérification et ne fonctionne qu’une fois. Ces codes ne seront plus affichés. Conservez-les dans un endroit sûr.'),
                          const SizedBox(height: 16),
                          SelectableText(session.recoveryCodes.join('\n'),
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 13)),
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Clipboard.setData(ClipboardData(
                              text: session.recoveryCodes.join('\n'))),
                          child: const Text('Copier les codes')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('J’ai enregistré mes codes')),
                    ],
                  ),
                ));
      }
      if (!mounted) return;
      if (widget.securityAction) {
        Navigator.pop(context, true);
      } else {
        TextInput.finishAutofillContext();
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      }
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_loading || _remaining > 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(authRepositoryProvider)
          .resendChallenge(_challenge.challengeId!);
      if (mounted) {
        setState(() {
          _challenge = response;
          _code.clear();
          _cooldown();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _recovery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _useRecovery ? 'Retrouvez votre accès' : 'Vérifiez votre identité',
      subtitle: _passwordless
          ? 'Si un compte correspond à cette adresse, un code a été envoyé à son email principal. Le code expire dans 10 minutes.'
          : _useRecovery
              ? 'Saisissez l’un de vos codes de récupération à usage unique.'
              : 'Saisissez le code à 6 chiffres reçu par email. Il expire dans 10 minutes.',
      icon: Icons.mark_email_read_outlined,
      showBack: true,
      busy: _loading,
      child: AutofillGroup(
          child: Form(
              key: _form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) AuthFeedback(message: _error!),
                    TextFormField(
                      key: ValueKey(_useRecovery),
                      controller: _code,
                      enabled: !_loading,
                      keyboardType: _useRecovery
                          ? TextInputType.text
                          : TextInputType.number,
                      autofillHints: _useRecovery
                          ? null
                          : const [AutofillHints.oneTimeCode],
                      inputFormatters: _useRecovery
                          ? null
                          : [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6)
                            ],
                      decoration: InputDecoration(
                          labelText: _useRecovery
                              ? 'Code de récupération'
                              : 'Code reçu par email',
                          prefixIcon: const Icon(Icons.password_rounded)),
                      validator: (value) => _useRecovery
                          ? ((value?.trim().length ?? 0) < 32
                              ? 'Saisissez un code de récupération complet.'
                              : null)
                          : (!RegExp(r'^\d{6}$').hasMatch(value ?? '')
                              ? 'Saisissez le code à 6 chiffres.'
                              : null),
                      onFieldSubmitted: (_) {
                        if (!_passwordless) _submit();
                      },
                    ),
                    if (_passwordless) ...[
                      const SizedBox(height: 18),
                      const Text(
                          'Si votre compte utilise la double vérification, ajoutez un code de récupération. Votre mot de passe n’est pas demandé.',
                          style: TextStyle(height: 1.5)),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _recovery,
                          enabled: !_loading,
                          autocorrect: false,
                          decoration: const InputDecoration(
                              labelText: 'Code de récupération (si activé)',
                              prefixIcon: Icon(Icons.key_outlined)),
                          onFieldSubmitted: (_) => _submit()),
                    ],
                    const SizedBox(height: 24),
                    AuthSubmitButton(
                        label: 'Vérifier et continuer',
                        loadingLabel: 'Vérification…',
                        loading: _loading,
                        onPressed: _submit),
                    if (_challenge.challengeType == 'MFA_LOGIN')
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                  _useRecovery = !_useRecovery;
                                  _code.clear();
                                  _error = null;
                                }),
                        child: Text(_useRecovery
                            ? 'Utiliser le code reçu par email'
                            : 'Utiliser un code de récupération'),
                      ),
                    if (!widget.securityAction && widget.recoveryLogin == null)
                      TextButton(
                          onPressed:
                              _loading || _remaining > 0 ? null : _resend,
                          child: Text(_remaining > 0
                              ? 'Renvoyer un code dans ${_remaining}s'
                              : 'Renvoyer un code')),
                  ]))),
    );
  }
}
