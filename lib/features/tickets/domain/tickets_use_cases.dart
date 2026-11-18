import 'payment_intent.dart';
import 'ticket_price_breakdown.dart';
import 'tickets_repository.dart';

/// Starts a TransactPay checkout for a film ticket.
class InitiateTicketPayment {
  const InitiateTicketPayment(this._repository);
  final TicketsRepository _repository;

  Future<PaymentIntent> call({
    required String filmId,
    required TicketType ticketType,
    required String email,
    String? currency,
  }) =>
      _repository.initiatePayment(
        filmId: filmId,
        ticketType: ticketType,
        email: email,
        currency: currency,
      );
}

/// Retrieves the VAT-inclusive price breakdown.
class GetPriceBreakdown {
  const GetPriceBreakdown(this._repository);
  final TicketsRepository _repository;

  Future<TicketPriceBreakdown> call({
    required String filmId,
    required TicketType ticketType,
    String? currency,
  }) =>
      _repository.getPriceBreakdown(
        filmId: filmId,
        ticketType: ticketType,
        currency: currency,
      );
}
