import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/authentication_state.dart';
import 'features/auth/forgot_password_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/auth/auth_error.dart';
import 'features/auth/widgets/auth_scaffold.dart';
import 'features/home/home_page.dart';
import 'features/profile/edit_profile_page.dart';
import 'features/profile/profile_page.dart';
import 'features/profile/settings_page.dart';
import 'features/security/security_page.dart';

void main() {
  runApp(const ProviderScope(child: MediCareApp()));
}

class MediCareApp extends ConsumerWidget {
  const MediCareApp({super.key});
  static final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authenticationStateProvider);
    ref.listen(authenticationStateProvider, (previous, next) {
      if (previous?.valueOrNull != null &&
          next.asData != null &&
          next.valueOrNull == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/login', (_) => false);
        });
      }
    });

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'MediCare',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: authState.when(
        data: (user) => user == null ? const LoginPage() : const HomePage(),
        loading: () => const _SplashPage(),
        error: (error, _) => _SessionRecoveryPage(error: error),
      ),
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/forgot-password': (_) => const ForgotPasswordPage(),
        '/home': (_) => const _ProtectedPage(child: HomePage()),
        '/profile': (_) => const _ProtectedPage(child: ProfilePage()),
        '/profile/edit': (_) => const _ProtectedPage(child: EditProfilePage()),
        '/settings': (_) => const _ProtectedPage(child: SettingsPage()),
        '/security': (_) => const _ProtectedPage(child: SecurityPage()),
      },
    );
  }
}

class _ProtectedPage extends ConsumerWidget {
  const _ProtectedPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(authenticationStateProvider).when(
          data: (user) => user == null ? const LoginPage() : child,
          loading: () => const _SplashPage(),
          error: (error, _) => _SessionRecoveryPage(error: error),
        );
  }
}

class _SessionRecoveryPage extends ConsumerWidget {
  const _SessionRecoveryPage({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthScaffold(
      title: 'Retrouvons votre session',
      subtitle: authErrorMessage(error),
      icon: Icons.cloud_off_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () =>
                ref.read(authenticationStateProvider.notifier).restoreSession(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () =>
                ref.read(authenticationStateProvider.notifier).logout(),
            child: const Text('Se connecter à un autre compte'),
          ),
        ],
      ),
    );
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
