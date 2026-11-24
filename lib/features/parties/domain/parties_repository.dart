import 'quick_messages.dart';

/// Contract for watch-party data and real-time Socket.IO messaging.
/// Implemented in `data/`.
abstract class PartiesRepository {
  /// GET /parties/quick-messages
  Future<QuickMessages> getQuickMessages();

  /// GET /parties/:partyId/sync — party playback position in seconds.
  Future<double> getSyncTimestamp(String partyId);

  /// Stream of incoming quick-chat message strings from `receiveQuickMessage`.
  Stream<String> get incomingQuickMessages;

  /// Stream of incoming emoji reactions from `receiveReaction`.
  Stream<String> get incomingReactions;

  /// Connects to the Watch Party Socket.IO server using [socketToken] and
  /// emits `joinParty` for [partyId].
  Future<void> connectWatchParty({
    required String partyId,
    required String socketToken,
  });

  /// Emits `sendQuickMessage` with `{ "text": text }`.
  void sendQuickMessage(String text);

  /// Emits `sendReaction` with `{ "emoji": emoji }`.
  void sendReaction(String emoji);

  /// Disconnects from the active Watch Party Socket.IO session.
  void disconnectWatchParty();
}
