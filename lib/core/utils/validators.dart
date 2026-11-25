/// Pure input validators: return an error message, or null when valid.
abstract class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(v)) return 'Enter a valid email address.';
    return null;
  }

  /// Extracts the magic-link token from a pasted URL (`...?token=XYZ`) or
  /// returns the input when it already looks like a bare token.
  static String? magicLinkToken(String input) {
    final v = input.trim();
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(v);
    final fromQuery = uri?.queryParameters['token'];
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
    if (v.contains(RegExp(r'\s')) || v.contains('/')) return null;
    return v;
  }

  /// Extracts a guest watch-party `inviteToken` from a pasted URL
  /// (`...?inviteToken=XYZ`). Returns null if the input is not an invite link.
  static String? inviteTokenFromUrl(String input) {
    final v = input.trim();
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(v);
    final fromQuery = uri?.queryParameters['inviteToken'];
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
    return null;
  }
}
