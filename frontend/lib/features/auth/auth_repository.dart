import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import 'auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    this.challengeId,
    this.challengeType,
    this.recoveryCodes = const [],
  });

  final String token;
  final AuthUser? user;
  final String? challengeId;
  final String? challengeType;
  final List<String> recoveryCodes;
  bool get requiresVerification => challengeId != null;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String? ?? '',
      user: json['user'] is Map
          ? AuthUser.fromJson(Map<String, dynamic>.from(json['user'] as Map))
          : null,
      challengeId: json['challengeId'] as String?,
      challengeType: json['challengeType'] as String?,
      recoveryCodes: (json['recoveryCodes'] as List? ?? []).cast<String>(),
    );
  }
}

class AuthRepository {
  final ApiClient api;
  AuthRepository(this.api);

  Future<AuthSession> login(String email, String password) async {
    final Response response = await api.dio.post('/auth/login', data: {
      'identifier': email,
      'password': password,
    });
    return AuthSession.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<AuthSession> register(String fullName, String email, String password,
      {String requestedRole = 'USER', String? username}) async {
    final Response response = await api.dio.post('/auth/register', data: {
      'fullName': fullName,
      'email': email,
      'password': password,
      'requestedRole': requestedRole,
      if (username != null && username.trim().isNotEmpty)
        'username': username.trim(),
    });
    return AuthSession.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<AuthUser> me() async {
    final Response response = await api.dio.get('/users/me');
    return AuthUser.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<AuthUser> updateProfile({
    required String fullName,
    required String email,
    String? phoneNumber,
    DateTime? birthDate,
    String? bio,
    String? profilePhotoUrl,
  }) async {
    final Response response = await api.dio.put('/users/me', data: {
      'fullName': fullName,
      'email': email,
      'phoneNumber': _blankToNull(phoneNumber),
      'birthDate': birthDate?.toIso8601String().split('T').first,
      'bio': _blankToNull(bio),
      'profilePhotoUrl': _blankToNull(profilePhotoUrl),
    });
    return AuthUser.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<AuthSession> changePassword(
      String currentPassword, String newPassword) async {
    final response = await api.dio.put('/users/me/password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    return AuthSession.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> forgotPassword(String email) async {
    await api.dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword(
      String email, String code, String newPassword) async {
    await api.dio.post('/auth/reset-password', data: {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
  }

  Future<void> logout() async {
    await api.dio.post('/auth/logout');
  }

  Future<AuthSession> loginWithRecovery(
      String identifier, String password, String code) async {
    final response = await api.dio.post('/auth/login/recovery',
        data: {'identifier': identifier, 'password': password, 'code': code});
    return AuthSession.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<AuthSession> passwordless(String email) async {
    final response = await api.dio
        .post('/auth/passwordless/request', data: {'email': email});
    return AuthSession.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<AuthSession> verifyChallenge(String id, String code,
      {String? recoveryCode,
      bool useRecoveryCode = false,
      bool securityAction = false}) async {
    final path = securityAction
        ? '/security/confirm'
        : useRecoveryCode
            ? '/auth/mfa/recover'
            : '/auth/verify';
    final response = await api.dio.post(path, data: {
      'challengeId': id,
      'code': code,
      if (recoveryCode != null) 'recoveryCode': recoveryCode
    });
    return AuthSession.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<AuthSession> resendChallenge(String id) async {
    final response = await api.dio.post('/auth/challenges/$id/resend');
    return AuthSession.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<Map<String, dynamic>> securityOverview() async {
    final response = await api.dio.get('/security');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<AuthSession> securityChallenge(String action, String password) async {
    final response = await api.dio.post('/security/challenge',
        data: {'action': action, 'currentPassword': password});
    return AuthSession.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<Map<String, dynamic>>> securityList(String path) async {
    final response = await api.dio.get(path);
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> securityPost(
      String path, Map<String, dynamic> data) async {
    final response = await api.dio.post(path, data: data);
    return Map<String, dynamic>.from(response.data as Map);
  }

  String? _blankToNull(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }
}
