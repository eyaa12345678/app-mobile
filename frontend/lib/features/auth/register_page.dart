import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_error.dart';
import 'auth_validation.dart';
import 'authentication_state.dart';
import 'verification_page.dart';
import 'widgets/auth_form_widgets.dart';
import 'widgets/auth_scaffold.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  String _requestedRole = 'USER';
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _confirmationKey = GlobalKey<FormFieldState<String>>();
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await ref.read(authenticationStateProvider.notifier).register(
                _name.text.trim(),
                _email.text.trim(),
                _password.text,
                requestedRole: _requestedRole,
                username: _username.text.trim().isEmpty
                    ? null
                    : _username.text.trim(),
              );
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

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Votre santé commence ici',
      subtitle: 'Créez votre compte pour organiser votre suivi au quotidien.',
      icon: Icons.person_add_alt_1_outlined,
      showBack: true,
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
                controller: _name,
                enabled: !_loading,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person_outline_rounded)),
                validator: AuthValidation.fullName,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _email,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(
                    labelText: 'Adresse email',
                    hintText: 'vous@exemple.fr',
                    prefixIcon: Icon(Icons.mail_outline_rounded)),
                validator: AuthValidation.email,
              ),
              const SizedBox(height: 18),
              TextFormField(
                  controller: _username,
                  enabled: !_loading,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                      labelText: 'Identifiant (facultatif)',
                      prefixIcon: Icon(Icons.badge_outlined)),
                  validator: AuthValidation.username),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _requestedRole,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Rôle souhaité',
                    prefixIcon: Icon(Icons.manage_accounts_outlined)),
                items: const [
                  DropdownMenuItem(value: 'USER', child: Text('Patient')),
                  DropdownMenuItem(value: 'DOCTOR', child: Text('Médecin')),
                  DropdownMenuItem(
                      value: 'ADMIN', child: Text('Administrateur'))
                ],
                onChanged: _loading
                    ? null
                    : (value) => setState(() => _requestedRole = value!),
              ),
              const SizedBox(height: 10),
              const Text(
                  'Les rôles Médecin et Administrateur nécessitent une validation. Votre compte Patient reste utilisable pendant l’examen.',
                  style: TextStyle(
                      fontSize: 12, height: 1.5, color: Color(0xFF637D88))),
              const SizedBox(height: 18),
              AuthPasswordField(
                controller: _password,
                label: 'Mot de passe',
                enabled: !_loading,
                newPassword: true,
                textInputAction: TextInputAction.next,
                validator: AuthValidation.newPassword,
                onChanged: (_) {
                  if (_confirmPassword.text.isNotEmpty) {
                    _confirmationKey.currentState?.validate();
                  }
                },
              ),
              PasswordStrengthIndicator(controller: _password),
              const SizedBox(height: 18),
              AuthPasswordField(
                fieldKey: _confirmationKey,
                controller: _confirmPassword,
                label: 'Confirmer le mot de passe',
                enabled: !_loading,
                newPassword: true,
                validator: (value) =>
                    AuthValidation.confirmPassword(value, _password.text),
                onSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 24),
              AuthSubmitButton(
                  label: 'Créer mon compte',
                  loadingLabel: 'Création du compte…',
                  loading: _loading,
                  onPressed: _register),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/login', (_) => false);
                      },
                child: const Text('Déjà un compte ? Se connecter',
                    textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
