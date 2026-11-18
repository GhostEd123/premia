/// Every route path in one place; screens never use raw strings.
abstract class RoutePaths {
  RoutePaths._();

  static const String splash = '/splash';
  static const String marquee = '/';
  static const String upcoming = '/upcoming';
  static const String checkout = '/checkout';
  static const String paymentPending = '/payment-pending';
  static const String enterLink = '/enter-link';

  static const String lobby = '/lobby';
  static const String hostParty = '/host-party';

  /// Deep-link target for the emailed magic link: `/auth/verify?token=...`.
  static const String verify = '/auth/verify';
  static const String player = '/player';

  /// Guest watch party link: `/watch?inviteToken=...&filmId=...`.
  static const String watch = '/watch';
}
