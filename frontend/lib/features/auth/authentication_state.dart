import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import 'auth_repository.dart';
import 'auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(apiClientProvider)),
);

final authenticationStateProvider =
    StateNotifierProvider<AuthenticationController, AsyncValue<AuthUser?>>(
  (ref) {
    final controller = AuthenticationController(ref);
    ref.listen<int>(
        sessionExpirationProvider, (_, __) => controller.expireSession());
    return controller;
  },
);

class AuthenticationController extends StateNotifier<AsyncValue<AuthUser?>> {
  AuthenticationController(this.ref) : super(const AsyncValue.loading()) {
    restoreSession();
  }

  final Ref ref;

  Future<void> restoreSession() async {
    state = const AsyncValue.loading();
    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        state = const AsyncValue.data(null);
        return;
      }
      final user = await ref.read(authRepositoryProvider).me();
      if (mounted) state = AsyncValue.data(user);
    } catch (error, stack) {
      if (!mounted) return;
      if (error is DioException && error.response?.statusCode == 401) {
        await expireSession();
      } else {
        // Keep the token when the network or server is temporarily unavailable.
        state = AsyncValue.error(error, stack);
      }
    }
  }

  Future<AuthSession> acceptSession(AuthSession session) async {
    if (session.requiresVerification) return session;
    if (session.token.isEmpty || session.user == null) {
      throw StateError('Invalid session');
    }
    await ref.read(tokenStorageProvider).save(session.token);
    if (mounted) state = AsyncValue.data(session.user);
    return session;
  }

  Future<AuthSession> login(String email, String password) async {
    return acceptSession(
        await ref.read(authRepositoryProvider).login(email, password));
  }

  Future<AuthSession> register(String fullName, String email, String password,
      {String requestedRole = 'USER', String? username}) async {
    return acceptSession(await ref.read(authRepositoryProvider).register(
        fullName, email, password,
        requestedRole: requestedRole, username: username));
  }

  Future<void> updateProfile({
    required String fullName,
    required String email,
    String? phoneNumber,
    DateTime? birthDate,
    String? bio,
    String? profilePhotoUrl,
  }) async {
    try {
      final user = await ref.read(authRepositoryProvider).updateProfile(
            fullName: fullName,
            email: email,
            phoneNumber: phoneNumber,
            birthDate: birthDate,
            bio: bio,
            profilePhotoUrl: profilePhotoUrl,
          );
      state = AsyncValue.data(user);
    } catch (_) {
      rethrow;
    }
  }

  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    await acceptSession(await ref
        .read(authRepositoryProvider)
        .changePassword(currentPassword, newPassword));
  }

  Future<void> forgotPassword(String email) async {
    await ref.read(authRepositoryProvider).forgotPassword(email);
  }

  Future<void> resetPassword(
      String email, String code, String newPassword) async {
    await ref
        .read(authRepositoryProvider)
        .resetPassword(email, code, newPassword);
  }

  Future<void> expireSession() async {
    final storage = ref.read(tokenStorageProvider);
    // Hide protected pages immediately, even if secure storage fails.
    if (mounted) state = const AsyncValue.data(null);
    try {
      await storage.clear();
    } catch (error, stack) {
      if (mounted) state = AsyncValue.error(error, stack);
    }
  }

  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    await expireSession();
    try {
      await repository.logout();
    } catch (_) {
      // Local logout must work even if the token is expired or the API is offline.
    }
  }
}
