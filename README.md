# MediCare Full-Stack

Application mobile de suivi médical :
- Frontend : Flutter
- Backend : Spring Boot 3.5.x / Java 21
- Database : PostgreSQL
- Authentication : JWT
- API : REST

## Fonctionnalités incluses

- Inscription / connexion avec JWT
- Profil utilisateur
- CRUD rendez-vous
- CRUD médicaments
- CRUD mesures de santé
- Dashboard Flutter
- Communication Flutter -> Spring Boot via Dio
- Stockage sécurisé du JWT avec flutter_secure_storage
- PostgreSQL via Spring Data JPA
- Validation DTO
- Gestion globale des erreurs

## 1. PostgreSQL

Créer la base :

```sql
CREATE DATABASE medicare;
```

Puis définir les variables :

```text
DB_USERNAME=postgres
DB_PASSWORD=postgres
JWT_SECRET=change-this-secret-key-with-at-least-32-characters
```

## 2. Backend

```bash
cd backend
mvn spring-boot:run
```

ou :

```bash
mvn spring-boot:run
```

API : http://localhost:8080

Pour Android Emulator, le frontend utilise `10.0.2.2` pour atteindre le localhost de la machine.

## 3. Frontend

Le dossier Flutter contient le code applicatif. Générer les fichiers plateformes :

```bash
cd frontend
flutter pub get
flutter run
```

Pour un téléphone physique, préciser l'adresse IP locale de la machine :

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080/api
```

Remplacer `192.168.1.10` par l'adresse du PC qui exécute le backend.

Si le port `8080` est déjà utilisé, démarrer le backend sur un autre port :

```bash
cd backend
java -jar target/medicare-backend-1.0.0.jar --spring.profiles.active=dev --server.port=8081
```

Puis lancer Flutter dans un second terminal depuis le dossier `frontend` :

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8081/api
```

L'adresse doit inclure `/api`. Pour l'émulateur Android, utiliser
`http://10.0.2.2:8081/api`. Après un changement de `--dart-define`, arrêter
l'application Flutter et la relancer avec la nouvelle commande.

## Comptes

Inscription via l'écran Register. Le mot de passe est hashé avec BCrypt.
Le token JWT est retourné après login et envoyé ensuite dans :

```text
Authorization: Bearer <token>
```

## Architecture

Flutter
   |
   | HTTP/JSON + JWT
   v
Spring Boot REST API
   |
   | JPA/Hibernate
   v
PostgreSQL

## Authentification et récupération du compte

Les écrans de connexion, d'inscription et de récupération s'adaptent au mobile
et au bureau. Ils proposent le remplissage automatique, l'affichage des mots de
passe, une validation immédiate et des messages d'erreur en français. L'indicateur
de robustesse est un conseil ; les nouveaux mots de passe acceptent au minimum
12 caractères et au maximum 72 octets UTF-8 (limite de BCrypt).

Pour activer la récupération par email, configurer le serveur SMTP du backend :

```text
MAIL_HOST=smtp.example.com
MAIL_PORT=587
MAIL_USERNAME=compte-smtp
MAIL_PASSWORD=mot-de-passe-smtp
MAIL_FROM=MediCare <noreply@example.com>
MAIL_SMTP_AUTH=true
MAIL_STARTTLS=true
```

Sans configuration SMTP, l'API renvoie `503` et l'interface signale que l'envoi
est indisponible. Aucun email n'est simulé. Pour un serveur SMTP local sans
authentification, définir `MAIL_SMTP_AUTH=false` et `MAIL_STARTTLS=false`.

### Lancement Windows avec Gmail

