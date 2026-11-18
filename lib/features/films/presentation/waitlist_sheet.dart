import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common_widgets.dart';
import '../application/waitlist_notifier.dart';

/// "Join our Waitlist" bottom sheet shown when no premiere is active.
class WaitlistSheet extends ConsumerStatefulWidget {
  const WaitlistSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const WaitlistSheet(),
    );
  }

  @override
  ConsumerState<WaitlistSheet> createState() => _WaitlistSheetState();
}

class _WaitlistSheetState extends ConsumerState<WaitlistSheet> {
  final TextEditingController _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(waitlistNotifierProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHeader(),
          if (state.isSubmitted) ...[
            const Text(
              'You’re on the list',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              state.successMessage ?? 'We’ll notify you about future premieres.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            AppButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
          ] else ...[
            const Text(
              'Join our Waitlist',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter your email address or phone number to receive notifications for future premieres',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text('Email or Phone', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'xyz@gmail.com or +234...',
                errorText: state.emailError,
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                style: const TextStyle(color: AppColors.primary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: 'Submit',
              isLoading: state.isSubmitting,
              onPressed: () =>
                  ref.read(waitlistNotifierProvider.notifier).submit(_email.text),
            ),
          ],
        ],
      ),
    );
  }
}
