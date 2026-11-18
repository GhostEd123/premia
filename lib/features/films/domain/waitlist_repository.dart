/// Contract for waitlist lead capture. Implemented in `data/`.
abstract class WaitlistRepository {
  /// POST /waitlist — registers an email or phone for premiere alerts.
  Future<String> submitWaitlist({String? email, String? phone});
}

