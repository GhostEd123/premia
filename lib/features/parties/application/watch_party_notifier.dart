import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/party_guest.dart';
import '../domain/quick_messages.dart';
import '../domain/watch_party.dart';
import 'parties_providers.dart';

const Object _keep = Object();

/// An animated emoji reaction floating upward over the video player.
class FloatingReaction {
  const FloatingReaction({
    required this.id,
    required this.emoji,
    required this.xOffset,
    required this.createdAt,
  });

  final String id;
  final String emoji;
  final double xOffset; // 0.0 to 1.0
  final DateTime createdAt;
}

/// A transient predefined quick message floating upward over the video player
/// and fading away slowly (not stored in any persistent history).
class FloatingMessage {
  const FloatingMessage({
    required this.id,
    required this.text,
    required this.xOffset,
    required this.createdAt,
  });

  final String id;
  final String text;
  final double xOffset; // 0.0 to 1.0
  final DateTime createdAt;
}

class WatchPartyState {
  const WatchPartyState({
    required this.party,
    this.quickMessages,
    this.syncTimestamp,
    this.pausesRemaining = 3,
    this.isPaused = false,
    this.isScreenLocked = false,
    this.isSubmittingInvite = false,
    this.inviteSuccess = false,
    this.inviteError,
    this.actionFeedbackMessage,
    this.partyStartedEvent,
    this.hostPlaybackSync,
    this.activeReactions = const [],
    this.activeMessages = const [],
    this.showPauseModal = false,
  });

  final WatchParty party;
  final QuickMessages? quickMessages;
  final double? syncTimestamp;
  final int pausesRemaining;
  final bool isPaused;
  final bool isScreenLocked;
  final bool isSubmittingInvite;
  final bool inviteSuccess;
  final String? inviteError;
  final String? actionFeedbackMessage;
  final PartyStartedEvent? partyStartedEvent;
  final PartyPlaybackSync? hostPlaybackSync;
  final List<FloatingReaction> activeReactions;
  final List<FloatingMessage> activeMessages;
  final bool showPauseModal;

  WatchPartyState copyWith({
    WatchParty? party,
    Object? quickMessages = _keep,
    Object? syncTimestamp = _keep,
    int? pausesRemaining,
    bool? isPaused,
    bool? isScreenLocked,
    bool? isSubmittingInvite,
    bool? inviteSuccess,
    Object? inviteError = _keep,
    Object? actionFeedbackMessage = _keep,
    Object? partyStartedEvent = _keep,
    Object? hostPlaybackSync = _keep,
    List<FloatingReaction>? activeReactions,
    List<FloatingMessage>? activeMessages,
    bool? showPauseModal,
  }) => WatchPartyState(
    party: party ?? this.party,
    quickMessages: quickMessages == _keep
        ? this.quickMessages
        : quickMessages as QuickMessages?,
    syncTimestamp: syncTimestamp == _keep
        ? this.syncTimestamp
        : syncTimestamp as double?,
    pausesRemaining: pausesRemaining ?? this.pausesRemaining,
    isPaused: isPaused ?? this.isPaused,
    isScreenLocked: isScreenLocked ?? this.isScreenLocked,
    isSubmittingInvite: isSubmittingInvite ?? this.isSubmittingInvite,
    inviteSuccess: inviteSuccess ?? this.inviteSuccess,
    inviteError: inviteError == _keep
        ? this.inviteError
        : inviteError as String?,
    actionFeedbackMessage: actionFeedbackMessage == _keep
        ? this.actionFeedbackMessage
        : actionFeedbackMessage as String?,
    partyStartedEvent: partyStartedEvent == _keep
        ? this.partyStartedEvent
        : partyStartedEvent as PartyStartedEvent?,
    hostPlaybackSync: hostPlaybackSync == _keep
        ? this.hostPlaybackSync
        : hostPlaybackSync as PartyPlaybackSync?,
    activeReactions: activeReactions ?? this.activeReactions,
    activeMessages: activeMessages ?? this.activeMessages,
    showPauseModal: showPauseModal ?? this.showPauseModal,
  );
}

class WatchPartyNotifier extends Notifier<WatchPartyState> {
  Timer? _reactionCleanupTimer;
  Timer? _messageCleanupTimer;
  Timer? _syncTimer;
  StreamSubscription<String>? _incomingMsgSub;
  StreamSubscription<String>? _incomingReactionSub;
  StreamSubscription<WatchParty>? _lobbyUpdateSub;
  StreamSubscription<PartyStartedEvent>? _partyStartedSub;
  StreamSubscription<PartyPlaybackSync>? _playbackSyncSub;
  String? _lastLocallySentMessage;
  DateTime? _lastLocallySentMessageAt;
  String? _lastLocallySentReaction;
  DateTime? _lastLocallySentReactionAt;

