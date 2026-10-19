import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routing/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../films/domain/film.dart';
import '../application/ticket_purchase_notifier.dart';
import '../domain/payment_intent.dart';

/// Single-ticket checkout: collects the buyer's email and hands off to the
/// TransactPay hosted checkout. The ticket is issued by the backend only
/// after payment is confirmed via webhook; the app never marks it paid.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({required this.film, super.key});

  final Film film;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final TextEditingController _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ticketPurchaseNotifierProvider, (prev, next) async {
      final intent = next.intent;
      if (intent != null && prev?.intent != intent) {
        await _openPayment(intent);
        if (context.mounted) context.pushReplacement(RoutePaths.paymentPending, extra: intent);
      }
    });

    final state = ref.watch(ticketPurchaseNotifierProvider);
    final film = widget.film;
    final price = film.ticketPriceNgn;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Get a ticket'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 72, height: 96, child: PosterImage(url: film.thumbnailUrl)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(film.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      if (film.premiereStart != null)
                        Text(
                          Formatters.premiereDate(film.premiereStart!),
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Single ticket', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('1 viewer • one premiere', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  if (price != null)
                    Text(Formatters.naira(price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(hintText: 'xyz@gmail.com'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your ticket link will be sent to this email after payment.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(state.error!, style: const TextStyle(color: AppColors.primary)),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: 'Continue to payment',
              isLoading: state.isSubmitting,
              onPressed: () => ref.read(ticketPurchaseNotifierProvider.notifier).purchase(
                    filmId: film.id,
                    ticketType: TicketType.single,
                    email: _email.text,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPayment(PaymentIntent intent) => openPaymentPage(intent);
}

/// Opens the hosted checkout in the external browser.
Future<void> openPaymentPage(PaymentIntent intent) async {
  final uri = Uri.tryParse(intent.paymentUrl);
  if (uri == null || uri.scheme != 'https') return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
