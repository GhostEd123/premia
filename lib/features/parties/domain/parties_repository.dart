import 'quick_messages.dart';

/// Contract for watch-party data. Implemented in `data/`.
abstract class PartiesRepository {
  /// GET /parties/quick-messages
  Future<QuickMessages> getQuickMessages();

  /// GET /parties/:partyId/sync — party playback position in seconds.
  Future<double> getSyncTimestamp(String partyId);
}
