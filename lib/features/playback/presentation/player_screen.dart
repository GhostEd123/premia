import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/application/auth_notifier.dart';
import '../../parties/application/watch_party_notifier.dart';
import '../../parties/domain/watch_party.dart';
import '../../parties/presentation/widgets/pause_premiere_dialog.dart';
import '../../parties/presentation/widgets/watch_party_overlay.dart';
import '../application/playback_notifier.dart';
import '../domain/playback_authorization.dart';
import '../domain/premiere_sync_policy.dart';

enum _Phase { authorizing, waitingForHost, loading, playing, ended, error }

/// Landscape premiere player.
///
/// Rules enforced here (all derived from the backend's `elapsedTime`):
/// - starts at the synced live position;
/// - can rewind at most 10 minutes behind live and never skip ahead of it;
/// - pauses and hides the picture while the screen is being captured;
/// - the stream only plays via the signed, short-lived playback token.
/// Pausing is unrestricted: the premiere keeps going live while paused.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({required this.title, this.inviteToken, super.key});

  final String title;
  final String? inviteToken;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  VideoPlayerController? _controller;
  PremiereSyncPolicy? _policy;
  Timer? _hideTimer;
  Timer? _hostSyncTimer;
  Timer? _guestSyncPollTimer;
  DateTime? _authorizeStartedAt;
  bool _isHostPaused = false;
  bool _isApplyingHostSync = false;
  bool _isStartingPlayback = false;
  String? _activeStreamId;
  _Phase _phase = _Phase.authorizing;
  String? _errorMessage;
  bool _controlsVisible = true;
  bool _chatVisible = false;
  bool _isLocked = false;

  bool get _isGuest {
    final session = ref.read(authNotifierProvider).magicLinkSession;
    return (widget.inviteToken?.isNotEmpty ?? false) ||
        (session != null && !session.isHost);
  }

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
    _hostSyncTimer?.cancel();
    _guestSyncPollTimer?.cancel();
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
    if (_isStartingPlayback || _phase == _Phase.playing) return;
    _authorizeStartedAt = DateTime.now();
    final session = ref.read(authNotifierProvider).magicLinkSession;
    final invite = widget.inviteToken ?? session?.inviteToken;
    if (invite != null && invite.isNotEmpty) {
      setState(() => _phase = _Phase.authorizing);
      await ref.read(playbackNotifierProvider.notifier).authorizeGuest(invite);
      return;
    }
    final ticketId = session?.claimedTicketId;
    if (ticketId == null || ticketId.isEmpty) {
      _fail('Open your ticket link to start the premiere.');
      return;
    }
    setState(() => _phase = _Phase.authorizing);
    await ref
        .read(playbackNotifierProvider.notifier)
        .authorizeHost(ticketId: ticketId);
  }

  Future<void> _startPlayback(PlaybackAuthorization auth) async {
    if (_isStartingPlayback) return;
    if (_phase == _Phase.playing &&
        _controller != null &&
        _controller!.value.isInitialized &&
        _activeStreamId == auth.streamId) {
      return;
    }

    _isStartingPlayback = true;
    _hostSyncTimer?.cancel();
    _guestSyncPollTimer?.cancel();
    final previousController = _controller;
    _controller = null;
    if (previousController != null) {
      previousController.removeListener(_onTick);
      await previousController.dispose();
    }

    if (auth.streamId.trim().isEmpty || auth.playbackToken.trim().isEmpty) {
      _isStartingPlayback = false;
      _fail('Missing Mux streamId or playbackToken from /playback/authorize.');
      return;
    }

    _activeStreamId = auth.streamId;
    setState(() => _phase = _Phase.loading);
    final manifestUrl = AppConstants.streamManifestUrl(
      auth.playbackToken,
      streamId: auth.streamId,
    );
    debugPrint(
      '[MovieStream] Streaming movie from Mux: '
      '${AppConstants.streamBaseUrl}/${auth.streamId.trim()}.m3u8?token=<signed> '
      '(elapsedTime: ${auth.elapsedSeconds}s, partyId: ${auth.partyId})',
    );

    final partyState = ref.read(watchPartyNotifierProvider);
    final effectivePartyId = (auth.partyId?.isNotEmpty ?? false)
        ? auth.partyId!
        : partyState.party.partyId;
    final effectiveSocketToken = (auth.socketToken?.isNotEmpty ?? false)
        ? auth.socketToken!
        : (partyState.party.socketToken ?? '');
    if (effectivePartyId.isNotEmpty && effectiveSocketToken.isNotEmpty) {
      unawaited(
        ref.read(watchPartyNotifierProvider.notifier).connectSocket(
              partyId: effectivePartyId,
              socketToken: effectiveSocketToken,
            ),
      );
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(manifestUrl));
    _controller = controller;
    try {
      await controller.initialize();
      final videoDuration = controller.value.duration;
      // Compensate for the time spent requesting authorization and initializing
      // the HLS manifest so a joining viewer doesn't start behind the live edge.
      final setupLag = _authorizeStartedAt != null
          ? DateTime.now().difference(_authorizeStartedAt!)
          : Duration.zero;
      final compensatedPosition = auth.seekPosition + setupLag;

      // If the backend's elapsedTime exceeds the actual duration of the video
      // asset uploaded to Mux (e.g. a short test clip uploaded for a 95-min
      // film entry), clamp/wrap the seek position so the stream plays instead
      // of immediately terminating as ended.
      final effectiveElapsed =
          (videoDuration > Duration.zero &&
                  compensatedPosition >= videoDuration)
              ? Duration(
                  milliseconds: videoDuration.inMilliseconds > 0
                      ? compensatedPosition.inMilliseconds %
                          videoDuration.inMilliseconds
                      : 0,
                )
              : compensatedPosition;

      final policy = PremiereSyncPolicy(
        elapsedAtAuthorization: effectiveElapsed,
        duration: videoDuration,
      );
      _policy = policy;

      // Start playback first before seeking so Android ExoPlayer binds its
      // video Texture surface cleanly instead of freezing on a single frame.
      await controller.play();

      final latestHostSync =
          ref.read(watchPartyNotifierProvider).hostPlaybackSync;
      Duration initialTarget = effectiveElapsed;
      if (_isGuest && latestHostSync != null) {
        _isHostPaused = latestHostSync.isPaused;
        if (latestHostSync.currentTimeSeconds > 0) {
          initialTarget = latestHostSync.position;
        }
      }

      if (initialTarget > Duration.zero) {
        final clampedInitial = (videoDuration > Duration.zero &&
                initialTarget >= videoDuration)
            ? Duration(
                milliseconds:
                    initialTarget.inMilliseconds % videoDuration.inMilliseconds,
              )
            : initialTarget;
        await controller.seekTo(clampedInitial);
      }

      controller.addListener(_onTick);
      if (_isGuest && _isHostPaused) {
        await controller.pause();
      } else if (!controller.value.isPlaying) {
        await controller.play();
      }
      _isStartingPlayback = false;
      if (!mounted) return;
      setState(() => _phase = _Phase.playing);
      _scheduleHide();

      // If this user is the host of a watch party, broadcast periodic `timeUpdate`
      // heartbeats every 3 seconds so guests stay locked to the host's time & pause state.
      if (!_isGuest && (auth.isWatchParty || effectivePartyId.isNotEmpty)) {
        _startHostSyncBroadcaster();
      } else if (_isGuest && effectivePartyId.isNotEmpty) {
        _startGuestSyncPoller(effectivePartyId);
      }
    } catch (e, st) {
      _isStartingPlayback = false;
      final desc = controller.value.errorDescription;
      debugPrint(
        '[MovieStreamError] Failed to initialize Mux premiere stream '
        '(url: ${AppConstants.streamBaseUrl}/${auth.streamId}.m3u8, '
        'hasDrmToken: ${auth.drmToken != null}): $e'
        '${desc != null ? ' | controllerError: $desc' : ''}\n$st',
      );
      _fail(
        desc != null && desc.isNotEmpty
            ? 'We couldn’t load the premiere: $desc'
            : 'We couldn’t load the premiere ($e)',
      );
    }
  }

  void _fail(String message) {
    debugPrint('[MovieStreamError] Player entered error state: $message');
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
    if (c == null) return;
    if (c.value.hasError && _phase != _Phase.error) {
      final desc = c.value.errorDescription ?? 'Unknown stream playback error';
      debugPrint('[MovieStreamError] Asynchronous VideoPlayer error: $desc');
      _fail('We couldn’t play the premiere: $desc');
      return;
    }
    if (policy == null || _phase != _Phase.playing) return;
    final position = c.value.position;

    if (policy.hasFinished(position)) {
      c.pause();
      if (mounted) setState(() => _phase = _Phase.ended);
      return;
    }
    // Keep guest paused if the host has paused the movie
    if (_isGuest && _isHostPaused && c.value.isPlaying) {
      c.pause();
      return;
    }
    // Never ahead of live (e.g. after a stall that jumped forward).
    if (!_isGuest && position > policy.liveEdge + const Duration(seconds: 2)) {
      c.seekTo(policy.liveEdge);
    }
  }

  void _startHostSyncBroadcaster() {
    _hostSyncTimer?.cancel();
    _broadcastHostState(action: 'sync');
    _hostSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _phase != _Phase.playing) return;
      _broadcastHostState(action: 'sync');
    });
  }

  void _startGuestSyncPoller(String partyId) {
    _guestSyncPollTimer?.cancel();
    _guestSyncPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _phase != _Phase.playing || !_isGuest) return;
      final lastSync = ref.read(watchPartyNotifierProvider).hostPlaybackSync;
      // Only poll REST `/parties/:partyId/sync` if we haven't received a real-time
      // Socket.IO `syncVideo` / `syncTimestamp` event within the last 6 seconds.
      if (lastSync == null ||
          DateTime.now().difference(lastSync.receivedAt) >
              const Duration(seconds: 6)) {
        ref.read(watchPartyNotifierProvider.notifier).pollSync(partyId: partyId);
      }
    });
  }

  void _broadcastHostState({String action = 'sync'}) {
    if (_isGuest) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final posSeconds = c.value.position.inMilliseconds / 1000.0;
    final paused = !c.value.isPlaying;
    ref.read(watchPartyNotifierProvider.notifier).broadcastHostPlaybackState(
          currentTimeSeconds: posSeconds,
          isPaused: paused,
          action: action,
        );
  }

  Future<void> _applyHostPlaybackSync(PartyPlaybackSync sync) async {
    if (!_isGuest || _isApplyingHostSync) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized || _phase != _Phase.playing) return;

    _isApplyingHostSync = true;
    try {
      if (sync.isEnded) {
        await c.pause();
        if (mounted) {
          setState(() => _phase = _Phase.ended);
        }
        return;
      }

      final hostPausedChanged = _isHostPaused != sync.isPaused;
      _isHostPaused = sync.isPaused;
      final isExplicitHostAction =
          sync.action == 'pause' ||
          sync.action == 'play' ||
          sync.action == 'resume' ||
          sync.action == 'seek';

      if (sync.currentTimeSeconds > 0) {
        final videoDuration = c.value.duration;
        var target = sync.position;
        if (videoDuration > Duration.zero && target > videoDuration) {
          target = Duration(
            milliseconds:
                target.inMilliseconds % videoDuration.inMilliseconds,
          );
        }
        final currentPos = c.value.position;
        final driftMs = (currentPos - target).inMilliseconds.abs();
        // On explicit host action (pause / play / seek) snap if > 600ms off;
        // on periodic `syncTimestamp` heartbeats, only seek if drift > 3000ms
        // so HLS doesn't repeatedly seek back to the same 2-4s keyframe!
        final thresholdMs = (isExplicitHostAction || hostPausedChanged)
            ? 600
            : 3000;
        if (driftMs > thresholdMs) {
          await c.seekTo(target);
        }
      }

      if (sync.isPaused) {
        if (c.value.isPlaying) {
          await c.pause();
        }
      } else {
        if (!c.value.isPlaying) {
          await c.play();
        }
      }
      if (hostPausedChanged && mounted) {
        setState(() {});
      }
    } finally {
      _isApplyingHostSync = false;
    }
  }

  Future<void> _seekTo(Duration target) async {
    if (_isGuest) return;
    final c = _controller;
    final policy = _policy;
    if (c == null || policy == null) return;
    await c.seekTo(policy.clamp(target));
    _broadcastHostState(action: 'seek');
    _scheduleHide();
  }

  void _togglePlay() {
    if (_isGuest) return;
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      final partyState = ref.read(watchPartyNotifierProvider);
      PausePremiereDialog.show(
        context,
        pausesRemaining: partyState.pausesRemaining,
        onKeepWatching: () {},
        onConfirmPause: () async {
          ref.read(watchPartyNotifierProvider.notifier).confirmPause();
          await c.pause();
          _broadcastHostState(action: 'pause');
        },
      );
    } else {
      ref.read(watchPartyNotifierProvider.notifier).resume();
      c.play().then((_) => _broadcastHostState(action: 'play'));
    }
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
            child: const Text(
              'Leave',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
    if ((leave ?? false) && mounted) {
      if (!_isGuest) {
        _broadcastHostState(action: 'pause');
        ref.read(watchPartyNotifierProvider.notifier).disconnectSocket();
      }
      context.pop();
    }
  }

  Future<void> _closeAfterPremiereEnded() async {
    final watchPartyNotifier = ref.read(watchPartyNotifierProvider.notifier);
    final authNotifier = ref.read(authNotifierProvider.notifier);
    watchPartyNotifier.resetPartySession();
    await authNotifier.signOut();
    if (!mounted) return;
    context.go(RoutePaths.marquee);
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    ref.listen(playbackNotifierProvider, (prev, next) {
      final auth = next.authorization;
      if (auth != null && prev?.authorization != auth) _startPlayback(auth);
      if (next.isWaitingForHost && prev?.isWaitingForHost != true) {
        setState(() => _phase = _Phase.waitingForHost);
        final partyId = next.waitingPartyId;
        if (partyId != null && partyId.isNotEmpty) {
          unawaited(
            ref
                .read(watchPartyNotifierProvider.notifier)
                .fetchLobby(partyId: partyId),
          );
        }
      }
      if (next.error != null && next.error != prev?.error) _fail(next.error!);
      if (next.isScreenCaptured && prev?.isScreenCaptured != true) {
        _controller?.pause();
      }
    });

    // When `partyStarted` fires over Socket.IO while waiting for host,
    // automatically re-authorize playback so the movie starts immediately.
    ref.listen(
      watchPartyNotifierProvider.select((s) => s.partyStartedEvent),
      (prev, next) {
        if (next != null &&
            next != prev &&
            _phase == _Phase.waitingForHost &&
            mounted) {
          _authorize();
        }
      },
    );

    // Keep guest playback position and play/pause state locked to the host.
    ref.listen(
      watchPartyNotifierProvider.select((s) => s.hostPlaybackSync),
      (prev, next) {
        if (next != null && next != prev && _isGuest && mounted) {
          _applyHostPlaybackSync(next);
        }
      },
    );

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
          _Phase.waitingForHost => _WaitingForHostDialog(
            onClose: () => context.pop(),
          ),
          _Phase.error => _MessageView(
            message: _errorMessage ?? 'Something went wrong.',
            primaryLabel: 'Try again',
            onPrimary: _authorize,
            onClose: () => context.pop(),
          ),
          _Phase.ended => _MessageView(
            message: 'The premiere has ended. Thanks for watching!',
            primaryLabel: 'Close',
            onPrimary: _closeAfterPremiereEnded,
            onClose: _closeAfterPremiereEnded,
          ),
          _Phase.playing => captured ? const _CaptureBlocked() : _buildPlayer(),
        },
      ),
    );
  }

  Widget _buildPlayer() {
    final controller = _controller!;
    final policy = _policy!;
    final partyState = ref.watch(watchPartyNotifierProvider);
    final auth = ref.watch(playbackNotifierProvider).authorization;
    final session = ref.watch(authNotifierProvider).magicLinkSession;
    final ticketType = (auth?.ticketType.isNotEmpty ?? false)
        ? auth!.ticketType
        : (session?.ticketType ?? 'single');
    final showChatAndReactions =
        ticketType != 'single' ||
        _isGuest ||
        (auth?.partyId?.isNotEmpty ?? false) ||
        partyState.party.partyId.isNotEmpty;

    if (_isLocked) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _controlsVisible = !_controlsVisible),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0
                    ? 16 / 9
                    : controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
            if (_controlsVisible)
              Positioned(
                top: 24,
                right: 24,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: 28,
                    tooltip: 'Unlock Screen',
                    icon: const Icon(Icons.lock, color: Colors.white),
                    onPressed: () => setState(() => _isLocked = false),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0
                  ? 16 / 9
                  : controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) => Stack(
              fit: StackFit.expand,
              children: [
                if (value.isBuffering) const _Spinner(),
                if (_isGuest && _isHostPaused)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pause_circle_filled,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Host paused the premiere',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: _Controls(
                      title: widget.title,
                      value: value,
                      policy: policy,
                      pausesRemaining: partyState.pausesRemaining,
                      isGuest: _isGuest,
                      isHostPaused: _isHostPaused,
                      isLocked: _isLocked,
                      showChatButton: showChatAndReactions,
                      chatVisible: _chatVisible,
                      onToggleLock: () =>
                          setState(() => _isLocked = !_isLocked),
                      onToggleChat: () =>
                          setState(() => _chatVisible = !_chatVisible),
                      onClose: _confirmExit,
                      onTogglePlay: _togglePlay,
                      onSeek: _seekTo,
                      onJumpToLive: () => _seekTo(policy.liveEdge),
                    ),
                  ),
                ),
                if (showChatAndReactions)
                  const WatchPartyFloatingLayer(),
                if (showChatAndReactions && _chatVisible)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: WatchPartyOverlay(
                      isExpanded: true,
                      onToggleExpand: () =>
                          setState(() => _chatVisible = false),
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
    required this.pausesRemaining,
    required this.isGuest,
    required this.isHostPaused,
    required this.isLocked,
    required this.showChatButton,
    required this.chatVisible,
    required this.onToggleLock,
    required this.onToggleChat,
    required this.onClose,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onJumpToLive,
  });

  final String title;
  final VideoPlayerValue value;
  final PremiereSyncPolicy policy;
  final int pausesRemaining;
  final bool isGuest;
  final bool isHostPaused;
  final bool isLocked;
  final bool showChatButton;
  final bool chatVisible;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleChat;
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
    final isLive = widget.isGuest || policy.isLive(position);
    final shownSeconds = _dragSeconds ?? position.inSeconds.toDouble();
    final totalSeconds = total.inSeconds < 1 ? 1.0 : total.inSeconds.toDouble();

    final canRewind =
        !widget.isGuest &&
        position > policy.earliest + const Duration(seconds: 1);
    final canForward = !widget.isGuest && !isLive;

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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!widget.isGuest)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '|| -- ${widget.pausesRemaining} pauses left',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        widget.isHostPaused
                            ? 'Paused by Host'
                            : 'Synced with Host',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!widget.isGuest) ...[
                    IconButton(
                      iconSize: 44,
                      tooltip: 'Back 10 seconds',
                      icon: const Icon(Icons.replay_10),
                      color: canRewind ? Colors.white : Colors.white38,
                      onPressed: canRewind
                          ? () => widget.onSeek(
                              position - const Duration(seconds: 10),
                            )
                          : null,
                    ),
                    const SizedBox(width: 32),
                    IconButton(
                      iconSize: 64,
                      tooltip: value.isPlaying ? 'Pause' : 'Play',
                      icon: Icon(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: widget.onTogglePlay,
                    ),
                    const SizedBox(width: 32),
                    IconButton(
                      iconSize: 44,
                      tooltip: 'Forward 10 seconds',
                      icon: const Icon(Icons.forward_10),
                      color: canForward ? Colors.white : Colors.white38,
                      onPressed: canForward
                          ? () => widget.onSeek(
                              position + const Duration(seconds: 10),
                            )
                          : null,
                    ),
                    const SizedBox(width: 24),
                  ],
                  IconButton(
                    iconSize: 28,
                    tooltip: 'Lock screen',
                    icon: const Icon(Icons.lock_open, color: Colors.white70),
                    onPressed: widget.onToggleLock,
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    Formatters.clock(Duration(seconds: shownSeconds.round())),
                    style: const TextStyle(fontSize: 12),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Colors.white24,
                        secondaryActiveTrackColor: Colors.white54,
                        thumbColor: Colors.white,
                        overlayShape: SliderComponentShape.noOverlay,
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: widget.isGuest ? 0 : 7,
                          disabledThumbRadius: 0,
                        ),
                      ),
                      child: Slider(
                        min: 0,
                        max: totalSeconds,
                        value: shownSeconds.clamp(0, totalSeconds).toDouble(),
                        secondaryTrackValue: policy.liveEdge.inSeconds
                            .toDouble()
                            .clamp(0, totalSeconds)
                            .toDouble(),
                        onChanged: widget.isGuest
                            ? null
                            : (v) {
                                final clamped = policy.clamp(
                                  Duration(seconds: v.round()),
                                );
                                setState(
                                  () => _dragSeconds = clamped.inSeconds
                                      .toDouble(),
                                );
                              },
                        onChangeEnd: widget.isGuest
                            ? null
                            : (v) {
                                final target = Duration(
                                  seconds: (_dragSeconds ?? v).round(),
                                );
                                setState(() => _dragSeconds = null);
                                widget.onSeek(target);
                              },
                      ),
                    ),
                  ),
                  Text(
                    Formatters.clock(total),
                    style: const TextStyle(fontSize: 12),
                  ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: widget.onJumpToLive,
                      child: const Text(
                        'Jump to Live',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  if (widget.showChatButton) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      icon: const Icon(Icons.forum_outlined, size: 16),
                      label: const Text(
                        'React & Chat',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: widget.onToggleChat,
                    ),
                  ],
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
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
  );
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

class _WaitingForHostDialog extends StatelessWidget {
  const _WaitingForHostDialog({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onClose,
            ),
          ),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'Waiting for Host',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please wait for the host to start the premiere. Your stream will begin automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
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
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
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
