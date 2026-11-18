import 'package:equatable/equatable.dart';

enum PartyGuestStatus {
  inLobby,
  sent;

  String get label => switch (this) {
        PartyGuestStatus.inLobby => 'In lobby',
        PartyGuestStatus.sent => 'Sent',
      };
}

/// A guest invited to a watch party.
class PartyGuest extends Equatable {
  const PartyGuest({
    required this.name,
    required this.email,
    this.status = PartyGuestStatus.sent,
    required this.invitedAt,
  });

  final String name;
  final String email;
  final PartyGuestStatus status;
  final DateTime invitedAt;

  PartyGuest copyWith({
    String? name,
    String? email,
    PartyGuestStatus? status,
    DateTime? invitedAt,
  }) =>
      PartyGuest(
        name: name ?? this.name,
        email: email ?? this.email,
        status: status ?? this.status,
        invitedAt: invitedAt ?? this.invitedAt,
      );

  @override
  List<Object?> get props => [name, email, status, invitedAt];
}
