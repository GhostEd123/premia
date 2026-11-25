import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/security/screen_protection.dart';
import '../domain/playback_authorization.dart';
import '../domain/playback_repository.dart';
import '../domain/playback_use_cases.dart';

/// Bound to the data implementation in `lib/composition_root.dart`.
final playbackRepositoryProvider = Provider<PlaybackRepository>(
  (ref) => throw UnimplementedError('playbackRepositoryProvider not overridden'),
);

final authorizePlaybackProvider =
    Provider((ref) => AuthorizePlayback(ref.watch(playbackRepositoryProvider)));

const Object _keep = Object();

class PlaybackState {
  const PlaybackState({
    this.isAuthorizing = false,
    this.isWaitingForHost = false,
    this.waitingPartyId,
    this.authorization,
    this.error,
    this.isScreenCaptured = false,
  });

  final bool isAuthorizing;

  /// True when a guest attempted to authorize before the host started the
  /// premiere (HTTP 409 `{ partyStatus: "waiting", partyId }`).
  final bool isWaitingForHost;
  final String? waitingPartyId;

  final PlaybackAuthorization? authorization;
  final String? error;

  /// True while the OS reports screen recording/mirroring (iOS). The UI must
  /// pause playback and hide the video while this is set.
  final bool isScreenCaptured;

  bool get isReady => authorization != null;

  PlaybackState copyWith({
    bool? isAuthorizing,
    bool? isWaitingForHost,
    Object? waitingPartyId = _keep,
    Object? authorization = _keep,
    Object? error = _keep,
    bool? isScreenCaptured,
  }) =>
      PlaybackState(
        isAuthorizing: isAuthorizing ?? this.isAuthorizing,
        isWaitingForHost: isWaitingForHost ?? this.isWaitingForHost,
        waitingPartyId: waitingPartyId == _keep
            ? this.waitingPartyId
            : waitingPartyId as String?,
        authorization: authorization == _keep
            ? this.authorization
            : authorization as PlaybackAuthorization?,
        error: error == _keep ? this.error : error as String?,
        isScreenCaptured: isScreenCaptured ?? this.isScreenCaptured,
      );
}

/// Authorizes hosts/guests and exposes the playback token + sync offset.
/// Tickets are single-viewing, so the result is kept only for this visit.
///
/// While authorized it turns on native screen protection (Android
/// FLAG_SECURE) and tracks screen capture (iOS); both are released when the
/// notifier is disposed.
class PlaybackNotifier extends Notifier<PlaybackState> {
  @override
  PlaybackState build() {
    final protection = ref.watch(screenProtectionProvider);
    final sub = protection.captureChanges.listen(
      (captured) => state = state.copyWith(isScreenCaptured: captured),
    );
    ref.onDispose(() {
      sub.cancel();
      unawaited(protection.disable());
    });
    return const PlaybackState();
  }

  /// Host entry; [guestEmails] only apply to bundle tickets.
  Future<void> authorizeHost({
    required String ticketId,
    List<String> guestEmails = const [],
  }) =>
      _authorize(
        PlaybackRequest.host(
          ticketId: ticketId,
          guestEmails: guestEmails.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        ),
      );

  /// Guest entry using the token from the emailed invite link.
  Future<void> authorizeGuest(String inviteToken) =>
      _authorize(PlaybackRequest.guest(inviteToken: inviteToken));

  Future<void> _authorize(PlaybackRequest request) async {
    state = state.copyWith(
      isAuthorizing: true,
      isWaitingForHost: false,
      error: null,
      authorization: null,
    );
    try {
      final auth = await ref.read(authorizePlaybackProvider)(request);
      final protection = ref.read(screenProtectionProvider);
      await protection.enable();
      state = state.copyWith(
        isAuthorizing: false,
        isWaitingForHost: false,
        authorization: auth,
        isScreenCaptured: await protection.isCaptured(),
      );
    } on ApiException catch (e) {
      final body = e.body;
      final partyStatus = body is Map ? body['partyStatus']?.toString() : null;
      final partyId = body is Map ? body['partyId']?.toString() : null;
      if (e.statusCode == 409 &&
          (partyStatus == 'waiting' || request.isGuest)) {
        state = state.copyWith(
          isAuthorizing: false,
          isWaitingForHost: true,
          waitingPartyId: partyId,
          error: null,
        );
        return;
      }
      state = state.copyWith(
        isAuthorizing: false,
        isWaitingForHost: false,
        error: e.message,
      );
    }
  }
}

final playbackNotifierProvider =
    NotifierProvider.autoDispose<PlaybackNotifier, PlaybackState>(
  PlaybackNotifier.new,
);