  static const QuickMessages _defaultQuickMessages = QuickMessages(
    messages: [
      'OMG!',
      'No way!',
      "I didn't see that coming...",
      'Lol',
      'This scene is intense',
      'Who is that?!',
      'I love this part',
      'Boring',
    ],
    reactions: ['🥱', '😱', '😂', '❤️', '🍿'],
  );

  @override
  WatchPartyState build() {
    ref.onDispose(() {
      _reactionCleanupTimer?.cancel();
      _messageCleanupTimer?.cancel();
      _syncTimer?.cancel();
      _incomingMsgSub?.cancel();
      _incomingReactionSub?.cancel();
      _lobbyUpdateSub?.cancel();
      _partyStartedSub?.cancel();
      _playbackSyncSub?.cancel();
      try {
        ref.read(partiesRepositoryProvider).disconnectWatchParty();
      } catch (_) {}
    });

    // Listen to incoming Socket.IO events if repository is overridden
    _subscribeSocketStreams();

    // Default empty watch party state (`1/2` passes used by default, `guests: []`)
    const initialParty = WatchParty(
      partyId: '',
      hostName: 'Host',
      filmId: '',
      status: 'not_created',
      totalPasses: 2,
      guests: [],
    );

    // Fetch quick messages from GET /api/parties/quick-messages in background
    Future.microtask(_loadQuickMessages);

    return WatchPartyState(
      party: initialParty,
      quickMessages: _defaultQuickMessages,
    );
  }

  /// Syncs the watch party capacity (`2` for `bundle_2`, `4` for `bundle_4`)
  /// from the verified ticket session.
  void configureForTicket({required String ticketType, String? filmId}) {
    final targetTotal = ticketType == 'bundle_2'
        ? 2
        : (ticketType == 'bundle_4' ? 4 : state.party.totalPasses);
    final nextFilmId = (filmId != null && filmId.isNotEmpty)
        ? filmId
        : state.party.filmId;

    if (state.party.totalPasses == targetTotal &&
        state.party.filmId == nextFilmId) {
      return;
    }

    final maxGuests = (targetTotal - 1).clamp(0, targetTotal);
    final adjustedGuests = state.party.guests.length > maxGuests
        ? state.party.guests.sublist(0, maxGuests)
        : state.party.guests;

    state = state.copyWith(
      party: state.party.copyWith(
        totalPasses: targetTotal,
        filmId: nextFilmId,
        guests: adjustedGuests,
      ),
    );
  }

  void _subscribeSocketStreams() {
    try {
      final repo = ref.read(partiesRepositoryProvider);
      _incomingMsgSub?.cancel();
      _incomingReactionSub?.cancel();
      _lobbyUpdateSub?.cancel();
      _partyStartedSub?.cancel();
      _playbackSyncSub?.cancel();

      _incomingMsgSub = repo.incomingQuickMessages.listen((text) {
        final now = DateTime.now();
        if (_lastLocallySentMessage == text &&
            _lastLocallySentMessageAt != null &&
            now.difference(_lastLocallySentMessageAt!) <
                const Duration(milliseconds: 900)) {
          _lastLocallySentMessage = null;
          return;
        }
        _spawnFloatingMessage(text);
      });
      _incomingReactionSub = repo.incomingReactions.listen((emoji) {
        final now = DateTime.now();
        if (_lastLocallySentReaction == emoji &&
            _lastLocallySentReactionAt != null &&
            now.difference(_lastLocallySentReactionAt!) <
                const Duration(milliseconds: 900)) {
          _lastLocallySentReaction = null;
          return;
        }
        _spawnFloatingReaction(emoji);
      });
      _lobbyUpdateSub = repo.lobbyUpdates.listen((updated) {
        state = state.copyWith(
          party: state.party.copyWith(
            partyId: updated.partyId.isNotEmpty
                ? updated.partyId
                : state.party.partyId,
            status: updated.status,
            hostOnline: updated.hostOnline,
            totalPasses: updated.totalPasses,
            remainingSlots: updated.remainingSlots,
            guests: updated.guests,
          ),
        );
      });
      _partyStartedSub = repo.partyStartedEvents.listen((event) {
        state = state.copyWith(
          partyStartedEvent: event,
          party: state.party.copyWith(status: 'active'),
        );
      });
      _playbackSyncSub = repo.playbackSyncEvents.listen((sync) {
        state = state.copyWith(
          hostPlaybackSync: sync,
          isPaused: sync.isPaused,
          syncTimestamp: sync.currentTimeSeconds >= 0
              ? sync.currentTimeSeconds
              : state.syncTimestamp,
        );
      });
    } catch (_) {
      // Repository not overridden in isolated widget tests.
    }
  }

