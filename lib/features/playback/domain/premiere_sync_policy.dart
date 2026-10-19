/// Pure rules that keep a viewer in sync with the premiere.
///
/// The backend returns `elapsedTime` (seconds into the film at authorization
/// time). From then on the "live edge" advances with the wall clock. The
/// player must start at the live edge, may rewind at most [maxRewind] behind
/// it, and can never skip ahead of it.
class PremiereSyncPolicy {
  PremiereSyncPolicy({
    required this.elapsedAtAuthorization,
    required this.duration,
    DateTime Function()? clock,
    this.maxRewind = const Duration(minutes: 10),
    this.liveTolerance = const Duration(seconds: 5),
  })  : _clock = clock ?? DateTime.now,
        _authorizedAt = (clock ?? DateTime.now)();

  final Duration elapsedAtAuthorization;
  final Duration duration;
  final Duration maxRewind;

  /// How far behind the live edge still counts as "Live".
  final Duration liveTolerance;

  final DateTime Function() _clock;
  final DateTime _authorizedAt;

  /// The furthest position the viewer may be at right now.
  Duration get liveEdge {
    final edge = elapsedAtAuthorization + _clock().difference(_authorizedAt);
    return edge > duration ? duration : edge;
  }

  /// The earliest position the viewer may rewind to right now.
  Duration get earliest {
    final e = liveEdge - maxRewind;
    return e < Duration.zero ? Duration.zero : e;
  }

  /// Clamps [target] into the allowed `[earliest, liveEdge]` range.
  Duration clamp(Duration target) {
    final lo = earliest;
    final hi = liveEdge;
    if (target < lo) return lo;
    if (target > hi) return hi;
    return target;
  }

  Duration behindLive(Duration position) {
    final d = liveEdge - position;
    return d.isNegative ? Duration.zero : d;
  }

  bool isLive(Duration position) => behindLive(position) <= liveTolerance;

  /// True once playback has reached the end of the film.
  bool hasFinished(Duration position) =>
      duration > Duration.zero &&
      position >= duration - const Duration(seconds: 1);
}