Arrêter le backend en cours avec `Ctrl+C`, puis lancer depuis la racine du projet :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\backend\start-dev-email.ps1
```

Le script cherche Java dans le PATH, `JAVA_HOME` ou les JDK du dossier utilisateur,
et Maven dans le PATH ou l'installation IntelliJ IDEA. Il reconstruit le JAR,
demande l'adresse du **compte Google qui a créé le mot de passe d'application**,
puis le code Google de 16 caractères en saisie masquée. Les espaces du code sont
retirés. Il transmet la configuration au processus Java et lance le profil `dev`
sur le port `8081`. Aucun identifiant n'est écrit dans un fichier ou le registre.
Le profil `dev` utilise une base H2 en mémoire, vidée à l'arrêt du backend.

Le contrôle SMTP au démarrage établit la connexion et vérifie l'authentification,
sans envoyer d'email. En cas de refus, le backend s'arrête avec la cause dans
le terminal. Une `AuthenticationFailedException` indique un problème de compte
ou de mot de passe d'application ; un délai réseau indique un problème d'accès
SMTP. Pour un autre port, ajouter `-Port 8082` à la commande du script.

Dans un second terminal, lancer l'interface sur le même port API :

```powershell
cd frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8081/api
```

Les mots de passe d'application exigent la validation Google en deux étapes.
Le mot de passe d'application est distinct du mot de passe de connexion Gmail.
[Création du code Google](https://support.google.com/accounts/answer/185833?hl=fr).

### Diagnostic des erreurs email

Le backend renvoie toujours `503` en cas d'indisponibilité email, avec un code
stable traduit dans l'interface. Les journaux indiquent la catégorie et les
réglages à vérifier, sans contenu d'email, OTP, identifiant SMTP ou mot de passe.

| Code | Vérification |
| --- | --- |
| `MAIL_NOT_CONFIGURED` | Variables `MAIL_HOST`, `MAIL_FROM`, et identifiants si l'authentification SMTP est activée ; redémarrer le backend dans le terminal configuré. |
| `MAIL_AUTHENTICATION_FAILED` | Même compte Google pour `MAIL_USERNAME` et le code dans `MAIL_PASSWORD` ; utiliser le mot de passe d'application. |
| `MAIL_CONNECTION_FAILED` | Accès réseau au serveur SMTP et port configuré ; `Test-NetConnection smtp.gmail.com -Port 587` sous Windows. |
| `MAIL_TLS_FAILED` | Réglages STARTTLS, horloge et certificats Java ; conserver la validation des certificats. |
| `MAIL_SEND_FAILED` | Adresse d'expédition, permissions et limites du fournisseur email. |

Les variables définies dans un terminal ne sont pas transmises à un backend déjà
lancé depuis IntelliJ ou un autre terminal. Il faut redémarrer ce backend avec
les nouveaux paramètres. Une erreur de connexion Flutter au serveur MediCare est
distincte : vérifier `http://localhost:8081/api/health` et `API_BASE_URL`.

Le parcours utilise deux routes publiques :

- `POST /api/auth/forgot-password` avec `email` : envoie un code à 6 chiffres si
  le compte existe. La réponse est identique pour une adresse inconnue. Un seul
  envoi par compte est autorisé par minute.
- `POST /api/auth/reset-password` avec `email`, `code` et `newPassword` : vérifie
  le code et change le mot de passe. Le code expire après 10 minutes, accepte
  au maximum 5 essais et devient inutilisable après validation. Il est stocké
  sous forme de hash BCrypt. Les JWT antérieurs sont invalidés et l'utilisateur
  doit se reconnecter.

Une panne réseau pendant la restauration de session conserve le jeton et permet
de réessayer. Une réponse `401` supprime la session locale et protège les écrans
privés.

Vérifications :

```bash
cd backend
mvn test
```

```bash
cd frontend
flutter analyze
flutter test
```

Les tests backend utilisent H2 et un service d'email simulé ; ils ne nécessitent
ni PostgreSQL ni identifiants SMTP et n'envoient aucun email réel.


## Authentification avancée

Après mise à jour, recompiler le backend (`mvn clean package`) et redémarrer
le JAR, puis relancer Flutter. Le nouveau frontend utilise de nouvelles routes.

### Vérification de l’identité

- Une inscription crée un compte **Patient**, vérifie l’email par OTP et active
  la double vérification. Aucun JWT n’est délivré avant le code email.
- À la connexion, les comptes avec double vérification reçoivent un OTP après
  validation du mot de passe. Un code de récupération peut remplacer cet OTP.
- Le bouton « Connexion avec un code de récupération » vérifie le mot de passe
  et un code de secours, sans dépendre de l’envoi SMTP. Il permet de se connecter
  même lorsque la messagerie est indisponible.
- Les anciens comptes peuvent vérifier leur email et activer la double
  vérification depuis **Profil → Sécurité et accès → Protection**.
- Les OTP expirent après 10 minutes, sont limités à 5 essais et sont liés à
  un compte, une action, un email et une version de sécurité. Un renvoi attend
  au moins 60 secondes et invalide le code précédent.
