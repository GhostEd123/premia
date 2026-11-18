import 'package:equatable/equatable.dart';

/// VAT-inclusive price breakdown returned by `GET /tickets/price-breakdown`.
class TicketPriceBreakdown extends Equatable {
  const TicketPriceBreakdown({
    required this.baseAmount,
    required this.vatAmount,
    required this.grossAmount,
    required this.currency,
  });

  /// Base price exclusive of VAT.
  final num baseAmount;

  /// 7.5% VAT component.
  final num vatAmount;

  /// Total payable gross amount (`baseAmount + vatAmount`).
  final num grossAmount;

  /// Currency code ('NGN' or 'USD').
  final String currency;

  @override
  List<Object?> get props => [baseAmount, vatAmount, grossAmount, currency];
}

