import '../../../core/utils/json_utils.dart';
import '../domain/film.dart';

/// Wire shape of a film (`_id`, `title`, `genre`, `premiereStart`, ...).
/// Optional marketing fields (`premiereEnd`, `directors`, `cast`, `studio`)
/// are parsed tolerantly: absent keys simply yield empty values.
class FilmDto {
  const FilmDto(this._json);

  factory FilmDto.fromJson(Map<String, dynamic> json) => FilmDto(json);

  final Map<String, dynamic> _json;

  Film toEntity() => Film(
        id: JsonUtils.string(_json, ['_id', 'id']),
        title: JsonUtils.string(_json, ['title']),
        genre: _joined(_json['genre']),
        description: JsonUtils.stringOrNull(_json, ['description']),
        durationMinutes: _json['duration'] == null
            ? null
            : JsonUtils.number(_json, ['duration']),
        thumbnailUrl: JsonUtils.stringOrNull(
          _json,
          ['thumbnail', 'thumbnailUrl', 'posterUrl', 'poster'],
        ),
        ticketPriceNgn: _json['ticketPriceNGN'] == null
            ? null
            : JsonUtils.number(_json, ['ticketPriceNGN']),
        premiereStart: JsonUtils.dateTime(_json, ['premiereStart']),
        premiereEnd: JsonUtils.dateTime(_json, ['premiereEnd']),
        directors: _list(_json['directors'] ?? _json['director']),
        cast: _list(_json['cast']),
        studio: JsonUtils.stringOrNull(_json, ['studio']),
      );

  // --- Helpers ---

  static List<String> _list(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static String? _joined(dynamic raw) {
    final items = _list(raw);
    return items.isEmpty ? null : items.join(' • ');
  }
}
