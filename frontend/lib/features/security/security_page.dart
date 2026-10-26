import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/auth_error.dart';
import '../auth/auth_validation.dart';
import '../auth/authentication_state.dart';
import '../auth/verification_page.dart';

final securityOverviewProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  ref.watch(authenticationStateProvider);
  return ref.read(authRepositoryProvider).securityOverview();
});
final securityListProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, path) {
  ref.watch(authenticationStateProvider);
  return ref.read(authRepositoryProvider).securityList(path);
});

const roleNames = {
  'USER': 'Patient',
  'DOCTOR': 'Médecin',
  'ADMIN': 'Administrateur'
};
const statusNames = {
  'PENDING': 'En attente',
  'APPROVED': 'Approuvée',
  'REJECTED': 'Refusée',
  'PENDING_VERIFICATION': 'Vérification des deux emails attendue',
  'AWAITING_REVIEW': 'Validation administrateur attendue',
  'COMPLETED': 'Fusion terminée',
  'CANCELLED': 'Annulée',
};
const profileLabels = {
  'fullName': 'Nom complet',
  'phoneNumber': 'Téléphone',
  'birthDate': 'Date de naissance',
  'bio': 'Présentation',
  'profilePhotoUrl': 'Photo de profil'
};

class SecurityPage extends ConsumerWidget {
  const SecurityPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin =
        ref.watch(authenticationStateProvider).valueOrNull?.role == 'ADMIN';
    return DefaultTabController(
      length: admin ? 4 : 3,
      child: Scaffold(
        appBar: AppBar(
            title: const Text('Sécurité et accès'),
            bottom: TabBar(isScrollable: true, tabs: [
              const Tab(text: 'Protection'),
              const Tab(text: 'Mes rôles'),
              const Tab(text: 'Mes comptes'),
              if (admin) const Tab(text: 'Administration'),
            ])),
        body: TabBarView(children: [
          const _ProtectionTab(),
          const _RoleTab(),
          const _MergeTab(),
          if (admin) const _AdministrationTab()
        ]),
      ),
    );
  }
}

