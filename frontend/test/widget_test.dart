import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/main.dart';
import 'package:medicare/core/network/api_client.dart';
import 'package:medicare/core/providers.dart';
import 'package:medicare/core/storage/token_storage.dart';
import 'package:medicare/features/auth/auth_repository.dart';
import 'package:medicare/features/auth/auth_user.dart';
import 'package:medicare/features/auth/authentication_state.dart';
import 'package:medicare/features/auth/forgot_password_page.dart';
import 'package:medicare/features/auth/login_page.dart';
import 'package:medicare/features/auth/register_page.dart';
import 'package:medicare/features/auth/verification_page.dart';

const user = AuthUser(
    id: 1, fullName: 'Alice Martin', email: 'alice@example.fr', role: 'USER');

class MemoryTokenStorage extends TokenStorage {
  String? token;
  int clears = 0;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> save(String value) async => token = value;
  @override
  Future<void> clear() async {
    token = null;
    clears++;
  }
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(ApiClient(MemoryTokenStorage()));
  int logins = 0;
  int registrations = 0;
  int verifications = 0;
  bool challengeLogin = false;
  String? selectedRole;
  String? verifiedRecovery;
  bool usedRecovery = false;
  int backupLogins = 0;
  String? postedPath;
  Map<String, dynamic>? postedData;
  String? recoveryEmail;
  String? resetCode;
  String? resetPasswordValue;
  Object? loginError;
  Object? sessionError;
  Completer<AuthSession>? pendingLogin;

  @override
  Future<AuthSession> login(String email, String password) async {
    logins++;
    if (loginError != null) throw loginError!;
    if (challengeLogin) {
      return const AuthSession(
          token: '',
          user: null,
          challengeId: 'challenge',
          challengeType: 'MFA_LOGIN');
    }
    return pendingLogin == null
        ? const AuthSession(token: 'token', user: user)
        : pendingLogin!.future;
  }

  @override
  Future<AuthSession> register(String fullName, String email, String password,
      {String requestedRole = 'USER', String? username}) async {
    registrations++;
    selectedRole = requestedRole;
    return const AuthSession(token: 'token', user: user);
  }

  @override
  Future<AuthSession> loginWithRecovery(
      String identifier, String password, String code) async {
    backupLogins++;
    return const AuthSession(token: 'backup-token', user: user);
  }

  @override
  Future<AuthSession> passwordless(String email) async => const AuthSession(
      token: '',
      user: null,
      challengeId: 'challenge',
      challengeType: 'PASSWORDLESS');

  @override
  Future<AuthSession> verifyChallenge(String id, String code,
      {String? recoveryCode,
      bool useRecoveryCode = false,
      bool securityAction = false}) async {
    verifications++;
    verifiedRecovery = recoveryCode;
    usedRecovery = useRecoveryCode;
    return const AuthSession(token: 'verified-token', user: user);
  }

  @override
  Future<Map<String, dynamic>> securityOverview() async => {
        'user': {
          'email': user.email,
          'emailVerified': true,
          'mfaEnabled': true
        },
        'recoveryCodesRemaining': 10,
        'compromisedPasswordCheck': true
      };

  @override
  Future<List<Map<String, dynamic>>> securityList(String path) async => [];

  @override
  Future<Map<String, dynamic>> securityPost(
      String path, Map<String, dynamic> data) async {
    postedPath = path;
    postedData = data;
    return {};
  }

  @override
  Future<AuthUser> me() async {
    if (sessionError != null) throw sessionError!;
    return user;
  }

  @override
  Future<void> forgotPassword(String email) async {
    recoveryEmail = email;
  }

  @override
  Future<void> resetPassword(
      String email, String code, String newPassword) async {
    resetCode = code;
    resetPasswordValue = newPassword;
  }
}

