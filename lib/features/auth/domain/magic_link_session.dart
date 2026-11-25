import 'package:equatable/equatable.dart';

/// Result of verifying an emailed magic link. The session itself lives in an
/// HTTP-only cookie managed by the HTTP layer; no token is exposed.
class MagicLinkSession extends Equatable {
  const MagicLinkSession({
    required this.userId,
    required this.claimedTicketId,
    required this.ticketType,
    this.filmId,
    this.accessToken,
    this.isHost = true,
    this.inviteToken,
    this.partyId,
  });

  final String userId;
  final String claimedTicketId;

  /// Raw ticket type string (`single`, `bundle_2`, `bundle_4`).
  final String ticketType;

  /// Film associated with the verified ticket (enables direct routing).
  final String? filmId;

  /// Mobile Bearer token returned by `GET /auth/verify` or `POST /parties/join-lobby`.
  final String? accessToken;

  /// True for the ticket purchaser (Host), false for an invited Watch Party guest.
  final bool isHost;

  /// Guest invite token when authenticated via a Watch Party invite link.
  final String? inviteToken;

  /// Watch party ID when authenticated via `POST /parties/join-lobby`.
  final String? partyId;

  /// True when the verified ticket is a Watch Party bundle (`bundle_2`, `bundle_4`)
  /// or an invited Watch Party guest session.
  bool get isWatchParty =>
      !isHost ||
      ticketType == 'bundle_2' ||
      ticketType == 'bundle_4' ||
      ticketType.startsWith('bundle');

  /// Total participant passes included with the ticket (counting the host).
  /// `2` for `bundle_2`, `4` for `bundle_4`, `1` for `single`.
  int get totalPasses {
    if (ticketType == 'bundle_2') return 2;
    if (ticketType == 'bundle_4') return 4;
    return 1;
  }

  @override
  List<Object?> get props => [
        userId,
        claimedTicketId,
        ticketType,
        filmId,
        accessToken,
        isHost,
        inviteToken,
        partyId,
      ];
}