void _message(BuildContext context, String message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

String _date(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null
      ? ''
      : DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
}

class _ProtectionTab extends ConsumerStatefulWidget {
  const _ProtectionTab();
  @override
  ConsumerState<_ProtectionTab> createState() => _ProtectionTabState();
}

class _ProtectionTabState extends ConsumerState<_ProtectionTab> {
  bool _busy = false;
  Future<void> _action(String action) async {
    String password = '';
    if (action != 'VERIFY_EMAIL') {
      final values = await _formDialog(
        context,
        title: action == 'MFA_DISABLE'
            ? 'Désactiver la double vérification'
            : action == 'RECOVERY_ROTATE'
                ? 'Renouveler les codes'
                : 'Activer la double vérification',
        message: action == 'RECOVERY_ROTATE'
            ? 'Après validation, les anciens codes deviendront inutilisables. Votre mot de passe et un code email sont nécessaires.'
            : action == 'MFA_DISABLE'
                ? 'Les prochaines connexions par mot de passe ne demanderont plus de code email. Confirmez votre mot de passe ; un code email vous sera ensuite demandé.'
                : 'Confirmez votre mot de passe. Un code email vous sera ensuite envoyé.',
        fields: const [
          _Input('password', 'Mot de passe actuel', password: true)
        ],
      );
      if (values == null || !mounted) return;
      password = values['password']!;
    }
    setState(() => _busy = true);
    try {
      final challenge = await ref
          .read(authRepositoryProvider)
          .securityChallenge(action, password);
      if (!mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => VerificationPage(
                  challenge: challenge, securityAction: true)));
      ref.invalidate(securityOverviewProvider);
    } catch (e) {
      if (mounted) _message(context, authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(securityOverviewProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Retry(
              message: authErrorMessage(e),
              retry: () => ref.invalidate(securityOverviewProvider)),
          data: (data) {
            final user = Map<String, dynamic>.from(data['user'] as Map);
            final mfa = user['mfaEnabled'] == true;
            final verified = user['emailVerified'] == true;
            return ListView(padding: const EdgeInsets.all(20), children: [
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Adresse email',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Text(user['email'].toString()),
                            const SizedBox(height: 8),
                            _Status(
                                label: verified
                                    ? 'Email vérifié'
                                    : 'Email à vérifier',
                                positive: verified),
                            if (!verified)
                              TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _action('VERIFY_EMAIL'),
                                  icon: const Icon(
                                      Icons.mark_email_read_outlined),
                                  label: const Text('Vérifier mon email')),
                            if (user['username'] != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                      'Identifiant : ${user['username']}')),
                          ]))),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Double vérification',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Text(mfa
                                ? 'Après votre mot de passe, un code envoyé par email ou un code de récupération est nécessaire.'
                                : 'Ajoutez une preuve d’identité après votre mot de passe.'),
                            const SizedBox(height: 12),
                            _Status(
                                label: mfa ? 'Activée' : 'Désactivée',
                                positive: mfa),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _action(
                                        mfa ? 'MFA_DISABLE' : 'MFA_ENABLE'),
                                icon: Icon(mfa
                                    ? Icons.lock_open_outlined
                                    : Icons.shield_outlined),
                                label: Text(mfa
                                    ? 'Désactiver après vérification'
                                    : 'Activer la double vérification')),
                          ]))),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Codes de récupération',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Text(
                                '${data['recoveryCodesRemaining']} code(s) encore disponible(s). Chaque code fonctionne une seule fois.'),
                            const SizedBox(height: 10),
                            const Text(
                                'Pour une connexion sans mot de passe lorsque la double vérification est active, utilisez le code email et un code de récupération.'),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                                onPressed: _busy || !mfa
                                    ? null
                                    : () => _action('RECOVERY_ROTATE'),
                                icon: const Icon(Icons.key_outlined),
                                label: const Text('Renouveler mes codes')),
                          ]))),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Vos mots de passe',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Text(data['compromisedPasswordCheck'] == true
                                ? 'Les nouveaux mots de passe sont comparés à des fuites connues sans transmettre votre mot de passe au service externe.'
                                : 'La recherche de mots de passe compromis a été désactivée dans la configuration du serveur.'),
                            const SizedBox(height: 10),
                            const Text(
                                'Utilisez une phrase d’au moins 12 caractères. Les derniers mots de passe ne peuvent pas être réutilisés. Un incident confirmé entraîne une réinitialisation obligatoire.'),
                            TextButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/settings'),
                                child: const Text('Changer mon mot de passe')),
                          ]))),
            ]);
          },
        );
  }
}

class _RoleTab extends ConsumerStatefulWidget {
  const _RoleTab();
  @override
  ConsumerState<_RoleTab> createState() => _RoleTabState();
}

class _RoleTabState extends ConsumerState<_RoleTab> {
  bool _busy = false;
  Future<void> _request() async {
    final current = ref.read(authenticationStateProvider).valueOrNull?.role;
    final result = await _formDialog(context,
        title: 'Demander un changement de rôle',
        message:
            'Expliquez votre besoin. Un administrateur vérifiera les justificatifs nécessaires avant de décider.',
        fields: [
          _Input('role', 'Rôle souhaité',
              choices: Map.fromEntries(
                  roleNames.entries.where((e) => e.key != current))),
          const _Input('reason', 'Motif de la demande',
              minLength: 10, multiline: true)
        ]);
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).securityPost(
          '/security/role-requests',
          {'requestedRole': result['role'], 'reason': result['reason']});
      ref.invalidate(securityListProvider('/security/role-requests'));
      if (mounted) _message(context, 'Votre demande a été transmise.');
    } catch (e) {
      if (mounted) _message(context, authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authenticationStateProvider).valueOrNull?.role;
    return _AsyncList(
      path: '/security/role-requests',
      empty: 'Vous n’avez pas encore de demande de rôle.',
      header: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Rôle actuel : ${roleNames[role] ?? role}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: _busy ? null : _request,
            icon: const Icon(Icons.add_task),
            label: const Text('Demander un rôle')),
        const SizedBox(height: 16),
      ]),
      itemBuilder: (r) => _RequestCard(
          title: roleNames[r['requestedRole']] ?? r['requestedRole'].toString(),
          status: r['status'].toString(),
          lines: [
            r['reason'].toString(),
            _date(r['requestedAt']),
            if (r['decisionNote'] != null) 'Décision : ${r['decisionNote']}'
          ]),
    );
  }
}