- Dix codes de récupération de 128 bits sont affichés une seule fois. Chaque
  code est utilisable une fois et seul son hash est conservé. Leur renouvellement
  exige le mot de passe et une nouvelle preuve email ; les anciens codes et
  sessions sont alors invalidés.
- **Connexion sans mot de passe** : cliquer sur « Me connecter par code email ».
  Si la double vérification est active, un code de récupération est également
  exigé. Le parcours sans mot de passe ne contourne donc pas cette protection.
- Les demandes sans mot de passe emploient une réponse générique, sans renvoyer
  de profil ni de jeton avant validation. Les OTP de connexion ne peuvent pas servir à une fusion ou à une
  modification de sécurité.

L’envoi SMTP doit être configuré pour ces parcours. Aucun code n’est affiché
par le backend, écrit dans les journaux ou envoyé fictivement en développement.
Les codes sont transmis au service email configuré lors des actions de l’utilisateur.

### Identifiants et rapprochement de comptes

L’email et l’identifiant facultatif sont normalisés et contrôlés sans distinction
majuscules/minuscules. Les contraintes uniques de base de données protègent
également les inscriptions concurrentes. Un identifiant ambigu est refusé.

**Mes comptes** permet de demander un rapprochement en fournissant l’email du
second compte et un motif. Il faut ensuite saisir les codes envoyés aux deux
adresses. La propriété des deux comptes doit être prouvée avant qu’un
administrateur puisse examiner la fusion.

Règles de fusion :

