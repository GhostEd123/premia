import '../../../core/utils/json_utils.dart';
import '../domain/magic_link_session.dart';

/// Wire shape of the magic-link verification response.
class MagicLinkSessionDto {
  const MagicLinkSessionDto({
    required this.userId,
    required this.claimedTicketId,
    required this.ticketType,
  });

  factory MagicLinkSessionDto.fromJson(Map<String, dynamic> json) =>
      MagicLinkSessionDto(
        userId: JsonUtils.string(json, ['userId', 'user_id']),
        claimedTicketId: JsonUtils.string(json, ['claimedTicketId']),
        ticketType: JsonUtils.string(json, ['ticketType']),
      );

  final String userId;
  final String claimedTicketId;
  final String ticketType;

  MagicLinkSession toEntity() => MagicLinkSession(
        userId: userId,
        claimedTicketId: claimedTicketId,
        ticketType: ticketType,
      );
}
