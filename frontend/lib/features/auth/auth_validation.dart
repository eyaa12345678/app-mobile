import 'dart:convert';

/// Keep these limits aligned with the API DTOs. Existing passwords remain valid.
class AuthValidation {
  static String? loginIdentifier(String? value) {
    final identifier = value?.trim() ?? '';
    if (identifier.isEmpty) {
      return 'Saisissez votre email ou votre identifiant.';
    }
    if (identifier.contains('@')) return email(identifier);
    return RegExp(r'^[a-zA-Z0-9._-]{3,40}$').hasMatch(identifier)
        ? null
        : 'Identifiant invalide.';
  }

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return RegExp(r'^[a-zA-Z0-9._-]{3,40}$').hasMatch(value.trim())
        ? null
        : '3 à 40 lettres, chiffres, points, tirets ou underscores.';
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Saisissez votre adresse email.';
    if (email.length > 160 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Saisissez une adresse email valide.';
    }
    return null;
  }

  static String? fullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Saisissez votre nom complet.';
    if (name.length > 120) return '120 caractères maximum.';
    return null;
  }

  static String? requiredPassword(String? value) {
    return value == null || value.isEmpty
        ? 'Saisissez votre mot de passe.'
        : null;
  }

  static String? newPassword(String? value) {
    if (value == null || value.trim().isEmpty || value.length < 12) {
      return 'Utilisez au moins 12 caractères.';
    }
    if (value.length > 100) return '100 caractères maximum.';
    if (utf8.encode(value).length > 72) {
      return 'Mot de passe trop long : 72 octets maximum.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirmez votre mot de passe.';
    return value != password ? 'Les mots de passe ne correspondent pas.' : null;
  }
}
