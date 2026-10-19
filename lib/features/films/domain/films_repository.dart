import 'film.dart';

/// Contract for the public film catalog. Implemented in `data/`.
abstract class FilmsRepository {
  /// GET /films — upcoming, live and ended films.
  Future<List<Film>> getActiveFilms();

  /// GET /films/now-showing — null when nothing is premiering.
  Future<Film?> getNowShowing();
}
