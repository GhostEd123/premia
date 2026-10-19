import '../../../core/network/http_service.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/auth_repository.dart';
import '../domain/magic_link_session.dart';
import 'auth_dtos.dart';

/// HTTP implementation of [AuthRepository]. Session cookies are persisted in
/// secure storage by [HttpService]'s cookie jar.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._http);
  final HttpService _http;

  @override
  Future<MagicLinkSession> verifyMagicLink(String token) async {
    final raw = await _http.get('/auth/verify', query: {'token': token});
    return MagicLinkSessionDto.fromJson(JsonUtils.asMap(raw)).toEntity();
  }

  @override
  Future<void> clearSession() => _http.clearSession();
}
