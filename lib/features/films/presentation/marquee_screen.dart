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
import '../application/films_notifier.dart';
import '../domain/film.dart';
import 'film_details_sheet.dart';
import 'waitlist_sheet.dart';

/// Home: "Premiering now" / "Upcoming Premiers" tabs.
class MarqueeScreen extends ConsumerStatefulWidget {
  const MarqueeScreen({super.key});

  @override
  ConsumerState<MarqueeScreen> createState() => _MarqueeScreenState();
}

class _MarqueeScreenState extends ConsumerState<MarqueeScreen> {
  bool _showUpcoming = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const PremiaLogo(),
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => context.push(RoutePaths.settings),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
              child: Row(
                children: [
                  _TabPill(
                    label: 'Premiering now',
                    selected: !_showUpcoming,
                    onTap: () => setState(() => _showUpcoming = false),
                  ),
                  const SizedBox(width: 8),
                  _TabPill(
                    label: 'Upcoming Premiers',
                    selected: _showUpcoming,
                    onTap: () => setState(() => _showUpcoming = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _showUpcoming
                  ? const _UpcomingList()
                  : const _NowShowing(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.pillLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

// --- Premiering now ---

class _NowShowing extends ConsumerWidget {
  const _NowShowing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final film = ref.watch(nowShowingFilmProvider);
    return film.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => _ErrorRetry(
        message: e.toString(),
        onRetry: () => ref.invalidate(nowShowingFilmProvider),
      ),
      data: (f) =>
          f == null ? const NoActivePremiere() : _NowShowingCard(film: f),
    );
  }
}

class _NowShowingCard extends ConsumerWidget {
  const _NowShowingCard({required this.film});

  final Film film;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final hasTicket = auth.isAuthenticated;
    final isWatchParty = auth.magicLinkSession?.isWatchParty ?? false;
    final start = film.premiereStart;
    final end = film.premiereEnd;
    final countdownTarget = film.isUpcoming
        ? start
        : (end ??
              DateTime.now().add(
                const Duration(hours: 48, minutes: 36, seconds: 9),
              ));

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusCard),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GestureDetector(
            onTap: () =>
                FilmDetailsSheet.show(context, film, autoPlayTrailer: true),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              child: AspectRatio(
                aspectRatio: 0.78,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PosterImage(url: film.thumbnailUrl),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.45, 1],
                          colors: [Colors.transparent, Colors.black],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,  
                      right: 20, 
                      bottom: 6,
                      child: Text(
                        film.title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((film.description ?? '').isNotEmpty)
                  Text(
                    film.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => FilmDetailsSheet.show(
                    context,
                    film,
                    autoPlayTrailer: true,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View details',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _MetaRow(film: film),
                if (hasTicket) ...[
                  if (film.isUpcoming && start != null) ...[
                    const SizedBox(height: 14),
                    _MarqueeCountdownBox(target: start),
                  ] else ...[
                    const Divider(color: AppColors.border, height: 24),
                    if (end != null)
                      CountdownBuilder(
                        target: end,
                        builder: (_, remaining) => Row(
                          children: [
                            const Icon(
                              Icons.fiber_manual_record,
                              size: 12,
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
                            size: 12,
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
                    const Divider(color: AppColors.border, height: 24),
                  ],
                  const SizedBox(height: 16),
                  if (isWatchParty)
                    AppButton(
                      label: 'Go to Lobby',
                      onPressed: () =>
                          context.push(RoutePaths.lobby, extra: film),
                    )
                  else
                    AppButton(
                      label: 'Start Premier',
                      onPressed: () =>
                          context.push(RoutePaths.player, extra: film.title),
                    ),
                ] else ...[
                  if (countdownTarget != null) ...[
                    const SizedBox(height: 14),
                    _MarqueeCountdownBox(target: countdownTarget),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Get a Ticket',
                          onPressed: () =>
                              context.push(RoutePaths.checkout, extra: film),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _CalendarIconButton(film: film),
                    ],
                  ),
                  const _HavePassLink(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarqueeCountdownBox extends StatelessWidget {
  const _MarqueeCountdownBox({required this.target});

  final DateTime target;

  @override
  Widget build(BuildContext context) {
    return CountdownBuilder(
      target: target,
      builder: (_, remaining) {
        String two(int n) => n.toString().padLeft(2, '0');
        final hours = two(remaining.inHours);
        final mins = two(remaining.inMinutes % 60);
        final secs = two(remaining.inSeconds % 60);

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            // crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CountdownUnit(value: hours, label: 'Hrs'),
              SizedBox(width: 24),
              const _CountdownColon(),
              SizedBox(width: 24),
              _CountdownUnit(value: mins, label: 'Mins'),
              SizedBox(width: 24),
              const _CountdownColon(),
              SizedBox(width: 24),
              _CountdownUnit(value: secs, label: 'Secs'),
            ],
          ),
        );
      },
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  const _CountdownUnit({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _CountdownColon extends StatelessWidget {
  const _CountdownColon();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _CalendarIconButton extends StatefulWidget {
  const _CalendarIconButton({required this.film});

  final Film film;

  @override
  State<_CalendarIconButton> createState() => _CalendarIconButtonState();
}

class _CalendarIconButtonState extends State<_CalendarIconButton> {
  bool _added = false;

  Future<void> _openCalendar() async {
    final film = widget.film;
    setState(() => _added = true);
    await CalendarLauncher.addPremiereToCalendar(
      title: film.title,
      description: film.description,
      premiereStart: film.premiereStart,
      premiereEnd: film.premiereEnd,
      durationMinutes: film.durationMinutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppDimens.controlHeight,
      height: AppDimens.controlHeight,
      child: OutlinedButton(
        onPressed: _openCalendar,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.white,
          side: BorderSide(color: _added ? Colors.white : AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusControl),
          ),
        ),
        child: Icon(
          _added ? Icons.check : Icons.calendar_today_outlined,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.film});

  final Film film;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12.5, color: AppColors.textSecondary);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(film.genre ?? '', style: style),
        if (film.durationMinutes != null)
          Text(
            'Duration: ${Formatters.runtime(film.durationMinutes!)}',
            style: style,
          ),
      ],
    );
  }
}

class _HavePassLink extends StatelessWidget {
  const _HavePassLink();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: Text.rich(
          TextSpan(
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            children: [
              const TextSpan(text: 'Already have a pass? Open the '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: () => context.push(RoutePaths.enterLink),
                  child: const Text(
                    'Link',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const TextSpan(text: ' in your email.'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state with the waitlist call to action.
class NoActivePremiere extends StatelessWidget {
  const NoActivePremiere({this.title = 'No active premiere', super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [AppColors.primary.withValues(alpha: 0.35), Colors.black],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.theaters_outlined,
            size: 96,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Join the VIP / Waitlist to be notified about upcoming premieres.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Join Waitlist',
            style: AppButtonStyle.outline,
            icon: Icons.event_outlined,
            onPressed: () => WaitlistSheet.show(context),
          ),
        ],
      ),
    );
  }
}

// --- Upcoming ---

class _UpcomingList extends ConsumerWidget {
  const _UpcomingList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final films = ref.watch(filmsNotifierProvider);
    return films.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => _ErrorRetry(
        message: e.toString(),
        onRetry: () => ref.invalidate(filmsNotifierProvider),
      ),
      data: (all) {
        final upcoming = all.where((f) => f.isUpcoming).toList()
          ..sort((a, b) => a.premiereStart!.compareTo(b.premiereStart!));
        if (upcoming.isEmpty) {
          return const NoActivePremiere(title: 'No upcoming premiere');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: upcoming.length + 1,
          separatorBuilder: (_, _) =>
              const Divider(color: AppColors.border, height: 24),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Coming to the Marquee',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${upcoming.length} ${upcoming.length == 1 ? 'Premier' : 'Premiers'}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              );
            }
            return _UpcomingRow(film: upcoming[i - 1]);
          },
        );
      },
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.film});

  final Film film;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(RoutePaths.upcoming, extra: film),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 56,
              height: 72,
              child: PosterImage(url: film.thumbnailUrl),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (film.premiereStart != null)
                  Text(
                    Formatters.premiereDate(film.premiereStart!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                Text(
                  film.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (film.durationMinutes != null)
                  Text(
                    Formatters.runtime(film.durationMinutes!),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: AppButton(label: 'Try again', onPressed: onRetry),
            ),
          ],
        ),
      ),
    );
  }
}
