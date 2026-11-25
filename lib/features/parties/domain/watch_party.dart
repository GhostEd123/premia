import 'package:equatable/equatable.dart';

import '../../films/domain/film.dart';
import 'party_guest.dart';
import 'party_message.dart';

/// Active watch-party state synced from `/api/parties/*` and Socket.IO `lobbyUpdated`.
class WatchParty extends Equatable {
  const WatchParty({
    required this.partyId,
    required this.hostName,
    required this.filmId,
    this.status = 'not_created',
    this.isHost = true,
    this.hostOnline = true,
    this.totalPasses = 2,
    this.remainingSlots,
    this.guests = const [],
    this.messages = const [],
    this.socketToken,
    this.accessToken,
    this.film,
  });

  final String partyId;
  final String hostName;
  final String filmId;

  /// Party lifecycle status: `'not_created'`, `'waiting'`, or `'active'`.
  final String status;

  /// True when the current viewer is the ticket-holding host.
  final bool isHost;

  /// True when the host is currently connected to the watch party room.
  final bool hostOnline;

  /// Total passes including the host (`2` for `bundle_2`, `4` for `bundle_4`).
  final int totalPasses;

  /// Remaining guest invite slots reported by the server, if any.
  final int? remainingSlots;

  final List<PartyGuest> guests;
  final List<PartyMessage> messages;

  /// Fresh Socket.IO auth token returned by lobby/invite endpoints.
  final String? socketToken;

  /// Bearer access token returned when a guest calls `POST /parties/join-lobby`.
  final String? accessToken;

  /// Film details returned by `POST /parties/join-lobby`, if provided.
  final Film? film;

  /// Total passes used: starts at 1 (counting the host) and increases as the
  /// host sends guest invites, capped at [totalPasses].
  int get usedPasses => (1 + guests.length).clamp(1, totalPasses);

  /// True while the host can still send more guest passes (`usedPasses < totalPasses`).
  bool get hasPassesRemaining =>
      remainingSlots != null ? remainingSlots! > 0 : usedPasses < totalPasses;

  WatchParty copyWith({
    String? partyId,
    String? hostName,
    String? filmId,
    String? status,
    bool? isHost,
    bool? hostOnline,
    int? totalPasses,
    int? remainingSlots,
    List<PartyGuest>? guests,
    List<PartyMessage>? messages,
    String? socketToken,
    String? accessToken,
    Film? film,
  }) =>
      WatchParty(
        partyId: partyId ?? this.partyId,
        hostName: hostName ?? this.hostName,
        filmId: filmId ?? this.filmId,
        status: status ?? this.status,
        isHost: isHost ?? this.isHost,
        hostOnline: hostOnline ?? this.hostOnline,
        totalPasses: totalPasses ?? this.totalPasses,
        remainingSlots: remainingSlots ?? this.remainingSlots,
        guests: guests ?? this.guests,
        messages: messages ?? this.messages,
        socketToken: socketToken ?? this.socketToken,
        accessToken: accessToken ?? this.accessToken,
        film: film ?? this.film,
      );

  @override
  List<Object?> get props => [
        partyId,
        hostName,
        filmId,
        status,
        isHost,
        hostOnline,
        totalPasses,
        remainingSlots,
        guests,
        messages,
        socketToken,
        accessToken,
        film,
      ];
}

/// Payload emitted by Socket.IO `partyStarted` when the host starts the premiere.
class PartyStartedEvent extends Equatable {
  const PartyStartedEvent({
    required this.partyId,
    required this.filmId,
    required this.elapsedSeconds,
  });

  final String partyId;
  final String filmId;
  final int elapsedSeconds;

  @override
  List<Object?> get props => [partyId, filmId, elapsedSeconds];
}

/// Real-time playback state broadcast by the host over Socket.IO (`syncVideo` /
/// `syncTimestamp`) so guests stay synchronized with the host's current position,
/// play/pause state, and party lifecycle.
class PartyPlaybackSync extends Equatable {
  const PartyPlaybackSync({
    required this.currentTimeSeconds,
    required this.isPaused,
    required this.receivedAt,
    this.action = 'sync',
    this.isEnded = false,
  });

  /// Host's current movie position in seconds.
  final double currentTimeSeconds;

  /// True when the host has paused the movie (`action == 'pause'`).
  final bool isPaused;

  /// Action type (`'play'`, `'pause'`, `'seek'`, `'sync'`, `'ended'`).
  final String action;

  /// True when the host ended/left the party (`partyEnded`).
  final bool isEnded;

  /// Monotonic timestamp of when this sync update was received.
  final DateTime receivedAt;

  Duration get position =>
      Duration(milliseconds: (currentTimeSeconds * 1000).round());

  @override
  List<Object?> get props => [
        currentTimeSeconds,
        isPaused,
        action,
        isEnded,
        receivedAt,
      ];
}
