import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common_widgets.dart';
import '../domain/film.dart';
import 'film_details_sheet.dart';

/// Detail page for a premiere that has not started: poster, countdown and a
/// "Get a Ticket" + Calendar call to action.
class UpcomingFilmScreen extends StatefulWidget {
  const UpcomingFilmScreen({required this.film, super.key});

  final Film film;

  @override
  State<UpcomingFilmScreen> createState() => _UpcomingFilmScreenState();
}

class _UpcomingFilmScreenState extends State<UpcomingFilmScreen> {
  bool _addedToCalendar = false;

  @override
  Widget build(BuildContext context) {
    final film = widget.film;
    final start = film.premiereStart;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: PosterImage(url: film.thumbnailUrl)),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.3, 0.7],
                  colors: [Colors.transparent, Colors.black],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () => FilmDetailsSheet.show(
                        context,
                        film,
                        autoPlayTrailer: true,
                      ),
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
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (start != null)
                        Text(
                          'Premieres ${Formatters.premiereDate(start)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        film.title,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.1),
                      ),
                      if ((film.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          film.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                        ),
                      ],
                      const SizedBox(height: 6),
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
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward, size: 16, color: AppColors.primary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(film.genre ?? '', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                          if (film.durationMinutes != null)
                            Text(
                              'Duration: ${Formatters.runtime(film.durationMinutes!)}',
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                      if (start != null) ...[
                        const SizedBox(height: 16),
                        _Countdown(target: start),
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
                          SizedBox(
                            width: AppDimens.controlHeight,
                            height: AppDimens.controlHeight,
                            child: OutlinedButton(
                              onPressed: () {
                                setState(
                                  () => _addedToCalendar = !_addedToCalendar,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.surfaceHigh,
                                    content: Text(
                                      _addedToCalendar
                                          ? '${film.title} added to calendar!'
                                          : 'Removed from calendar',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: _addedToCalendar
                                      ? Colors.white
                                      : AppColors.border,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusControl,
                                  ),
                                ),
                              ),
                              child: Icon(
                                _addedToCalendar
                                    ? Icons.check
                                    : Icons.calendar_today_outlined,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: GestureDetector(
                          onTap: () => context.push(RoutePaths.enterLink),
                          child: const Text.rich(
                            TextSpan(
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              children: [
                                TextSpan(text: 'Already have a pass? Open the '),
                                TextSpan(
                                  text: 'Link',
                                  style: TextStyle(color: Colors.white, decoration: TextDecoration.underline),
                                ),
                                TextSpan(text: ' in your email.'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
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

class _Countdown extends StatelessWidget {
  const _Countdown({required this.target});

  final DateTime target;

  @override
  Widget build(BuildContext context) {
    return CountdownBuilder(
      target: target,
      builder: (_, remaining) {
        String two(int n) => n.toString().padLeft(2, '0');
        final hours = remaining.inHours;
        final mins = remaining.inMinutes % 60;
        final secs = remaining.inSeconds % 60;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Unit(value: two(hours), label: 'Hrs'),
              const _Colon(),
              _Unit(value: two(mins), label: 'Mins'),
              const _Colon(),
              _Unit(value: two(secs), label: 'Secs'),
            ],
          ),
        );
      },
    );
  }
}

class _Unit extends StatelessWidget {
  const _Unit({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _Colon extends StatelessWidget {
  const _Colon();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Text(':', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
      );
}
