import 'payment_intent.dart';

/// Contract for ticket purchasing. Implemented in `data/`.
abstract class TicketsRepository {
  /// POST /tickets/initiate
  Future<PaymentIntent> initiatePayment({
    required String filmId,
    required TicketType ticketType,
    required String email,
  });
}
