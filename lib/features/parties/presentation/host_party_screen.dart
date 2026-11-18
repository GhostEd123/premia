import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../application/watch_party_notifier.dart';
import '../domain/party_guest.dart';

/// Screen allowing the host to invite friends and manage their guest passes.
class HostPartyScreen extends ConsumerStatefulWidget {
  const HostPartyScreen({super.key});

  @override
  ConsumerState<HostPartyScreen> createState() => _HostPartyScreenState();
}

class _HostPartyScreenState extends ConsumerState<HostPartyScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submitInvite() {
    ref.read(watchPartyNotifierProvider.notifier).inviteGuest(
          name: _nameController.text,
          email: _emailController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final partyState = ref.watch(watchPartyNotifierProvider);
    final party = partyState.party;

    ref.listen(watchPartyNotifierProvider, (prev, next) {
      if (next.inviteSuccess && prev?.inviteSuccess != true) {
        _nameController.clear();
        _emailController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surfaceHigh,
            content: Text('Magic link sent to guest!'),
            duration: Duration(seconds: 2),
          ),
        );
        ref.read(watchPartyNotifierProvider.notifier).clearInviteStatus();
      }
      if (next.inviteError != null && next.inviteError != prev?.inviteError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(next.inviteError!),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            const Text(
              'Host party',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Each guest gets their own secure Magic Link.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            // --- Form Inputs ---
            const Text(
              'Guest Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'John Doe',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Email',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'xyz@gmail.com',
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Send Magic Link',
              isLoading: partyState.isSubmittingInvite,
              onPressed: party.hasPassesRemaining ? _submitInvite : null,
            ),
            const SizedBox(height: 32),
            // --- Guest List ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Guest list',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${party.usedPasses}/${party.totalPasses}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (party.guests.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No guests invited yet. Add your friends above!',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else
              ...party.guests.map((g) => _GuestCard(guest: g)),
          ],
        ),
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.guest});

  final PartyGuest guest;

  @override
  Widget build(BuildContext context) {
    final isInLobby = guest.status == PartyGuestStatus.inLobby;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusControl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guest.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  guest.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isInLobby
                  ? const Color(0xFF332A00)
                  : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isInLobby
                    ? const Color(0xFFF59E0B)
                    : AppColors.border,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isInLobby
                        ? const Color(0xFFF59E0B)
                        : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  guest.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isInLobby
                        ? const Color(0xFFF59E0B)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
