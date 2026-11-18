import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/film.dart';
import '../domain/films_repository.dart';
import '../domain/films_use_cases.dart';

/// Bound to the data implementation in `lib/composition_root.dart`.
final filmsRepositoryProvider = Provider<FilmsRepository>(
  (ref) => throw UnimplementedError('filmsRepositoryProvider not overridden'),
);

final getActiveFilmsProvider =
    Provider((ref) => GetActiveFilms(ref.watch(filmsRepositoryProvider)));
final getNowShowingFilmProvider =
    Provider((ref) => GetNowShowingFilm(ref.watch(filmsRepositoryProvider)));
final getFilmByIdProvider =
    Provider((ref) => GetFilmById(ref.watch(filmsRepositoryProvider)));

/// Catalog loaded on entry; `ref.invalidate` to refetch. Errors surface as
/// `AsyncError` carrying an `ApiException`.
class FilmsNotifier extends AsyncNotifier<List<Film>> {
  @override
  Future<List<Film>> build() => ref.watch(getActiveFilmsProvider)();
}

final filmsNotifierProvider =
    AsyncNotifierProvider.autoDispose<FilmsNotifier, List<Film>>(
  FilmsNotifier.new,
);

/// The currently premiering film (null if none).
final nowShowingFilmProvider = FutureProvider.autoDispose<Film?>(
  (ref) => ref.watch(getNowShowingFilmProvider)(),
);

/// Individual film by ID.
final filmByIdProvider = FutureProvider.autoDispose.family<Film, String>(
  (ref, id) => ref.watch(getFilmByIdProvider)(id),
);
