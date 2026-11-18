import 'auth_repository.dart';
import 'magic_link_session.dart';

/// Verifies a magic-link token and establishes a ticket-holder session.
class VerifyMagicLink {
  const VerifyMagicLink(this._repository);
  final AuthRepository _repository;

  Future<MagicLinkSession> call(String token) => _repository.verifyMagicLink(token);
}

/// Requests a fresh access link for an active premiere.
class ResendMagicLink {
  const ResendMagicLink(this._repository);
  final AuthRepository _repository;

  Future<String> call({
    required String email,
    required String filmId,
  }) =>
      _repository.resendMagicLink(email: email, filmId: filmId);
}

/// Invalidates the session on the server and wipes local session cookies.
class SignOut {
  const SignOut(this._repository);
  final AuthRepository _repository;

  Future<void> call() => _repository.signOut();
}
