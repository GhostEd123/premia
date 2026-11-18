import 'magic_link_session.dart';

/// Contract for ticket-holder authentication. Implemented in `data/`.
abstract class AuthRepository {
  /// GET /auth/verify?token=...
  Future<MagicLinkSession> verifyMagicLink(String token);

  /// POST /auth/resend-magic-link
  Future<String> resendMagicLink({
    required String email,
    required String filmId,
  });

  /// POST /auth/logout and clears local session cookies.
  Future<void> signOut();
}