class _MergeTab extends ConsumerStatefulWidget {
  const _MergeTab();
  @override
  ConsumerState<_MergeTab> createState() => _MergeTabState();
}

class _MergeTabState extends ConsumerState<_MergeTab> {
  bool _busy = false;
  Future<void> _request() async {
    final values = await _formDialog(context,
        title: 'Rapprocher deux comptes',
        message:
            'Le compte actuel sera conservé. Vous devrez fournir un code envoyé à chacun des deux emails, puis attendre la validation d’un administrateur.',
        fields: const [
          _Input('email', 'Email de l’autre compte', email: true),
          _Input('reason', 'Motif du rapprochement',
              minLength: 10, multiline: true)
        ]);
    if (values == null || !mounted) return;
    await _post(
        '/security/merges',
        {'targetEmail': values['email'], 'reason': values['reason']},
        'Si l’autre compte existe, un code a été envoyé à chacun des deux emails.');
  }

  Future<void> _verify(Map<String, dynamic> item) async {
    final values = await _formDialog(context,
        title: 'Prouver la propriété des deux comptes',
        message:
            'Renseignez les deux codes reçus. Cette étape prépare la demande ; elle ne déclenche aucune fusion automatique.',
        fields: const [
          _Input('primary', 'Code de votre email actuel', digits: true),
          _Input('secondary', 'Code de l’autre email', digits: true)
        ]);
    if (values == null || !mounted) return;
    await _post(
        '/security/merges/${item['id']}/verify',
        {
          'primaryCode': values['primary'],
          'secondaryCode': values['secondary']
        },
        'Les deux comptes sont vérifiés. La demande attend maintenant une décision administrateur.');
  }

  Future<void> _post(
      String path, Map<String, dynamic> data, String message) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).securityPost(path, data);
      ref.invalidate(securityListProvider('/security/merges'));
      if (mounted) _message(context, message);
    } catch (e) {
      if (mounted) _message(context, authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AsyncList(
      path: '/security/merges',
      empty: 'Aucun rapprochement en cours.',
      header: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Un compte, toutes vos données',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text(
            'La fusion conserve vos rendez-vous, médicaments et mesures. L’email et le mot de passe du compte principal sont conservés. Les comptes Médecin et Administrateur ne sont pas fusionnés.'),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: _busy ? null : _request,
            icon: const Icon(Icons.merge_type_rounded),
            label: const Text('Demander un rapprochement')),
        const SizedBox(height: 16),
      ]),
      itemBuilder: (r) => _RequestCard(
        title: r['targetEmail'].toString(),
        status: r['status'].toString(),
        lines: [
          r['reason'].toString(),
          _date(r['requestedAt']),
          if (r['decisionNote'] != null) 'Décision : ${r['decisionNote']}'
        ],
        actions: [
          if (r['status'] == 'PENDING_VERIFICATION')
            TextButton(
                onPressed: _busy ? null : () => _verify(r),
                child: const Text('Saisir les deux codes')),
          if (r['status'] == 'PENDING_VERIFICATION' ||
              r['status'] == 'AWAITING_REVIEW')
            TextButton(
                onPressed: _busy
                    ? null
                    : () => _post('/security/merges/${r['id']}/cancel', {},
                        'Demande annulée.'),
                child: const Text('Annuler la demande')),
        ],
      ),
    );
  }
}

class _AdministrationTab extends ConsumerStatefulWidget {
  const _AdministrationTab();
  @override
  ConsumerState<_AdministrationTab> createState() => _AdministrationTabState();
}

