import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var screenChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerScreenProtection(engineBridge)
  }

  /// iOS cannot block screen capture, so report recording/mirroring state to
  /// Dart, which pauses playback while `captured == true`.
  private func registerScreenProtection(_ engineBridge: FlutterImplicitEngineBridge) {
    guard let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "ScreenProtection")?.messenger() else { return }
    let channel = FlutterMethodChannel(name: "premia/screen_protection", binaryMessenger: messenger)
    screenChannel = channel

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "enable", "disable":
        result(nil)
      case "isCaptured":
        result(UIScreen.main.isCaptured)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.screenChannel?.invokeMethod("captureChanged", arguments: UIScreen.main.isCaptured)
    }
  }
}
