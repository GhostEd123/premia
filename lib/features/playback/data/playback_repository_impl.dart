import '../../../core/network/api_exception.dart';
import '../../../core/network/http_service.dart';
import '../../../core/security/device_id_service.dart';
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
    this.partyId,
    this.socketToken,
  });

  factory PlaybackAuthorizationDto.fromJson(Map<String, dynamic> json) =>
      PlaybackAuthorizationDto(
        playbackToken: JsonUtils.string(json, ['playbackToken']),
        streamId: JsonUtils.string(json, ['streamId']),
        ticketType: JsonUtils.string(json, ['ticketType']),
        elapsedTime: JsonUtils.integer(json, ['elapsedTime']),
        partyId: JsonUtils.stringOrNull(json, ['partyId']),
        socketToken: JsonUtils.stringOrNull(json, ['socketToken']),
      );

  final String playbackToken;
  final String streamId;
  final String ticketType;
  final int elapsedTime;
  final String? partyId;
  final String? socketToken;

  PlaybackAuthorization toEntity() => PlaybackAuthorization(
        playbackToken: playbackToken,
        streamId: streamId,
        ticketType: ticketType,
        elapsedSeconds: elapsedTime,
        partyId: partyId,
        socketToken: socketToken,
      );
}

/// HTTP implementation of [PlaybackRepository].
class PlaybackRepositoryImpl implements PlaybackRepository {
  PlaybackRepositoryImpl(this._http, [DeviceIdService? deviceIdService])
      : _deviceIdService = deviceIdService ?? DeviceIdService();

  final HttpService _http;
  final DeviceIdService _deviceIdService;

  @override
  Future<PlaybackAuthorization> authorize(PlaybackRequest request) async {
    final deviceId = await _deviceIdService.getOrCreate();
    final body = _body(request, deviceId);
    final raw = await _http.post('/playback/authorize', body: body);
    final dto = PlaybackAuthorizationDto.fromJson(JsonUtils.asMap(raw));
    if (dto.playbackToken.isEmpty) {
      throw const ApiException(ApiException.unexpectedResponse);
    }
    return dto.toEntity();
  }

  Map<String, dynamic> _body(PlaybackRequest r, String deviceId) {
    if (r.isGuest) {
      return {
        'inviteToken': r.inviteToken,
        'deviceId': deviceId,
      };
    }
    return {
      'ticketId': r.ticketId,
      'deviceId': deviceId,
      if (r.guestEmails.isNotEmpty) 'guestEmails': r.guestEmails,
    };
  }
}