  /// Fetches the current lobby state (`GET /api/parties/lobby?ticketId=...` or `?partyId=...`)
  /// and connects to the Watch Party Socket.IO room.
  Future<void> fetchLobby({String? ticketId, String? partyId}) async {
    if ((ticketId == null || ticketId.trim().isEmpty) &&
        (partyId == null || partyId.trim().isEmpty)) {
      return;
    }
    try {
      final repo = ref.read(partiesRepositoryProvider);
      final lobby = await repo.getLobby(ticketId: ticketId, partyId: partyId);
      final merged = state.party.copyWith(
        partyId: lobby.partyId.isNotEmpty ? lobby.partyId : state.party.partyId,
        filmId: lobby.filmId.isNotEmpty ? lobby.filmId : state.party.filmId,
        status: lobby.status,
        isHost: lobby.isHost,
        hostOnline: lobby.hostOnline,
        totalPasses: lobby.totalPasses,
        remainingSlots: lobby.remainingSlots,
        guests: lobby.guests,
        socketToken: lobby.socketToken ?? state.party.socketToken,
      );
      state = state.copyWith(party: merged);

      if (merged.partyId.isNotEmpty &&
          (merged.socketToken?.isNotEmpty ?? false)) {
        await connectSocket(
          partyId: merged.partyId,
          socketToken: merged.socketToken!,
        );
      }
    } catch (_) {
      // Keep local party state when offline or in isolated tests.
    }
  }

  /// Guest enters the wait lobby via `POST /api/parties/join-lobby`.
  Future<WatchParty?> joinGuestLobby(String inviteToken) async {
    state = state.copyWith(isSubmittingInvite: true, inviteError: null);
    try {
      final repo = ref.read(partiesRepositoryProvider);
      final lobby = await repo.joinLobby(inviteToken: inviteToken);
      state = state.copyWith(
        party: lobby.copyWith(isHost: false),
        isSubmittingInvite: false,
      );
      if (lobby.partyId.isNotEmpty &&
          (lobby.socketToken?.isNotEmpty ?? false)) {
        await connectSocket(
          partyId: lobby.partyId,
          socketToken: lobby.socketToken!,
        );
      }
      return lobby;
    } catch (e) {
      state = state.copyWith(
        isSubmittingInvite: false,
        inviteError: e.toString(),
      );
      return null;
    }
  }

  /// Connects to the real-time Watch Party Socket.IO room.
  Future<void> connectSocket({
    required String partyId,
    required String socketToken,
  }) async {
    if (partyId.trim().isEmpty || socketToken.trim().isEmpty) return;
    _subscribeSocketStreams();
    state = state.copyWith(
      party: state.party.copyWith(
        partyId: partyId.trim(),
        socketToken: socketToken.trim(),
      ),
    );
    try {
      await ref
          .read(partiesRepositoryProvider)
          .connectWatchParty(partyId: partyId, socketToken: socketToken);
    } catch (_) {}
  }

  /// Disconnects from the Watch Party Socket.IO room.
  void disconnectSocket() {
    try {
      ref.read(partiesRepositoryProvider).disconnectWatchParty();
    } catch (_) {}
  }

  /// Resets the watch party state and disconnects the socket after a premiere ends.
  void resetPartySession() {
    disconnectSocket();
    state = WatchPartyState(
      party: const WatchParty(
        partyId: '',
        hostName: 'Host',
        filmId: '',
        status: 'not_created',
        totalPasses: 2,
        guests: [],
      ),
      quickMessages: state.quickMessages ?? _defaultQuickMessages,
    );
  }

  Future<void> _loadQuickMessages() async {
    try {
      final messages = await ref.read(getQuickMessagesProvider)();
      if (messages.messages.isNotEmpty || messages.reactions.isNotEmpty) {
        state = state.copyWith(quickMessages: messages);
      }
    } catch (_) {
      state = state.copyWith(quickMessages: _defaultQuickMessages);
    }
  }

