import '../../../core/network/api_exception.dart';
import '../../../core/network/http_service.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/payment_intent.dart';
import '../domain/tickets_repository.dart';

/// Wire shape of the initiate-payment response.
class PaymentIntentDto {
  const PaymentIntentDto({required this.paymentUrl, required this.reference});

  factory PaymentIntentDto.fromJson(Map<String, dynamic> json) =>
      PaymentIntentDto(
        paymentUrl: JsonUtils.string(json, ['paymentUrl']),
        reference: JsonUtils.string(json, ['reference']),
      );

  final String paymentUrl;
  final String reference;

  PaymentIntent toEntity() =>
      PaymentIntent(paymentUrl: paymentUrl, reference: reference);
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
  }) async {
    final raw = await _http.post(
      '/tickets/initiate',
      body: {
        'filmId': filmId,
        'ticketType': ticketType.apiValue,
        'email': email,
      },
    );
    final dto = PaymentIntentDto.fromJson(JsonUtils.asMap(raw));
    if (dto.paymentUrl.isEmpty) {
      throw const ApiException(ApiException.unexpectedResponse);
    }
    return dto.toEntity();
  }
}
