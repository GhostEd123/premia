import 'package:equatable/equatable.dart';

/// Ticket products accepted by `POST /tickets/initiate`.
enum TicketType {
  single('single', 1),
  bundle2('bundle_2', 2),
  bundle4('bundle_4', 4);

  const TicketType(this.apiValue, this.seats);

  final String apiValue;

  /// Total viewers covered (host + guests).
  final int seats;

  int get maxGuests => seats - 1;
}

/// Checkout details returned when a payment is initiated.
class PaymentIntent extends Equatable {
  const PaymentIntent({required this.paymentUrl, required this.reference});

  /// Hosted checkout page the app must send the user to.
  final String paymentUrl;
  final String reference;

  @override
  List<Object?> get props => [paymentUrl, reference];
}
