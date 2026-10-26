import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../storage/token_storage.dart';

class ApiClient {
  final TokenStorage storage;
  final VoidCallback? onSessionExpired;
  late final Dio dio;

  ApiClient(this.storage, {this.onSessionExpired}) {
    dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            if (!options.path.startsWith('/auth/')) {
              final token = await storage.read();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            }
            handler.next(options);
          } catch (error) {
            handler.reject(DioException(requestOptions: options, error: error));
          }
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.startsWith('/auth/')) {
            try {
              final token = await storage.read();
              final authorization =
                  token == null || token.isEmpty ? null : 'Bearer $token';
              // A delayed response from an old session must not end a newer one.
              if (error.requestOptions.headers['Authorization'] ==
                  authorization) {
                onSessionExpired?.call();
              }
            } catch (_) {
              // Always forward the original response, even if storage is unavailable.
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  String get _baseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredUrl.isNotEmpty) {
      return configuredUrl;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api';
    }
    return 'http://localhost:8080/api';
  }
}
