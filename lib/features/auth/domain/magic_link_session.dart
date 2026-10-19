import 'package:equatable/equatable.dart';

/// Result of verifying an emailed magic link. The session itself lives in an
/// HTTP-only cookie managed by the HTTP layer; no token is exposed.
class MagicLinkSession extends Equatable {
  const MagicLinkSession({
    required this.userId,
    required this.claimedTicketId,
    required this.ticketType,
  });

  final String userId;
  final String claimedTicketId;

  /// Raw ticket type string (`single`, `bundle_2`, `bundle_4`).
  final String ticketType;

  @override
  List<Object?> get props => [userId, claimedTicketId, ticketType];
}