class AdministratorRepository extends FakeAuthRepository {
  @override
  Future<AuthUser> me() async => const AuthUser(
      id: 99,
      fullName: 'Admin Example',
      email: 'admin@example.fr',
      role: 'ADMIN',
      emailVerified: true,
      mfaEnabled: true);
  @override
  Future<List<Map<String, dynamic>>> securityList(String path) async =>
      path == '/security/admin/merges'
          ? [
              {
                'id': 'merge-1',
                'primaryUserId': 1,
                'secondaryUserId': 2,
                'targetEmail': 'second@example.fr',
                'reason': 'Les deux comptes ont été vérifiés.',
                'status': 'AWAITING_REVIEW',
                'conflicts': {
                  'fullName': ['Alice Martin', 'Alice Dupont']
                }
              }
            ]
          : [];
}

DioException requestError(int? status) => DioException(
      requestOptions: RequestOptions(path: '/users/me'),
      type: status == null
          ? DioExceptionType.connectionError
          : DioExceptionType.badResponse,
      response: status == null
          ? null
          : Response(
              requestOptions: RequestOptions(path: '/users/me'),
              statusCode: status),
    );

Future<void> showPage(WidgetTester tester, FakeAuthRepository repository,
    {Widget page = const LoginPage(), Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
      authRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      home: page,
      routes: {
        '/home': (_) => const Scaffold(body: Text('Espace santé')),
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/forgot-password': (_) => const ForgotPasswordPage(),
      },
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Invalid email is rejected before calling the API',
      (tester) async {
    final repository = FakeAuthRepository();
    await showPage(tester, repository);
    await tester.enterText(find.byType(TextFormField).at(0), 'alice@');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tapVisible(tester, find.text('Se connecter'));
    expect(find.text('Saisissez une adresse email valide.'), findsOneWidget);
    expect(repository.logins, 0);
  });

  testWidgets('Password visibility can be toggled without losing the value',
      (tester) async {
    await showPage(tester, FakeAuthRepository());
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tapVisible(tester, find.byTooltip('Afficher le mot de passe'));
    final field =
        tester.widgetList<EditableText>(find.byType(EditableText)).last;
    expect(field.obscureText, isFalse);
    expect(field.controller.text, 'secret');
  });

  testWidgets('Login prevents duplicate requests and saves the session',
      (tester) async {
    final repository = FakeAuthRepository()
      ..pendingLogin = Completer<AuthSession>();
    await showPage(tester, repository);
    await tester.enterText(
        find.byType(TextFormField).at(0), 'alice@example.fr');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    expect(find.text('Connexion en cours…'), findsOneWidget);
    expect(repository.logins, 1);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    repository.pendingLogin!
        .complete(const AuthSession(token: 'token', user: user));
    await tester.pumpAndSettle();
    expect(find.text('Espace santé'), findsOneWidget);
  });

  testWidgets('Login errors remain visible and preserve the email',
      (tester) async {
    final repository = FakeAuthRepository()..loginError = requestError(401);
    await showPage(tester, repository);
    await tester.enterText(
        find.byType(TextFormField).at(0), 'alice@example.fr');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tapVisible(tester, find.text('Se connecter'));
    expect(
        find.text(
            'Adresse email, identifiant ou mot de passe incorrect, ou session expirée.'),
        findsOneWidget);
    expect(find.text('alice@example.fr'), findsOneWidget);
  });

  testWidgets('Registration rejects mismatched passwords', (tester) async {
    final repository = FakeAuthRepository();
    await showPage(tester, repository, page: const RegisterPage());
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Alice Martin');
    await tester.enterText(fields.at(1), 'alice@example.fr');
    await tester.enterText(fields.at(3), 'Password123!');
    await tester.enterText(fields.at(4), 'different');
    await tapVisible(tester, find.text('Créer mon compte'));
    expect(
        find.text('Les mots de passe ne correspondent pas.'), findsOneWidget);
    expect(repository.registrations, 0);
  });

  testWidgets('Recovery reuses the email and completes the code flow',
      (tester) async {
    final repository = FakeAuthRepository();
    await showPage(tester, repository);
    await tester.enterText(
        find.byType(TextFormField).first, 'alice@example.fr');
    await tapVisible(tester, find.text('Mot de passe oublié ?'));
    expect(find.text('alice@example.fr'), findsOneWidget);
    await tapVisible(tester, find.text('Recevoir un code'));
    expect(repository.recoveryEmail, 'alice@example.fr');
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), 'NewPassword123!');
    await tester.enterText(fields.at(2), 'NewPassword123!');
    await tapVisible(tester, find.text('Enregistrer le mot de passe'));
    expect(repository.resetCode, '123456');
    expect(repository.resetPasswordValue, 'NewPassword123!');
    expect(find.text('Un nouveau départ'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(320, 568), const Size(1280, 900)]) {
    testWidgets('Authentication pages fit viewport $size', (tester) async {
      for (final page in [
        const LoginPage(),
        const RegisterPage(),
        const ForgotPasswordPage()
      ]) {
        await showPage(tester, FakeAuthRepository(), page: page, size: size);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('Expired sessions clear the entire private navigation stack',
      (tester) async {
    final storage = MemoryTokenStorage()..token = 'saved-token';
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
      child: const MediCareApp(),
    ));
    await tester.pumpAndSettle();
    final home = tester.element(find.text('Bonjour Alice Martin'));
    final container = ProviderScope.containerOf(home);
    Navigator.of(home).push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Données privées')),
    ));
    await tester.pumpAndSettle();
    container.read(sessionExpirationProvider.notifier).state++;
    await tester.pumpAndSettle();
    expect(find.text('Données privées'), findsNothing);
    expect(find.text('Heureux de vous revoir'), findsOneWidget);
    expect(
        Navigator.of(tester.element(find.byType(LoginPage))).canPop(), isFalse);
  });

  testWidgets('MFA keeps the session pending until an email code is verified',
      (tester) async {
    final repository = FakeAuthRepository()..challengeLogin = true;
    await showPage(tester, repository);
    await tester.enterText(
        find.byType(TextFormField).at(0), 'alice@example.fr');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tapVisible(tester, find.text('Se connecter'));
    expect(find.byType(VerificationPage), findsOneWidget);
    expect(find.text('Espace santé'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, '123456');
    await tapVisible(tester, find.text('Vérifier et continuer'));
    expect(repository.verifications, 1);
    expect(find.text('Espace santé'), findsOneWidget);
  });

  testWidgets('Recovery codes can replace the email second factor',
      (tester) async {
    final repository = FakeAuthRepository();
    await showPage(tester, repository,
        page: const VerificationPage(
            challenge: AuthSession(
                token: '',
                user: null,
                challengeId: 'challenge',
                challengeType: 'MFA_LOGIN')));
    await tapVisible(tester, find.text('Utiliser un code de récupération'));
    await tester.enterText(find.byType(TextFormField).first,
        'AAAAAAAA-BBBBBBBB-CCCCCCCC-DDDDDDDD');
    await tapVisible(tester, find.text('Vérifier et continuer'));
    expect(repository.usedRecovery, isTrue);
    expect(find.text('Espace santé'), findsOneWidget);
  });

  testWidgets(
      'Passwordless requests an email without requiring the password field',
      (tester) async {
    final repository = FakeAuthRepository();
    await showPage(tester, repository);
    await tester.enterText(
        find.byType(TextFormField).first, 'alice@example.fr');
    await tapVisible(tester, find.text('Me connecter par code email'));
    expect(repository.logins, 0);
    await tester.enterText(find.byType(TextFormField).at(0), '123456');
    await tester.enterText(find.byType(TextFormField).at(1),
        'AAAAAAAA-BBBBBBBB-CCCCCCCC-DDDDDDDD');
    await tapVisible(tester, find.text('Vérifier et continuer'));
    expect(repository.verifiedRecovery, 'AAAAAAAA-BBBBBBBB-CCCCCCCC-DDDDDDDD');
    expect(find.text('Espace santé'), findsOneWidget);
  });

  testWidgets('Signup sends the selected role as a request', (tester) async {
    final repository = FakeAuthRepository();
    await showPage(tester, repository, page: const RegisterPage());
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Alice Martin');
    await tester.enterText(fields.at(1), 'alice@example.fr');
    await tester.enterText(fields.at(3), 'LongPassword123!');
    await tester.enterText(fields.at(4), 'LongPassword123!');
    await tapVisible(tester, find.text('Patient'));
    await tapVisible(tester, find.text('Médecin').last);
    await tapVisible(tester, find.text('Créer mon compte'));
    expect(repository.selectedRole, 'DOCTOR');
  });

  testWidgets(
      'Patients can submit role requests but cannot see the administration tab',
      (tester) async {
    final storage = MemoryTokenStorage()..token = 'saved-token';
    final repository = FakeAuthRepository();
    await tester.pumpWidget(ProviderScope(overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repository),
    ], child: const MediCareApp()));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Bonjour Alice Martin')))
        .pushNamed('/security');
    await tester.pumpAndSettle();
    expect(find.text('Administration'), findsNothing);
    await tapVisible(tester, find.text('Mes rôles'));
    await tapVisible(tester, find.text('Demander un rôle'));
    await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
    await tapVisible(tester, find.text('Médecin').last);
    await tester.enterText(
        find.byType(TextFormField).last, 'Je souhaite exercer comme médecin.');
    await tapVisible(tester, find.text('Continuer'));
    expect(repository.postedPath, '/security/role-requests');
    expect(repository.postedData?['requestedRole'], 'DOCTOR');
  });

  testWidgets(
      'Administrators must resolve merge conflicts before sending approval',
      (tester) async {
    final storage = MemoryTokenStorage()..token = 'admin-token';
    final repository = AdministratorRepository();
    await tester.pumpWidget(ProviderScope(overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repository),
    ], child: const MediCareApp()));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Bonjour Admin Example')))
        .pushNamed('/security');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Administration'));
    await tapVisible(tester, find.text('Fusions'));
    await tapVisible(tester, find.text('Examiner et approuver'));
    await tester.enterText(find.byType(TextFormField).last,
        'Les identités et conflits sont vérifiés.');
    await tapVisible(tester, find.text('Approuver'));
    expect(find.text('Choisissez une valeur.'), findsOneWidget);
    expect(repository.postedPath, isNull);
    await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
    await tapVisible(tester, find.text('Compte conservé : Alice Martin').last);
    await tapVisible(tester, find.text('Approuver'));
    expect(repository.postedPath, '/security/admin/merges/merge-1/decision');
    expect(
        (repository.postedData?['fieldSources'] as Map)['fullName'], 'PRIMARY');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Backup login can start without requesting an email',
      (tester) async {
    final repository = FakeAuthRepository();
    await showPage(tester, repository);
    await tester.enterText(
        find.byType(TextFormField).at(0), 'alice@example.fr');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tapVisible(
        tester, find.text('Connexion avec un code de récupération'));
    await tester.enterText(find.byType(TextFormField).first,
        'AAAAAAAA-BBBBBBBB-CCCCCCCC-DDDDDDDD');
    await tapVisible(tester, find.text('Vérifier et continuer'));
    expect(repository.logins, 0);
    expect(repository.backupLogins, 1);
    expect(find.text('Espace santé'), findsOneWidget);
  });

  test('A network failure retains the saved session and supports retry',
      () async {
    final storage = MemoryTokenStorage()..token = 'saved-token';
    final repository = FakeAuthRepository()..sessionError = requestError(null);
    final container = ProviderContainer(overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final controller = container.read(authenticationStateProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authenticationStateProvider).hasError, isTrue);
    expect(storage.token, 'saved-token');
    expect(storage.clears, 0);
    repository.sessionError = null;
    await controller.restoreSession();
    expect(container.read(authenticationStateProvider).valueOrNull, user);
  });

  test('An API session expiration event clears an active session', () async {
    final storage = MemoryTokenStorage()..token = 'saved-token';
    final container = ProviderContainer(overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
    ]);
    addTearDown(container.dispose);
    container.read(authenticationStateProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authenticationStateProvider).valueOrNull, user);
    container.read(sessionExpirationProvider.notifier).state++;
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authenticationStateProvider).valueOrNull, isNull);
    expect(storage.token, isNull);
  });

  test('An expired session clears the saved token', () async {
    final storage = MemoryTokenStorage()..token = 'expired-token';
    final repository = FakeAuthRepository()..sessionError = requestError(401);
    final container = ProviderContainer(overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    container.read(authenticationStateProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authenticationStateProvider).valueOrNull, isNull);
    expect(container.read(authenticationStateProvider).hasError, isFalse);
    expect(storage.token, isNull);
  });
}
