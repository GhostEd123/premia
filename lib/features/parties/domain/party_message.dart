import 'package:equatable/equatable.dart';

/// A chat message or system alert in the watch-party live feed.
class PartyMessage extends Equatable {
  const PartyMessage({
    required this.id,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isHost = false,
    this.isSystem = false,
    this.isAnnouncement = false,
  });

  final String id;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isHost;
  final bool isSystem;
  final bool isAnnouncement;

  @override
  List<Object?> get props => [
        id,
        senderName,
        text,
        timestamp,
        isHost,
        isSystem,
        isAnnouncement,
      ];
}
