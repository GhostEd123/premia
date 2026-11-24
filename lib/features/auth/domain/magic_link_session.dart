import 'package:equatable/equatable.dart';

/// Result of verifying an emailed magic link. The session itself lives in an
/// HTTP-only cookie managed by the HTTP layer; no token is exposed.
class MagicLinkSession extends Equatable {
  const MagicLinkSession({
    required this.userId,
    required this.claimedTicketId,
    required this.ticketType,
    this.filmId,
  });

  final String userId;
  final String claimedTicketId;

  /// Raw ticket type string (`single`, `bundle_2`, `bundle_4`).
  final String ticketType;

  /// Film associated with the verified ticket (enables direct routing).
  final String? filmId;

  /// True when the verified ticket is a Watch Party bundle (`bundle_2`, `bundle_4`).
  bool get isWatchParty =>
      ticketType == 'bundle_2' ||
      ticketType == 'bundle_4' ||
      ticketType.startsWith('bundle');

  @override
  List<Object?> get props => [userId, claimedTicketId, ticketType, filmId];
}
