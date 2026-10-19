/// Every route path in one place; screens never use raw strings.
abstract class RoutePaths {
  RoutePaths._();

  static const String splash = '/splash';
  static const String marquee = '/';
  static const String upcoming = '/upcoming';
  static const String checkout = '/checkout';
  static const String paymentPending = '/payment-pending';
  static const String enterLink = '/enter-link';

  /// Deep-link target for the emailed magic link: `/auth/verify?token=...`.
  static const String verify = '/auth/verify';
  static const String player = '/player';
}
