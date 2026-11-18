import '../../../core/network/http_service.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/film.dart';
import '../domain/films_repository.dart';
import 'film_dto.dart';

/// HTTP implementation of [FilmsRepository].
class FilmsRepositoryImpl implements FilmsRepository {
  FilmsRepositoryImpl(this._http);
  final HttpService _http;

  @override
  Future<List<Film>> getActiveFilms() async {
    final raw = await _http.get('/films');
    final map = JsonUtils.asMap(raw);
    return JsonUtils.asMapList(map['films'] ?? const [])
        .map((j) => FilmDto.fromJson(j).toEntity())
        .toList();
  }

  @override
  Future<Film?> getNowShowing() async {
    final raw = await _http.get('/films/now-showing');
    final film = JsonUtils.asMap(raw)['film'];
    if (film == null) return null;
    return FilmDto.fromJson(JsonUtils.asMap(film)).toEntity();
  }

  @override
  Future<Film> getFilmById(String id) async {
    final raw = await _http.get('/films/${Uri.encodeComponent(id)}');
    final map = JsonUtils.asMap(raw);
    final filmData = map['film'] ?? map;
    return FilmDto.fromJson(JsonUtils.asMap(filmData)).toEntity();
  }
}
