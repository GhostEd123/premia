import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../films/application/films_notifier.dart';
import '../../films/domain/film.dart';
import '../application/watch_party_notifier.dart';

/// The Lobby screen where ticket-holders wait, manage watch-party passes,
/// view house rules, and start the premiere when doors open.
class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({this.film, super.key});

  final Film? film;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If film not passed via extra, watch nowShowingFilmProvider
    final activeFilm = film ?? ref.watch(nowShowingFilmProvider).asData?.value;

    if (activeFilm == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final partyState = ref.watch(watchPartyNotifierProvider);
    final party = partyState.party;
    final isUpcoming = activeFilm.isUpcoming;
    final start = activeFilm.premiereStart;
    final end = activeFilm.premiereEnd;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // --- Film Poster Header ---
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PosterImage(url: activeFilm.thumbnailUrl),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.4, 0.85, 1.0],
                        colors: [
                          Colors.black54,
                          Colors.transparent,
                          Colors.black87,
                          Colors.black,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // --- Content Body ---
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  activeFilm.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                if ((activeFilm.description ?? '').isNotEmpty)
                  Text(
                    activeFilm.description!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      activeFilm.genre ?? 'Drama • Comedy',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (activeFilm.durationMinutes != null)
                      Text(
                        'Duration: ${Formatters.runtime(activeFilm.durationMinutes!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // --- Countdown OR Doors Close Action ---
                if (isUpcoming && start != null) ...[
                  CountdownBuilder(
                    target: start,
                    builder: (_, remaining) => _CountdownCard(remaining: remaining),
                  ),
                  const SizedBox(height: 14),
                  AppButton(
                    label: 'Add to Calendar',
                    style: AppButtonStyle.outline,
                    icon: Icons.calendar_today_outlined,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Added to calendar!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  if (end != null)
                    CountdownBuilder(
                      target: end,
                      builder: (_, remaining) => Row(
                        children: [
                          const Icon(
                            Icons.fiber_manual_record,
                            size: 10,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Doors close in ${Formatters.hoursMinutes(remaining)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Row(
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          size: 10,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Doors close in 41h 12m',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  AppButton(
                    label: 'Start Premiere',
                    onPressed: () {
                      // Trigger playback authorization
                      context.push(RoutePaths.player, extra: activeFilm.title);
                    },
                  ),
                ],
                const SizedBox(height: 24),
                // --- Guest Passes Card ---
                _GuestPassesCard(
                  usedPasses: party.usedPasses,
                  totalPasses: party.totalPasses,
                  onInvite: () => context.push(RoutePaths.hostParty),
                ),
                const SizedBox(height: 20),
                // --- House Rules Card ---
                const _HouseRulesCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final hours = remaining.inHours.toString().padLeft(2, '0');
    final mins = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TimeUnit(value: hours, label: 'Hrs'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              _TimeUnit(value: mins, label: 'Mins'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              _TimeUnit(value: secs, label: 'Secs'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeUnit extends StatelessWidget {
  const _TimeUnit({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _GuestPassesCard extends StatelessWidget {
  const _GuestPassesCard({
    required this.usedPasses,
    required this.totalPasses,
    required this.onInvite,
  });

  final int usedPasses;
  final int totalPasses;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Guest Passes',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  text: '$usedPasses',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  children: [
                    TextSpan(
                      text: '/$totalPasses',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          InkWell(
            onTap: onInvite,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Text(
                    'Invite to party',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 14, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseRulesCard extends StatelessWidget {
  const _HouseRulesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'House Rules',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 14),
          _RuleItem(text: 'Watch live. No skipping ahead of the premiere'),
          SizedBox(height: 12),
          _RuleItem(text: 'Rewind up to 10 minutes behind where you are'),
          SizedBox(height: 12),
          _RuleItem(text: 'Three pauses per premiere. Use them wisely'),
        ],
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
        height: 1.4,
      ),
    );
  }
}
