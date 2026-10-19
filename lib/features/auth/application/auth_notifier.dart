import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_use_cases.dart';
import '../domain/magic_link_session.dart';

// --- Providers wiring the domain ---

/// Bound to the data implementation in `lib/composition_root.dart`.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError('authRepositoryProvider not overridden'),
);

final verifyMagicLinkProvider =
    Provider((ref) => VerifyMagicLink(ref.watch(authRepositoryProvider)));
final signOutProvider =
    Provider((ref) => SignOut(ref.watch(authRepositoryProvider)));

// --- State ---

const Object _keep = Object();

/// Who is signed in. Only the entity is held; the token stays in the
/// HTTP-only session cookie.
class AuthState {
  const AuthState({
    this.magicLinkSession,
    this.isLoading = false,
    this.error,
  });

  final MagicLinkSession? magicLinkSession;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => magicLinkSession != null;

  AuthState copyWith({
    Object? magicLinkSession = _keep,
    bool? isLoading,
    Object? error = _keep,
  }) =>
      AuthState(
        magicLinkSession: magicLinkSession == _keep
            ? this.magicLinkSession
            : magicLinkSession as MagicLinkSession?,
        isLoading: isLoading ?? this.isLoading,
        error: error == _keep ? this.error : error as String?,
      );
}

/// Session-lived auth state. Only mutates [state]; UI observes it.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<void> verifyMagicLink(String token) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final session = await ref.read(verifyMagicLinkProvider)(token);
      state = state.copyWith(isLoading: false, magicLinkSession: session);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  /// Always wipes local state, even if clearing storage fails.
  Future<void> signOut() async {
    try {
      await ref.read(signOutProvider)();
    } finally {
      state = const AuthState();
    }
  }
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