- Aucune fusion automatique. Les correspondances proposées utilisent les
  identifiants de comptes vérifiés ou une demande avec deux preuves. Les variantes
  publiques `@gmail.com` avec points ou suffixes `+` constituent aussi un signal
  de boîte commune, uniquement lorsque les deux emails sont vérifiés. Cette règle
  ne s’applique pas aux domaines d’organisation et ne prouve pas à elle seule
  que deux profils désignent la même personne. Voir la [documentation Gmail](https://support.google.com/mail/answer/7436150)
  et les [variantes avec suffixe](https://gmail.googleblog.com/2008/03/2-hidden-ways-to-get-more-from-your.html).
  Un nom,
  un téléphone déclaré ou une date de naissance ne constitue pas une preuve.
- Un administrateur distinct des comptes concernés doit confirmer la décision
  et son motif. Il vérifie que les comptes appartiennent bien à la même personne.
- La fusion est limitée à deux comptes Patient actifs. Les droits Médecin et
  Administrateur ne sont jamais combinés ni hérités.
- Chaque valeur de profil en conflit doit être choisie explicitement. Les champs
  vides du compte conservé peuvent être complétés avec ceux du second compte.
- L’email principal, le mot de passe et les codes de récupération du compte
  conservé restent les références. Tous les rendez-vous, médicaments et mesures
  sont transférés, sans déduplication destructive des dossiers médicaux.
- Le second compte devient une identité de connexion liée au compte conservé ;
  ses anciens identifiants restent réservés. Ses anciennes informations de
  connexion ne permettent plus d’ouvrir une session autonome.
- Les sessions des deux comptes sont révoquées. La double vérification reste
  active si elle était active sur l’un des deux comptes.
- Une preuve datant de plus de 24 heures, un changement d’email/de sécurité ou
  un incident invalide la demande. Les décisions sont enregistrées dans le journal.

Le remplacement de l’email d’authentification depuis l’édition ordinaire du
profil est bloqué : il ne doit pas permettre de rediriger les codes de sécurité.

### Politique des mots de passe

Les nouveaux mots de passe exigent au moins 12 caractères et au maximum
72 octets UTF-8. La connexion aux anciens mots de passe n’impose pas rétroactivement
une nouvelle longueur. L’indicateur de robustesse est calculé localement ; aucun
mot de passe en clair n’est conservé dans la base ou dans l’historique.

La vérification des fuites utilise [Pwned Passwords](https://haveibeenpwned.com/API/v3#PwnedPasswords)
par k-anonymat : seuls les 5 premiers caractères du hash SHA-1 sont envoyés en
HTTPS avec `Add-Padding: true`. Le mot de passe et son hash complet restent locaux.
Cette recherche n’est effectuée que lors d’une création ou d’un changement,
pas à chaque caractère tapé. SHA-1 sert uniquement à cette requête ; les mots
de passe stockés et leur historique utilisent BCrypt.

```text
PASSWORD_COMPROMISE_CHECK_ENABLED=true
PASSWORD_HISTORY_SIZE=5
AUTH_RATE_LIMIT_ENABLED=true
```

La vérification des fuites est activée par défaut et refuse une création ou
modification si le service est indisponible. Le mot de passe courant et les quatre
précédents sont refusés avec la configuration par défaut. La taille d’historique
est configurable de 0 à 20 ; 0 désactive l’historique antérieur mais conserve
l’interdiction de choisir à nouveau le mot de passe courant.

Un administrateur peut déclarer un **incident confirmé**, avec justification.
Les sessions et codes de récupération sont révoqués ; les connexions par mot de
passe et sans mot de passe sont bloquées jusqu’à une réinitialisation réussie.
Aucune expiration périodique arbitraire n’est imposée.

Le limiteur autorise au maximum 60 requêtes d’authentification par adresse IP
sur 5 minutes, en plus des limites par compte et par OTP. Il est en mémoire,
par instance ; une installation distribuée doit partager cette limitation.

### Rôles et administration

L’inscription propose Patient, Médecin et Administrateur. Choisir un rôle
privilégié crée une demande en attente ; le compte reste Patient jusqu’à validation.
Les demandes ultérieures se font depuis **Sécurité et accès → Mes rôles**.
L’administrateur examine les qualifications, approuve ou refuse avec un motif.
L’auto-approbation est interdite. Une décision déjà rendue ne peut pas être rejouée.
L’ancien endpoint d’attribution directe des rôles est bloqué au profit du workflow.

Pour initialiser un premier administrateur, un opérateur du serveur peut définir :

```text
BOOTSTRAP_ADMIN_EMAIL=<email dont vous contrôlez la boîte>
BOOTSTRAP_ADMIN_PASSWORD=<phrase de passe personnelle unique, 12 caractères minimum>
```

Au démarrage, un nouveau compte administrateur est créé si l’email n’existe pas.
Sa première connexion exige une vérification email. Un compte existant ne peut
être promu par cette configuration que si son email est déjà vérifié ; son mot
de passe n’est jamais remplacé. L’opération est auditée. Retirer les variables de
bootstrap après initialisation d’une base persistante pour éviter une nouvelle
promotion involontaire après un changement de rôle ultérieur.

Le journal d’administration conserve auteur, compte concerné, action, date et
motif, sans mots de passe, OTP ni codes de récupération. Les endpoints
`/api/security/admin/**` exigent un administrateur avec email vérifié.

Hors profil `dev`, `JWT_SECRET` est obligatoire et doit contenir au moins
32 octets. Le profil `dev` utilise H2 en mémoire et une clé locale de développement ;
les données disparaissent au redémarrage. Une base PostgreSQL et une clé secrète
configurée sont nécessaires pour conserver les comptes hors développement.

### Routes principales

| Parcours | Routes |
| --- | --- |
| Inscription et connexion | `POST /api/auth/register`, `/login`, `/verify` |
| Sans mot de passe | `POST /api/auth/passwordless/request` puis `/api/auth/verify` |
| Code de récupération | `POST /api/auth/mfa/recover` après le mot de passe ou `/api/auth/login/recovery` sans envoi email |
| Renvoi de code | `POST /api/auth/challenges/{id}/resend` |
| Protection du compte | `GET /api/security`, `POST /api/security/challenge`, `/confirm` |
| Rôles | `GET/POST /api/security/role-requests` |
| Rapprochement | `GET/POST /api/security/merges`, `POST /api/security/merges/{id}/verify`, `/cancel` |
| Décisions | `POST /api/security/admin/role-requests/{id}/decision`, `/api/security/admin/merges/{id}/decision` |
| Résolution des identités | `GET /api/security/admin/duplicates` |
| Incidents et audit | `POST /api/security/admin/users/{id}/incident`, `GET /api/security/admin/audit` |

Les tests automatisés simulent SMTP et Pwned Passwords. Aucun email réel ni mot
de passe réel n’est envoyé pendant les tests. Les tests couvrent notamment les
preuves séparées, le rejeu, la concurrence, les refus de privilèges, la conservation
des dossiers et l’invalidation des sessions.
