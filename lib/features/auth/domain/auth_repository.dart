import 'magic_link_session.dart';

/// Contract for ticket-holder authentication. Implemented in `data/`.
abstract class AuthRepository {
  /// GET /auth/verify?token=...
  Future<MagicLinkSession> verifyMagicLink(String token);

  /// Clears the local session (cookies).
  Future<void> clearSession();
}
