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
    this.drmToken,
    this.thumbnailToken,
    this.partyId,
    this.socketToken,
  });

  /// Signed video playback token (Mux / Cloudflare Stream RS256 JWT).
  final String playbackToken;
  final String streamId;
  final String ticketType;

  /// The player MUST seek to this offset so everyone watches in sync.
  final int elapsedSeconds;

  /// Optional signed DRM token (`aud: "d"`).
  final String? drmToken;

  /// Optional signed thumbnail token (`aud: "t"`).
  final String? thumbnailToken;

  /// Associated watch party room ID if part of a group/bundle premiere.
  final String? partyId;

  /// Real-time watch party authentication token for Socket.IO connections.
  final String? socketToken;

  /// True when the playback session belongs to a Watch Party (not a `'single'` ticket).
  bool get isWatchParty => ticketType != 'single' && ticketType.isNotEmpty;

  Duration get seekPosition => Duration(seconds: elapsedSeconds);

  @override
  List<Object?> get props => [
        playbackToken,
        streamId,
        ticketType,
        elapsedSeconds,
        drmToken,
        thumbnailToken,
        partyId,
        socketToken,
      ];
}
