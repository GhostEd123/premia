import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/payment_intent.dart';
import 'checkout_screen.dart';

/// Shown after the user is sent to TransactPay. The ticket arrives by email
/// once the backend confirms payment; the user then opens that link.
class PaymentPendingScreen extends StatelessWidget {
  const PaymentPendingScreen({required this.intent, super.key});

  final PaymentIntent intent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.mark_email_unread_outlined, size: 72, color: AppColors.primary),
              const SizedBox(height: 24),
              const Text(
                'Complete your payment',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Finish paying in your browser. Once the payment is confirmed we’ll '
                'email you a ticket link. Open that link here to start the premiere.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                'Ref: ${intent.reference}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const Spacer(),
              AppButton(
                label: 'I have my ticket link',
                onPressed: () => context.go(RoutePaths.enterLink),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Reopen payment page',
                style: AppButtonStyle.outline,
                onPressed: () => openPaymentPage(intent),
              ),
              TextButton(
                onPressed: () => context.go(RoutePaths.marquee),
                child: const Text('Back to Marquee', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