  /// Sends a magic link invite to a guest via `POST /api/parties/invites`.
  Future<void> inviteGuest({
    required String name,
    required String email,
    String? ticketId,
  }) async {
    if (name.trim().isEmpty) {
      state = state.copyWith(
        inviteError: 'Please enter the guest name.',
        inviteSuccess: false,
      );
      return;
    }
    if (email.trim().isEmpty || !email.contains('@')) {
      state = state.copyWith(
        inviteError: 'Please enter a valid email address.',
        inviteSuccess: false,
      );
      return;
    }
    if (!state.party.hasPassesRemaining) {
      state = state.copyWith(
        inviteError:
            'Maximum invites reached for this ticket (${state.party.totalPasses}/${state.party.totalPasses} passes used).',
        inviteSuccess: false,
      );
      return;
    }

    state = state.copyWith(isSubmittingInvite: true, inviteError: null);

    if (ticketId != null && ticketId.trim().isNotEmpty) {
      try {
        final repo = ref.read(partiesRepositoryProvider);
        final updated = await repo.sendInvites(
          ticketId: ticketId.trim(),
          guests: [(name: name.trim(), email: email.trim())],
        );
        state = state.copyWith(
          party: state.party.copyWith(
            partyId: updated.partyId.isNotEmpty
                ? updated.partyId
                : state.party.partyId,
            filmId: updated.filmId.isNotEmpty
                ? updated.filmId
                : state.party.filmId,
            status: updated.status,
            isHost: updated.isHost,
            hostOnline: updated.hostOnline,
            totalPasses: updated.totalPasses,
            remainingSlots: updated.remainingSlots,
            guests: updated.guests,
            socketToken: updated.socketToken ?? state.party.socketToken,
          ),
          isSubmittingInvite: false,
          inviteSuccess: true,
          inviteError: null,
        );
        if (updated.partyId.isNotEmpty &&
            (updated.socketToken?.isNotEmpty ?? false)) {
          await connectSocket(
            partyId: updated.partyId,
            socketToken: updated.socketToken!,
          );
        }
        return;
      } catch (e) {
        state = state.copyWith(
          isSubmittingInvite: false,
          inviteSuccess: false,
          inviteError: e.toString(),
        );
        return;
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 600));

    final newGuest = PartyGuest(
      name: name.trim(),
      email: email.trim(),
      status: PartyGuestStatus.sent,
      invitedAt: DateTime.now(),
    );

    final updatedGuests = [...state.party.guests, newGuest];
    final updatedParty = state.party.copyWith(guests: updatedGuests);

    state = state.copyWith(
      party: updatedParty,
      isSubmittingInvite: false,
      inviteSuccess: true,
      inviteError: null,
    );
  }

  /// Removes an invited guest via `DELETE /api/parties/:partyId/invites` and frees the slot.
  Future<void> removeGuestInvite(String email) async {
    final targetEmail = email.trim().toLowerCase();
    if (targetEmail.isEmpty) return;

    final previousGuests = state.party.guests;
    final filtered = previousGuests
        .where((g) => g.email.trim().toLowerCase() != targetEmail)
        .toList();
    final nextRemaining = state.party.remainingSlots != null
        ? state.party.remainingSlots! + 1
        : null;

    state = state.copyWith(
      party: state.party.copyWith(
        guests: filtered,
        remainingSlots: nextRemaining,
      ),
      actionFeedbackMessage: 'Removed $email and freed guest pass slot.',
    );

    final partyId = state.party.partyId;
    if (partyId.isNotEmpty) {
      try {
        final updated = await ref
            .read(partiesRepositoryProvider)
            .removeInvite(partyId: partyId, email: targetEmail);
        if (updated != null) {
          state = state.copyWith(
            party: state.party.copyWith(
              guests: updated.guests,
              remainingSlots: updated.remainingSlots,
            ),
          );
        }
      } catch (_) {
        // Optimistic deletion stands if offline or in isolated tests.
      }
    }
  }

  /// Resends an invite link via `POST /api/parties/:partyId/invites/resend`.
  Future<void> resendGuestInvite(String email) async {
    final targetEmail = email.trim().toLowerCase();
    if (targetEmail.isEmpty) return;

    final partyId = state.party.partyId;
    if (partyId.isNotEmpty) {
      try {
        await ref
            .read(partiesRepositoryProvider)
            .resendInvite(partyId: partyId, email: targetEmail);
      } catch (_) {}
    }

    state = state.copyWith(
      inviteSuccess: true,
      actionFeedbackMessage: 'Magic link resent to $email!',
    );
  }

  void clearInviteStatus() {
    state = state.copyWith(
      inviteSuccess: false,
      inviteError: null,
      actionFeedbackMessage: null,
    );
  }

  /// Emits `sendQuickMessage` via Socket.IO and spawns a transient floating
  /// message that hovers upward over the movie and fades away.
  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _lastLocallySentMessage = trimmed;
    _lastLocallySentMessageAt = DateTime.now();

