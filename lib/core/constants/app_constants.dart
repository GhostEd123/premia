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
    defaultValue: 'https://premia-backend.onrender.com/api',
  );

  /// Comma-separated lowercase hex SHA-256 fingerprints of the accepted
  /// server certificates (DER). Include at least one backup pin so a
  /// certificate rotation does not lock users out. Empty disables pinning.
  static const String pinnedCertSha256 = String.fromEnvironment(
    'PINNED_CERT_SHA256',
  );

  /// Header carrying the per-install device identifier.
  static const String deviceIdHeader = 'X-Device-Id';

  /// Cloudflare Stream customer code (the `customer-<code>` subdomain),
  /// supplied with `--dart-define=CLOUDFLARE_CUSTOMER_CODE=<code>`.
  static const String cloudflareCustomerCode = String.fromEnvironment(
    'CLOUDFLARE_CUSTOMER_CODE',
  );

  /// HLS manifest for a signed [playbackToken]. Cloudflare accepts a signed
  /// token in place of the video id.
  static String streamManifestUrl(String playbackToken) =>
      'https://customer-$cloudflareCustomerCode.cloudflarestream.com/'
      '$playbackToken/manifest/video.m3u8';
}
