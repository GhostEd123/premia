import 'package:flutter_test/flutter_test.dart';
import 'package:premia/features/tickets/data/tickets_repository_impl.dart';

void main() {
  group('TicketPriceBreakdownDto & PaymentIntentDto', () {
    test('TicketPriceBreakdownDto parses 7.5% VAT breakdown', () {
      final json = {
        'baseAmount': 5000,
        'vatAmount': 375,
        'grossAmount': 5375,
        'currency': 'NGN',
      };

      final dto = TicketPriceBreakdownDto.fromJson(json);
      final entity = dto.toEntity();

      expect(entity.baseAmount, 5000);
      expect(entity.vatAmount, 375);
      expect(entity.grossAmount, 5375);
      expect(entity.currency, 'NGN');
    });

    test('PaymentIntentDto parses VAT, currency, amount, paymentUrl, and reference', () {
      final json = {
        'paymentUrl': 'https://checkout.transactpay.ai/pay',
        'reference': 'film_123__single__170000000',
        'currency': 'NGN',
        'amount': 5375,
        'vat': 375,
      };

      final dto = PaymentIntentDto.fromJson(json);
      final entity = dto.toEntity();

      expect(entity.paymentUrl, 'https://checkout.transactpay.ai/pay');
      expect(entity.reference, 'film_123__single__170000000');
      expect(entity.currency, 'NGN');
      expect(entity.grossAmount, 5375);
      expect(entity.vatAmount, 375);
    });
  });
}

