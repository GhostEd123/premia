import 'auth_repository.dart';
import 'magic_link_session.dart';

/// Verifies a magic-link token and establishes a ticket-holder session.
class VerifyMagicLink {
  const VerifyMagicLink(this._repository);
  final AuthRepository _repository;

  Future<MagicLinkSession> call(String token) => _repository.verifyMagicLink(token);
}

/// Wipes the local session.
class SignOut {
  const SignOut(this._repository);
  final AuthRepository _repository;

  Future<void> call() => _repository.clearSession();
}
