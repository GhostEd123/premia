import 'package:equatable/equatable.dart';

enum PartyGuestStatus {
  inLobby,
  sent;

  String get label => switch (this) {
        PartyGuestStatus.inLobby => 'In lobby',
        PartyGuestStatus.sent => 'Sent',
      };

  static PartyGuestStatus fromApi(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    if (normalized == 'in_lobby' || normalized == 'inlobby') {
      return PartyGuestStatus.inLobby;
    }
    return PartyGuestStatus.sent;
  }
}

/// A guest invited to a watch party.
class PartyGuest extends Equatable {
  const PartyGuest({
    required this.name,
    required this.email,
    this.status = PartyGuestStatus.sent,
    required this.invitedAt,
    this.joinedAt,
  });

  final String name;
  final String email;
  final PartyGuestStatus status;
  final DateTime invitedAt;
  final DateTime? joinedAt;

  PartyGuest copyWith({
    String? name,
    String? email,
    PartyGuestStatus? status,
    DateTime? invitedAt,
    DateTime? joinedAt,
  }) =>
      PartyGuest(
        name: name ?? this.name,
        email: email ?? this.email,
        status: status ?? this.status,
        invitedAt: invitedAt ?? this.invitedAt,
        joinedAt: joinedAt ?? this.joinedAt,
      );

  @override
  List<Object?> get props => [name, email, status, invitedAt, joinedAt];
}
