import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/enter_link_screen.dart';
import '../../features/films/domain/film.dart';
import '../../features/films/presentation/marquee_screen.dart';
import '../../features/films/presentation/upcoming_film_screen.dart';
import '../../features/parties/presentation/host_party_screen.dart';
import '../../features/parties/presentation/lobby_screen.dart';
import '../../features/playback/presentation/player_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/tickets/domain/payment_intent.dart';
import '../../features/tickets/presentation/checkout_screen.dart';
import '../../features/tickets/presentation/payment_pending_screen.dart';
import 'route_paths.dart';

/// Single router for the app. Complex arguments travel via `state.extra`;
/// simple ones via query parameters.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RoutePaths.splash,
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.marquee,
        builder: (_, _) => const MarqueeScreen(),
      ),
      GoRoute(
        path: RoutePaths.upcoming,
        redirect: (_, state) => state.extra is Film ? null : RoutePaths.marquee,
        builder: (_, state) => UpcomingFilmScreen(film: state.extra! as Film),
      ),
      GoRoute(
        path: RoutePaths.checkout,
        redirect: (_, state) => state.extra is Film ? null : RoutePaths.marquee,
        builder: (_, state) => CheckoutScreen(film: state.extra! as Film),
      ),
      GoRoute(
        path: RoutePaths.paymentPending,
        redirect: (_, state) =>
            state.extra is PaymentIntent ? null : RoutePaths.marquee,
        builder: (_, state) =>
            PaymentPendingScreen(intent: state.extra! as PaymentIntent),
      ),
      GoRoute(
        path: RoutePaths.enterLink,
        builder: (_, _) => const EnterLinkScreen(),
      ),
      GoRoute(
        path: RoutePaths.verify,
        builder: (_, state) =>
            EnterLinkScreen(initialToken: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: RoutePaths.lobby,
        builder: (_, state) => LobbyScreen(film: state.extra as Film?),
      ),
      GoRoute(
        path: RoutePaths.hostParty,
        builder: (_, _) => const HostPartyScreen(),
      ),
      GoRoute(
        path: RoutePaths.player,
        builder: (_, state) =>
            PlayerScreen(title: state.extra is String ? state.extra! as String : 'Premiere'),
      ),
      GoRoute(
        path: RoutePaths.watch,
        builder: (_, state) => PlayerScreen(
          title: 'Watch Party',
          inviteToken: state.uri.queryParameters['inviteToken'],
        ),
      ),
    ],
  );
});
