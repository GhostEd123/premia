import 'package:equatable/equatable.dart';

/// Credentials to start playback: either a host (ticket id + optional guest
/// invites) or a guest (invite token). Exactly one shape is used per request.
class PlaybackRequest extends Equatable {
  const PlaybackRequest.host({
    required String this.ticketId,
    this.guestEmails = const [],
  }) : inviteToken = null;

  const PlaybackRequest.guest({required String this.inviteToken})
      : ticketId = null,
        guestEmails = const [];

  final String? ticketId;
  final List<String> guestEmails;
  final String? inviteToken;

  bool get isGuest => inviteToken != null;

  @override
  List<Object?> get props => [ticketId, guestEmails, inviteToken];
}

/// Everything the player needs to start a synchronized stream.
class PlaybackAuthorization extends Equatable {
  const PlaybackAuthorization({
    required this.playbackToken,
    required this.streamId,
    required this.ticketType,
    required this.elapsedSeconds,
  });

  /// Signed Cloudflare Stream token.
  final String playbackToken;
  final String streamId;
  final String ticketType;

  /// The player MUST seek to this offset so everyone watches in sync.
  final int elapsedSeconds;

  Duration get seekPosition => Duration(seconds: elapsedSeconds);

  @override
  List<Object?> get props => [playbackToken, streamId, ticketType, elapsedSeconds];
}
