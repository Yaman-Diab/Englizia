import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Kept here: a stream handler lives as long as its channel needs it.
  private let screenCapture = ScreenCaptureStream()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FlutterMethodChannel(
      name: "englizia/mail_app",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      guard call.method == "open", let mail = URL(string: "message://") else {
        result(FlutterMethodNotImplemented)
        return
      }
      UIApplication.shared.open(mail) { opened in result(opened) }
    }
    FlutterMethodChannel(
      name: "englizia/links",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      guard call.method == "open", let text = call.arguments as? String,
        let link = URL(string: text)
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      UIApplication.shared.open(link) { opened in result(opened) }
    }
    FlutterMethodChannel(
      name: "englizia/screen_awake",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      guard call.method == "set", let on = call.arguments as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }
      UIApplication.shared.isIdleTimerDisabled = on
      result(nil)
    }
    FlutterEventChannel(
      name: "englizia/screen_capture",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setStreamHandler(screenCapture)
  }
}

/// Whether the screen is being recorded or mirrored, sent at once and on
/// every change. iOS can't keep a screenshot from being taken, so a lesson's
/// video hides itself while this says true.
final class ScreenCaptureStream: NSObject, FlutterStreamHandler {
  private var observer: NSObjectProtocol?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    events(UIScreen.main.isCaptured)
    observer = NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { _ in
      events(UIScreen.main.isCaptured)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer = observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
    return nil
  }
}
