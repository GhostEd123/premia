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
final resendMagicLinkProvider =
    Provider((ref) => ResendMagicLink(ref.watch(authRepositoryProvider)));
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
    this.isResending = false,
    this.resendSuccessMessage,
    this.error,
  });

  final MagicLinkSession? magicLinkSession;
  final bool isLoading;
  final bool isResending;
  final String? resendSuccessMessage;
  final String? error;

  bool get isAuthenticated => magicLinkSession != null;

  AuthState copyWith({
    Object? magicLinkSession = _keep,
    bool? isLoading,
    bool? isResending,
    Object? resendSuccessMessage = _keep,
    Object? error = _keep,
  }) =>
      AuthState(
        magicLinkSession: magicLinkSession == _keep
            ? this.magicLinkSession
            : magicLinkSession as MagicLinkSession?,
        isLoading: isLoading ?? this.isLoading,
        isResending: isResending ?? this.isResending,
        resendSuccessMessage: resendSuccessMessage == _keep
            ? this.resendSuccessMessage
            : resendSuccessMessage as String?,
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

  /// Self-service recovery: sends a fresh access link to buyer email.
  Future<void> resendMagicLink({
    required String email,
    required String filmId,
  }) async {
    state = state.copyWith(
      isResending: true,
      error: null,
      resendSuccessMessage: null,
    );
    try {
      final msg = await ref.read(resendMagicLinkProvider)(
        email: email,
        filmId: filmId,
      );
      state = state.copyWith(isResending: false, resendSuccessMessage: msg);
    } on ApiException catch (e) {
      state = state.copyWith(isResending: false, error: e.message);
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
