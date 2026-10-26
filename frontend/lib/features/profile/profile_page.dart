import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_user.dart';
import '../auth/authentication_state.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authenticationStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          IconButton(
            tooltip: 'Parametres',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: authState.when(
        data: (user) => user == null
            ? const Center(child: Text('Aucun utilisateur connecte.'))
            : _ProfileContent(user: user),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Impossible de charger le profil.')),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: CircleAvatar(
            radius: 42,
            backgroundImage: user.profilePhotoUrl == null
                ? null
                : NetworkImage(user.profilePhotoUrl!),
            child: user.profilePhotoUrl == null
                ? Text(
                    _initials(user.fullName),
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            user.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        Center(child: Text(user.roleLabel)),
        const SizedBox(height: 24),
        _info(Icons.mail_outline, 'Email',
            '${user.email} · ${user.emailVerified ? 'Vérifié' : 'À vérifier'}'),
        if (user.username != null)
          _info(Icons.badge_outlined, 'Identifiant', user.username!),
        ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('Sécurité et accès'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/security')),
        _info(Icons.phone_outlined, 'Telephone', user.phoneNumber ?? '-'),
        _info(Icons.cake_outlined, 'Date de naissance', _date(user.birthDate)),
        _info(Icons.notes_outlined, 'Bio', user.bio ?? '-'),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/profile/edit'),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Modifier le profil'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Parametres'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            await ref.read(authenticationStateProvider.notifier).logout();
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (_) => false);
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Deconnexion'),
        ),
      ],
    );
  }

  Widget _info(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      contentPadding: EdgeInsets.zero,
    );
  }

  String _date(DateTime? date) {
    if (date == null) {
      return '-';
    }
    return date.toIso8601String().split('T').first;
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final letters = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return letters.isEmpty ? 'U' : letters;
  }
}
