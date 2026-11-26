import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/calendar_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/application/auth_notifier.dart';
import '../../films/application/films_notifier.dart';
import '../../films/domain/film.dart';
import '../application/watch_party_notifier.dart';

/// The Lobby screen where ticket-holders wait, manage watch-party passes,
/// view house rules, and start the premiere when doors open.
class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({this.film, super.key});

  final Film? film;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _addedToCalendar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTicketCapacity());
  }

  void _syncTicketCapacity() {
    final session = ref.read(authNotifierProvider).magicLinkSession;
    if (session != null) {
      // log("CHECKING TICKET TYPE: ${session.ticketType}");
      ref
          .read(watchPartyNotifierProvider.notifier)
          .configureForTicket(
            ticketType: session.ticketType,
            filmId: session.filmId ?? widget.film?.id,
          );
      ref
          .read(watchPartyNotifierProvider.notifier)
          .fetchLobby(
            ticketId: session.claimedTicketId,
            partyId: session.partyId,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider, (prev, next) {
      final session = next.magicLinkSession;
      if (session != null && prev?.magicLinkSession != session) {
        ref
            .read(watchPartyNotifierProvider.notifier)
            .configureForTicket(
              ticketType: session.ticketType,
              filmId: session.filmId ?? widget.film?.id,
            );
        ref
            .read(watchPartyNotifierProvider.notifier)
            .fetchLobby(
              ticketId: session.claimedTicketId,
              partyId: session.partyId,
            );
      }
    });

    final partyState = ref.watch(watchPartyNotifierProvider);
    final party = partyState.party;
    final session = ref.watch(authNotifierProvider).magicLinkSession;
    final isHost = (session?.isHost ?? true) && party.isHost;

    // If guest is on the lobby screen and the host starts the premiere, auto-route to player
    ref.listen(
      watchPartyNotifierProvider.select((s) => s.partyStartedEvent),
      (prev, next) {
        if (next != null && prev != next && !isHost) {
          final isTopCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
          if (!isTopCurrentRoute) return;
          final filmForPlayer =
              widget.film ??
              party.film ??
              ref.read(nowShowingFilmProvider).asData?.value;
          if (mounted) {
            context.push(
              RoutePaths.player,
              extra: filmForPlayer?.title ?? 'Premiere',
            );
          }
        }
      },
    );

    // If film not passed via extra, watch party.film or nowShowingFilmProvider
    final activeFilm =
        widget.film ??
        party.film ??
        ref.watch(nowShowingFilmProvider).asData?.value;

    if (activeFilm == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

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
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.marquee);
                }
              },
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
                const SizedBox(height: 16),
                // --- Countdown OR Doors Close Action ---
                if (isUpcoming && start != null) ...[
                  CountdownBuilder(
                    target: start,
                    builder: (_, remaining) =>
                        _CountdownCard(remaining: remaining),
                  ),
                  const SizedBox(height: 14),
                  AppButton(
                    label: _addedToCalendar
                        ? 'Added to Calendar'
                        : 'Add to Calendar',
                    style: AppButtonStyle.outline,
                    icon: _addedToCalendar
                        ? Icons.check
                        : Icons.calendar_today_outlined,
                    onPressed: () async {
                      setState(() => _addedToCalendar = true);
                      await CalendarLauncher.addPremiereToCalendar(
                        title: activeFilm.title,
                        description: activeFilm.description,
                        premiereStart: activeFilm.premiereStart,
                        premiereEnd: activeFilm.premiereEnd,
                        durationMinutes: activeFilm.durationMinutes,
                      );
                    },
                  ),
                ] else ...[
                  const Divider(color: AppColors.border, height: 20),
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
                    label: isHost ? 'Start Premiere' : 'Join Premiere',
                    onPressed: () {
                      // Trigger playback authorization (Host starts, Guest joins)
                      context.push(RoutePaths.player, extra: activeFilm.title);
                    },
                  ),
                ],
                if (isHost) ...[
                  const SizedBox(height: 24),
                  // --- Guest Passes Card (Host only) ---
                  _GuestPassesCard(
                    usedPasses: party.usedPasses,
                    totalPasses: party.totalPasses,
                    hasPassesRemaining: party.hasPassesRemaining,
                    onInvite: () => context.push(RoutePaths.hostParty),
                  ),
                ],
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
    required this.hasPassesRemaining,
    required this.onInvite,
  });

  final int usedPasses;
  final int totalPasses;
  final bool hasPassesRemaining;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final buttonText = hasPassesRemaining
        ? 'Invite to party'
        : 'See guest list';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.8, -0.6),
          radius: 1.4,
          colors: [
            AppColors.primary.withValues(alpha: 0.28),
            AppColors.surface,
          ],
        ),
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
              child: Row(
                children: [
                  Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: Colors.white,
                  ),
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
          Divider(color: AppColors.border, height: 24),
          _RuleItem(text: 'Rewind up to 10 minutes behind where you are'),
          Divider(color: AppColors.border, height: 24),
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
