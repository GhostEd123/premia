import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/application/auth_notifier.dart';
import '../application/playback_notifier.dart';
import '../domain/playback_authorization.dart';
import '../domain/premiere_sync_policy.dart';

enum _Phase { authorizing, loading, playing, ended, error }

/// Landscape premiere player.
///
/// Rules enforced here (all derived from the backend's `elapsedTime`):
/// - starts at the synced live position;
/// - can rewind at most 10 minutes behind live and never skip ahead of it;
/// - pauses and hides the picture while the screen is being captured;
/// - the stream only plays via the signed, short-lived playback token.
/// Pausing is unrestricted: the premiere keeps going live while paused.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({required this.title, super.key});

  final String title;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  VideoPlayerController? _controller;
  PremiereSyncPolicy? _policy;
  Timer? _hideTimer;
  _Phase _phase = _Phase.authorizing;
  String? _errorMessage;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authorize());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller
      ?..removeListener(_onTick)
      ..dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // --- Authorization & setup ---

  Future<void> _authorize() async {
    final ticketId = ref.read(authNotifierProvider).magicLinkSession?.claimedTicketId;
    if (ticketId == null || ticketId.isEmpty) {
      _fail('Open your ticket link to start the premiere.');
      return;
    }
    setState(() => _phase = _Phase.authorizing);
    await ref.read(playbackNotifierProvider.notifier).authorizeHost(ticketId: ticketId);
  }

  Future<void> _startPlayback(PlaybackAuthorization auth) async {
    if (AppConstants.cloudflareCustomerCode.isEmpty) {
      _fail('Streaming is not configured (missing CLOUDFLARE_CUSTOMER_CODE).');
      return;
    }
    setState(() => _phase = _Phase.loading);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(AppConstants.streamManifestUrl(auth.playbackToken)),
    );
    _controller = controller;
    try {
      await controller.initialize();
      final policy = PremiereSyncPolicy(
        elapsedAtAuthorization: auth.seekPosition,
        duration: controller.value.duration,
      );
      _policy = policy;
      if (policy.hasFinished(auth.seekPosition)) {
        if (mounted) setState(() => _phase = _Phase.ended);
        return;
      }
      await controller.seekTo(policy.clamp(auth.seekPosition));
      controller.addListener(_onTick);
      await controller.play();
      if (!mounted) return;
      setState(() => _phase = _Phase.playing);
      _scheduleHide();
    } catch (_) {
      _fail('We couldn’t load the premiere. Please try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _errorMessage = message;
    });
  }

  // --- Playback rules ---

  void _onTick() {
    final c = _controller;
    final policy = _policy;
    if (c == null || policy == null || _phase != _Phase.playing) return;
    final position = c.value.position;

    if (policy.hasFinished(position)) {
      c.pause();
      if (mounted) setState(() => _phase = _Phase.ended);
      return;
    }
    // Never ahead of live (e.g. after a stall that jumped forward).
    if (position > policy.liveEdge + const Duration(seconds: 2)) {
      c.seekTo(policy.liveEdge);
    }
  }

  Future<void> _seekTo(Duration target) async {
    final c = _controller;
    final policy = _policy;
    if (c == null || policy == null) return;
    await c.seekTo(policy.clamp(target));
    _scheduleHide();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
    _scheduleHide();
  }

  // --- Controls visibility ---

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Leave the premiere?'),
        content: const Text(
          'The premiere keeps going live while you’re away. Your ticket is '
          'single-viewing, so make sure you can come back before the window closes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep watching'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if ((leave ?? false) && mounted) context.pop();
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    ref.listen(playbackNotifierProvider, (prev, next) {
      final auth = next.authorization;
      if (auth != null && prev?.authorization != auth) _startPlayback(auth);
      if (next.error != null && next.error != prev?.error) _fail(next.error!);
      if (next.isScreenCaptured && prev?.isScreenCaptured != true) {
        _controller?.pause();
      }
    });
    final captured = ref.watch(playbackNotifierProvider).isScreenCaptured;

    return PopScope(
      canPop: _phase != _Phase.playing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: switch (_phase) {
          _Phase.authorizing || _Phase.loading => const _Spinner(),
          _Phase.error => _MessageView(
              message: _errorMessage ?? 'Something went wrong.',
              primaryLabel: 'Try again',
              onPrimary: _authorize,
              onClose: () => context.pop(),
            ),
          _Phase.ended => _MessageView(
              message: 'The premiere has ended. Thanks for watching!',
              primaryLabel: 'Close',
              onPrimary: () => context.pop(),
              onClose: () => context.pop(),
            ),
          _Phase.playing => captured ? const _CaptureBlocked() : _buildPlayer(),
        },
      ),
    );
  }

  Widget _buildPlayer() {
    final controller = _controller!;
    final policy = _policy!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) => Stack(
              fit: StackFit.expand,
              children: [
                if (value.isBuffering) const _Spinner(),
                AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: _Controls(
                      title: widget.title,
                      value: value,
                      policy: policy,
                      onClose: _confirmExit,
                      onTogglePlay: _togglePlay,
                      onSeek: _seekTo,
                      onJumpToLive: () => _seekTo(policy.liveEdge),
                    ),
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

// --- Controls overlay ---

class _Controls extends StatefulWidget {
  const _Controls({
    required this.title,
    required this.value,
    required this.policy,
    required this.onClose,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onJumpToLive,
  });

  final String title;
  final VideoPlayerValue value;
  final PremiereSyncPolicy policy;
  final VoidCallback onClose;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onJumpToLive;

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  double? _dragSeconds;

  @override
  Widget build(BuildContext context) {
    final policy = widget.policy;
    final value = widget.value;
    final total = value.duration;
    final position = value.position;
    final behind = policy.behindLive(position);
    final isLive = policy.isLive(position);
    final shownSeconds = _dragSeconds ?? position.inSeconds.toDouble();
    final totalSeconds = total.inSeconds < 1 ? 1.0 : total.inSeconds.toDouble();

    final canRewind = position > policy.earliest + const Duration(seconds: 1);
    final canForward = !isLive;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.65),
            Colors.black.withValues(alpha: 0.25),
            Colors.black.withValues(alpha: 0.75),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 44,
                    tooltip: 'Back 10 seconds',
                    icon: const Icon(Icons.replay_10),
                    color: canRewind ? Colors.white : Colors.white38,
                    onPressed: canRewind
                        ? () => widget.onSeek(position - const Duration(seconds: 10))
                        : null,
                  ),
                  const SizedBox(width: 48),
                  IconButton(
                    iconSize: 64,
                    tooltip: value.isPlaying ? 'Pause' : 'Play',
                    icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: widget.onTogglePlay,
                  ),
                  const SizedBox(width: 48),
                  IconButton(
                    iconSize: 44,
                    tooltip: 'Forward 10 seconds',
                    icon: const Icon(Icons.forward_10),
                    color: canForward ? Colors.white : Colors.white38,
                    onPressed: canForward
                        ? () => widget.onSeek(position + const Duration(seconds: 10))
                        : null,
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Text(Formatters.clock(Duration(seconds: shownSeconds.round())), style: const TextStyle(fontSize: 12)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Colors.white24,
                        secondaryActiveTrackColor: Colors.white54,
                        thumbColor: Colors.white,
                        overlayShape: SliderComponentShape.noOverlay,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        min: 0,
                        max: totalSeconds,
                        value: shownSeconds.clamp(0, totalSeconds).toDouble(),
                        secondaryTrackValue:
                            policy.liveEdge.inSeconds.toDouble().clamp(0, totalSeconds).toDouble(),
                        onChanged: (v) {
                          final clamped = policy.clamp(Duration(seconds: v.round()));
                          setState(() => _dragSeconds = clamped.inSeconds.toDouble());
                        },
                        onChangeEnd: (v) {
                          final target = Duration(seconds: (_dragSeconds ?? v).round());
                          setState(() => _dragSeconds = null);
                          widget.onSeek(target);
                        },
                      ),
                    ),
                  ),
                  Text(Formatters.clock(total), style: const TextStyle(fontSize: 12)),
                ],
              ),
              Row(
                children: [
                  _LiveBadge(isLive: isLive, behind: behind),
                  const Spacer(),
                  if (!isLive)
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: widget.onJumpToLive,
                      child: const Text('Jump to Live', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isLive, required this.behind});

  final bool isLive;
  final Duration behind;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.fiber_manual_record,
          size: 10,
          color: isLive ? AppColors.primary : AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Text(
          isLive ? 'Live' : '-${Formatters.clock(behind)} Behind live',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// --- Simple states ---

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2));
}

class _CaptureBlocked extends StatelessWidget {
  const _CaptureBlocked();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Screen recording detected.\nPlayback is paused until it stops.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onClose,
  });

  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  AppButton(label: primaryLabel, onPressed: onPrimary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
