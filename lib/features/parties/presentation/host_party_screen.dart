import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/application/auth_notifier.dart';
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
  OverlayEntry? _toastEntry;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(authNotifierProvider).magicLinkSession;
      if (session != null) {
        ref.read(watchPartyNotifierProvider.notifier).configureForTicket(
              ticketType: session.ticketType,
              filmId: session.filmId,
            );
        ref.read(watchPartyNotifierProvider.notifier).fetchLobby(
              ticketId: session.claimedTicketId,
              partyId: session.partyId,
            );
      }
    });
  }

  @override
  void dispose() {
    _removeTopToast();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _removeTopToast() {
    _toastTimer?.cancel();
    _toastTimer = null;
    _toastEntry?.remove();
    _toastEntry = null;
  }

  void _showTopToast({
    required String message,
    IconData icon = Icons.check_circle_rounded,
    Color backgroundColor = AppColors.primary,
    Color foregroundColor = Colors.black,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    _removeTopToast();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (ctx) => _TopToastBanner(
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        onDismiss: _removeTopToast,
      ),
    );
    _toastEntry = entry;
    overlay.insert(entry);
    _toastTimer = Timer(duration, _removeTopToast);
  }

  void _submitInvite() {
    final ticketId =
        ref.read(authNotifierProvider).magicLinkSession?.claimedTicketId;
    ref.read(watchPartyNotifierProvider.notifier).inviteGuest(
          name: _nameController.text,
          email: _emailController.text,
          ticketId: ticketId,
        );
  }

  void _showMaxInvitesReachedSnackbar(int totalPasses) {
    _showTopToast(
      message:
          'Maximum invites reached for this ticket ($totalPasses/$totalPasses passes used).',
      icon: Icons.info_outline_rounded,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
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
        final feedback =
            next.actionFeedbackMessage ?? 'Magic link sent to guest!';
        _showTopToast(
          message: feedback,
          icon: Icons.mark_email_read_rounded,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
        );
        ref.read(watchPartyNotifierProvider.notifier).clearInviteStatus();
      } else if (next.actionFeedbackMessage != null &&
          next.actionFeedbackMessage != prev?.actionFeedbackMessage) {
        _showTopToast(
          message: next.actionFeedbackMessage!,
          icon: Icons.check_circle_outline_rounded,
          backgroundColor: AppColors.surfaceHigh,
          foregroundColor: Colors.white,
        );
        ref.read(watchPartyNotifierProvider.notifier).clearInviteStatus();
      }
      if (next.inviteError != null && next.inviteError != prev?.inviteError) {
        _showTopToast(
          message: next.inviteError!,
          icon: Icons.error_outline_rounded,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          duration: const Duration(seconds: 3),
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
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: party.hasPassesRemaining
                  ? null
                  : () => _showMaxInvitesReachedSnackbar(party.totalPasses),
              child: IgnorePointer(
                ignoring: !party.hasPassesRemaining,
                child: AppButton(
                  label: 'Send Magic Link',
                  isLoading: partyState.isSubmittingInvite,
                  onPressed: party.hasPassesRemaining ? _submitInvite : null,
                ),
              ),
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
                _GuestPassRing(
                  used: party.usedPasses,
                  total: party.totalPasses,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  children: [
                    for (int i = 0; i < party.guests.length; i++) ...[
                      if (i > 0)
                        const Divider(color: AppColors.border, height: 1),
                      _SwipeableGuestCard(
                        key: ValueKey(party.guests[i].email),
                        guest: party.guests[i],
                        onResend: () => ref
                            .read(watchPartyNotifierProvider.notifier)
                            .resendGuestInvite(party.guests[i].email),
                        onDelete: () => ref
                            .read(watchPartyNotifierProvider.notifier)
                            .removeGuestInvite(party.guests[i].email),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GuestPassRing extends StatelessWidget {
  const _GuestPassRing({required this.used, required this.total});

  final int used;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3.2,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
          RichText(
            text: TextSpan(
              text: '$used',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              children: [
                TextSpan(
                  text: '/$total',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
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

/// Guest row that slides left on horizontal swipe (or tap) to reveal
/// "Resend" and "Delete" action buttons.
class _SwipeableGuestCard extends StatefulWidget {
  const _SwipeableGuestCard({
    required this.guest,
    required this.onResend,
    required this.onDelete,
    super.key,
  });

  final PartyGuest guest;
  final VoidCallback onResend;
  final VoidCallback onDelete;

  @override
  State<_SwipeableGuestCard> createState() => _SwipeableGuestCardState();
}

class _SwipeableGuestCardState extends State<_SwipeableGuestCard> {
  static const double _maxSlide = 148.0;
  double _dragOffset = 0.0;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset - details.delta.dx).clamp(0.0, _maxSlide);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    setState(() {
      if (velocity < -200 || _dragOffset > _maxSlide * 0.4) {
        _dragOffset = _maxSlide;
      } else {
        _dragOffset = 0.0;
      }
    });
  }

  void _toggleSlide() {
    setState(() {
      _dragOffset = _dragOffset > 10 ? 0.0 : _maxSlide;
    });
  }

  @override
  Widget build(BuildContext context) {
    final guest = widget.guest;
    final isInLobby = guest.status == PartyGuestStatus.inLobby;

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        // --- Underlying Action Buttons (Revealed when swiped left) ---
        Positioned.fill(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _SlideActionButton(
                icon: Icons.send_outlined,
                label: 'Resend',
                backgroundColor: AppColors.surfaceHigh,
                foregroundColor: Colors.white,
                onTap: () {
                  setState(() => _dragOffset = 0.0);
                  widget.onResend();
                },
              ),
              const SizedBox(width: 6),
              _SlideActionButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                onTap: () {
                  setState(() => _dragOffset = 0.0);
                  widget.onDelete();
                },
              ),
            ],
          ),
        ),
        // --- Foreground Guest Row ---
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleSlide,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(-_dragOffset, 0, 0),
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 14),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isInLobby
                        ? const Color(0xFF4A3700)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isInLobby
                          ? const Color(0xFF4A3700)
                          : AppColors.border,
                      width: 0.9,
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
                              ? const Color(0xFFF5B800)
                              : Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        guest.status.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isInLobby
                              ? const Color(0xFFF5B800)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SlideActionButton extends StatelessWidget {
  const _SlideActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 68,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: foregroundColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopToastBanner extends StatefulWidget {
  const _TopToastBanner({
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onDismiss,
  });

  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onDismiss;

  @override
  State<_TopToastBanner> createState() => _TopToastBannerState();
}

class _TopToastBannerState extends State<_TopToastBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.45),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: topPadding + 14,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.foregroundColor.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        size: 18,
                        color: widget.foregroundColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: widget.foregroundColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: widget.foregroundColor.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
