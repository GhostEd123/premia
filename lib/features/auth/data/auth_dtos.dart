import '../../../core/utils/json_utils.dart';
import '../domain/magic_link_session.dart';

/// Wire shape of the magic-link verification response.
class MagicLinkSessionDto {
  const MagicLinkSessionDto({
    required this.userId,
    required this.claimedTicketId,
    required this.ticketType,
    this.filmId,
    this.accessToken,
    this.isHost = true,
  });

  factory MagicLinkSessionDto.fromJson(Map<String, dynamic> json) =>
      MagicLinkSessionDto(
        userId: JsonUtils.string(json, ['userId', 'user_id']),
        claimedTicketId: JsonUtils.string(json, ['claimedTicketId']),
        ticketType: JsonUtils.string(json, ['ticketType']),
        filmId: JsonUtils.stringOrNull(json, ['filmId', 'film_id']),
        accessToken: JsonUtils.stringOrNull(json, ['accessToken', 'token']),
        isHost: json['isHost'] is bool ? json['isHost'] as bool : true,
      );

  final String userId;
  final String claimedTicketId;
  final String ticketType;
  final String? filmId;
  final String? accessToken;
  final bool isHost;

  MagicLinkSession toEntity() => MagicLinkSession(
        userId: userId,
        claimedTicketId: claimedTicketId,
        ticketType: ticketType,
        filmId: filmId,
        accessToken: accessToken,
        isHost: isHost,
      );
}
