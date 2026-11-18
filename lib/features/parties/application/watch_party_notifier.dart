import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/party_guest.dart';
import '../domain/party_message.dart';
import '../domain/quick_messages.dart';
import '../domain/watch_party.dart';
import 'parties_providers.dart';

const Object _keep = Object();

/// An animated emoji reaction floating over the video player.
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
    bool? showPauseModal,
  }) =>
      WatchPartyState(
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
        inviteError:
            inviteError == _keep ? this.inviteError : inviteError as String?,
        activeReactions: activeReactions ?? this.activeReactions,
        showPauseModal: showPauseModal ?? this.showPauseModal,
      );
}

class WatchPartyNotifier extends Notifier<WatchPartyState> {
  Timer? _reactionCleanupTimer;
  Timer? _syncTimer;

  @override
  WatchPartyState build() {
    ref.onDispose(() {
      _reactionCleanupTimer?.cancel();
      _syncTimer?.cancel();
    });

    // Seed initial mock watch party matching the design
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
      messages: [
        PartyMessage(
          id: 'sys-1',
          senderName: 'System',
          text: 'JORDAN JOINED THE LOBBY',
          timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
          isSystem: true,
        ),
        PartyMessage(
          id: 'msg-1',
          senderName: 'Collins - Host',
          text: 'Doors open in two minutes. Get comfortable.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
          isHost: true,
          isAnnouncement: true,
        ),
        PartyMessage(
          id: 'msg-2',
          senderName: 'Sam Ortiz',
          text: 'Did anyone watch the trailer? No spoilers',
          timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
          isHost: false,
        ),
      ],
    );

    // Fetch quick messages in background
    Future.microtask(_loadQuickMessages);

    return WatchPartyState(party: initialParty);
  }

  Future<void> _loadQuickMessages() async {
    try {
      final messages = await ref.read(getQuickMessagesProvider)();
      state = state.copyWith(quickMessages: messages);
    } catch (_) {
      // Fallback defaults if offline
      state = state.copyWith(
        quickMessages: const QuickMessages(
          messages: [
            'This is so good',
            'No way!',
            'Did you catch that?',
            'Brb',
            'Can’t hear audio',
          ],
          reactions: ['😂', '😱', '🔥', '👏', '❤️', '🤯'],
        ),
      );
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

  /// Posts a chat message or host announcement to the party feed.
  void sendMessage(String text, {bool isAnnouncement = false}) {
    if (text.trim().isEmpty) return;
    final message = PartyMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      senderName: state.party.hostName,
      text: text.trim(),
      timestamp: DateTime.now(),
      isHost: true,
      isAnnouncement: isAnnouncement,
    );

    final updatedMessages = [...state.party.messages, message];
    state = state.copyWith(
      party: state.party.copyWith(messages: updatedMessages),
    );
  }

  /// Broadcasts an emoji reaction and triggers a floating animation on screen.
  void sendReaction(String emoji) {
    final now = DateTime.now();
    final randomOffset = (now.millisecond % 80) / 100.0 + 0.1; // 0.1 .. 0.9

    final reaction = FloatingReaction(
      id: '${now.microsecondsSinceEpoch}',
      emoji: emoji,
      xOffset: randomOffset,
      createdAt: now,
    );

    final updated = [...state.activeReactions, reaction];
    state = state.copyWith(activeReactions: updated);

    _reactionCleanupTimer?.cancel();
    _reactionCleanupTimer = Timer(const Duration(seconds: 4), () {
      final cutoff = DateTime.now().subtract(const Duration(seconds: 4));
      final remaining =
          state.activeReactions.where((r) => r.createdAt.isAfter(cutoff)).toList();
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
    final nextRemaining =
        state.pausesRemaining > 0 ? state.pausesRemaining - 1 : 0;
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
      final ts =
          await ref.read(partiesRepositoryProvider).getSyncTimestamp(state.party.partyId);
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
