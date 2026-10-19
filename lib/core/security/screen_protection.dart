import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridge to native screen-capture protection.
///
/// - Android: `FLAG_SECURE` blocks screenshots/recording and hides the app in
///   the recents switcher.
/// - iOS: the OS cannot block capture, so the native side reports when the
///   screen is being recorded/mirrored; [captureChanges] emits that state so
///   playback can be paused.
class ScreenProtection {
  ScreenProtection() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'captureChanged') {
        _captureController.add(call.arguments == true);
      }
    });
  }

  static const MethodChannel _channel = MethodChannel('premia/screen_protection');

  final StreamController<bool> _captureController =
      StreamController<bool>.broadcast();

  /// Emits `true` while the screen is being captured, `false` otherwise.
  Stream<bool> get captureChanges => _captureController.stream;

  Future<void> enable() => _invoke('enable');

  Future<void> disable() => _invoke('disable');

  /// Whether the screen is currently being recorded or mirrored.
  Future<bool> isCaptured() async {
    try {
      return await _channel.invokeMethod<bool>('isCaptured') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Unsupported platform (tests, desktop): nothing to protect.
    }
  }
}

final screenProtectionProvider = Provider<ScreenProtection>((ref) => ScreenProtection());
