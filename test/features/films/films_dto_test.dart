import 'package:flutter_test/flutter_test.dart';
import 'package:premia/features/films/data/film_dto.dart';

void main() {
  group('FilmDto with multi-currency', () {
    test('parses ticketPriceUSD and detectedCurrency', () {
      final json = {
        '_id': 'film-id-101',
        'title': 'Behind the Scenes: Reloaded',
        'duration': 124,
        'ticketPriceNGN': 5000,
        'ticketPriceUSD': 10,
        'detectedCurrency': 'NGN',
        'premiereStart': '2026-11-15T20:00:00.000Z',
      };

      final dto = FilmDto.fromJson(json);
      final entity = dto.toEntity();

      expect(entity.id, 'film-id-101');
      expect(entity.title, 'Behind the Scenes: Reloaded');
      expect(entity.durationMinutes, 124);
      expect(entity.ticketPriceNgn, 5000);
      expect(entity.ticketPriceUsd, 10);
      expect(entity.detectedCurrency, 'NGN');
    });
  });
}

