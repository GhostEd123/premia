import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../application/auth_notifier.dart';

/// Lets a ticket holder open their emailed magic link. Accepts either a
/// pasted link / token or a deep link (`/auth/verify?token=...`), in which
/// case [initialToken] is verified automatically.
class EnterLinkScreen extends ConsumerStatefulWidget {
  const EnterLinkScreen({this.initialToken, super.key});

  final String? initialToken;

  @override
  ConsumerState<EnterLinkScreen> createState() => _EnterLinkScreenState();
}

class _EnterLinkScreenState extends ConsumerState<EnterLinkScreen> {
  final TextEditingController _input = TextEditingController();
  String? _inputError;

  @override
  void initState() {
    super.initState();
    final token = widget.initialToken;
    if (token != null && token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(authNotifierProvider.notifier).verifyMagicLink(token);
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    final token = Validators.magicLinkToken(_input.text);
    setState(
      () => _inputError = token == null
          ? 'Paste the link from your email.'
          : null,
    );
    if (token != null) {
      ref.read(authNotifierProvider.notifier).verifyMagicLink(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider, (prev, next) {
      if (next.isAuthenticated && prev?.isAuthenticated != true) {
        context.go(RoutePaths.marquee);
      }
    });
    final auth = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Open your ticket link',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste the link from your ticket email to unlock your premiere.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _input,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'https://…',
                errorText: _inputError,
              ),
            ),
            if (auth.error != null) ...[
              const SizedBox(height: 12),
              Text(
                auth.error!,
                style: const TextStyle(color: AppColors.primary),
              ),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: 'Verify',
              isLoading: auth.isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => _showResendModal(context),
                child: const Text(
                  'Didn’t receive your ticket link? Resend',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Links expire after 10 minutes and work once.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  void _showResendModal(BuildContext context) {
    final emailCtrl = TextEditingController();
    final filmIdCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final authState = ref.watch(authNotifierProvider);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Resend Ticket Link',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your purchase email and film ID to get a fresh access link.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Email used during purchase',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: filmIdCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Film ID (optional if now-showing)',
                  ),
                ),
                if (authState.resendSuccessMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    authState.resendSuccessMessage!,
                    style: const TextStyle(color: Colors.green, fontSize: 13),
                  ),
                ],
                if (authState.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    authState.error!,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                AppButton(
                  label: 'Send Fresh Link',
                  isLoading: authState.isResending,
                  onPressed: () {
                    if (emailCtrl.text.trim().isNotEmpty) {
                      ref
                          .read(authNotifierProvider.notifier)
                          .resendMagicLink(
                            email: emailCtrl.text.trim(),
                            filmId: filmIdCtrl.text.trim(),
                          );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
