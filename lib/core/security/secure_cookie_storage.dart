import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cookie-jar [Storage] backed by the platform keystore (Keychain on iOS,
/// encrypted storage on Android) so HTTP-only session cookies never sit in
/// plain files. Used by `PersistCookieJar`.
class SecureCookieStorage implements Storage {
  SecureCookieStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _prefix = 'premia.cookie.';

  final FlutterSecureStorage _storage;

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) => _storage.read(key: '$_prefix$key');

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: '$_prefix$key', value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: '$_prefix$key');

  @override
  Future<void> deleteAll(List<String> keys) async {
    for (final key in keys) {
      await _storage.delete(key: '$_prefix$key');
    }
  }
}
