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
  TicketType _selectedType = TicketType.single;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchBreakdown());
  }

  void _fetchBreakdown() {
    ref
        .read(ticketPurchaseNotifierProvider.notifier)
        .loadPriceBreakdown(
          filmId: widget.film.id,
          ticketType: _selectedType,
          currency: widget.film.detectedCurrency,
        );
  }

  void _selectType(TicketType type) {
    if (_selectedType == type) return;
    setState(() => _selectedType = type);
    _fetchBreakdown();
  }

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
        if (context.mounted)
          context.pushReplacement(RoutePaths.paymentPending, extra: intent);
      }
    });

    final state = ref.watch(ticketPurchaseNotifierProvider);
    final film = widget.film;
    final price = film.ticketPriceNgn;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Get a ticket',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 96,
                    child: PosterImage(url: film.thumbnailUrl),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        film.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (film.premiereStart != null)
                        Text(
                          Formatters.premiereDate(film.premiereStart!),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _TicketTierOption(
              title: 'Single ticket',
              subtitle: '1 viewer • one premiere',
              selected: _selectedType == TicketType.single,
              onTap: () => _selectType(TicketType.single),
            ),
            const SizedBox(height: 10),
            _TicketTierOption(
              title: 'Watch Party • 2 Passes',
              subtitle: 'Host + 1 guest pass',
              selected: _selectedType == TicketType.bundle2,
              onTap: () => _selectType(TicketType.bundle2),
            ),
            const SizedBox(height: 10),
            _TicketTierOption(
              title: 'Watch Party • 4 Passes',
              subtitle: 'Host + 3 guest passes',
              selected: _selectedType == TicketType.bundle4,
              onTap: () => _selectType(TicketType.bundle4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (state.breakdown != null)
                        Text(
                          state.breakdown!.currency == 'USD'
                              ? '\$${state.breakdown!.grossAmount.toStringAsFixed(2)}'
                              : Formatters.naira(state.breakdown!.grossAmount),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      else if (price != null)
                        Text(
                          Formatters.naira(price * _selectedType.seats),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  if (state.breakdown != null) ...[
                    const Divider(color: AppColors.border, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Includes 7.5% VAT',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          state.breakdown!.currency == 'USD'
                              ? 'VAT: \$${state.breakdown!.vatAmount.toStringAsFixed(2)}'
                              : 'VAT: ${Formatters.naira(state.breakdown!.vatAmount)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
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
              Text(
                state.error!,
                style: const TextStyle(color: AppColors.primary),
              ),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: 'Continue to payment',
              isLoading: state.isSubmitting,
              onPressed: () => ref
                  .read(ticketPurchaseNotifierProvider.notifier)
                  .purchase(
                    filmId: film.id,
                    ticketType: _selectedType,
                    email: _email.text,
                    currency: film.detectedCurrency,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPayment(PaymentIntent intent) => openPaymentPage(intent);
}

class _TicketTierOption extends StatelessWidget {
  const _TicketTierOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the hosted checkout in the external browser.
Future<void> openPaymentPage(PaymentIntent intent) async {
  final uri = Uri.tryParse(intent.paymentUrl);
  if (uri == null || uri.scheme != 'https') return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
