import '../../../core/network/api_exception.dart';
import '../../../core/network/http_service.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/playback_authorization.dart';
import '../domain/playback_repository.dart';

/// Wire shape of the authorize response.
class PlaybackAuthorizationDto {
  const PlaybackAuthorizationDto({
    required this.playbackToken,
    required this.streamId,
    required this.ticketType,
    required this.elapsedTime,
  });

  factory PlaybackAuthorizationDto.fromJson(Map<String, dynamic> json) =>
      PlaybackAuthorizationDto(
        playbackToken: JsonUtils.string(json, ['playbackToken']),
        streamId: JsonUtils.string(json, ['streamId']),
        ticketType: JsonUtils.string(json, ['ticketType']),
        elapsedTime: JsonUtils.integer(json, ['elapsedTime']),
      );

  final String playbackToken;
  final String streamId;
  final String ticketType;
  final int elapsedTime;

  PlaybackAuthorization toEntity() => PlaybackAuthorization(
        playbackToken: playbackToken,
        streamId: streamId,
        ticketType: ticketType,
        elapsedSeconds: elapsedTime,
      );
}

/// HTTP implementation of [PlaybackRepository].
class PlaybackRepositoryImpl implements PlaybackRepository {
  PlaybackRepositoryImpl(this._http);
  final HttpService _http;

  @override
  Future<PlaybackAuthorization> authorize(PlaybackRequest request) async {
    final raw = await _http.post('/playback/authorize', body: _body(request));
    final dto = PlaybackAuthorizationDto.fromJson(JsonUtils.asMap(raw));
    if (dto.playbackToken.isEmpty) {
      throw const ApiException(ApiException.unexpectedResponse);
    }
    return dto.toEntity();
  }

  Map<String, dynamic> _body(PlaybackRequest r) {
    if (r.isGuest) return {'inviteToken': r.inviteToken};
    return {
      'ticketId': r.ticketId,
      if (r.guestEmails.isNotEmpty) 'guestEmails': r.guestEmails,
    };
  }
}
