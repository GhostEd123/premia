import 'quick_messages.dart';
import 'watch_party.dart';

/// Contract for watch-party data and real-time Socket.IO messaging.
/// Implemented in `data/`.
abstract class PartiesRepository {
  /// GET /parties/quick-messages
  Future<QuickMessages> getQuickMessages();

  /// GET /parties/:partyId/sync — party playback position and pause state.
  Future<PartyPlaybackSync> getPartySyncState(String partyId);

  /// GET /parties/:partyId/sync — party playback position in seconds.
  Future<double> getSyncTimestamp(String partyId);

  /// POST /parties/invites — host invites one or more guests.
  Future<WatchParty> sendInvites({
    required String ticketId,
    required List<({String name, String email})> guests,
  });

  /// DELETE /parties/:partyId/invites — removes an invited guest and frees slot.
  Future<WatchParty?> removeInvite({
    required String partyId,
    required String email,
  });

  /// POST /parties/:partyId/invites/resend — resends invite email to guest.
  Future<void> resendInvite({
    required String partyId,
    required String email,
  });

  /// POST /parties/join-lobby — guest enters wait lobby with inviteToken.
  Future<WatchParty> joinLobby({required String inviteToken});

  /// GET /parties/lobby — fetches current lobby state by ticketId or partyId.
  Future<WatchParty> getLobby({String? ticketId, String? partyId});

  /// Stream of incoming quick-chat message strings from `receiveQuickMessage`.
  Stream<String> get incomingQuickMessages;

  /// Stream of incoming emoji reactions from `receiveReaction`.
  Stream<String> get incomingReactions;

  /// Stream of real-time lobby state updates from `lobbyUpdated`.
  Stream<WatchParty> get lobbyUpdates;

  /// Stream of `partyStarted` events when the host starts the premiere.
  Stream<PartyStartedEvent> get partyStartedEvents;

  /// Stream of real-time host playback sync events (play, pause, seek, heartbeat).
  Stream<PartyPlaybackSync> get playbackSyncEvents;

  /// Connects to the Watch Party Socket.IO server using [socketToken] and
  /// emits `joinParty` for [partyId].
  Future<void> connectWatchParty({
    required String partyId,
    required String socketToken,
  });

  /// Emits `sendQuickMessage` with `{ "partyId": ..., "message": text, "text": text }`.
  void sendQuickMessage(String text);

  /// Emits `sendReaction` with `{ "partyId": ..., "reaction": emoji, "emoji": emoji }`.
  void sendReaction(String emoji);

  /// Broadcasts the host's current playback time and play/pause state to the room.
  void emitHostPlaybackState({
    required double currentTimeSeconds,
    required bool isPaused,
    String action = 'sync',
  });

  /// Disconnects from the active Watch Party Socket.IO session.
  void disconnectWatchParty();
}
