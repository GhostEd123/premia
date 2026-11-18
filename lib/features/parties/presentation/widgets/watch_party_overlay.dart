import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/watch_party_notifier.dart';
import '../../domain/party_message.dart';

/// Interactive watch-party feed, avatar header, and reaction pills overlay.
class WatchPartyOverlay extends ConsumerWidget {
  const WatchPartyOverlay({
    this.isExpanded = true,
    this.onToggleExpand,
    super.key,
  });

  final bool isExpanded;
  final VoidCallback? onToggleExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partyState = ref.watch(watchPartyNotifierProvider);
    final party = partyState.party;
    final quick = partyState.quickMessages;
    final reactions = quick?.reactions.isNotEmpty == true
        ? quick!.reactions
        : const ['😂', '😱', '🔥', '👏', '❤️', '🤯'];
    final quickMessages = quick?.messages.isNotEmpty == true
        ? quick!.messages
        : const [
            'This is so good',
            'No way!',
            'Did you catch that?',
            'Brb',
            'Can’t hear audio',
          ];

    final hostAnnouncements = const [
      'Welcome guys',
      'Let’s start',
      'Taking a quick break',
      'Be back in 2 mins',
    ];

    return Stack(
      children: [
        // --- Floating Animated Reactions ---
        ...partyState.activeReactions.map((r) => _FloatingReactionItem(reaction: r)),

        // --- Party Live Chat & Control Panel ---
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Party Info Badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text(
                    '${party.hostName}’s Party • Host',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Participant Avatars
                  _AvatarBadge(label: 'MC', color: const Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  _AvatarBadge(label: 'SO', color: const Color(0xFFF97316)),
                  const Spacer(),
                  if (onToggleExpand != null)
                    IconButton(
                      icon: Icon(
                        isExpanded ? Icons.expand_more : Icons.chat_bubble_outline,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: onToggleExpand,
                    ),
                ],
              ),
            ),

            if (isExpanded) ...[
              // Live Feed Messages
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: party.messages.length,
                  itemBuilder: (context, index) {
                    final msg = party.messages[index];
                    return _MessageTile(message: msg);
                  },
                ),
              ),

              const SizedBox(height: 10),

              // Quick Reactions Row (Emojis)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Row(
                  children: [
                    const Text(
                      'Quick Reactions',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: reactions.map((emoji) {
                            return GestureDetector(
                              onTap: () => ref
                                  .read(watchPartyNotifierProvider.notifier)
                                  .sendReaction(emoji),
                              child: Container(
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Text(emoji, style: const TextStyle(fontSize: 18)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Host Announcements Horizontal Scroll
              SizedBox(
                height: 32,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: hostAnnouncements.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final text = hostAnnouncements[index];
                    return _ActionChip(
                      text: text,
                      isAnnouncement: true,
                      onTap: () => ref
                          .read(watchPartyNotifierProvider.notifier)
                          .sendMessage(text, isAnnouncement: true),
                    );
                  },
                ),
              ),

              const SizedBox(height: 6),

              // Quick Comments Horizontal Scroll
              SizedBox(
                height: 32,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: quickMessages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final text = quickMessages[index];
                    return _ActionChip(
                      text: text,
                      isAnnouncement: false,
                      onTap: () => ref
                          .read(watchPartyNotifierProvider.notifier)
                          .sendMessage(text),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ],
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});

  final PartyMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    final isAnnouncement = message.isAnnouncement;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isAnnouncement
                  ? AppColors.primary.withValues(alpha: 0.8)
                  : Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isAnnouncement
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isAnnouncement ? Colors.white : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  message.text,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
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

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.text,
    required this.onTap,
    this.isAnnouncement = false,
  });

  final String text;
  final VoidCallback onTap;
  final bool isAnnouncement;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isAnnouncement
              ? const Color(0xFF3B1214)
              : const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAnnouncement
                ? AppColors.primary.withValues(alpha: 0.6)
                : AppColors.border.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isAnnouncement ? const Color(0xFFFF8A8F) : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _FloatingReactionItem extends StatefulWidget {
  const _FloatingReactionItem({required this.reaction});

  final FloatingReaction reaction;

  @override
  State<_FloatingReactionItem> createState() => _FloatingReactionItemState();
}

class _FloatingReactionItemState extends State<_FloatingReactionItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final progress = _anim.value;
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        final bottom = progress * (screenHeight * 0.7);
        final left = widget.reaction.xOffset * (screenWidth - 40);
        final opacity = (1.0 - progress).clamp(0.0, 1.0);
        final scale = 1.0 + (progress * 0.5);

        return Positioned(
          bottom: bottom,
          left: left,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Text(
                widget.reaction.emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
        );
      },
    );
  }
}
