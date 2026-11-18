import 'package:flutter_riverpod/misc.dart' show Override;

import 'core/network/http_service.dart';
import 'features/auth/application/auth_notifier.dart';
import 'features/auth/data/auth_repository_impl.dart';
import 'features/films/application/films_notifier.dart';
import 'features/films/application/waitlist_notifier.dart';
import 'features/films/data/films_repository_impl.dart';
import 'features/films/data/waitlist_repository_impl.dart';
import 'features/parties/application/parties_providers.dart';
import 'features/parties/data/parties_repository_impl.dart';
import 'features/playback/application/playback_notifier.dart';
import 'features/playback/data/playback_repository_impl.dart';
import 'features/tickets/application/ticket_purchase_notifier.dart';
import 'features/tickets/data/tickets_repository_impl.dart';

/// Composition root: the ONLY place where data-layer implementations are
/// bound to the domain interfaces the application layer depends on.
/// Pass to `ProviderScope(overrides: repositoryOverrides)`; tests can pass
/// their own fakes instead.
final List<Override> repositoryOverrides = [
  authRepositoryProvider.overrideWith(
    (ref) => AuthRepositoryImpl(ref.watch(httpServiceProvider)),
  ),
  filmsRepositoryProvider.overrideWith(
    (ref) => FilmsRepositoryImpl(ref.watch(httpServiceProvider)),
  ),
  waitlistRepositoryProvider.overrideWith(
    (ref) => WaitlistRepositoryImpl(ref.watch(httpServiceProvider)),
  ),
  ticketsRepositoryProvider.overrideWith(
    (ref) => TicketsRepositoryImpl(ref.watch(httpServiceProvider)),
  ),
  playbackRepositoryProvider.overrideWith(
    (ref) => PlaybackRepositoryImpl(ref.watch(httpServiceProvider)),
  ),
  partiesRepositoryProvider.overrideWith(
    (ref) => PartiesRepositoryImpl(ref.watch(httpServiceProvider)),
  ),
];
