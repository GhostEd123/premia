import 'playback_authorization.dart';

/// Contract for playback authorization. Implemented in `data/`.
abstract class PlaybackRepository {
  /// POST /playback/authorize
  Future<PlaybackAuthorization> authorize(PlaybackRequest request);
}
