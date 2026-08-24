import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models.dart';

class CredentialStore {
  CredentialStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _keys = [
    'access_token',
    'refresh_token',
    'account_id',
    'last_refresh',
  ];
  Future<CodexCredentials?> read() async {
    final values = await _storage.readAll();
    final access = values['access_token'];
    final refresh = values['refresh_token'];
    final account = values['account_id'];
    if ([access, refresh, account].any((v) => v == null || v.isEmpty)) {
      return null;
    }
    return CodexCredentials(
      accessToken: access!,
      refreshToken: refresh!,
      accountId: account!,
      lastRefresh: DateTime.tryParse(values['last_refresh'] ?? '')?.toUtc(),
    );
  }

  Future<void> write(CodexCredentials value) async {
    // Secure storage operations are serialized; write the new pair before removing any valid key.
    await _storage.write(key: 'access_token', value: value.accessToken);
    await _storage.write(key: 'refresh_token', value: value.refreshToken);
    await _storage.write(key: 'account_id', value: value.accountId);
    await _storage.write(
      key: 'last_refresh',
      value: (value.lastRefresh ?? DateTime.now().toUtc()).toIso8601String(),
    );
  }

  Future<void> clear() async {
    for (final key in _keys) {
      await _storage.delete(key: key);
    }
  }
}
