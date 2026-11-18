import '../../../core/network/http_service.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/waitlist_repository.dart';

/// HTTP implementation of [WaitlistRepository].
class WaitlistRepositoryImpl implements WaitlistRepository {
  WaitlistRepositoryImpl(this._http);
  final HttpService _http;

  @override
  Future<String> submitWaitlist({String? email, String? phone}) async {
    final raw = await _http.post(
      '/waitlist',
      body: {
        if (email != null && email.trim().isNotEmpty)
          'email': email.trim().toLowerCase(),
        if (phone != null && phone.trim().isNotEmpty)
          'phone': phone.trim(),
      },
    );
    return JsonUtils.string(
      JsonUtils.asMap(raw),
      ['message'],
      fallback: "You're on the list. We'll alert you first.",
    );
  }
}

