import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_error.dart';
import 'auth_validation.dart';
import 'authentication_state.dart';
import 'verification_page.dart';
import 'auth_repository.dart';
import 'widgets/auth_form_widgets.dart';
import 'widgets/auth_scaffold.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(authenticationStateProvider.notifier)
          .login(_email.text.trim(), _password.text);
      if (!mounted) return;
      if (response.requiresVerification) {
        setState(() => _loading = false);
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => VerificationPage(challenge: response)));
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

  Future<void> _recoveryLogin() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VerificationPage(
                  challenge: const AuthSession(
                      token: '', user: null, challengeType: 'RECOVERY_LOGIN'),
                  recoveryLogin: (code) => ref
                      .read(authRepositoryProvider)
                      .loginWithRecovery(
                          _email.text.trim(), _password.text, code),
                )));
  }

  Future<void> _passwordless() async {
    if (_loading) return;
    final error = AuthValidation.email(_email.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(authRepositoryProvider)
          .passwordless(_email.text.trim());
      if (!mounted) return;
      setState(() => _loading = false);
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => VerificationPage(challenge: response)));
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Heureux de vous revoir',
      subtitle: 'Connectez-vous pour retrouver votre espace santé.',
      busy: _loading,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) AuthFeedback(message: _error!),
              TextFormField(
                controller: _email,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email
                ],
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email ou identifiant',
                  hintText: 'vous@exemple.fr',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: AuthValidation.loginIdentifier,
              ),
              const SizedBox(height: 18),
              AuthPasswordField(
                controller: _password,
                label: 'Mot de passe',
                enabled: !_loading,
                validator: AuthValidation.requiredPassword,
                onSubmitted: (_) => _login(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.pushNamed(
                            context,
                            '/forgot-password',
                            arguments: _email.text.trim(),
                          ),
                  child: const Text('Mot de passe oublié ?'),
                ),
              ),
              const SizedBox(height: 8),
              AuthSubmitButton(
                label: 'Se connecter',
                loadingLabel: 'Connexion en cours…',
                loading: _loading,
                onPressed: _login,
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                  onPressed: _loading ? null : _passwordless,
                  icon: const Icon(Icons.alternate_email_rounded),
                  label: const Text('Me connecter par code email',
                      textAlign: TextAlign.center)),
              TextButton.icon(
                  onPressed: _loading ? null : _recoveryLogin,
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('Connexion avec un code de récupération',
                      textAlign: TextAlign.center)),
              const SizedBox(height: 14),
              const Row(children: [
                Expanded(child: Divider()),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Nouveau sur MediCare ?',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF637D88))),
                  ),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.pushNamed(context, '/register'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Créer un compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