class _AdministrationTabState extends ConsumerState<_AdministrationTab> {
  bool _busy = false;
  Future<void> _decision(Map<String, dynamic> item, bool approve,
      {bool merge = false}) async {
    final conflictMap =
        Map<String, dynamic>.from(item['conflicts'] as Map? ?? {});
    final fields = <_Input>[
      if (merge && approve)
        ...conflictMap.entries.map((entry) {
          final values = entry.value as List;
          return _Input(entry.key, profileLabels[entry.key] ?? entry.key,
              choices: {
                'PRIMARY': 'Compte conservé : ${values[0]}',
                'SECONDARY': 'Autre compte : ${values[1]}'
              });
        }),
      const _Input('note', 'Motif de la décision',
          minLength: 10, multiline: true),
    ];
    final result = await _formDialog(context,
        title:
            '${approve ? 'Approuver' : 'Refuser'} ${merge ? 'la fusion' : 'le rôle'}',
        message: merge
            ? 'Les deux propriétaires ont fourni leurs codes. Choisissez les valeurs à conserver pour chaque conflit. Les droits ne seront jamais combinés.'
            : 'Vérifiez l’identité et les qualifications nécessaires avant toute attribution de rôle. Votre décision sera enregistrée.',
        fields: fields,
        confirmLabel: approve ? 'Approuver' : 'Refuser');
    if (result == null || !mounted) return;
    final path = merge
        ? '/security/admin/merges/${item['id']}/decision'
        : '/security/admin/role-requests/${item['id']}/decision';
    await _post(path, {
      'approve': approve,
      'note': result['note'],
      if (merge)
        'fieldSources':
            Map.fromEntries(result.entries.where((e) => e.key != 'note'))
    });
  }

  Future<void> _incident(Map<String, dynamic> user) async {
    final result = await _formDialog(context,
        title: 'Confirmer un incident',
        message:
            'Compte : ${user['email']}. Cette action révoquera ses sessions et imposera une réinitialisation du mot de passe. Utilisez-la uniquement pour un incident confirmé.',
        fields: const [
          _Input('reason', 'Incident confirmé et justification',
              minLength: 10, multiline: true)
        ],
        confirmLabel: 'Imposer la réinitialisation');
    if (result == null || !mounted) return;
    await _post('/security/admin/users/${user['id']}/incident',
        {'reason': result['reason']});
  }

  Future<void> _post(String path, Map<String, dynamic> data) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).securityPost(path, data);
      for (final path in [
        '/security/admin/role-requests',
        '/security/admin/merges',
        '/security/admin/duplicates',
        '/security/admin/audit',
        '/users'
      ]) {
        ref.invalidate(securityListProvider(path));
      }
      if (mounted) _message(context, 'La décision a été enregistrée.');
    } catch (e) {
      if (mounted) _message(context, authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 5,
        child: Column(children: [
          const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Rôles'),
            Tab(text: 'Fusions'),
            Tab(text: 'Doublons'),
            Tab(text: 'Incidents'),
            Tab(text: 'Journal')
          ]),
          Expanded(
              child: TabBarView(children: [
            _AsyncList(
                path: '/security/admin/role-requests',
                empty: 'Aucune demande de rôle en attente.',
                itemBuilder: (r) => _RequestCard(
                        title:
                            '${r['fullName']} · ${roleNames[r['requestedRole']]}',
                        status: r['status'].toString(),
                        lines: [
                          r['email'].toString(),
                          r['reason'].toString(),
                          _date(r['requestedAt'])
                        ],
                        actions: [
                          TextButton(
                              onPressed:
                                  _busy ? null : () => _decision(r, true),
                              child: const Text('Approuver')),
                          TextButton(
                              onPressed:
                                  _busy ? null : () => _decision(r, false),
                              child: const Text('Refuser')),
                        ])),
            _AsyncList(
                path: '/security/admin/merges',
                empty: 'Aucune fusion vérifiée en attente.',
                itemBuilder: (r) => _RequestCard(
                        title:
                            'Compte #${r['secondaryUserId']} vers #${r['primaryUserId']}',
                        status: r['status'].toString(),
                        lines: [
                          r['targetEmail'].toString(),
                          r['reason'].toString(),
                          '${(r['conflicts'] as Map).length} conflit(s) à examiner'
                        ],
                        actions: [
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _decision(r, true, merge: true),
                              child: const Text('Examiner et approuver')),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _decision(r, false, merge: true),
                              child: const Text('Refuser')),
                        ])),
            _AsyncList(
                path: '/security/admin/duplicates',
                empty: 'Aucune correspondance vérifiée détectée.',
                header: const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                        'Seuls les identifiants de comptes vérifiés et les demandes avec deux preuves sont rapprochés. Un nom ressemblant ne suffit pas à identifier une personne. Aucune fusion automatique.')),
                itemBuilder: (r) => Card(
                    child: ListTile(
                        leading: const Icon(Icons.person_search_outlined),
                        title: Text(
                            'Comptes #${r['primaryUserId']} et #${r['secondaryUserId']}'),
                        subtitle: Text(r['reason'].toString())))),
            _AsyncList(
                path: '/users',
                empty: 'Aucun compte.',
                itemBuilder: (u) => Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u['fullName'].toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(u['email'].toString()),
                              if (u['passwordResetRequired'] == true)
                                const Text('Réinitialisation déjà obligatoire'),
                              TextButton.icon(
                                  onPressed: _busy ||
                                          u['passwordResetRequired'] == true
                                      ? null
                                      : () => _incident(u),
                                  icon: const Icon(Icons.report_outlined),
                                  label: const Text(
                                      'Signaler un incident confirmé')),
                            ])))),
            _AsyncList(
                path: '/security/admin/audit',
                empty: 'Aucune décision enregistrée.',
                itemBuilder: (e) => Card(
                    child: ListTile(
                        title: Text(_auditLabel(e['action'].toString())),
                        subtitle: Text(
                            '${_date(e['occurredAt'])}\nAuteur : ${e['actorId'] ?? 'Système'} · Compte : ${e['subjectId']}\n${e['detail'] ?? ''}'),
                        isThreeLine: true))),
          ])),
        ]));
  }
}

