import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/watch_party_notifier.dart';

/// Full-screen non-interactive layer that renders transient quick messages and
/// emoji reactions floating upward over the movie and fading away slowly.
class WatchPartyFloatingLayer extends ConsumerWidget {
  const WatchPartyFloatingLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partyState = ref.watch(watchPartyNotifierProvider);

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final msg in partyState.activeMessages)
            _FloatingMessageItem(
              key: ValueKey(msg.id),
              message: msg,
            ),
          for (final reaction in partyState.activeReactions)
            _FloatingReactionItem(
              key: ValueKey(reaction.id),
              reaction: reaction,
            ),
        ],
      ),
    );
  }
}

/// Interactive Watch Party quick-reaction and predefined quick-message picker.
/// Sent and received messages/reactions are not stored in a list; they hover
/// upward over the movie and fade away via [WatchPartyFloatingLayer].
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
    final quick = partyState.quickMessages;
    final reactions = (quick?.reactions.isNotEmpty ?? false)
        ? quick!.reactions
        : const ['🥱', '😱', '😂', '❤️', '🍿'];
    final quickMessages = (quick?.messages.isNotEmpty ?? false)
        ? quick!.messages
        : const [
            'OMG!',
            'No way!',
            "I didn't see that coming...",
            'Lol',
            'This scene is intense',
            'Who is that?!',
            'I love this part',
            'Boring',
          ];

    if (!isExpanded) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.78),
            Colors.black.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + Close picker button
            Row(
              children: [
                const Text(
                  'Quick Reactions',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
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
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                if (onToggleExpand != null)
                  IconButton(
                    tooltip: 'Hide React & Chat',
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white70,
                      size: 22,
                    ),
                    onPressed: onToggleExpand,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Predefined Quick Messages Horizontal Scroll
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quickMessages.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final text = quickMessages[index];
                  return _QuickMessageChip(
                    text: text,
                    onTap: () => ref
                        .read(watchPartyNotifierProvider.notifier)
                        .sendMessage(text),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickMessageChip extends StatelessWidget {
  const _QuickMessageChip({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _FloatingMessageItem extends StatefulWidget {
  const _FloatingMessageItem({required this.message, super.key});

  final FloatingMessage message;

  @override
  State<_FloatingMessageItem> createState() => _FloatingMessageItemState();
}

class _FloatingMessageItemState extends State<_FloatingMessageItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
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
        final progress = Curves.easeOut.transform(_anim.value);
        final size = MediaQuery.of(context).size;
        final bottom = 72.0 + progress * (size.height * 0.58);
        final left = (widget.message.xOffset * (size.width - 220))
            .clamp(20.0, size.width - 220.0);
        // Fade in quickly, stay readable, then fade out slowly as it rises
        final opacity = _anim.value < 0.12
            ? (_anim.value / 0.12).clamp(0.0, 1.0)
            : (1.0 - ((_anim.value - 0.12) / 0.88)).clamp(0.0, 1.0);

        return Positioned(
          bottom: bottom,
          left: left,
          child: Opacity(
            opacity: opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.55),
                ),
              ),
              child: Text(
                widget.message.text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FloatingReactionItem extends StatefulWidget {
  const _FloatingReactionItem({required this.reaction, super.key});

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
      duration: const Duration(milliseconds: 3400),
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
        final progress = Curves.easeOut.transform(_anim.value);
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        final bottom = 72.0 + progress * (screenHeight * 0.62);
        final left = (widget.reaction.xOffset * (screenWidth - 48))
            .clamp(20.0, screenWidth - 48.0);
        final opacity = (1.0 - _anim.value).clamp(0.0, 1.0);
        final scale = 1.0 + (progress * 0.45);

        return Positioned(
          bottom: bottom,
          left: left,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Text(
                widget.reaction.emoji,
                style: const TextStyle(fontSize: 30),
              ),
            ),
          ),
        );
      },
    );
  }
}
