import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/parties_repository.dart';
import '../domain/parties_use_cases.dart';
import '../domain/quick_messages.dart';

/// Bound to the data implementation in `lib/composition_root.dart`.
final partiesRepositoryProvider = Provider<PartiesRepository>(
  (ref) => throw UnimplementedError('partiesRepositoryProvider not overridden'),
);

final getQuickMessagesProvider =
    Provider((ref) => GetQuickMessages(ref.watch(partiesRepositoryProvider)));
final syncPartyStateProvider =
    Provider((ref) => SyncPartyState(ref.watch(partiesRepositoryProvider)));

/// Allowed chat strings and reactions.
final quickMessagesProvider = FutureProvider.autoDispose<QuickMessages>(
  (ref) => ref.watch(getQuickMessagesProvider)(),
);

/// Party playback position in seconds for a given party id. Invalidate (or
/// poll from the UI) to resync.
final partySyncProvider = FutureProvider.autoDispose.family<double, String>(
  (ref, partyId) => ref.watch(syncPartyStateProvider)(partyId),
);
