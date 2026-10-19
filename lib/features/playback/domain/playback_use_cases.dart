import 'playback_authorization.dart';
import 'playback_repository.dart';

/// Authorizes a host or guest to watch and returns the sync offset.
class AuthorizePlayback {
  const AuthorizePlayback(this._repository);
  final PlaybackRepository _repository;

  Future<PlaybackAuthorization> call(PlaybackRequest request) =>
      _repository.authorize(request);
}
