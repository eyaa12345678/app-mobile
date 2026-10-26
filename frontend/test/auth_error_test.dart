import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/features/auth/auth_error.dart';

DioException unavailable(String code) {
  final request = RequestOptions(path: '/auth/register');
  return DioException.badResponse(
    statusCode: 503,
    requestOptions: request,
    response: Response(
      requestOptions: request,
      statusCode: 503,
      data: {'message': code},
    ),
  );
}

void main() {
  test('Mail configuration, credentials and network failures stay distinct',
      () {
    final messages = {
      for (final code in [
        'MAIL_NOT_CONFIGURED',
        'MAIL_AUTHENTICATION_FAILED',
        'MAIL_CONNECTION_FAILED',
        'MAIL_TLS_FAILED',
        'MAIL_SEND_FAILED',
      ])
        authErrorMessage(unavailable(code)),
    };
    expect(messages.length, 5);
    expect(authErrorMessage(unavailable('MAIL_NOT_CONFIGURED')),
        contains('n’est pas configuré'));
    expect(authErrorMessage(unavailable('MAIL_AUTHENTICATION_FAILED')),
        contains('s’authentifier'));
    expect(authErrorMessage(unavailable('MAIL_CONNECTION_FAILED')),
        contains('joindre le service'));
  });

  test('A generic unavailable service is not incorrectly diagnosed as SMTP',
      () {
    expect(authErrorMessage(unavailable('UNKNOWN_SERVICE_UNAVAILABLE')),
        isNot(contains('emails')));
    expect(authErrorMessage(unavailable('Password reset email is unavailable')),
        contains('emails'));
  });

  test('A frontend connection failure identifies the application server', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/auth/register'),
      type: DioExceptionType.connectionError,
    );
    expect(authErrorMessage(error), contains('serveur MediCare'));
  });
}
