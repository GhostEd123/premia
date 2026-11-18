import 'payment_intent.dart';
import 'ticket_price_breakdown.dart';

/// Contract for ticket purchasing. Implemented in `data/`.
abstract class TicketsRepository {
  /// POST /tickets/initiate
  Future<PaymentIntent> initiatePayment({
    required String filmId,
    required TicketType ticketType,
    required String email,
    String? currency,
  });

  /// GET /tickets/price-breakdown
  Future<TicketPriceBreakdown> getPriceBreakdown({
    required String filmId,
    required TicketType ticketType,
    String? currency,
  });
}
