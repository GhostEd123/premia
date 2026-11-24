import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common_widgets.dart';
import '../application/films_notifier.dart';
import '../domain/film.dart';

/// Full-screen modal sheet displaying the auto-playing trailer, ticket &
/// calendar actions, credits, and viewing rights ("View details" / poster play).
class FilmDetailsSheet extends StatefulWidget {
  const FilmDetailsSheet({
    required this.film,
    this.autoPlayTrailer = true,
    super.key,
  });

  final Film film;
  final bool autoPlayTrailer;

  static Future<void> show(
    BuildContext context,
    Film film, {
    bool autoPlayTrailer = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (_) => FilmDetailsSheet(
        film: film,
        autoPlayTrailer: autoPlayTrailer,
      ),
    );
  }

  @override
  State<FilmDetailsSheet> createState() => _FilmDetailsSheetState();
}

class _FilmDetailsSheetState extends State<FilmDetailsSheet> {
  bool _addedToCalendar = false;

  @override
  Widget build(BuildContext context) {
    final film = widget.film;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _TrailerPlayerHeader(
            film: film,
            autoPlay: widget.autoPlayTrailer,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text(
                  film.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                if ((film.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    film.description!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                AppButton(
                  label: 'Get a Ticket',
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push(RoutePaths.checkout, extra: film);
                  },
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: _addedToCalendar ? 'Added to Calendar' : 'Add to Calendar',
                  style: AppButtonStyle.outline,
                  icon: _addedToCalendar
                      ? Icons.check
                      : Icons.calendar_today_outlined,
                  onPressed: () {
                    setState(() => _addedToCalendar = !_addedToCalendar);
                  },
                ),
                if (film.directors.isNotEmpty)
                  _Section(
                    title: 'Directors',
                    body: film.directors.join(' • '),
                  ),
                if (film.cast.isNotEmpty)
                  _Section(
                    title: 'Cast',
                    body: film.cast.join(' • '),
                  ),
                if ((film.genre ?? '').isNotEmpty)
                  _Section(
                    title: 'Genre',
                    body: film.genre!,
                  ),
                if ((film.studio ?? '').isNotEmpty)
                  _Section(
                    title: 'Studio',
                    body: film.studio!,
                  ),
                if (film.durationMinutes != null)
                  _Section(
                    title: 'Runtime',
                    body: Formatters.runtime(film.durationMinutes!),
                  ),
                const _Section(
                  title: 'Viewing Rights',
                  body: _viewingRights,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const String _viewingRights =
    'Each Premia ticket gives you access to one premiere during its premiere window, typically 48 to 72 hours (as shown on the marquee page). You can start watching any time after the premiere goes live, until the window closes. You can\'t skip ahead of the premiere\'s live point. You can rewind up to 10 minutes behind the furthest point you\'ve watched, and you can pause up to 3 times. If your ticket includes Guest Passes, invited friends can join your Watch Party during the same window. Once the window closes, the premiere is no longer available.';

class _TrailerPlayerHeader extends ConsumerStatefulWidget {
  const _TrailerPlayerHeader({
    required this.film,
    required this.autoPlay,
    required this.onBack,
  });

  final Film film;
  final bool autoPlay;
  final VoidCallback onBack;

  @override
  ConsumerState<_TrailerPlayerHeader> createState() =>
      _TrailerPlayerHeaderState();
}

class _TrailerPlayerHeaderState extends ConsumerState<_TrailerPlayerHeader> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initTrailer();
  }

  Future<String?> _resolveTrailerUrl() async {
    var raw = widget.film.trailerUrl?.trim();
    if (raw == null || raw.isEmpty) {
      // If the Film object was cached before trailerStreamId was parsed,
      // fetch the fresh film details from the backend.
      try {
        final fresh = await ref.read(getNowShowingFilmProvider)();
        if (fresh != null && fresh.id == widget.film.id) {
          raw = fresh.trailerUrl?.trim();
        }
        if (raw == null || raw.isEmpty) {
          final byId = await ref.read(getFilmByIdProvider)(widget.film.id);
          raw = byId.trailerUrl?.trim();
        }
      } catch (e) {
        debugPrint('[TrailerStreamError] Failed to refresh film for trailerStreamId: $e');
      }
    }
    if (raw == null || raw.isEmpty) return null;
    return AppConstants.trailerManifestUrl(raw);
  }

  Future<void> _initTrailer() async {
    _controller
      ?..removeListener(_onTick)
      ..dispose();
    _controller = null;

    setState(() {
      _initialized = false;
      _isLoading = true;
      _errorMessage = null;
    });

    final url = await _resolveTrailerUrl();
    if (!mounted) return;

    if (url == null) {
      debugPrint(
        '[TrailerStreamError] Missing trailerStreamId for film '
        '"${widget.film.title}" (id: ${widget.film.id}).',
      );
      setState(() {
        _isLoading = false;
        _errorMessage = 'Trailer unavailable for this film.';
      });
      return;
    }

    debugPrint('[TrailerStream] Streaming trailer from Mux: $url');
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      controller.addListener(_onTick);
      if (widget.autoPlay) {
        await controller.play();
      }
      if (mounted) {
        setState(() {
          _initialized = true;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      final desc = controller.value.errorDescription;
      debugPrint(
        '[TrailerStreamError] Failed to initialize trailer stream for '
        '"${widget.film.title}" (url: $url): $e'
        '${desc != null ? ' | controllerError: $desc' : ''}\n$st',
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = desc ?? 'Unable to stream trailer ($e)';
        });
      }
    }
  }

  void _onTick() {
    final c = _controller;
    if (c != null && c.value.hasError && _errorMessage == null) {
      final desc = c.value.errorDescription ?? 'Unknown trailer playback error';
      debugPrint(
        '[TrailerStreamError] Asynchronous playback error for '
        '"${widget.film.title}": $desc',
      );
      if (mounted) {
        setState(() {
          _errorMessage = desc;
        });
      }
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ?..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !_initialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
  }

  String _formatMinSec(Duration d) {
    final mins = d.inMinutes;
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final position = _initialized && c != null ? c.value.position : Duration.zero;
    final duration = _initialized && c != null ? c.value.duration : Duration.zero;
    final isPlaying = _initialized && c != null && c.value.isPlaying;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: GestureDetector(
        onTap: _togglePlay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_initialized && c != null)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              )
            else
              PosterImage(url: widget.film.thumbnailUrl),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.35, 0.75, 1.0],
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87,
                  ],
                ),
              ),
            ),
            // Top-left Back arrow
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: widget.onBack,
              ),
            ),
            if (_errorMessage != null)
              Container(
                color: Colors.black.withValues(alpha: 0.78),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.primary,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _initTrailer,
                      icon: const Icon(
                        Icons.refresh,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      label: const Text(
                        'Retry trailer',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            else ...[
              // Center play / pause button
              Center(
                child: AnimatedOpacity(
                  opacity: isPlaying ? 0.35 : 0.9,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 1.2),
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              // Bottom-left timestamp
              Positioned(
                left: 14,
                bottom: 12,
                child: Text(
                  '${_formatMinSec(position)} / ${_formatMinSec(duration)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              // Bottom progress line
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
