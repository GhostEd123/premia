import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../domain/payment_intent.dart';
import '../domain/ticket_price_breakdown.dart';
import '../domain/tickets_repository.dart';
import '../domain/tickets_use_cases.dart';

/// Bound to the data implementation in `lib/composition_root.dart`.
final ticketsRepositoryProvider = Provider<TicketsRepository>(
  (ref) => throw UnimplementedError('ticketsRepositoryProvider not overridden'),
);

final initiateTicketPaymentProvider = Provider(
  (ref) => InitiateTicketPayment(ref.watch(ticketsRepositoryProvider)),
);

final getPriceBreakdownProvider = Provider(
  (ref) => GetPriceBreakdown(ref.watch(ticketsRepositoryProvider)),
);

const Object _keep = Object();

class TicketPurchaseState {
  const TicketPurchaseState({
    this.isSubmitting = false,
    this.isLoadingBreakdown = false,
    this.breakdown,
    this.intent,
    this.error,
  });

  final bool isSubmitting;
  final bool isLoadingBreakdown;
  final TicketPriceBreakdown? breakdown;

  /// Set on success; the UI redirects the user to `intent.paymentUrl`.
  final PaymentIntent? intent;
  final String? error;

  TicketPurchaseState copyWith({
    bool? isSubmitting,
    bool? isLoadingBreakdown,
    Object? breakdown = _keep,
    Object? intent = _keep,
    Object? error = _keep,
  }) =>
      TicketPurchaseState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        isLoadingBreakdown: isLoadingBreakdown ?? this.isLoadingBreakdown,
        breakdown: breakdown == _keep
            ? this.breakdown
            : breakdown as TicketPriceBreakdown?,
        intent: intent == _keep ? this.intent : intent as PaymentIntent?,
        error: error == _keep ? this.error : error as String?,
      );
}

/// Per-visit checkout state. Mutates [state] only.
class TicketPurchaseNotifier extends Notifier<TicketPurchaseState> {
  @override
  TicketPurchaseState build() => const TicketPurchaseState();

  Future<void> loadPriceBreakdown({
    required String filmId,
    required TicketType ticketType,
    String? currency,
  }) async {
    state = state.copyWith(isLoadingBreakdown: true, error: null);
    try {
      final breakdown = await ref.read(getPriceBreakdownProvider)(
        filmId: filmId,
        ticketType: ticketType,
        currency: currency,
      );
      state = state.copyWith(
        isLoadingBreakdown: false,
        breakdown: breakdown,
      );
    } catch (_) {
      state = state.copyWith(isLoadingBreakdown: false);
    }
  }

  Future<void> purchase({
    required String filmId,
    required TicketType ticketType,
    required String email,
    String? currency,
  }) async {
    final trimmed = email.trim();
    if (!_emailPattern.hasMatch(trimmed)) {
      state = state.copyWith(error: 'Enter a valid email address.', intent: null);
      return;
    }
    state = state.copyWith(isSubmitting: true, error: null, intent: null);
    try {
      final intent = await ref.read(initiateTicketPaymentProvider)(
        filmId: filmId,
        ticketType: ticketType,
        email: trimmed,
        currency: currency,
      );
      state = state.copyWith(isSubmitting: false, intent: intent);
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.message);
    }
  }
}

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

final ticketPurchaseNotifierProvider = NotifierProvider.autoDispose<
    TicketPurchaseNotifier, TicketPurchaseState>(TicketPurchaseNotifier.new);
