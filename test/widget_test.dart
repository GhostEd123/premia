import 'package:flutter_test/flutter_test.dart';
import 'package:premia/features/playback/domain/premiere_sync_policy.dart';

void main() {
  group('PremiereSyncPolicy', () {
    late DateTime now;
    late PremiereSyncPolicy policy;

    setUp(() {
      now = DateTime(2026, 10, 1, 20);
      policy = PremiereSyncPolicy(
        elapsedAtAuthorization: const Duration(minutes: 30),
        duration: const Duration(hours: 2),
        clock: () => now,
      );
    });

    test('live edge advances with the wall clock', () {
      now = now.add(const Duration(minutes: 5));
      expect(policy.liveEdge, const Duration(minutes: 35));
    });

    test('cannot skip ahead of live', () {
      expect(policy.clamp(const Duration(minutes: 90)), const Duration(minutes: 30));
    });

    test('rewind is limited to 10 minutes behind live', () {
      expect(policy.clamp(Duration.zero), const Duration(minutes: 20));
    });

    test('isLive within tolerance, behind otherwise', () {
      expect(policy.isLive(const Duration(minutes: 30)), isTrue);
      expect(policy.isLive(const Duration(minutes: 25)), isFalse);
      expect(policy.behindLive(const Duration(minutes: 25)), const Duration(minutes: 5));
    });

    test('live edge is capped at the film duration', () {
      now = now.add(const Duration(hours: 5));
      expect(policy.liveEdge, const Duration(hours: 2));
      expect(policy.hasFinished(const Duration(hours: 2)), isTrue);
    });
  });
}
