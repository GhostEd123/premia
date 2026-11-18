import 'package:flutter_test/flutter_test.dart';
import 'package:premia/features/auth/data/auth_dtos.dart';

void main() {
  group('MagicLinkSessionDto', () {
    test('parses userId, claimedTicketId, ticketType, and filmId correctly', () {
      final json = {
        'message': 'Logged in successfully',
        'userId': 'user-123',
        'claimedTicketId': 'ticket-456',
        'ticketType': 'bundle_2',
        'filmId': 'film-789',
      };

      final dto = MagicLinkSessionDto.fromJson(json);
      final entity = dto.toEntity();

      expect(entity.userId, 'user-123');
      expect(entity.claimedTicketId, 'ticket-456');
      expect(entity.ticketType, 'bundle_2');
      expect(entity.filmId, 'film-789');
    });
  });
}

