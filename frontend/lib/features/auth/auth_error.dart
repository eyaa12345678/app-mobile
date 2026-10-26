import 'package:dio/dio.dart';

String authErrorMessage(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Le serveur met trop de temps à répondre. Réessayez dans un instant.';
      case DioExceptionType.connectionError:
        return 'Impossible de joindre le serveur MediCare. Réessayez dans un instant.';
      default:
        break;
    }
    final data = error.response?.data;
    final code = data is Map ? data['message']?.toString() : null;
    const messages = {
      'MAIL_NOT_CONFIGURED':
          'Le service d’envoi d’emails n’est pas configuré sur le serveur. Contactez l’administrateur.',
      'MAIL_AUTHENTICATION_FAILED':
          'Le service d’envoi d’emails ne parvient pas à s’authentifier. Contactez l’administrateur.',
      'MAIL_CONNECTION_FAILED':
          'Le serveur ne parvient pas à joindre le service d’envoi d’emails. Réessayez plus tard.',
      'MAIL_TLS_FAILED':
          'La connexion sécurisée au service d’envoi d’emails a échoué. Contactez l’administrateur.',
      'MAIL_SEND_FAILED':
          'L’envoi de l’email a échoué. Réessayez plus tard ou contactez l’administrateur.',
      'Password reset email is unavailable':
          'Le service d’envoi d’emails est indisponible. Réessayez plus tard.',
      'EMAIL_CHANGE_REQUIRES_VERIFICATION':
          'Votre email d’authentification ne peut pas être remplacé par une simple modification du profil.',
      'Invalid or expired reset code':
          'Code incorrect ou expiré. Demandez un nouveau code.',
      'CODE_INVALID_OR_EXPIRED':
          'Code incorrect, expiré ou déjà utilisé. Après plusieurs essais, recommencez la connexion.',
      'RECOVERY_CODE_INVALID':
          'Ce code de récupération est incorrect ou a déjà été utilisé.',
      'PASSWORDLESS_RECOVERY_REQUIRED':
          'Votre double vérification est active. Ajoutez un code de récupération pour continuer sans mot de passe.',
      'Current password is incorrect': 'Le mot de passe actuel est incorrect.',
      'OTP_COOLDOWN': 'Patientez une minute avant de demander un nouveau code.',
      'AUTH_RATE_LIMITED':
          'Trop de tentatives. Patientez cinq minutes avant de réessayer.',
      'PASSWORD_COMPROMISED':
          'Ce mot de passe apparaît dans des fuites connues. Choisissez une autre phrase de passe.',
      'PASSWORD_REUSED':
          'Choisissez un mot de passe qui n’a pas été utilisé récemment.',
      'PASSWORD_POLICY_VIOLATION':
          'Utilisez au moins 12 caractères et au maximum 72 octets UTF-8.',
      'PASSWORD_SCREENING_UNAVAILABLE':
          'La vérification des mots de passe compromis est indisponible. Réessayez plus tard.',
      'PASSWORD_RESET_REQUIRED':
          'Une réinitialisation est obligatoire après un incident confirmé. Utilisez « Mot de passe oublié ? ».',
      'Email already exists':
          'Cette adresse email est déjà utilisée. Connectez-vous ou récupérez votre accès.',
      'IDENTIFIER_ALREADY_USED':
          'Cette adresse email ou cet identifiant est déjà utilisé.',
      'AMBIGUOUS_IDENTITY':
          'Plusieurs comptes correspondent à cet identifiant. Contactez un administrateur.',
      'EMAIL_NOT_VERIFIED':
          'Vérifiez d’abord votre adresse email dans Sécurité et accès.',
      'ROLE_REQUEST_PENDING':
          'Une demande de rôle est déjà en attente de validation.',
      'ROLE_ALREADY_ASSIGNED': 'Ce rôle est déjà associé à votre compte.',
      'SELF_APPROVAL_FORBIDDEN':
          'Une autre personne habilitée doit examiner cette demande.',
      'ACCOUNT_REQUIRES_VERIFICATION':
          'Le compte doit être vérifié et tout incident résolu avant validation.',
      'ROLE_CHANGED_SINCE_REQUEST':
          'Le rôle a changé depuis la demande. Refusez cette demande et créez-en une nouvelle.',
      'REQUEST_ALREADY_REVIEWED':
          'Cette demande n’est plus en attente. Actualisez la liste.',
      'USE_ROLE_REQUEST_WORKFLOW':
          'Les rôles sont attribués via le workflow de demande et de validation.',
      'MFA_NOT_ENABLED': 'Activez d’abord la double vérification.',
      'MERGE_REQUEST_PENDING':
          'Une demande de rapprochement est déjà en cours. Terminez-la ou annulez-la.',
      'MERGE_SAME_ACCOUNT': 'Cet email est déjà lié à votre compte.',
      'MERGE_PROOF_EXPIRED':
          'Les preuves ont expiré ou la sécurité d’un compte a changé. Recommencez le rapprochement.',
      'MERGE_PRIVILEGED_ACCOUNTS_FORBIDDEN':
          'La fusion est réservée à deux comptes Patient. Les droits professionnels et administratifs ne sont jamais combinés.',
      'MERGE_CONFLICTS_UNRESOLVED':
          'Choisissez la valeur à conserver pour chaque conflit de profil.',
      'MERGE_INVALID_SELECTION':
          'La sélection des valeurs à conserver est invalide.',
    };
    if (messages.containsKey(code)) return messages[code]!;
    switch (error.response?.statusCode) {
      case 401:
        return 'Adresse email, identifiant ou mot de passe incorrect, ou session expirée.';
      case 403:
        return 'Vous ne disposez pas des droits nécessaires pour cette action.';
      case 409:
        return 'Cette action entre en conflit avec l’état actuel du compte. Actualisez et réessayez.';
      case 429:
        return 'Trop de tentatives. Patientez avant de réessayer.';
      case 503:
        return 'Le service est momentanément indisponible. Réessayez plus tard.';
      case 400:
        return 'Vérifiez les informations saisies puis réessayez.';
    }
    if ((error.response?.statusCode ?? 0) >= 500) {
      return 'Le service est momentanément indisponible. Réessayez plus tard.';
    }
  }
  return 'Cette action n’a pas pu aboutir. Veuillez réessayer.';
}
