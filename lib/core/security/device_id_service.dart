import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Provides a stable per-install device identifier (UUID v4) kept in secure
/// storage. `HttpService` sends it on every request so the backend can bind
/// playback sessions to a device (anti-piracy / session enforcement).
class DeviceIdService {
  DeviceIdService([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'premia.device_id';

  final FlutterSecureStorage _storage;
  String? _cached;

  Future<String> getOrCreate() async {
    final cached = _cached;
    if (cached != null) return cached;
    var id = await _storage.read(key: _key);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await _storage.write(key: _key, value: id);
    }
    return _cached = id;
  }
}
