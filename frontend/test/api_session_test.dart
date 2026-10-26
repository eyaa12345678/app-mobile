import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/network/api_client.dart';
import 'widget_test.dart' show MemoryTokenStorage;

class PendingUnauthorizedAdapter implements HttpClientAdapter {
  final started = Completer<void>();
  final response = Completer<ResponseBody>();

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    started.complete();
    return response.future;
  }

  @override
  void close({bool force = false}) {}

  void reject() =>
      response.complete(ResponseBody.fromString('{}', 401, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      }));
}

void main() {
  for (final newSession in [false, true]) {
    test(
        'A 401 expires only the session that sent the request (new session: $newSession)',
        () async {
      final storage = MemoryTokenStorage()..token = 'old-token';
      var expirations = 0;
      final client = ApiClient(storage, onSessionExpired: () => expirations++);
      final adapter = PendingUnauthorizedAdapter();
      client.dio.httpClientAdapter = adapter;
      final pending = client.dio.get<void>('/users/me');
      await adapter.started.future;
      if (newSession) storage.token = 'new-token';
      adapter.reject();
      await expectLater(pending, throwsA(isA<DioException>()));
      expect(expirations, newSession ? 0 : 1);
      client.dio.close();
    });
  }
}
