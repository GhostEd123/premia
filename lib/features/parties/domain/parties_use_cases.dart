import 'parties_repository.dart';
import 'quick_messages.dart';

/// Loads the allowed quick-chat messages and reactions.
class GetQuickMessages {
  const GetQuickMessages(this._repository);
  final PartiesRepository _repository;

  Future<QuickMessages> call() => _repository.getQuickMessages();
}

/// Reads the shared party playback position (seconds).
class SyncPartyState {
  const SyncPartyState(this._repository);
  final PartiesRepository _repository;

  Future<double> call(String partyId) => _repository.getSyncTimestamp(partyId);
}
