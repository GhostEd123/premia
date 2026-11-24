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
      try {
        ref.read(partiesRepositoryProvider).disconnectWatchParty();
      } catch (_) {}
    });

    // Listen to incoming Socket.IO events if repository is overridden
    _subscribeSocketStreams();

    // Seed initial watch party guest list matching the lobby/host design
    final initialParty = WatchParty(
      partyId: 'party-collins-101',
      hostName: 'Collins',
      filmId: 'bts-reloaded',
      totalPasses: 4,
      guests: [
        PartyGuest(
          name: 'Joshua OG',
          email: 'josh@premiamail.com',
          status: PartyGuestStatus.inLobby,
          invitedAt: DateTime.now().subtract(const Duration(minutes: 25)),
        ),
        PartyGuest(
          name: 'Sam',
          email: 'sam@premiamail.com',
          status: PartyGuestStatus.inLobby,
          invitedAt: DateTime.now().subtract(const Duration(minutes: 15)),
        ),
        PartyGuest(
          name: 'Mirarosue',
          email: 'mira@premiamail.com',
          status: PartyGuestStatus.sent,
          invitedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ],
    );

    // Fetch quick messages from GET /api/parties/quick-messages in background
    Future.microtask(_loadQuickMessages);

    return WatchPartyState(
      party: initialParty,
      quickMessages: _defaultQuickMessages,
    );
  }

  void _subscribeSocketStreams() {
    try {
      final repo = ref.read(partiesRepositoryProvider);
      _incomingMsgSub?.cancel();
      _incomingReactionSub?.cancel();
      _incomingMsgSub = repo.incomingQuickMessages.listen(
        _spawnFloatingMessage,
      );
      _incomingReactionSub = repo.incomingReactions.listen(
        _spawnFloatingReaction,
      );
    } catch (_) {
      // Repository not overridden in isolated widget tests.
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
      party: state.party.copyWith(partyId: partyId.trim()),
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

  /// Sends a magic link invite to a guest.
  Future<void> inviteGuest({
    required String name,
    required String email,
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
        inviteError: 'All guest passes have already been issued.',
        inviteSuccess: false,
      );
      return;
    }

    state = state.copyWith(isSubmittingInvite: true, inviteError: null);
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

  void clearInviteStatus() {
    state = state.copyWith(inviteSuccess: false, inviteError: null);
  }

  /// Emits `sendQuickMessage` via Socket.IO and spawns a transient floating
  /// message that hovers upward over the movie and fades away.
  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    try {
      ref.read(partiesRepositoryProvider).sendQuickMessage(trimmed);
    } catch (_) {}

    _spawnFloatingMessage(trimmed);
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

  /// Resyncs with backend timestamp via GET /parties/:partyId/sync.
  Future<void> pollSync() async {
    try {
      final ts = await ref
          .read(partiesRepositoryProvider)
          .getSyncTimestamp(state.party.partyId);
      state = state.copyWith(syncTimestamp: ts);
    } catch (_) {
      // Keep local clock sync if endpoint is temporarily unreachable
    }
  }
}

final watchPartyNotifierProvider =
    NotifierProvider<WatchPartyNotifier, WatchPartyState>(
      WatchPartyNotifier.new,
    );
