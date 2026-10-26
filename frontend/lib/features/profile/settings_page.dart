import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_error.dart';
import '../auth/authentication_state.dart';
import '../auth/auth_validation.dart';
import '../auth/widgets/auth_form_widgets.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;

  Future<void> _changePassword() async {
    if (_loading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref.read(authenticationStateProvider.notifier).changePassword(
            _currentPassword.text,
            _newPassword.text,
          );
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe mis à jour')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authenticationStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Rôle'),
            subtitle: Text(user?.roleLabel ?? '-'),
          ),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: const Text('Sécurité et accès'),
                  subtitle: const Text(
                      'Double vérification, récupération, rôles et rapprochement de comptes'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/security'))),
          const Divider(height: 32),
          const Text(
            'Changer le mot de passe',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                AuthPasswordField(
                  controller: _currentPassword,
                  label: 'Mot de passe actuel',
                  enabled: !_loading,
                  textInputAction: TextInputAction.next,
                  validator: AuthValidation.requiredPassword,
                ),
                const SizedBox(height: 12),
                AuthPasswordField(
                  controller: _newPassword,
                  label: 'Nouveau mot de passe',
                  enabled: !_loading,
                  newPassword: true,
                  textInputAction: TextInputAction.next,
                  validator: AuthValidation.newPassword,
                ),
                PasswordStrengthIndicator(controller: _newPassword),
                const SizedBox(height: 12),
                AuthPasswordField(
                  controller: _confirmPassword,
                  label: 'Confirmer le nouveau mot de passe',
                  enabled: !_loading,
                  newPassword: true,
                  validator: (value) =>
                      AuthValidation.confirmPassword(value, _newPassword.text),
                  onSubmitted: (_) => _changePassword(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _changePassword,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_loading ? 'Mise à jour…' : 'Mettre à jour'),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _loading
                ? null
                : () async {
                    await ref
                        .read(authenticationStateProvider.notifier)
                        .logout();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/login', (_) => false);
                    }
                  },
            icon: const Icon(Icons.logout),
            label: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }
}
