import 'package:equatable/equatable.dart';

import 'party_guest.dart';
import 'party_message.dart';

/// Active watch-party state.
class WatchParty extends Equatable {
  const WatchParty({
    required this.partyId,
    required this.hostName,
    required this.filmId,
    this.totalPasses = 4,
    this.guests = const [],
    this.messages = const [],
  });

  final String partyId;
  final String hostName;
  final String filmId;
  final int totalPasses;
  final List<PartyGuest> guests;
  final List<PartyMessage> messages;

  int get usedPasses => guests.length;
  bool get hasPassesRemaining => usedPasses < totalPasses;

  WatchParty copyWith({
    String? partyId,
    String? hostName,
    String? filmId,
    int? totalPasses,
    List<PartyGuest>? guests,
    List<PartyMessage>? messages,
  }) =>
      WatchParty(
        partyId: partyId ?? this.partyId,
        hostName: hostName ?? this.hostName,
        filmId: filmId ?? this.filmId,
        totalPasses: totalPasses ?? this.totalPasses,
        guests: guests ?? this.guests,
        messages: messages ?? this.messages,
      );

  @override
  List<Object?> get props => [
        partyId,
        hostName,
        filmId,
        totalPasses,
        guests,
        messages,
      ];
}
