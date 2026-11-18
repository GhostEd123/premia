import '../../../core/network/api_exception.dart';
import '../../../core/network/http_service.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/payment_intent.dart';
import '../domain/ticket_price_breakdown.dart';
import '../domain/tickets_repository.dart';

/// Wire shape of the initiate-payment response.
class PaymentIntentDto {
  const PaymentIntentDto({
    required this.paymentUrl,
    required this.reference,
    this.currency,
    this.grossAmount,
    this.vatAmount,
  });

  factory PaymentIntentDto.fromJson(Map<String, dynamic> json) =>
      PaymentIntentDto(
        paymentUrl: JsonUtils.string(json, ['paymentUrl']),
        reference: JsonUtils.string(json, ['reference']),
        currency: JsonUtils.stringOrNull(json, ['currency']),
        grossAmount: JsonUtils.numberOrNull(json, ['amount', 'grossAmount']),
        vatAmount: JsonUtils.numberOrNull(json, ['vat', 'vatAmount']),
      );

  final String paymentUrl;
  final String reference;
  final String? currency;
  final num? grossAmount;
  final num? vatAmount;

  PaymentIntent toEntity() => PaymentIntent(
        paymentUrl: paymentUrl,
        reference: reference,
        currency: currency,
        grossAmount: grossAmount,
        vatAmount: vatAmount,
      );
}

/// Wire shape of the price-breakdown response.
class TicketPriceBreakdownDto {
  const TicketPriceBreakdownDto({
    required this.baseAmount,
    required this.vatAmount,
    required this.grossAmount,
    required this.currency,
  });

  factory TicketPriceBreakdownDto.fromJson(Map<String, dynamic> json) =>
      TicketPriceBreakdownDto(
        baseAmount: JsonUtils.number(json, ['baseAmount']),
        vatAmount: JsonUtils.number(json, ['vatAmount']),
        grossAmount: JsonUtils.number(json, ['grossAmount']),
        currency: JsonUtils.string(json, ['currency'], fallback: 'NGN'),
      );

  final num baseAmount;
  final num vatAmount;
  final num grossAmount;
  final String currency;

  TicketPriceBreakdown toEntity() => TicketPriceBreakdown(
        baseAmount: baseAmount,
        vatAmount: vatAmount,
        grossAmount: grossAmount,
        currency: currency,
      );
}

/// HTTP implementation of [TicketsRepository].
class TicketsRepositoryImpl implements TicketsRepository {
  TicketsRepositoryImpl(this._http);
  final HttpService _http;

  @override
  Future<PaymentIntent> initiatePayment({
    required String filmId,
    required TicketType ticketType,
    required String email,
    String? currency,
  }) async {
    final raw = await _http.post(
      '/tickets/initiate',
      body: {
        'filmId': filmId,
        'ticketType': ticketType.apiValue,
        'email': email.trim().toLowerCase(),
        if (currency != null && currency.isNotEmpty) 'currency': currency,
      },
    );
    final dto = PaymentIntentDto.fromJson(JsonUtils.asMap(raw));
    if (dto.paymentUrl.isEmpty) {
      throw const ApiException(ApiException.unexpectedResponse);
    }
    return dto.toEntity();
  }

  @override
  Future<TicketPriceBreakdown> getPriceBreakdown({
    required String filmId,
    required TicketType ticketType,
    String? currency,
  }) async {
    final raw = await _http.get(
      '/tickets/price-breakdown',
      query: {
        'filmId': filmId,
        'ticketType': ticketType.apiValue,
        if (currency != null && currency.isNotEmpty) 'currency': currency,
      },
    );
    return TicketPriceBreakdownDto.fromJson(JsonUtils.asMap(raw)).toEntity();
  }
}