    try {
      ref.read(partiesRepositoryProvider).sendQuickMessage(trimmed);
    } catch (_) {}

    _spawnFloatingMessage(trimmed);
  }

  /// Broadcasts the host's current playback time and play/pause state to the
  /// watch party room so guests follow the host's exact playback position and pause state.
  void broadcastHostPlaybackState({
    required double currentTimeSeconds,
    required bool isPaused,
    String action = 'sync',
  }) {
    try {
      ref
          .read(partiesRepositoryProvider)
          .emitHostPlaybackState(
            currentTimeSeconds: currentTimeSeconds,
            isPaused: isPaused,
            action: action,
          );
    } catch (_) {}
  }

  void _spawnFloatingMessage(String text) {
    final now = DateTime.now();
    final randomOffset = (now.microsecond % 65) / 100.0 + 0.12; // 0.12 .. 0.77

    final floating = FloatingMessage(
      id: 'msg-${now.microsecondsSinceEpoch}',
      text: text,
      xOffset: randomOffset,
      createdAt: now,
    );

    state = state.copyWith(activeMessages: [...state.activeMessages, floating]);

    _messageCleanupTimer?.cancel();
    _messageCleanupTimer = Timer(const Duration(seconds: 4), () {
      final cutoff = DateTime.now().subtract(const Duration(seconds: 4));
      final remaining = state.activeMessages
          .where((m) => m.createdAt.isAfter(cutoff))
          .toList();
      state = state.copyWith(activeMessages: remaining);
    });
  }

  /// Emits `sendReaction` via Socket.IO and triggers a floating emoji animation.
  void sendReaction(String emoji) {
    final trimmed = emoji.trim();
    if (trimmed.isEmpty) return;

    _lastLocallySentReaction = trimmed;
    _lastLocallySentReactionAt = DateTime.now();

    try {
      ref.read(partiesRepositoryProvider).sendReaction(trimmed);
    } catch (_) {}

    _spawnFloatingReaction(trimmed);
  }

  void _spawnFloatingReaction(String emoji) {
    final now = DateTime.now();
    final randomOffset = (now.microsecond % 80) / 100.0 + 0.1; // 0.1 .. 0.9

    final reaction = FloatingReaction(
      id: 'rx-${now.microsecondsSinceEpoch}',
      emoji: emoji,
      xOffset: randomOffset,
      createdAt: now,
    );

    state = state.copyWith(
      activeReactions: [...state.activeReactions, reaction],
    );

    _reactionCleanupTimer?.cancel();
    _reactionCleanupTimer = Timer(const Duration(seconds: 4), () {
      final cutoff = DateTime.now().subtract(const Duration(seconds: 4));
      final remaining = state.activeReactions
          .where((r) => r.createdAt.isAfter(cutoff))
          .toList();
      state = state.copyWith(activeReactions: remaining);
    });
  }

  /// Prompts or performs pause, decrementing the allowed 3 pauses.
  bool requestPause() {
    if (state.pausesRemaining <= 0) {
      return false;
    }
    state = state.copyWith(showPauseModal: true);
    return true;
  }

  void dismissPauseModal() {
    state = state.copyWith(showPauseModal: false);
  }

  void confirmPause() {
    final nextRemaining = state.pausesRemaining > 0
        ? state.pausesRemaining - 1
        : 0;
    state = state.copyWith(
      isPaused: true,
      pausesRemaining: nextRemaining,
      showPauseModal: false,
    );
  }

  void resume() {
    state = state.copyWith(isPaused: false);
  }

  void toggleScreenLock() {
    state = state.copyWith(isScreenLocked: !state.isScreenLocked);
  }

  /// Resyncs with backend timestamp and pause state via GET /parties/:partyId/sync.
  Future<void> pollSync({String? partyId}) async {
    final targetId = (partyId != null && partyId.trim().isNotEmpty)
        ? partyId.trim()
        : state.party.partyId;
    if (targetId.isEmpty) return;
    try {
      final sync = await ref
          .read(partiesRepositoryProvider)
          .getPartySyncState(targetId);
      state = state.copyWith(
        hostPlaybackSync: sync,
        isPaused: sync.isPaused,
        syncTimestamp: sync.currentTimeSeconds >= 0
            ? sync.currentTimeSeconds
            : state.syncTimestamp,
      );
    } catch (_) {
      // Keep local clock sync if endpoint is temporarily unreachable
    }
  }
}

final watchPartyNotifierProvider =
    NotifierProvider<WatchPartyNotifier, WatchPartyState>(
      WatchPartyNotifier.new,
    );
