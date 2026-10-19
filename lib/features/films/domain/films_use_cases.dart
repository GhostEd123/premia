import 'film.dart';
import 'films_repository.dart';

/// Lists all upcoming, live and ended films.
class GetActiveFilms {
  const GetActiveFilms(this._repository);
  final FilmsRepository _repository;

  Future<List<Film>> call() => _repository.getActiveFilms();
}

/// Fetches the film that is currently premiering, if any.
class GetNowShowingFilm {
  const GetNowShowingFilm(this._repository);
  final FilmsRepository _repository;

  Future<Film?> call() => _repository.getNowShowing();
}
