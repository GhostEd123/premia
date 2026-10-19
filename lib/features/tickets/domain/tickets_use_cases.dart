import 'payment_intent.dart';
import 'tickets_repository.dart';

/// Starts a TransactPay checkout for a film ticket.
class InitiateTicketPayment {
  const InitiateTicketPayment(this._repository);
  final TicketsRepository _repository;

  Future<PaymentIntent> call({
    required String filmId,
    required TicketType ticketType,
    required String email,
  }) =>
      _repository.initiatePayment(
        filmId: filmId,
        ticketType: ticketType,
        email: email,
      );
}