String _auditLabel(String action) =>
    const {
      'ROLE_REQUESTED': 'Demande de rôle',
      'ROLE_APPROVED': 'Rôle approuvé',
      'ROLE_REJECTED': 'Rôle refusé',
      'MERGE_REQUESTED': 'Demande de rapprochement',
      'MERGE_OWNERSHIP_VERIFIED': 'Propriété des deux comptes vérifiée',
      'MERGE_APPROVED': 'Fusion approuvée',
      'MERGE_REJECTED': 'Fusion refusée',
      'MERGE_CANCELLED': 'Demande annulée',
      'ACCOUNTS_MERGED': 'Comptes fusionnés',
      'PASSWORD_RESET_REQUIRED': 'Réinitialisation imposée après incident',
      'PASSWORD_CHANGED': 'Mot de passe modifié',
      'MFA_ENABLE': 'Double vérification activée',
      'MFA_DISABLE': 'Double vérification désactivée',
      'RECOVERY_ROTATE': 'Codes de récupération renouvelés',
      'VERIFY_EMAIL': 'Email vérifié',
      'ACCOUNT_REGISTERED': 'Compte créé',
      'ADMIN_BOOTSTRAPPED': 'Administrateur initial configuré',
      'LOGIN_MFA_LOGIN': 'Connexion avec double vérification',
      'LOGIN_SIGNUP': 'Inscription vérifiée',
      'LOGIN_PASSWORDLESS': 'Connexion sans mot de passe',
      'LOGIN_RECOVERY_CODE': 'Connexion avec code de récupération',
      'LOGIN_PASSWORD': 'Connexion par mot de passe',
    }[action] ??
    'Événement de sécurité';

class _Status extends StatelessWidget {
  const _Status({required this.label, this.positive = false});
  final String label;
  final bool positive;
  @override
  Widget build(BuildContext context) => Chip(
      avatar: Icon(
          positive ? Icons.check_circle_outline : Icons.pending_outlined,
          size: 18),
      label: Text(label));
}

class _RequestCard extends StatelessWidget {
  const _RequestCard(
      {required this.title,
      required this.status,
      required this.lines,
      this.actions = const []});
  final String title, status;
  final List<String> lines;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            _Status(
                label: statusNames[status] ?? status,
                positive: status == 'APPROVED' || status == 'COMPLETED'),
            ...lines.where((line) => line.isNotEmpty).map((line) => Padding(
                padding: const EdgeInsets.only(top: 6), child: Text(line))),
            if (actions.isNotEmpty) Wrap(spacing: 8, children: actions),
          ])));
}

