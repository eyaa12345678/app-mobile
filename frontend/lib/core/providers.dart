import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'network/api_client.dart';
import 'storage/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
final sessionExpirationProvider = StateProvider<int>((ref) => 0);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    ref.read(tokenStorageProvider),
    onSessionExpired: () =>
        ref.read(sessionExpirationProvider.notifier).state++,
  ),
);
