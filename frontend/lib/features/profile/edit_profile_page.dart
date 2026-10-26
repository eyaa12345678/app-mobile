import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_error.dart';
import '../auth/authentication_state.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _birthDate = TextEditingController();
  final _bio = TextEditingController();
  final _profilePhotoUrl = TextEditingController();
  bool _initialized = false;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final user = ref.read(authenticationStateProvider).valueOrNull;
    if (user != null) {
      _fullName.text = user.fullName;
      _email.text = user.email;
      _phoneNumber.text = user.phoneNumber ?? '';
      _birthDate.text =
          user.birthDate?.toIso8601String().split('T').first ?? '';
      _bio.text = user.bio ?? '';
      _profilePhotoUrl.text = user.profilePhotoUrl ?? '';
      _initialized = true;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final parsedBirthDate = _birthDate.text.trim().isEmpty
        ? null
        : DateTime.tryParse(_birthDate.text.trim());
    if (_birthDate.text.trim().isNotEmpty && parsedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format de date attendu: YYYY-MM-DD')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authenticationStateProvider.notifier).updateProfile(
            fullName: _fullName.text.trim(),
            email: _email.text.trim(),
            phoneNumber: _phoneNumber.text,
            birthDate: parsedBirthDate,
            bio: _bio.text,
            profilePhotoUrl: _profilePhotoUrl.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis a jour')),
        );
        Navigator.pop(context);
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
    _fullName.dispose();
    _email.dispose();
    _phoneNumber.dispose();
    _birthDate.dispose();
    _bio.dispose();
    _profilePhotoUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authenticationStateProvider).valueOrNull;
    if (user == null && !_loading) {
      return const Scaffold(
        body: Center(child: Text('Aucun utilisateur connecte.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le profil')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nom requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                readOnly: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email vérifié du compte',
                  helperText:
                      'Cette identité est protégée et ne se modifie pas depuis le profil.',
                  helperMaxLines: 3,
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email requis';
                  }
                  if (!value.contains('@')) {
                    return 'Email invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneNumber,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telephone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _birthDate,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Date de naissance',
                  hintText: 'YYYY-MM-DD',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bio,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _profilePhotoUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL photo de profil',
                  prefixIcon: Icon(Icons.image_outlined),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loading ? null : _save,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_loading ? 'Enregistrement...' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