class _AsyncList extends ConsumerWidget {
  const _AsyncList(
      {required this.path,
      required this.empty,
      required this.itemBuilder,
      this.header});
  final String path, empty;
  final Widget Function(Map<String, dynamic>) itemBuilder;
  final Widget? header;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(securityListProvider(path)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Retry(
                message: authErrorMessage(e),
                retry: () => ref.invalidate(securityListProvider(path))),
            data: (items) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(securityListProvider(path));
                  await ref.read(securityListProvider(path).future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (header != null) header!,
                    if (items.isEmpty)
                      Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(empty)),
                    ...items.map(itemBuilder)
                  ],
                )),
          );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: retry, child: const Text('Réessayer'))
          ])));
}

class _Input {
  const _Input(this.name, this.label,
      {this.password = false,
      this.email = false,
      this.digits = false,
      this.multiline = false,
      this.minLength = 1,
      this.choices});
  final String name, label;
  final bool password, email, digits, multiline;
  final int minLength;
  final Map<String, String>? choices;
}

Future<Map<String, String>?> _formDialog(BuildContext context,
    {required String title,
    required String message,
    required List<_Input> fields,
    String confirmLabel = 'Continuer'}) {
  return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _ActionFormDialog(
          title: title,
          message: message,
          fields: fields,
          confirmLabel: confirmLabel));
}

class _ActionFormDialog extends StatefulWidget {
  const _ActionFormDialog(
      {required this.title,
      required this.message,
      required this.fields,
      required this.confirmLabel});
  final String title, message, confirmLabel;
  final List<_Input> fields;
  @override
  State<_ActionFormDialog> createState() => _ActionFormDialogState();
}

class _ActionFormDialogState extends State<_ActionFormDialog> {
  final _form = GlobalKey<FormState>();
  late final _controllers = {
    for (final field in widget.fields.where((f) => f.choices == null))
      field.name: TextEditingController()
  };
  final Map<String, String> _selected = {};
  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(widget.message),
                          const SizedBox(height: 20),
                          ...widget.fields.map((field) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: field.choices != null
                                  ? DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                          labelText: field.label,
                                          border: const OutlineInputBorder()),
                                      items: field.choices!.entries
                                          .map((e) => DropdownMenuItem(
                                              value: e.key,
                                              child: Text(e.value,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis)))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          _selected[field.name] = value;
                                        }
                                      },
                                      validator: (value) => value == null
                                          ? 'Choisissez une valeur.'
                                          : null)
                                  : TextFormField(
                                      controller: _controllers[field.name],
                                      obscureText: field.password,
                                      autocorrect: !field.password,
                                      keyboardType: field.email
                                          ? TextInputType.emailAddress
                                          : field.digits
                                              ? TextInputType.number
                                              : TextInputType.text,
                                      maxLines: field.multiline ? 3 : 1,
                                      decoration: InputDecoration(
                                          labelText: field.label,
                                          border: const OutlineInputBorder()),
                                      validator: (value) {
                                        if (field.email) {
                                          return AuthValidation.email(value);
                                        }
                                        if (field.digits) {
                                          return RegExp(r'^\d{6}$')
                                                  .hasMatch(value ?? '')
                                              ? null
                                              : 'Saisissez 6 chiffres.';
                                        }
                                        if ((value?.trim().length ?? 0) <
                                            field.minLength) {
                                          return 'Au moins ${field.minLength} caractère(s).';
                                        }
                                        if ((value?.length ?? 0) >
                                            (field.password ? 100 : 500)) {
                                          return 'Texte trop long.';
                                        }
                                        return null;
                                      },
                                    ))),
                        ])))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, {
                    for (final entry in _controllers.entries)
                      entry.key: widget.fields
                              .firstWhere((field) => field.name == entry.key)
                              .password
                          ? entry.value.text
                          : entry.value.text.trim(),
                    ..._selected
                  });
                }
              },
              child: Text(widget.confirmLabel))
        ],
      );
}
