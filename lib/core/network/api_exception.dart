/// The only error type upstream code (repositories, use cases, notifiers)
/// catches. Pure Dart so the domain layer may reference it.
///
/// [message] is always user-safe; raw exception text never reaches the UI.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.body});

  static const String unexpectedResponse = 'Unexpected response from the server.';

  final String message;
  final int? statusCode;
  final Object? body;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}
