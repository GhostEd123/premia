import 'dart:io';

import 'package:crypto/crypto.dart';

import '../constants/app_constants.dart';

/// Certificate pinning check for the API host.
///
/// Compares the SHA-256 of the server's DER certificate with the pins in
/// [AppConstants.pinnedCertSha256]. With no pins configured it accepts the
/// connection (normal TLS validation still applies).
///
/// TODO(security): pin to the production certificate and keep a backup pin;
/// hosts such as Render rotate certificates automatically, so pin the
/// intermediate/CA certificate or update pins before every rotation.
class CertificatePinning {
  CertificatePinning({String pins = AppConstants.pinnedCertSha256})
      : _pins = pins
            .split(',')
            .map((p) => p.trim().toLowerCase().replaceAll(':', ''))
            .where((p) => p.isNotEmpty)
            .toSet();

  final Set<String> _pins;

  bool get isEnabled => _pins.isNotEmpty;

  bool validate(X509Certificate? certificate, String host, int port) {
    if (!isEnabled) return true;
    if (certificate == null) return false;
    return _pins.contains(sha256.convert(certificate.der).toString());
  }
}
