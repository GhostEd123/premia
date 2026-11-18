import 'package:flutter_test/flutter_test.dart';
import 'package:premia/features/playback/data/playback_repository_impl.dart';

void main() {
  group('PlaybackAuthorizationDto', () {
    test('parses playbackToken, streamId, partyId, and socketToken', () {
      final json = {
        'playbackToken': 'rs256-jwt-token',
        'streamId': 'cf-stream-id-123',
        'ticketType': 'bundle_4',
        'elapsedTime': 142,
        'partyId': 'party-abc-999',
        'socketToken': 'hs256-socket-token',
      };

      final dto = PlaybackAuthorizationDto.fromJson(json);
      final entity = dto.toEntity();

      expect(entity.playbackToken, 'rs256-jwt-token');
      expect(entity.streamId, 'cf-stream-id-123');
      expect(entity.ticketType, 'bundle_4');
      expect(entity.elapsedSeconds, 142);
      expect(entity.partyId, 'party-abc-999');
      expect(entity.socketToken, 'hs256-socket-token');
    });
  });
}

