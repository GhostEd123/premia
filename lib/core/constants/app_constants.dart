/// Global constants. Environment values are supplied with `--dart-define`:
///
/// ```
/// flutter run \
///   --dart-define=API_BASE_URL=http://10.0.2.2:3000/api \
///   --dart-define=PINNED_CERT_SHA256=<hex>,<backup-hex>
/// ```
abstract class AppConstants {
  AppConstants._();

  static const String appName = 'Premia';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://premia-frontend-prev.onrender.com/api',
  );

  /// Socket.IO base URL for Watch Party WebSockets.
  static const String socketBaseUrl = String.fromEnvironment(
    'SOCKET_BASE_URL',
    defaultValue: 'https://premia-frontend-prev.onrender.com',
  );

  /// Comma-separated lowercase hex SHA-256 fingerprints of the accepted
  /// server certificates (DER). Include at least one backup pin so a
  /// certificate rotation does not lock users out. Empty disables pinning.
  static const String pinnedCertSha256 = String.fromEnvironment(
    'PINNED_CERT_SHA256',
  );

  /// Header carrying the per-install device identifier.
  static const String deviceIdHeader = 'X-Device-Id';

  /// Nigerian statutory Value Added Tax (7.5%).
  static const double vatPercentage = 7.5;
  static const double vatMultiplier = 1.075;

  /// Mux HLS streaming base URL.
  static const String streamBaseUrl = 'https://stream.mux.com';

  /// Public Mux HLS manifest URL for a film trailer:
  /// `https://stream.mux.com/<trailerStreamId>.m3u8`
  static String trailerManifestUrl(String trailerStreamId) {
    final id = trailerStreamId.trim();
    if (id.startsWith('http://') || id.startsWith('https://')) {
      return id;
    }
    return '$streamBaseUrl/$id.m3u8';
  }

  /// Signed Mux HLS manifest URL for a premiere movie stream:
  /// `https://stream.mux.com/<streamId>.m3u8?token=<playbackToken>`
  static String streamManifestUrl(
    String playbackToken, {
    required String streamId,
  }) {
    final id = streamId.trim();
    final token = playbackToken.trim();
    return '$streamBaseUrl/$id.m3u8?token=$token';
  }
}
