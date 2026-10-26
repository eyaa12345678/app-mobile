class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.username,
    this.emailVerified = false,
    this.mfaEnabled = false,
    this.passwordResetRequired = false,
    this.phoneNumber,
    this.birthDate,
    this.bio,
    this.profilePhotoUrl,
  });

  final int id;
  final String fullName;
  final String email;
  final String role;
  String get roleLabel =>
      const {
        'USER': 'Patient',
        'DOCTOR': 'Médecin',
        'ADMIN': 'Administrateur'
      }[role] ??
      role;
  final String? username;
  final bool emailVerified;
  final bool mfaEnabled;
  final bool passwordResetRequired;
  final String? phoneNumber;
  final DateTime? birthDate;
  final String? bio;
  final String? profilePhotoUrl;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num).toInt(),
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'USER',
      username: json['username'] as String?,
      emailVerified: json['emailVerified'] == true,
      mfaEnabled: json['mfaEnabled'] == true,
      passwordResetRequired: json['passwordResetRequired'] == true,
      phoneNumber: json['phoneNumber'] as String?,
      birthDate: _parseDate(json['birthDate']),
      bio: json['bio'] as String?,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
