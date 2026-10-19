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
    setState(() => _inputError = token == null ? 'Paste the link from your email.' : null);
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
            const Text('Open your ticket link', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
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
              decoration: InputDecoration(hintText: 'https://…', errorText: _inputError),
            ),
            if (auth.error != null) ...[
              const SizedBox(height: 12),
              Text(auth.error!, style: const TextStyle(color: AppColors.primary)),
            ],
            const SizedBox(height: 24),
            AppButton(label: 'Verify', isLoading: auth.isLoading, onPressed: _submit),
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
}
